import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'gopro_constants.dart';
import 'gopro_http_service.dart';

/// Manages GoPro Live Preview streaming using RTMP protocol.
/// Uses WebView with flv.js to play RTMP streams since Flutter's video_player
/// doesn't natively support RTMP.
class GoProPreviewService extends ChangeNotifier {
  final GoProHttpService httpService;

  WebViewController? _webViewController;
  WebViewController? get webViewController => _webViewController;

  bool _isStreaming = false;
  bool get isStreaming => _isStreaming;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _rtmpUrl;
  String? get rtmpUrl => _rtmpUrl;

  GoProPreviewService({required this.httpService});

  /// Start the live camera preview using RTMP
  Future<bool> startPreview({bool isDemo = false}) async {
    if (_isStreaming || _isConnecting) return true;

    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (isDemo) {
        // In Demo Mode, use a sample RTMP stream
        _rtmpUrl = 'rtmp://live.twitch.tv/app/live_549077846_xxxxxxxxxxxxx';
        debugPrint('[GoPro Preview] Demo mode - using sample RTMP stream');
      } else {
        // Start the camera's RTMP stream via HTTP command
        final ok = await httpService.startPreviewStream(
          port: GoProConstants.defaultStreamPort,
        );
        if (!ok) {
          throw Exception('Camera rejected preview start request (Check Wi-Fi)');
        }

        // RTMP URL format: rtmp://<camera_ip>:1935/live
        _rtmpUrl = 'rtmp://${httpService.host}:1935/live';
        debugPrint('[GoPro Preview] Connecting to RTMP stream: $_rtmpUrl');
      }

      // Create WebView controller with flv.js for RTMP playback
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              debugPrint('[GoPro Preview] WebView page loaded');
              _isConnecting = false;
              _isStreaming = true;
              notifyListeners();
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('[GoPro Preview] WebView error: ${error.description}');
              _errorMessage = error.description;
              _isConnecting = false;
              _isStreaming = false;
              notifyListeners();
            },
          ),
        )
        ..loadHtmlString(_getFlvJsHtml(_rtmpUrl!));

      _isStreaming = true;
      _isConnecting = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[GoPro Preview] Failed to start preview: $e');
      _errorMessage = e.toString();
      _isConnecting = false;
      _isStreaming = false;
      await stopPreview();
      notifyListeners();
      return false;
    }
  }

  /// Generate HTML with flv.js for RTMP playback
  String _getFlvJsHtml(String rtmpUrl) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body, html { margin: 0; padding: 0; width: 100%; height: 100%; background: #000; overflow: hidden; }
    #videoElement { width: 100%; height: 100%; object-fit: cover; }
  </style>
  <script src="https://cdn.bootcdn.net/ajax/libs/flv.js/1.6.2/flv.min.js"></script>
</head>
<body>
  <video id="videoElement" muted autoplay playsinline></video>
  <script>
    if (flvjs.isSupported()) {
      var videoElement = document.getElementById('videoElement');
      var flvPlayer = flvjs.createPlayer({
        type: 'flv',
        url: '$rtmpUrl',
        isLive: true,
        hasAudio: false,
        hasVideo: true,
        cors: true
      });
      flvPlayer.attachMediaElement(videoElement);
      flvPlayer.load();
      flvPlayer.play().catch(function(error) {
        console.error('Playback error:', error);
      });
    } else {
      console.error('FLV is not supported');
    }
  </script>
</body>
</html>
''';
  }

  bool _isDisposed = false;

  /// Stop preview streaming and clean up
  Future<void> stopPreview() async {
    _webViewController = null;

    // Send stop command to camera if not disposed
    if (!_isDisposed) {
      try {
        await httpService.stopPreviewStream();
      } catch (_) {}
    }

    _isStreaming = false;
    _isConnecting = false;
    _rtmpUrl = null;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _webViewController = null;
    super.dispose();
  }
}
