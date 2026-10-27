library gopro_plugin;

/// GoPro Plugin - Flutter plugin for GoPro camera control via BLE and Wi-Fi
///
/// This plugin provides comprehensive control over GoPro cameras including:
/// - BLE device discovery and connection
/// - Wi-Fi hotspot management and HTTP API communication
/// - Camera controls (recording, shutter, modes)
/// - Media file listing and download
/// - Live camera preview streaming
///
/// Example usage:
/// ```dart
/// import 'package:gopro_plugin/gopro_plugin.dart';
///
/// final controller = GoProController();
/// await controller.startScan();
/// await controller.oneClickAutoConnect(device);
/// await controller.startRecording();
/// ```

// Core controller
export 'services/gopro_controller.dart';

// Services
export 'services/gopro_ble_service.dart';
export 'services/gopro_http_service.dart';
export 'services/gopro_preview_service.dart';
export 'services/gopro_wifi_service.dart';
export 'services/gopro_constants.dart';

// Models
export 'models/gopro_models.dart';
