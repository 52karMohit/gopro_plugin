import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/gopro_models.dart';
import 'gopro_constants.dart';

/// HTTP Client service for communicating with GoPro camera's Open GoPro REST server
/// over Wi-Fi AP or wired USB connection (default IP: 10.5.5.9:8080).
class GoProHttpService {
  String _host = GoProConstants.defaultCameraIp;
  int _port = GoProConstants.defaultCameraPort;
  final http.Client _client = http.Client();

  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  String get host => _host;
  int get port => _port;
  String get baseUrl => 'http://$_host:$_port';

  void updateEndpoint({String? host, int? port}) {
    if (host != null && host.isNotEmpty) _host = host;
    if (port != null && port > 0) _port = port;
    _log('GoPro HTTP endpoint updated to: $baseUrl');
  }

  void _log(String message) {
    debugPrint('[GoPro HTTP] $message');
    _logController.add(message);
  }

  /// Ping the camera to verify Wi-Fi / HTTP reachability
  Future<bool> pingCamera({Duration timeout = const Duration(seconds: 4)}) async {
    try {
      final uri = Uri.parse('$baseUrl${GoProConstants.endpointKeepAlive}');
      _log('Pinging camera: $uri');
      final response = await _client.get(uri).timeout(timeout);
      final ok = response.statusCode == 200;
      _log('Ping result: statusCode=${response.statusCode}, ok=$ok');
      return ok;
    } catch (e) {
      _log('Ping error: $e');
      return false;
    }
  }

