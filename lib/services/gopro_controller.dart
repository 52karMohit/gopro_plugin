import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/gopro_models.dart';
import 'gopro_ble_service.dart';
import 'gopro_http_service.dart';
import 'gopro_preview_service.dart';
import 'gopro_wifi_service.dart';

/// Central controller and state manager orchestrating BLE connection,
/// Wi-Fi HTTP API communication, recording states, file creation, and media retrieval.
class GoProController extends ChangeNotifier {
  final GoProBleService bleService = GoProBleService();
  final GoProHttpService httpService = GoProHttpService();
  final GoProWifiService wifiService = GoProWifiService();
  late final GoProPreviewService previewService;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  bool _isDemoMode = false;
  bool get isDemoMode => _isDemoMode;

  List<GoProDevice> _discoveredDevices = [];
  List<GoProDevice> get discoveredDevices => _discoveredDevices;

  GoProDevice? _currentDevice;
  GoProDevice? get currentDevice => _currentDevice;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isBleConnected = false;
  bool get isBleConnected => _isBleConnected;

  bool _isWifiConnected = false;
  bool get isWifiConnected => _isWifiConnected;

  bool _isAutoConnecting = false;
  bool get isAutoConnecting => _isAutoConnecting;

  String? _autoConnectStep;
  String? get autoConnectStep => _autoConnectStep;

  GoProStatus _status = const GoProStatus();
  GoProStatus get status => _status;

  int _recordingSeconds = 0;
  int get recordingSeconds => _recordingSeconds;

  Timer? _recordingTimer;
  Timer? _heartbeatTimer;
  Timer? _statusTimer;

  List<GoProMediaFile> _mediaFiles = [];
  List<GoProMediaFile> get mediaFiles => _mediaFiles;

  bool _isLoadingMedia = false;
  bool get isLoadingMedia => _isLoadingMedia;

  final Map<String, FileDownloadTask> _activeDownloads = {};
  Map<String, FileDownloadTask> get activeDownloads => _activeDownloads;

  List<File> _localSavedFiles = [];
  List<File> get localSavedFiles => _localSavedFiles;

  GoProMediaFile? _lastCreatedFile;
  GoProMediaFile? get lastCreatedFile => _lastCreatedFile;

  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  String _currentMode = 'Video'; // 'Video', 'Photo', 'Timelapse'
  String get currentMode => _currentMode;

  int _simulatedFileCounter = 101;

  GoProController() {
    previewService = GoProPreviewService(httpService: httpService);
    previewService.addListener(notifyListeners);
    _initListeners();
    loadLocalSavedFiles();
  }

  void _initListeners() {
    // BLE listeners
    bleService.discoveredDevicesStream.listen((devices) {
      if (!_isDemoMode) {
        _discoveredDevices = devices;
        notifyListeners();
      }
    });

    bleService.connectionStatusStream.listen((connected) {
      _isBleConnected = connected;
      if (!connected) {
        _isWifiConnected = false;
        _stopHeartbeat();
      }
      notifyListeners();
    });

    bleService.logStream.listen(_addLog);
    httpService.logStream.listen(_addLog);
    wifiService.logStream.listen(_addLog);
  }

