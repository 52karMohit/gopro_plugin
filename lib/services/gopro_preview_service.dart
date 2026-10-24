import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'gopro_constants.dart';
import 'gopro_http_service.dart';

enum GoProStreamState { idle, connecting, streaming, error }

class GoProPreviewService extends ChangeNotifier {
  final GoProHttpService httpService;

  Player? _player;
  VideoController? _videoController;
  VideoController? get videoController => _videoController;

  GoProStreamState _state = GoProStreamState.idle;
  GoProStreamState get state => _state;
  bool get isStreaming => _state == GoProStreamState.streaming;
  bool get isConnecting => _state == GoProStreamState.connecting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _streamUrl;
  String? get streamUrl => _streamUrl;

  bool _isDisposed = false;

  GoProPreviewService({required this.httpService});

  Future<bool> startPreview({bool isDemo = false}) async {
    if (isStreaming || isConnecting) return true;

    _errorMessage = null;
    _updateState(GoProStreamState.connecting);

    try {
      if (!isDemo) {
        final ok = await httpService.startPreviewStream(
          port: GoProConstants.defaultStreamPort,
        );
        if (!ok) {
          throw Exception('Camera rejected preview start request (Check Wi-Fi)');
        }
      }

      // The camera pushes UDP to the phone, so listen locally.
      _streamUrl = 'udp://0.0.0.0:${GoProConstants.defaultStreamPort}';

      final player = Player();
      final native = player.platform as NativePlayer;
      await native.setProperty('profile', 'low-latency');
      await native.setProperty('cache', 'no');

      _player = player;
      _videoController = VideoController(player);

      await player.open(Media(_streamUrl!), play: true);

      _updateState(GoProStreamState.streaming);
      return true;
    } catch (e) {
      debugPrint('[GoPro Preview] Failed to start preview: $e');
      await stopPreview();
      _errorMessage = e.toString();
      _updateState(GoProStreamState.error);
      return false;
    }
  }

  Future<void> stopPreview() async {
    final player = _player;
    _player = null;
    _videoController = null;
    _streamUrl = null;
    _updateState(GoProStreamState.idle); // UI removes the Video widget first

    await Future.delayed(const Duration(milliseconds: 100));
    try {
      await player?.dispose();
    } catch (e) {
      debugPrint('[GoPro Preview] Player dispose error: $e');
    }

    if (!_isDisposed) {
      try {
        await httpService.stopPreviewStream();
      } catch (e) {
        debugPrint('[GoPro Preview] Error stopping stream command: $e');
      }
    }
  }

  void _updateState(GoProStreamState newState) {
    if (_isDisposed) return;
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _player?.dispose();
    _player = null;
    _videoController = null;
    super.dispose();
  }
}