  /// Start recording / trigger capture over HTTP (GET /gopro/camera/shutter/start)
  Future<bool> startRecording() async {
    try {
      final uri = Uri.parse('$baseUrl${GoProConstants.endpointShutterStart}');
      _log('Sending HTTP Shutter Start: $uri');
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _log('Shutter Start succeeded (200 OK)');
        return true;
      } else {
        _log('Shutter Start failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _log('Error sending Shutter Start: $e');
      return false;
    }
  }

  /// Stop recording / release capture over HTTP (GET /gopro/camera/shutter/stop)
  Future<bool> stopRecording() async {
    try {
      final uri = Uri.parse('$baseUrl${GoProConstants.endpointShutterStop}');
      _log('Sending HTTP Shutter Stop: $uri');
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _log('Shutter Stop succeeded (200 OK)');
        return true;
      } else {
        _log('Shutter Stop failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _log('Error sending Shutter Stop: $e');
      return false;
    }
  }

  /// Query camera state and status telemetry (GET /gopro/camera/state)
  Future<GoProStatus?> getCameraState() async {
    try {
      final uri = Uri.parse('$baseUrl${GoProConstants.endpointCameraState}');
      final response = await _client.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final status = GoProStatus.fromJson(decoded);
        return status;
      } else {
        _log('Failed to fetch camera state: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _log('Error getting camera state: $e');
      return null;
    }
  }

  /// Send keep-alive heartbeat to maintain Wi-Fi connection
  Future<bool> sendKeepAlive() async {
    try {
      final uri = Uri.parse('$baseUrl${GoProConstants.endpointKeepAlive}');
      final response = await _client.get(uri).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Tag a highlight moment during video recording (GET /gopro/camera/tag_moment)
  Future<bool> tagMoment() async {
    try {
      final uri = Uri.parse('$baseUrl${GoProConstants.endpointTagMoment}');
      _log('Tagging highlight moment: $uri');
      final response = await _client.get(uri).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (e) {
      _log('Error tagging moment: $e');
      return false;
    }
  }

  /// Load a capture preset (e.g. 0 = Standard Video, 65536 = Photo)
  Future<bool> loadPreset(int presetId) async {
    try {
      final uri = Uri.parse(
          '$baseUrl${GoProConstants.endpointPresetsLoad}?id=$presetId');
      _log('Loading preset: $uri');
      final response = await _client.get(uri).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (e) {
      _log('Error loading preset: $e');
      return false;
    }
  }

  /// Fetch list of all media files on the GoPro SD card (GET /gopro/media/list)
  Future<List<GoProMediaFile>> fetchMediaList() async {
    try {
      final uri = Uri.parse('$baseUrl${GoProConstants.endpointMediaList}');
      _log('Fetching media list: $uri');
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _log('Media list failed: status ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final mediaList = data['media'] as List<dynamic>? ?? [];

      final List<GoProMediaFile> files = [];

      for (final item in mediaList) {
        if (item is Map<String, dynamic>) {
          final directory = item['d']?.toString() ?? '100GOPRO';
          final fileList = item['fs'] as List<dynamic>? ?? [];

          for (final f in fileList) {
            if (f is Map<String, dynamic>) {
              final filename = f['n']?.toString() ?? '';
              final size = int.tryParse(f['s']?.toString() ?? '0') ?? 0;
              final creTime = int.tryParse(f['cre']?.toString() ?? '0');
              final modTime = int.tryParse(f['mod']?.toString() ?? '0');

              DateTime? createdAt;
              if (creTime != null && creTime > 0) {
                createdAt = DateTime.fromMillisecondsSinceEpoch(creTime * 1000);
              }

              DateTime? modifiedAt;
              if (modTime != null && modTime > 0) {
                modifiedAt = DateTime.fromMillisecondsSinceEpoch(modTime * 1000);
              }

              if (filename.isNotEmpty) {
                files.add(
                  GoProMediaFile(
                    directory: directory,
                    filename: filename,
                    sizeBytes: size,
                    createdAt: createdAt,
                    modifiedAt: modifiedAt,
                  ),
                );
              }
            }
          }
        }
      }

      // Sort newest files first
      files.sort((a, b) {
        final aTime = a.createdAt ?? a.modifiedAt ?? DateTime(2000);
        final bTime = b.createdAt ?? b.modifiedAt ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

      _log('Parsed ${files.length} media files from camera');
      return files;
    } catch (e) {
      _log('Error fetching media list: $e');
      return [];
    }
  }

  /// Download / retrieve a file from the GoPro camera to mobile device storage.
  /// Streams chunk-by-chunk and reports download progress.
  Future<File?> downloadFile({
    required GoProMediaFile mediaFile,
    required void Function(int receivedBytes, int totalBytes, double progress)
        onProgress,
  }) async {
    try {
      final downloadUrl = mediaFile.getDownloadUrl(_host, _port);
      _log('Starting file retrieval from: $downloadUrl');

      final request = http.Request('GET', Uri.parse(downloadUrl));
      final streamedResponse = await _client.send(request);

      if (streamedResponse.statusCode != 200) {
        _log('File download failed with HTTP status: ${streamedResponse.statusCode}');
        return null;
      }

      final contentLength = streamedResponse.contentLength ?? mediaFile.sizeBytes;

      // Determine local storage directory on the mobile device
      final appDir = await getApplicationDocumentsDirectory();
      final localMediaDir = Directory('${appDir.path}/GoProMedia');
      if (!await localMediaDir.exists()) {
        await localMediaDir.create(recursive: true);
      }

      final targetFile = File('${localMediaDir.path}/${mediaFile.filename}');
      final fileSink = targetFile.openWrite();

      int bytesReceived = 0;

      await for (final chunk in streamedResponse.stream) {
        fileSink.add(chunk);
        bytesReceived += chunk.length;

        final progress = contentLength > 0
            ? (bytesReceived / contentLength).clamp(0.0, 1.0)
            : 0.0;

        onProgress(bytesReceived, contentLength, progress);
      }

      await fileSink.flush();
      await fileSink.close();

      _log('File successfully retrieved and saved locally: ${targetFile.path} ($bytesReceived bytes)');
      return targetFile;
    } catch (e) {
      _log('Error downloading file: $e');
      return null;
    }
  }

  /// Delete a file from the GoPro camera SD card (GET /gopro/media/delete/file?path=...)
  Future<bool> deleteFile(GoProMediaFile file) async {
    try {
      final uri = Uri.parse(
          '$baseUrl${GoProConstants.endpointMediaDelete}?path=${file.relativePath}');
      _log('Deleting file from camera: $uri');
      final response = await _client.get(uri).timeout(const Duration(seconds: 6));
      final ok = response.statusCode == 200;
      _log('Delete result: ${response.statusCode}, ok=$ok');
      return ok;
    } catch (e) {
      _log('Error deleting file: $e');
      return false;
    }
  }

  /// Start camera preview stream (GET /gopro/camera/stream/start?port=8554)
  Future<bool> startPreviewStream({int port = GoProConstants.defaultStreamPort}) async {
    try {
      final uri = Uri.parse('$baseUrl${GoProConstants.endpointStreamStart}?port=$port');
      _log('Starting live preview stream: $uri');
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _log('Preview stream started successfully (200 OK)');
        return true;
      } else if (response.statusCode == 409) {
        // 409 Conflict: stream is already running. Stop and restart.
        _log('Stream already active (409 Conflict). Resetting stream...');
        await stopPreviewStream();
        await Future.delayed(const Duration(milliseconds: 600));
        final retry = await _client.get(uri).timeout(const Duration(seconds: 5));
        return retry.statusCode == 200;
      } else {
        _log('Failed to start preview stream: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _log('Error starting preview stream: $e');
      return false;
    }
  }

  /// Stop camera preview stream (GET /gopro/camera/stream/stop)
  Future<bool> stopPreviewStream() async {
    try {
      final uri = Uri.parse('$baseUrl${GoProConstants.endpointStreamStop}');
      _log('Stopping live preview stream: $uri');
      final response = await _client.get(uri).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (e) {
      _log('Error stopping preview stream: $e');
      return false;
    }
  }

  void dispose() {
    _client.close();
    _logController.close();
  }
}