  void _addLog(String log) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    _logs.insert(0, '[$time] $log');
    if (_logs.length > 100) {
      _logs.removeLast();
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Demo Mode (Simulator for development & testing without live camera)
  // ---------------------------------------------------------------------------
  void toggleDemoMode(bool enable) {
    _isDemoMode = enable;
    _addLog('Demo / Simulator mode ${enable ? "ENABLED" : "DISABLED"}');

    if (enable) {
      _discoveredDevices = [
        const GoProDevice(
          id: 'SIM-GOPRO-HERO12',
          name: 'GoPro HERO12 Black (Simulated)',
          rssi: -48,
          wifiSsid: 'GP24928172',
          wifiPassword: 'goproheroaction',
        ),
        const GoProDevice(
          id: 'SIM-GOPRO-HERO11',
          name: 'GoPro HERO11 Black (Simulated)',
          rssi: -72,
          wifiSsid: 'GP11093821',
          wifiPassword: 'actioncamerawifi',
        ),
      ];

      // Populate mock media files
      _generateDemoMediaFiles();
    } else {
      _discoveredDevices.clear();
      _mediaFiles.clear();
      _isBleConnected = false;
      _isWifiConnected = false;
      _currentDevice = null;
    }
    notifyListeners();
  }

  void _generateDemoMediaFiles() {
    final now = DateTime.now();
    _mediaFiles = [
      GoProMediaFile(
        directory: '100GOPRO',
        filename: 'GX010098.MP4',
        sizeBytes: 154823104, // ~147 MB
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      GoProMediaFile(
        directory: '100GOPRO',
        filename: 'GOPR0099.JPG',
        sizeBytes: 4982100, // ~4.7 MB
        createdAt: now.subtract(const Duration(minutes: 42)),
      ),
      GoProMediaFile(
        directory: '100GOPRO',
        filename: 'GX010100.MP4',
        sizeBytes: 312450000, // ~298 MB
        createdAt: now.subtract(const Duration(minutes: 15)),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // BLE Connection Flow
  // ---------------------------------------------------------------------------
  Future<void> startScan() async {
    _isScanning = true;
    notifyListeners();

    if (_isDemoMode) {
      _addLog('Scanning for simulated GoPro devices...');
      await Future.delayed(const Duration(milliseconds: 900));
      _isScanning = false;
      notifyListeners();
      return;
    }

    await bleService.startScan();
    _isScanning = bleService.isScanning;
    notifyListeners();
  }

  Future<void> stopScan() async {
    if (!_isDemoMode) {
      await bleService.stopScan();
    }
    _isScanning = false;
    notifyListeners();
  }

  Future<bool> connectDevice(GoProDevice device) async {
    _currentDevice = device;
    _addLog('Initiating connection to ${device.name}...');
    notifyListeners();

    if (_isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 800));
      _isBleConnected = true;
      _currentDevice = device.copyWith(
        isBleConnected: true,
        wifiSsid: device.wifiSsid ?? 'GoPro 9283',
        wifiPassword: device.wifiPassword ?? 'actionpro99',
      );
      _status = const GoProStatus(batteryPercent: 92);
      _addLog('Connected to simulated ${device.name} via BLE!');
      notifyListeners();
      return true;
    }

    final success = await bleService.connect(device.id);
    if (success) {
      _isBleConnected = true;
      // Fetch Wi-Fi SSID and Password over BLE
      final creds = await bleService.readWifiCredentials();
      _currentDevice = device.copyWith(
        isBleConnected: true,
        wifiSsid: creds['ssid'],
        wifiPassword: creds['password'],
      );
      _addLog('BLE connection established. Wi-Fi SSID: ${creds['ssid']}');
      notifyListeners();
    }
    return success;
  }

  /// 1-Click Direct Auto-Connect:
  /// Connects BLE -> Turns on Camera Wi-Fi Hotspot -> Reads Credentials ->
  /// Automatically connects mobile Wi-Fi programmatically -> Verifies HTTP session & starts keep-alive!
  ///
  /// [manualPassword]: optional override password if BLE credential read fails.
  Future<bool> oneClickAutoConnect(
    GoProDevice device, {
    String? manualPassword,
  }) async {
    _isAutoConnecting = true;
    _autoConnectStep = 'Connecting to ${device.name} over BLE...';
    _addLog('🚀 1-Click Auto-Connect started for ${device.name}');
    notifyListeners();

    try {
      // ── Step 1: BLE connect ──────────────────────────────────────────────
      final bleOk = await connectDevice(device);
      if (!bleOk) {
        throw Exception('Could not connect to camera via BLE');
      }

      // ── Step 2: Power on Camera Wi-Fi AP ─────────────────────────────────
      _autoConnectStep = 'Powering on Camera Wi-Fi Hotspot...';
      notifyListeners();
      await enableWifiAp();

      // GoPro typically needs 2–4 s after the AP command before credentials are valid.
      _autoConnectStep = 'Waiting for hotspot to start...';
      notifyListeners();
      await Future.delayed(const Duration(seconds: 3));

      // ── Step 3: Read SSID / Password from BLE characteristics ────────────
      _autoConnectStep = 'Reading Wi-Fi credentials from camera...';
      notifyListeners();

      final creds = await bleService.readWifiCredentials(retries: 3);
      final rawSsid = creds['ssid'] ?? '';
      final rawPassword = creds['password'] ?? '';

      // Resolve SSID — prefer BLE read, then device cache, then manual override
      final ssid = rawSsid.isNotEmpty
          ? rawSsid
          : (_currentDevice?.wifiSsid?.isNotEmpty == true
                ? _currentDevice!.wifiSsid!
                : (device.wifiSsid?.isNotEmpty == true
                      ? device.wifiSsid!
                      : ''));

      final password = rawPassword.isNotEmpty
          ? rawPassword
          : (manualPassword?.isNotEmpty == true
                ? manualPassword!
                : (_currentDevice?.wifiPassword ?? device.wifiPassword ?? ''));

      if (ssid.isEmpty) {
        _addLog(
          '⚠️ SSID could not be read from camera BLE. '
          'Ensure camera has paired and Wi-Fi AP is active. '
          'You can enter the SSID/password manually below.',
        );
        _autoConnectStep = 'SSID unresolved — enter credentials manually';
        _isAutoConnecting = false;
        notifyListeners();
        return false;
      }

      _currentDevice = _currentDevice?.copyWith(
        wifiSsid: ssid,
        wifiPassword: password,
      );

      _addLog('✅ Wi-Fi credentials resolved — SSID: "$ssid"');

      // ── Step 4: Programmatically join camera Wi-Fi network ───────────────
      _autoConnectStep = 'Connecting phone to "$ssid"...';
      notifyListeners();

      if (!_isDemoMode) {
        final wifiSuccess = await wifiService.connectToCameraWifi(
          ssid: ssid,
          password: password,
        );
        _addLog('Wi-Fi association result: $wifiSuccess');
        if (!wifiSuccess) {
          _addLog(
            '⚠️ Programmatic Wi-Fi join failed. '
            'On Android 10+, please connect manually to "$ssid" in Wi-Fi settings, '
            'then tap "Ping & Connect" in Advanced Settings.',
          );
          _autoConnectStep = 'Wi-Fi connection failed';
          _isAutoConnecting = false;
          notifyListeners();
          return false;
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 700));
      }

      // ── Step 5: Verify HTTP session ──────────────────────────────────────
      _autoConnectStep = 'Verifying camera HTTP connection...';
      notifyListeners();

      _addLog('Waiting for network routing to settle...');
      await Future.delayed(const Duration(seconds: 4));

      final httpOk = await connectWifiHttp(
        host: device.gatewayIp,
        port: device.port,
      );

      if (httpOk) {
        _autoConnectStep = '✅ Connected to GoPro successfully!';
        _addLog('1-Click Direct Connect succeeded!');
        _isAutoConnecting = false;
        notifyListeners();
        return true;
      } else {
        _autoConnectStep = 'Retrying HTTP verification...';
        notifyListeners();
        await Future.delayed(const Duration(seconds: 3));
        final retryOk = await connectWifiHttp(
          host: device.gatewayIp,
          port: device.port,
        );
        _autoConnectStep = retryOk
            ? '✅ Connected to GoPro!'
            : '⚠️ HTTP unreachable — check Wi-Fi is connected to "$ssid"';
        _isAutoConnecting = false;
        notifyListeners();
        return retryOk;
      }
    } catch (e) {
      _addLog('❌ 1-Click Connect error: $e');
      _autoConnectStep = 'Error: $e';
      _isAutoConnecting = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> enableWifiAp() async {
    _addLog('Enabling GoPro Wi-Fi Access Point...');
    if (_isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 600));
      _addLog(
        'GoPro Wi-Fi Access Point is now ON (SSID: ${_currentDevice?.wifiSsid})',
      );
      return true;
    }
    final success = await bleService.enableWifiAp();
    if (success) {
      // Small delay for camera to spin up its Wi-Fi AP, then fetch credentials
      await Future.delayed(const Duration(milliseconds: 1500));
      final creds = await bleService.readWifiCredentials();
      if ((creds['ssid'] != null && creds['ssid']!.isNotEmpty) ||
          (creds['password'] != null && creds['password']!.isNotEmpty)) {
        _currentDevice = _currentDevice?.copyWith(
          wifiSsid: creds['ssid']?.isNotEmpty == true
              ? creds['ssid']
              : _currentDevice?.wifiSsid,
          wifiPassword: creds['password']?.isNotEmpty == true
              ? creds['password']
              : _currentDevice?.wifiPassword,
        );
        _addLog(
          'Camera AP Credentials ready: SSID=${_currentDevice?.wifiSsid}',
        );
        notifyListeners();
      }
    }
    return success;
  }

  /// Connect to the camera's HTTP API over Wi-Fi
  Future<bool> connectWifiHttp({String? host, int? port}) async {
    final targetHost = host ?? _currentDevice?.gatewayIp ?? httpService.host;
    final targetPort = port ?? _currentDevice?.port ?? httpService.port;

    httpService.updateEndpoint(host: targetHost, port: targetPort);
    _addLog('Verifying HTTP connection to $targetHost:$targetPort...');

    if (_isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      _isWifiConnected = true;
      _currentDevice = _currentDevice?.copyWith(isWifiConnected: true);
      _startHeartbeat();
      _addLog('Connected to GoPro Wi-Fi HTTP API (Simulated)!');
      notifyListeners();
      return true;
    }

    final isMobile = Platform.isAndroid || Platform.isIOS;

    if (!isMobile) {
      _addLog('Skipping Wi-Fi connectivity check on non-mobile platform');
    } else {
      final currentSsid = await wifiService.getCurrentSsid();
      final expectedSsid = _currentDevice?.wifiSsid;
      _addLog(
        'SSID check - Current: "${currentSsid ?? "None"}", Expected: "${expectedSsid ?? "None"}"',
      );

      final normalizedCurrent = (currentSsid ?? '').replaceAll('"', '').trim();
      // Android 10+ returns "<unknown ssid>" (or nothing) unless location
      // permission AND location services are on. In that case we cannot tell,
      // so let the HTTP ping decide instead of failing here.
      final ssidUnreadable =
          normalizedCurrent.isEmpty ||
          normalizedCurrent.toLowerCase() == '<unknown ssid>';

      if (expectedSsid != null && expectedSsid.isNotEmpty) {
        final normalizedExpected = expectedSsid.replaceAll('"', '').trim();
        if (ssidUnreadable) {
          _addLog(
            '⚠️ Current SSID is unreadable (grant location permission and '
            'turn on location services). Skipping SSID check; trying HTTP ping.',
          );
        } else if (normalizedCurrent.toLowerCase() !=
            normalizedExpected.toLowerCase()) {
          _addLog(
            '⚠️ Phone is not connected to GoPro Wi-Fi network "$expectedSsid". '
            'Current SSID: $normalizedCurrent. Please connect manually in Wi-Fi settings.',
          );
          notifyListeners();
          return false;
        } else {
          _addLog(
            '✅ SSID verification passed: connected to $normalizedCurrent',
          );
        }
      } else {
        _addLog('⚠️ Expected SSID is empty, skipping SSID verification');
      }

      // Pin ALL app traffic (HTTP + native UDP video) to the Wi-Fi network so
      // Android doesn't route it over mobile data (the camera has no internet).
      await wifiService.bindProcessToWifi();
    }

    // Retry HTTP ping with exponential backoff for network routing to settle
    int maxRetries = 5;
    int retryDelayMs = 1000;
    bool ok = false;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      _addLog(
        'HTTP ping attempt $attempt/$maxRetries to $targetHost:$targetPort...',
      );
      ok = await httpService.pingCamera();
      if (ok) {
        break;
      }
      if (attempt < maxRetries) {
        _addLog('Ping failed, retrying in ${retryDelayMs}ms...');
        await Future.delayed(Duration(milliseconds: retryDelayMs));
        retryDelayMs *= 2;
      }
    }

    if (ok) {
      _isWifiConnected = true;
      _currentDevice = _currentDevice?.copyWith(isWifiConnected: true);
      _startHeartbeat();
      _pollCameraStatus();
      _addLog('Connected to GoPro Wi-Fi HTTP API at $targetHost:$targetPort!');
      fetchMediaList();
    } else {
      _addLog(
        'Could not reach GoPro at $targetHost:$targetPort after $maxRetries attempts. '
        'Make sure your phone is connected to the camera\'s Wi-Fi network and the camera is powered on.',
      );
      if (isMobile) await wifiService.releaseWifiBinding();
    }
    notifyListeners();
    return ok;
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_isWifiConnected && !_isDemoMode) {
        await httpService.sendKeepAlive();
      }
    });

    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_isWifiConnected && !_isDemoMode) {
        _pollCameraStatus();
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  Future<void> _pollCameraStatus() async {
    final newStatus = await httpService.getCameraState();
    if (newStatus != null) {
      _status = newStatus;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Recording & Shutter Controls
  // ---------------------------------------------------------------------------
  String get formattedRecordingTime {
    final m = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_recordingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void setCaptureMode(String mode) {
    _currentMode = mode;
    _status = _status.copyWith(currentMode: mode);
    _addLog('Switched capture mode to $mode');

    if (!_isDemoMode) {
      if (_isBleConnected) {
        bleService.setPresetMode(mode);
      }
      if (_isWifiConnected) {
        final presetId = mode == 'Photo'
            ? 65536
            : mode == 'Timelapse'
            ? 131072
            : 0;
        httpService.loadPreset(presetId);
      }
    }
    notifyListeners();
  }

  /// Start Recording (Video) or Trigger Shutter (Photo)
  Future<bool> startRecording() async {
    if (_status.isRecording) {
      _addLog('Recording already in progress');
      return false;
    }

    _addLog('Starting recording / shutter trigger...');
    bool success = false;

    if (_isDemoMode) {
      success = true;
    } else if (_isWifiConnected) {
      success = await httpService.startRecording();
    } else if (_isBleConnected) {
      success = await bleService.startRecording();
    } else {
      _addLog('Cannot start recording: No active BLE or Wi-Fi connection');
      return false;
    }

    if (success) {
      if (_currentMode == 'Photo') {
        _addLog('Photo captured!');
        unawaited(_syncCreatedFileFromCamera(isVideo: false));
      } else {
        _status = _status.copyWith(isRecording: true);
        _recordingSeconds = 0;
        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _recordingSeconds++;
          notifyListeners();
        });
        _addLog('Video recording started!');

        // Auto-start the preview, but don't block the shutter UI on it.
        if (!previewService.isStreaming &&
            !previewService.isConnecting &&
            (_isWifiConnected || _isDemoMode)) {
          _addLog('Auto-starting camera preview during recording...');
          unawaited(startCameraPreview());
        }
      }
      notifyListeners();
    }

    return success;
  }

  /// Stop Recording (Video)
  Future<bool> stopRecording() async {
    if (!_status.isRecording) {
      _addLog('No recording active to stop');
      return false;
    }

    _addLog('Stopping recording...');
    bool success = false;

    if (_isDemoMode) {
      success = true;
    } else if (_isWifiConnected) {
      success = await httpService.stopRecording();
    } else if (_isBleConnected) {
      success = await bleService.stopRecording();
    }

    if (success) {
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _status = _status.copyWith(isRecording: false);
      _addLog('Recording stopped. Total duration: $formattedRecordingTime');

      // Look up the real file the camera just finalized (demo: simulated).
      unawaited(_syncCreatedFileFromCamera(isVideo: true));

      // Automatically stop camera preview when recording ends
      if (previewService.isStreaming || previewService.isConnecting) {
        _addLog('Auto-stopping camera preview after recording...');
        await stopCameraPreview();
      }
      notifyListeners();
    }

    return success;
  }

  /// Tag highlight moment
  Future<bool> tagHighlight() async {
    _addLog('Tagging highlight moment...');
    if (_isDemoMode) {
      _addLog('Highlight moment tagged!');
      return true;
    }
    if (_isWifiConnected) {
      return await httpService.tagMoment();
    } else if (_isBleConnected) {
      return await bleService.tagHighlight();
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // File Creation & Tracking
  // ---------------------------------------------------------------------------

  /// After a capture, ask the camera for its real media list and use the newest
  /// entry as [lastCreatedFile]. In demo mode a fake file is created instead.
  Future<void> _syncCreatedFileFromCamera({required bool isVideo}) async {
    if (_isDemoMode) {
      _handleCreatedFile(isVideo: isVideo);
      return;
    }
    if (!_isWifiConnected) {
      _addLog('Wi-Fi not connected; cannot look up the new file on the camera');
      return;
    }
    await Future.delayed(const Duration(seconds: 2)); // let camera finalize
    final files = await httpService.fetchMediaList();
    if (files.isEmpty) return;
    _mediaFiles = files;
    _lastCreatedFile = files.first; // list is sorted newest first
    _addLog('New file on SD card: ${_lastCreatedFile!.filename}');
    notifyListeners();
  }

  /// Demo mode only: fabricates a file entry.
  void _handleCreatedFile({required bool isVideo}) {
    _simulatedFileCounter++;
    final pad = _simulatedFileCounter.toString().padLeft(4, '0');
    final filename = isVideo ? 'GX01$pad.MP4' : 'GOPR$pad.JPG';
    final randomBytes = isVideo
        ? (50 * 1024 * 1024 + Random().nextInt(150 * 1024 * 1024))
        : (4 * 1024 * 1024 + Random().nextInt(3 * 1024 * 1024));

    final newFile = GoProMediaFile(
      directory: '100GOPRO',
      filename: filename,
      sizeBytes: randomBytes,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );

    _lastCreatedFile = newFile;
    _mediaFiles.insert(0, newFile);
    _addLog(
      'New file created on SD card: ${newFile.filename} (${newFile.formattedSize})',
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Media Listing & File Retrieval
  // ---------------------------------------------------------------------------
  Future<void> fetchMediaList() async {
    _isLoadingMedia = true;
    notifyListeners();

    if (_isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 600));
      _isLoadingMedia = false;
      _addLog('Fetched ${_mediaFiles.length} media files (Demo)');
      notifyListeners();
      return;
    }

    _addLog('Retrieving media list from GoPro SD card...');
    final files = await httpService.fetchMediaList();
    _mediaFiles = files;
    _isLoadingMedia = false;
    _addLog('Found ${_mediaFiles.length} media files on GoPro');
    notifyListeners();
  }

  /// Download / retrieve a file from the GoPro to mobile device storage
  Future<void> retrieveFile(GoProMediaFile file) async {
    final key = file.relativePath;
    if (_activeDownloads.containsKey(key) &&
        _activeDownloads[key]?.status == 'downloading') {
      _addLog('Download already in progress for ${file.filename}');
      return;
    }

    _activeDownloads[key] = FileDownloadTask(
      file: file,
      status: 'downloading',
      progress: 0.0,
      totalBytes: file.sizeBytes,
    );
    notifyListeners();

    _addLog(
      'Starting retrieval of ${file.filename} (${file.formattedSize})...',
    );

    if (_isDemoMode) {
      final appDir = await getApplicationDocumentsDirectory();
      final localMediaDir = Directory('${appDir.path}/GoProMedia');
      if (!await localMediaDir.exists()) {
        await localMediaDir.create(recursive: true);
      }
      final localFile = File('${localMediaDir.path}/${file.filename}');

      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
        final progress = i / 10.0;
        final received = (file.sizeBytes * progress).round();
        _activeDownloads[key] = FileDownloadTask(
          file: file,
          status: 'downloading',
          progress: progress,
          bytesDownloaded: received,
          totalBytes: file.sizeBytes,
        );
        notifyListeners();
      }

      await localFile.writeAsString(
        'GoPro Open API Sample file data for ${file.filename}',
      );
      await loadLocalSavedFiles();

      _activeDownloads[key] = FileDownloadTask(
        file: file.copyWith(isDownloaded: true, localFilePath: localFile.path),
        status: 'completed',
        progress: 1.0,
        bytesDownloaded: file.sizeBytes,
        totalBytes: file.sizeBytes,
        savedFile: localFile,
      );

      _updateMediaFileDownloadedState(file.filename, localFile.path);
      _addLog('Download completed! Saved to ${localFile.path}');
      notifyListeners();
      return;
    }

    // Real camera download
    final savedFile = await httpService.downloadFile(
      mediaFile: file,
      onProgress: (received, total, progress) {
        _activeDownloads[key] = FileDownloadTask(
          file: file,
          status: 'downloading',
          progress: progress,
          bytesDownloaded: received,
          totalBytes: total,
        );
        notifyListeners();
      },
    );

    if (savedFile != null) {
      _activeDownloads[key] = FileDownloadTask(
        file: file.copyWith(isDownloaded: true, localFilePath: savedFile.path),
        status: 'completed',
        progress: 1.0,
        bytesDownloaded: file.sizeBytes,
        totalBytes: file.sizeBytes,
        savedFile: savedFile,
      );
      _updateMediaFileDownloadedState(file.filename, savedFile.path);
      await loadLocalSavedFiles();
      _addLog('File retrieved and saved: ${savedFile.path}');
    } else {
      _activeDownloads[key] = FileDownloadTask(
        file: file,
        status: 'error',
        error: 'Download failed. Check Wi-Fi connection.',
      );
      _addLog('Failed to download ${file.filename}');
    }
    notifyListeners();
  }

  void _updateMediaFileDownloadedState(String filename, String path) {
    final index = _mediaFiles.indexWhere((f) => f.filename == filename);
    if (index != -1) {
      _mediaFiles[index] = _mediaFiles[index].copyWith(
        isDownloaded: true,
        localFilePath: path,
      );
    }
  }

  /// Delete file from camera
  Future<bool> deleteFile(GoProMediaFile file) async {
    _addLog('Deleting ${file.filename} from camera...');
    bool success = false;

    if (_isDemoMode) {
      _mediaFiles.removeWhere((f) => f.filename == file.filename);
      success = true;
    } else {
      success = await httpService.deleteFile(file);
      if (success) {
        _mediaFiles.removeWhere((f) => f.filename == file.filename);
      }
    }

    if (success) {
      _addLog('File ${file.filename} deleted successfully');
      notifyListeners();
    }
    return success;
  }

  /// Load files already retrieved and stored on mobile device
  Future<void> loadLocalSavedFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final localMediaDir = Directory('${appDir.path}/GoProMedia');
      if (await localMediaDir.exists()) {
        final entities = await localMediaDir.list().toList();
        _localSavedFiles = entities.whereType<File>().toList();
        _localSavedFiles.sort(
          (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
        );
        notifyListeners();
      }
    } catch (e) {
      _addLog('Error reading local files: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Camera Live Preview Controls
  // ---------------------------------------------------------------------------
  bool get isPreviewActive => previewService.isStreaming;

  Future<bool> startCameraPreview() async {
    _addLog('Starting camera live preview...');
    return await previewService.startPreview(isDemo: _isDemoMode);
  }

  Future<void> stopCameraPreview() async {
    _addLog('Stopping camera live preview...');
    await previewService.stopPreview();
  }

  /// Disconnect completely
  Future<void> disconnect() async {
    _stopHeartbeat();
    await previewService.stopPreview();
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _status = _status.copyWith(isRecording: false);

    if (!_isDemoMode) {
      await bleService.disconnect();
      await wifiService.releaseWifiBinding();
    }
    _isBleConnected = false;
    _isWifiConnected = false;
    _currentDevice = null;
    _addLog('Disconnected from GoPro');
    notifyListeners();
  }

  @override
  void dispose() {
    _stopHeartbeat();
    _recordingTimer?.cancel();
    previewService.dispose();
    wifiService.dispose();
    bleService.dispose();
    httpService.dispose();
    super.dispose();
  }
}
