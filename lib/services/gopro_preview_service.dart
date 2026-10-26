import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'gopro_constants.dart';
import 'gopro_http_service.dart';

enum GoProStreamState { idle, connecting, streaming, error }

/// Live preview for GoPro cameras (Open GoPro).
///
/// Pipeline:
///   camera --UDP MPEG-TS--> Dart RawDatagramSocket (port 8554)
///          --> loopback HTTP server (127.0.0.1:<random>/gopro.ts)
///          --> mpv (media_kit) --> Video widget
///
/// Why the relay: mpv opening `udp://` directly probes the (still empty) socket
/// and falls back to its "plaintext playlist" demuxer ("Refusing to load
/// potentially unsafe URL from a playlist"). Here the player is created only
/// after the first UDP packet has arrived and is given a plain HTTP MPEG-TS
/// stream, which mpv handles reliably.
class GoProPreviewService extends ChangeNotifier {
  /// Flip to true if frames are received but the picture stays black.
  static const bool useSoftwareDecoding = false;

  static const _firstPacketTimeout = Duration(seconds: 8);
  static const _firstFrameTimeout = Duration(seconds: 12);
  static const _maxPendingPackets = 500; // ~650 KB buffered until mpv connects

  final GoProHttpService httpService;

  Player? _player;
  VideoController? _videoController;
  VideoController? get videoController => _videoController;

  GoProStreamState _state = GoProStreamState.idle;
  GoProStreamState get state => _state;
  bool get isStreaming => _state == GoProStreamState.streaming;
  bool get isConnecting => _state == GoProStreamState.connecting;

  /// True in demo mode (no camera): the UI shows a simulated viewfinder.
  bool _isDemoStream = false;
  bool get isDemoStream => _isDemoStream;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _streamUrl;
  String? get streamUrl => _streamUrl;

  String? _lastPlayerError;

  // Relay state
  RawDatagramSocket? _udp;
  HttpServer? _server;
  HttpResponse? _client;
  final List<Uint8List> _pending = [];
  Completer<void>? _firstPacket;
  int _packets = 0;

  final List<StreamSubscription> _subs = [];
  Timer? _firstFrameTimer;

  // Incremented on every start/stop so stale async continuations can bail out.
  int _session = 0;
  bool _isDisposed = false;

  GoProPreviewService({required this.httpService});

  // ---------------------------------------------------------------------------
  // Start / stop
  // ---------------------------------------------------------------------------

