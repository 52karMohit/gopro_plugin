import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:wifi_iot/wifi_iot.dart';

/// Service responsible for automatically connecting the mobile device to the
/// GoPro camera's Wi-Fi Access Point programmatically without manual user intervention.
class GoProWifiService {
  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  void _log(String message) {
    debugPrint('[GoPro WiFi Auto-Connect] $message');
    _logController.add(message);
  }

  /// Automatically connects the phone to the GoPro's Wi-Fi network programmatically.
  /// Uses Android 10+ WifiNetworkSpecifier (withInternet: false) so Android doesn't
  /// drop the connection due to lack of public internet.
  Future<bool> connectToCameraWifi({
    required String ssid,
    required String password,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      _log('Platform not supported for programmatic Wi-Fi connection');
      return false;
    }

    try {
      _log('Initiating programmatic connection to Wi-Fi SSID: "$ssid"...');

      // Check if Wi-Fi hardware is enabled on phone
      final isEnabled = await WiFiForIoTPlugin.isEnabled();
      if (!isEnabled) {
        _log('Turning on phone Wi-Fi...');
        await WiFiForIoTPlugin.setEnabled(true);
        await Future.delayed(const Duration(milliseconds: 800));
      }

      // Check if already connected to this SSID
      final currentSsid = await WiFiForIoTPlugin.getSSID();
      if (currentSsid != null &&
          (currentSsid == ssid || currentSsid == '"$ssid"')) {
        _log('Phone is already connected to $ssid!');
        return true;
      }

      _log('Connecting to "$ssid" (WPA/WPA2)...');

      // Connect programmatically
      // Note: withInternet: true is used to ensure Android properly routes traffic
      // through the Wi-Fi network. Even though the camera has no public internet,
      // this setting prevents the "Network is unreachable" error by ensuring
      // the HTTP client uses the correct network interface.
      final success = await WiFiForIoTPlugin.connect(
        ssid,
        password: password.isNotEmpty ? password : null,
        security: password.isNotEmpty ? NetworkSecurity.WPA : NetworkSecurity.NONE,
        joinOnce: false,
        withInternet: true,
      ).timeout(timeout, onTimeout: () {
        _log('Wi-Fi connection timed out after ${timeout.inSeconds}s');
        return false;
      });

      _log('Wi-Fi connection result: $success');

      // Wait a moment for DHCP / local gateway IP (10.5.5.9) routing to settle
      if (success) {
        await Future.delayed(const Duration(seconds: 2));
      }

      return success;
    } catch (e) {
      _log('Error connecting to camera Wi-Fi: $e');
      return false;
    }
  }

  /// Check current connected Wi-Fi SSID
  Future<String?> getCurrentSsid() async {
    try {
      return await WiFiForIoTPlugin.getSSID();
    } catch (_) {
      return null;
    }
  }

  /// Disconnect from current Wi-Fi
  Future<void> disconnect() async {
    try {
      await WiFiForIoTPlugin.disconnect();
    } catch (_) {}
  }

  void dispose() {
    _logController.close();
  }
}
