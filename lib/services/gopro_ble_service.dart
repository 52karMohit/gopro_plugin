import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/gopro_models.dart';
import 'gopro_constants.dart';

/// Bluetooth Low Energy service for discovering, connecting to, and controlling
/// GoPro cameras using the Open GoPro BLE protocol.
class GoProBleService {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _commandChar;
  BluetoothCharacteristic? _responseChar;
  BluetoothCharacteristic? _ssidChar;
  BluetoothCharacteristic? _passwordChar;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _responseSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  final _discoveredDevicesController =
      StreamController<List<GoProDevice>>.broadcast();
  Stream<List<GoProDevice>> get discoveredDevicesStream =>
      _discoveredDevicesController.stream;

  final _connectionStatusController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  final _lastLogController = StreamController<String>.broadcast();
  Stream<String> get logStream => _lastLogController.stream;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool get isConnected => _connectedDevice != null;
  String? get connectedDeviceName => _connectedDevice?.platformName;

  void _log(String message) {
    debugPrint('[GoPro BLE] $message');
    _lastLogController.add(message);
  }

  /// Request runtime permissions for Bluetooth and Location
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    try {
      if (Platform.isAndroid) {
        final scanStatus = await Permission.bluetoothScan.request();
        final connectStatus = await Permission.bluetoothConnect.request();
        final locationStatus = await Permission.locationWhenInUse.request();

        final granted = (scanStatus.isGranted || scanStatus.isLimited) &&
            (connectStatus.isGranted || connectStatus.isLimited);

        _log('Android BLE permissions: scan=$scanStatus, connect=$connectStatus, loc=$locationStatus');
        return granted;
      } else if (Platform.isIOS) {
        final status = await Permission.bluetooth.request();
        _log('iOS BLE permission: $status');
        return status.isGranted;
      }
    } catch (e) {
      _log('Permission request error: $e');
    }
    return true;
  }

  /// Start scanning for GoPro devices
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (_isScanning) return;

    final hasPermissions = await requestPermissions();
    if (!hasPermissions) {
      _log('Cannot scan: Bluetooth permissions not granted');
      return;
    }

    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        _log('Bluetooth is not supported on this platform/device');
        return;
      }

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _log('Bluetooth is OFF. Please turn on Bluetooth.');
        return;
      }

      _isScanning = true;
      _log('Starting BLE scan for GoPro devices...');

      final Map<String, GoProDevice> foundDevices = {};

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final name = r.device.platformName.isNotEmpty
              ? r.device.platformName
              : r.advertisementData.advName;

          // GoPro cameras advertise with names like "GoPro 1234"
          // or include the 16-bit FEA6 service UUID
          final isGoPro = name.toLowerCase().contains('gopro') ||
              r.advertisementData.serviceUuids.any((u) =>
                  u.toString().toLowerCase().contains(GoProConstants.goproServiceUuidShort));

          if (isGoPro && name.isNotEmpty) {
            foundDevices[r.device.remoteId.str] = GoProDevice(
              id: r.device.remoteId.str,
              name: name,
              rssi: r.rssi,
              isBleConnected: false,
            );
            _discoveredDevicesController.add(foundDevices.values.toList());
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: false,
      );

      _isScanning = false;
      _log('BLE scan completed. Found ${foundDevices.length} GoPro camera(s).');
    } catch (e) {
      _isScanning = false;
      _log('Error during BLE scan: $e');
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      _log('BLE scan stopped');
    } catch (e) {
      _log('Error stopping scan: $e');
    }
  }

  /// Connect to a GoPro camera by BLE device ID
  Future<bool> connect(String deviceId) async {
    try {
      await stopScan();
      _log('Connecting to GoPro [$deviceId]...');

      final device = BluetoothDevice.fromId(deviceId);
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      _connectedDevice = device;

      // Monitor connection state
      _connectionStateSubscription?.cancel();
      _connectionStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _log('GoPro BLE disconnected');
          _cleanUpConnection();
          _connectionStatusController.add(false);
        }
      });

      // Request MTU negotiation (HERO9/10/11/12/13 benefit from 512 MTU)
      if (Platform.isAndroid) {
        try {
          await device.requestMtu(512);
        } catch (_) {}
      }

      // Discover GATT Services and Characteristics
      // IMPORTANT: GoPro uses TWO separate custom services:
      //   1. FEA6 service  -> Command (0072), Settings (0074), Query (0076) characteristics
      //   2. b5f90001 AP Control Service -> SSID (0003) and Password (0002) characteristics
      // We must scan ALL services to find both.
      _log('Discovering GoPro BLE services...');
      final services = await device.discoverServices();
      _log('Total GATT services found: ${services.length}');

      for (final service in services) {
        final sUuid = service.uuid.toString().toLowerCase();
        final isMainService = sUuid.contains(GoProConstants.goproServiceUuidShort) ||
            sUuid == GoProConstants.goproServiceUuid;
        final isApControlService = sUuid.contains(GoProConstants.goproApControlServiceUuidShort) ||
            sUuid == GoProConstants.goproApControlServiceUuid;

        if (isMainService || isApControlService) {
          _log('Found GoPro Service [${isApControlService ? "AP Control" : "Main"}]: ${service.uuid}');

          for (final char in service.characteristics) {
            final cUuid = char.uuid.toString().toLowerCase();
            if (cUuid == GoProConstants.commandReqUuid) {
              _commandChar = char;
              _log('Found Command characteristic');
            } else if (cUuid == GoProConstants.commandRespUuid) {
              _responseChar = char;
              _log('Found Command Response characteristic');
            } else if (cUuid == GoProConstants.wifiSsidUuid) {
              _ssidChar = char;
              _log('Found Wi-Fi SSID characteristic (UUID: ${char.uuid})');
            } else if (cUuid == GoProConstants.wifiPasswordUuid) {
              _passwordChar = char;
              _log('Found Wi-Fi Password characteristic (UUID: ${char.uuid})');
            }
          }
        }
      }

      if (_ssidChar == null || _passwordChar == null) {
        _log('WARNING: SSID/Password characteristics not found. Scanning all services for fallback...');
        // Fallback: scan ALL remaining services for credential characteristics
        for (final service in services) {
          for (final char in service.characteristics) {
            final cUuid = char.uuid.toString().toLowerCase();
            if (_ssidChar == null && cUuid == GoProConstants.wifiSsidUuid) {
              _ssidChar = char;
              _log('Fallback: Found SSID char in service ${service.uuid}');
            } else if (_passwordChar == null && cUuid == GoProConstants.wifiPasswordUuid) {
              _passwordChar = char;
              _log('Fallback: Found Password char in service ${service.uuid}');
            }
          }
        }
      }

      // Enable notifications on response characteristic
      if (_responseChar != null) {
        await _responseChar!.setNotifyValue(true);
        _responseSubscription?.cancel();
        _responseSubscription = _responseChar!.lastValueStream.listen((bytes) {
          _log('BLE Response received: ${bytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
        });
        _log('Subscribed to GoPro notifications');
      }

      _connectionStatusController.add(true);
      _log('Successfully connected to GoPro via BLE!');
      return true;
    } catch (e) {
      _log('Connection failed: $e');
      _cleanUpConnection();
      _connectionStatusController.add(false);
      return false;
    }
  }

  /// Start recording / shutter press over BLE
  Future<bool> startRecording() async {
    if (_commandChar == null) {
      _log('Cannot start recording: Command characteristic not ready');
      return false;
    }
    try {
      _log('Sending BLE Command: Shutter Start [0x03, 0x01, 0x01, 0x01]');
      await _commandChar!.write(GoProConstants.cmdShutterStart, withoutResponse: false);
      _log('Shutter Start sent successfully');
      return true;
    } catch (e) {
      _log('Error sending Shutter Start: $e');
      return false;
    }
  }

  /// Stop recording / shutter release over BLE
  Future<bool> stopRecording() async {
    if (_commandChar == null) {
      _log('Cannot stop recording: Command characteristic not ready');
      return false;
    }
    try {
      _log('Sending BLE Command: Shutter Stop [0x03, 0x01, 0x01, 0x00]');
      await _commandChar!.write(GoProConstants.cmdShutterStop, withoutResponse: false);
      _log('Shutter Stop sent successfully');
      return true;
    } catch (e) {
      _log('Error sending Shutter Stop: $e');
      return false;
    }
  }

  /// Power ON the GoPro's Wi-Fi Access Point using BLE Command 0x17
  Future<bool> enableWifiAp() async {
    if (_commandChar == null) {
      _log('Cannot enable Wi-Fi AP: Command characteristic not ready');
      return false;
    }
    try {
      _log('Sending BLE Command: Enable Wi-Fi AP [0x03, 0x17, 0x01, 0x01]');
      await _commandChar!.write(GoProConstants.cmdEnableWifiAp, withoutResponse: false);
      _log('Wi-Fi AP command sent! Camera is turning on Wi-Fi hotspot...');
      return true;
    } catch (e) {
      _log('Error enabling Wi-Fi AP: $e');
      return false;
    }
  }

  /// Read Wi-Fi SSID and Password directly from GoPro characteristics.
  /// The camera must have received the cmdEnableWifiAp command first so the
  /// AP is active before credentials are meaningful.
  Future<Map<String, String>> readWifiCredentials({int retries = 2}) async {
    String? ssid;
    String? password;

    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        if (_ssidChar != null) {
          final ssidBytes = await _ssidChar!.read();
          // Filter out null bytes (0x00) that some cameras append
          final filtered = ssidBytes.where((b) => b != 0).toList();
          final decoded = utf8.decode(filtered, allowMalformed: true).trim();
          if (decoded.isNotEmpty) {
            ssid = decoded;
            _log('Retrieved Wi-Fi SSID: "$ssid" (${ssidBytes.length} bytes raw)');
            break;
          } else if (attempt < retries) {
            _log('SSID read returned empty on attempt ${attempt + 1}, retrying...');
            await Future.delayed(const Duration(milliseconds: 600));
          }
        } else {
          _log('SSID characteristic is null — not found during service discovery');
          break;
        }
      } catch (e) {
        _log('Failed to read SSID characteristic (attempt ${attempt + 1}): $e');
        if (attempt < retries) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    try {
      if (_passwordChar != null) {
        final passBytes = await _passwordChar!.read();
        final filtered = passBytes.where((b) => b != 0).toList();
        password = utf8.decode(filtered, allowMalformed: true).trim();
        _log('Retrieved Wi-Fi Password: "$password" (${passBytes.length} bytes raw)');
      } else {
        _log('Password characteristic is null — not found during service discovery');
      }
    } catch (e) {
      _log('Failed to read Password characteristic: $e');
    }

    final result = {
      'ssid': ssid ?? '',
      'password': password ?? '',
    };
    _log('Credentials resolved => SSID: "${result['ssid']}" | Password: "${result['password']}"');
    return result;
  }

  /// Set camera capture preset mode over BLE
  Future<bool> setPresetMode(String mode) async {
    if (_commandChar == null) return false;

    List<int> cmd;
    switch (mode.toLowerCase()) {
      case 'photo':
        cmd = GoProConstants.cmdSetPresetPhoto;
        break;
      case 'timelapse':
        cmd = GoProConstants.cmdSetPresetTimelapse;
        break;
      case 'video':
      default:
        cmd = GoProConstants.cmdSetPresetVideo;
        break;
    }

    try {
      _log('Setting preset mode to $mode over BLE');
      await _commandChar!.write(cmd, withoutResponse: false);
      return true;
    } catch (e) {
      _log('Error setting preset mode: $e');
      return false;
    }
  }

  /// Tag a highlight moment during recording over BLE
  Future<bool> tagHighlight() async {
    if (_commandChar == null) return false;
    try {
      _log('Tagging highlight moment over BLE');
      await _commandChar!.write(GoProConstants.cmdTagHighlight, withoutResponse: false);
      return true;
    } catch (e) {
      _log('Error tagging highlight: $e');
      return false;
    }
  }

  /// Disconnect from the current GoPro device
  Future<void> disconnect() async {
    try {
      if (_connectedDevice != null) {
        _log('Disconnecting from ${_connectedDevice!.platformName}...');
        await _connectedDevice!.disconnect();
      }
    } catch (e) {
      _log('Error disconnecting: $e');
    } finally {
      _cleanUpConnection();
      _connectionStatusController.add(false);
    }
  }

  void _cleanUpConnection() {
    _connectedDevice = null;
    _commandChar = null;
    _responseChar = null;
    _ssidChar = null;
    _passwordChar = null;
    _responseSubscription?.cancel();
    _responseSubscription = null;
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
  }

  void dispose() {
    _scanSubscription?.cancel();
    _responseSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _discoveredDevicesController.close();
    _connectionStatusController.close();
    _lastLogController.close();
  }
}