  /// Starts the preview. State becomes `streaming` only once the first video
  /// frame is decoded. Keep-alive is handled by GoProController's heartbeat.
  Future<bool> startPreview({bool isDemo = false}) async {
    if (isStreaming || isConnecting) return true;

    final session = ++_session;
    _errorMessage = null;
    _lastPlayerError = null;

    if (isDemo) {
      _isDemoStream = true;
      _updateState(GoProStreamState.streaming);
      return true;
    }

    _isDemoStream = false;
    _updateState(GoProStreamState.connecting);

    try {
      final port = GoProConstants.defaultStreamPort;

      // 1. Start listening for the camera's UDP stream and expose it on a
      //    loopback HTTP port.
      final relayPort = await _startRelay(port);
      if (session != _session) return false;
      _streamUrl = 'http://127.0.0.1:$relayPort/gopro.ts';

      // 2. Ask the camera to start sending to this phone.
      final ok = await httpService.startPreviewStream(port: port);
      if (session != _session) return false;
      if (!ok) {
        throw Exception(
          'Camera rejected the preview start request (check Wi-Fi connection)',
        );
      }

      // 3. Wait until real video data is actually arriving.
      try {
        await _firstPacket!.future.timeout(_firstPacketTimeout);
      } on TimeoutException {
        throw Exception(
          'Camera accepted the request but no video packets arrived. Make '
          'sure the phone is on the GoPro Wi-Fi and mobile data is not '
          'taking over.',
        );
      }
      if (session != _session) return false;

      // 4. Now create the player (data is flowing, so probing succeeds).
      final player = Player(
        configuration: const PlayerConfiguration(
          logLevel: MPVLogLevel.warn,
          protocolWhitelist: [
            'udp',
            'rtp',
            'tcp',
            'tls',
            'http',
            'https',
            'crypto',
            'data',
          ],
        ),
      );

      // mpv options must be set BEFORE open().
      final native = player.platform as NativePlayer;
      await native.setProperty('profile', 'low-latency');
      await native.setProperty('cache', 'no');
      await native.setProperty('untimed', 'yes');
      await native.setProperty('demuxer', 'lavf');
      await native.setProperty('demuxer-lavf-format', 'mpegts');
      await native.setProperty('demuxer-lavf-probesize', '500000');
      await native.setProperty('demuxer-lavf-analyzeduration', '1');
      await native.setProperty('network-timeout', '20');
      if (useSoftwareDecoding) {
        await native.setProperty('hwdec', 'no');
      }

      final videoController = VideoController(
        player,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: !useSoftwareDecoding,
        ),
      );

      if (session != _session) {
        await player.dispose();
        return false;
      }

      _player = player;
      _videoController = videoController;

      // First decoded frame => real "streaming" state.
      _subs.add(
        player.stream.width.listen((w) {
          if (w != null && w > 0) _onFirstFrame(session);
        }),
      );
      _subs.add(
        player.stream.log.listen(
          (l) => debugPrint('[mpv:${l.level}] ${l.prefix}: ${l.text}'),
        ),
      );
      _subs.add(
        player.stream.error.listen((e) {
          debugPrint('[GoPro Preview] player error: $e');
          if (e.trim().isNotEmpty) _lastPlayerError = e.trim();
        }),
      );

      // Let the UI mount the Video widget (still behind the connecting overlay).
      _notify();

      unawaited(
        player.open(Media(_streamUrl!), play: true).catchError((Object e) {
          debugPrint('[GoPro Preview] open() failed: $e');
          _lastPlayerError = e.toString();
        }),
      );

      // 5. Give up if no frame is decoded.
      _firstFrameTimer = Timer(_firstFrameTimeout, () {
        if (session == _session && isConnecting) {
          final detail = (_lastPlayerError?.isNotEmpty ?? false)
              ? '\nPlayer: $_lastPlayerError'
              : '';
          stopPreview(
            error:
                'Video packets are arriving ($_packets) but the player '
                'could not decode them.$detail',
          );
        }
      });
      return true;
    } catch (e) {
      debugPrint('[GoPro Preview] Failed to start preview: $e');
      await stopPreview(error: e.toString().replaceFirst('Exception: ', ''));
      return false;
    }
  }

  void _onFirstFrame(int session) {
    if (session != _session || !isConnecting) return;
    _firstFrameTimer?.cancel();
    _updateState(GoProStreamState.streaming);
  }

  Future<void> stopPreview({String? error}) async {
    _session++; // invalidate in-flight work
    _firstFrameTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();

    final wasDemo = _isDemoStream;
    _isDemoStream = false;

    final player = _player;
    _player = null;
    _videoController = null;
    _streamUrl = null;
    _errorMessage = error;
    // UI removes the Video widget first
    _updateState(
      error != null ? GoProStreamState.error : GoProStreamState.idle,
    );

    await Future.delayed(const Duration(milliseconds: 100));
    try {
      await player?.dispose();
    } catch (e) {
      debugPrint('[GoPro Preview] Player dispose error: $e');
    }

    await _stopRelay();

    if (!_isDisposed && !wasDemo) {
      try {
        await httpService.stopPreviewStream();
      } catch (e) {
        debugPrint('[GoPro Preview] Error stopping stream command: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // UDP -> loopback HTTP relay
  // ---------------------------------------------------------------------------

  /// Binds the UDP port the camera sends to and a loopback HTTP server mpv
  /// reads from. Returns the HTTP port.
  Future<int> _startRelay(int udpPort) async {
    await _stopRelay();
    _pending.clear();
    _packets = 0;
    _firstPacket = Completer<void>();

    _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, udpPort);
    _udp!.listen(_onUdpEvent);

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_onHttpRequest);
    debugPrint(
      '[GoPro Preview] relay: UDP :$udpPort -> HTTP 127.0.0.1:${_server!.port}',
    );
    return _server!.port;
  }

  void _onUdpEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    Datagram? d;
    while ((d = _udp?.receive()) != null) {
      _onPacket(d!.data);
    }
  }

  void _onPacket(Uint8List data) {
    _packets++;
    if (_packets == 1) {
      debugPrint(
        '[GoPro Preview] first UDP packet received (${data.length} bytes)',
      );
      final c = _firstPacket;
      if (c != null && !c.isCompleted) c.complete();
    }

    final client = _client;
    if (client == null) {
      // mpv hasn't connected yet: keep recent packets (datagram-aligned).
      _pending.add(data);
      if (_pending.length > _maxPendingPackets) _pending.removeAt(0);
    } else {
      try {
        client.add(data);
      } catch (_) {
        _client = null;
      }
    }
  }

  void _onHttpRequest(HttpRequest request) {
    final response = request.response;
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType('video', 'mp2t');
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    response.bufferOutput = false;

    // A newer connection replaces an older one.
    final old = _client;
    if (old != null) {
      unawaited(old.close().catchError((_) => old));
    }

    for (final p in _pending) {
      response.add(p);
    }
    _pending.clear();
    _client = response;
    debugPrint('[GoPro Preview] player connected to relay');

    response.done.catchError((_) => response).whenComplete(() {
      if (identical(_client, response)) _client = null;
    });
  }

  Future<void> _stopRelay() async {
    final client = _client;
    final server = _server;
    final udp = _udp;
    _client = null;
    _server = null;
    _udp = null;
    _pending.clear();

    try {
      udp?.close();
    } catch (_) {}
    try {
      await client?.close();
    } catch (_) {}
    try {
      await server?.close(force: true);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  /// Counts raw UDP packets from the camera for 5 seconds (no player involved).
  /// Wired to a debug-only button on the remote screen.
  Future<String> debugProbeUdp({int? port}) async {
    final p = port ?? GoProConstants.defaultStreamPort;
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, p);
      int packets = 0, bytes = 0;
      socket.listen((e) {
        if (e == RawSocketEvent.read) {
          final d = socket!.receive();
          if (d != null) {
            packets++;
            bytes += d.data.length;
          }
        }
      });

      final ok = await httpService.startPreviewStream(port: p);
      await Future.delayed(const Duration(seconds: 5));
      final result =
          'camera start ok=$ok, received $packets packets / $bytes bytes in 5s';
      debugPrint('[Probe] $result');
      return result;
    } catch (e) {
      debugPrint('[Probe] failed: $e');
      return 'probe failed: $e';
    } finally {
      socket?.close();
      await httpService.stopPreviewStream();
    }
  }

  // ---------------------------------------------------------------------------

  void _updateState(GoProStreamState newState) {
    if (_isDisposed) return;
    _state = newState;
    notifyListeners();
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _session++;
    _firstFrameTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _player?.dispose();
    _player = null;
    _videoController = null;
    unawaited(_stopRelay());
    super.dispose();
  }
}
