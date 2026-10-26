import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:wifi_iot/wifi_iot.dart';

/// Service responsible for connecting the phone to the GoPro's Wi-Fi Access
/// Point and making sure ALL app traffic (HTTP and the native UDP video
/// stream) uses that network.
class GoProWifiService {
  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  /// iOS can only join a Wi-Fi network programmatically via NEHotspotConfiguration,
  /// which needs the "Hotspot Configuration" entitlement (normally a paid Apple
  /// Developer account). Leave false for free / sideloaded signing: the user
  /// joins the GoPro network in Settings -> Wi-Fi and the controller waits.
  static const bool iosProgrammaticJoin = false;

  bool _isBound = false;

  void _log(String message) {
    debugPrint('[GoPro WiFi] $message');
    _logController.add(message);
  }


  Future<void> bindProcessToWifi() async {
    if (!Platform.isAndroid || _isBound) return;
    try {
      await WiFiForIoTPlugin.forceWifiUsage(true);
      _isBound = true;
      _log('Process bound to Wi-Fi network');
    } catch (e) {
      _log('Could not bind process to Wi-Fi: $e');
    }
  }

  /// Releases the binding so the rest of the app can use mobile data again.
  Future<void> releaseWifiBinding() async {
    if (!Platform.isAndroid || !_isBound) return;
    try {
      await WiFiForIoTPlugin.forceWifiUsage(false);
      _log('Wi-Fi binding released');
    } catch (e) {
      _log('Could not release Wi-Fi binding: $e');
    } finally {
      _isBound = false;
    }
  }

  /// Connects the phone to the GoPro's Wi-Fi network programmatically.
  Future<bool> connectToCameraWifi({
    required String ssid,
    required String password,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      _log('Platform not supported for programmatic Wi-Fi connection');
      return false;
    }
    if (Platform.isIOS && !iosProgrammaticJoin) {
      _log(
        'Programmatic Wi-Fi join is disabled on iOS; join "$ssid" manually in Settings.',
      );
      return false;
    }

    try {
      _log('Initiating programmatic connection to Wi-Fi SSID: "$ssid"...');

      final isEnabled = await WiFiForIoTPlugin.isEnabled();
      if (!isEnabled) {
        _log('Turning on phone Wi-Fi...');
        await WiFiForIoTPlugin.setEnabled(true);
        await Future.delayed(const Duration(milliseconds: 800));
      }

      final currentSsid = await WiFiForIoTPlugin.getSSID();
      if (currentSsid != null &&
          (currentSsid == ssid || currentSsid == '"$ssid"')) {
        _log('Phone is already connected to $ssid!');
        await bindProcessToWifi();
        return true;
      }

      _log('Connecting to "$ssid" (WPA/WPA2)...');

      final success =
          await WiFiForIoTPlugin.connect(
            ssid,
            password: password.isNotEmpty ? password : null,
            security: password.isNotEmpty
                ? NetworkSecurity.WPA
                : NetworkSecurity.NONE,
            joinOnce: false,
            withInternet: true,
          ).timeout(
            timeout,
            onTimeout: () {
              _log('Wi-Fi connection timed out after ${timeout.inSeconds}s');
              return false;
            },
          );

      _log('Wi-Fi connection result: $success');

      if (success) {
        // Let DHCP / the local gateway (10.5.5.9) settle, then pin traffic
        // to this network.
        await Future.delayed(const Duration(seconds: 2));
        await bindProcessToWifi();
      }
      return success;
    } catch (e) {
      _log('Error connecting to camera Wi-Fi: $e');
      return false;
    }
  }

  /// Current connected Wi-Fi SSID. On Android 10+ this can be null, empty or
  /// "<unknown ssid>" unless location permission AND location services are on.
  Future<String?> getCurrentSsid() async {
    try {
      return await WiFiForIoTPlugin.getSSID();
    } catch (_) {
      return null;
    }
  }

  Future<void> disconnect() async {
    await releaseWifiBinding();
    try {
      await WiFiForIoTPlugin.disconnect();
    } catch (_) {}
  }

  void dispose() {
    releaseWifiBinding();
    _logController.close();
  }
}
