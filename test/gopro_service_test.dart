import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gopro_plugin/models/gopro_models.dart';
import 'package:gopro_plugin/services/gopro_constants.dart';
import 'package:gopro_plugin/services/gopro_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('gopro_test_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Open GoPro Specifications & Constants', () {
    test('BLE Command payloads match official Open GoPro specification', () {
      expect(GoProConstants.cmdShutterStart, equals([0x03, 0x01, 0x01, 0x01]));
      expect(GoProConstants.cmdShutterStop, equals([0x03, 0x01, 0x01, 0x00]));
      expect(GoProConstants.cmdEnableWifiAp, equals([0x03, 0x17, 0x01, 0x01]));
      expect(GoProConstants.cmdDisableWifiAp, equals([0x03, 0x17, 0x01, 0x00]));
    });

    test('BLE UUIDs match official Open GoPro GATT characteristics', () {
      expect(GoProConstants.goproServiceUuidShort, equals('fea6'));
      expect(
        GoProConstants.goproServiceUuid,
        equals('0000fea6-0000-1000-8000-00805f9b34fb'),
      );
      expect(
        GoProConstants.commandReqUuid,
        equals('b5f90072-aa8d-11e3-9046-0002a5d5c51b'),
      );
      expect(
        GoProConstants.commandRespUuid,
        equals('b5f90073-aa8d-11e3-9046-0002a5d5c51b'),
      );
      // AP Control Service (SSID + Password live in this separate service)
      expect(
        GoProConstants.goproApControlServiceUuid,
        equals('b5f90001-aa8d-11e3-9046-0002a5d5c51b'),
      );
      // b5f90002 = SSID, b5f90003 = PASSWORD — confirmed by real GoPro hardware
      expect(
        GoProConstants.wifiSsidUuid,
        equals('b5f90002-aa8d-11e3-9046-0002a5d5c51b'),
      );
      expect(
        GoProConstants.wifiPasswordUuid,
        equals('b5f90003-aa8d-11e3-9046-0002a5d5c51b'),
      );
    });

    test('HTTP API Endpoints match Open GoPro specification', () {
      expect(GoProConstants.defaultCameraIp, equals('10.5.5.9'));
      expect(GoProConstants.defaultCameraPort, equals(8080));
      expect(
        GoProConstants.endpointShutterStart,
        equals('/gopro/camera/shutter/start'),
      );
      expect(
        GoProConstants.endpointShutterStop,
        equals('/gopro/camera/shutter/stop'),
      );
      expect(
        GoProConstants.endpointMediaList,
        equals('/gopro/media/list'),
      );
      expect(
        GoProConstants.directDownloadBasePath,
        equals('/videos/DCIM'),
      );
    });
  });

  group('GoPro Models & JSON Deserialization', () {
    test('GoProStatus.fromJson correctly parses camera state JSON', () {
      final mockStateJson = {
        'status': {
          '8': 1, // Recording active
          '10': 95, // Battery %
          '32': 58400000, // SD space KB
          '33': 1200, // Photos left
          '34': 7400, // Video seconds left
          '70': 0, // Not hot
        }
      };

      final status = GoProStatus.fromJson(mockStateJson);
      expect(status.isRecording, isTrue);
      expect(status.batteryPercent, equals(95));
      expect(status.sdCardRemainingKb, equals(58400000));
      expect(status.photosRemaining, equals(1200));
      expect(status.videoTimeRemainingSeconds, equals(7400));
      expect(status.isOverheating, isFalse);
      expect(status.formattedRemainingTime, equals('2h 3m'));
      expect(status.formattedRemainingStorage, equals('55.7 GB'));
    });

    test('GoProMediaFile computes correct relative paths and URLs', () {
      const file = GoProMediaFile(
        directory: '100GOPRO',
        filename: 'GX010045.MP4',
        sizeBytes: 154823104,
      );

      expect(file.relativePath, equals('100GOPRO/GX010045.MP4'));
      expect(file.isVideo, isTrue);
      expect(file.isPhoto, isFalse);
      expect(file.formattedSize, equals('147.7 MB'));
      expect(
        file.getDownloadUrl('10.5.5.9', 8080),
        equals('http://10.5.5.9:8080/videos/DCIM/100GOPRO/GX010045.MP4'),
      );
      expect(
        file.getThumbnailUrl('10.5.5.9', 8080),
        equals('http://10.5.5.9:8080/gopro/media/thumbnail?path=100GOPRO/GX010045.MP4'),
      );
    });
  });

  group('GoProController Lifecycle & Features', () {
    late GoProController controller;

    setUp(() {
      controller = GoProController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Demo Mode connection, recording, file creation and retrieval', () async {
      // 1. Enable Demo Mode
      controller.toggleDemoMode(true);
      expect(controller.isDemoMode, isTrue);
      expect(controller.discoveredDevices.length, greaterThan(0));

      final testDevice = controller.discoveredDevices.first;

      // 2. Connect to device
      final connectSuccess = await controller.connectDevice(testDevice);
      expect(connectSuccess, isTrue);
      expect(controller.isBleConnected, isTrue);
      expect(controller.currentDevice?.wifiSsid, isNotNull);

      // 3. Connect to Wi-Fi HTTP API
      final wifiSuccess = await controller.connectWifiHttp();
      expect(wifiSuccess, isTrue);
      expect(controller.isWifiConnected, isTrue);

      // 4. Start Recording
      final initialCount = controller.mediaFiles.length;
      final startSuccess = await controller.startRecording();
      expect(startSuccess, isTrue);
      expect(controller.status.isRecording, isTrue);

      // 5. Stop Recording (triggers File Creation)
      final stopSuccess = await controller.stopRecording();
      expect(stopSuccess, isTrue);
      expect(controller.status.isRecording, isFalse);
      expect(controller.lastCreatedFile, isNotNull);
      expect(controller.mediaFiles.length, equals(initialCount + 1));
      expect(controller.lastCreatedFile!.isVideo, isTrue);

      // 6. Retrieve File (Download)
      final createdFile = controller.lastCreatedFile!;
      await controller.retrieveFile(createdFile);

      final task = controller.activeDownloads[createdFile.relativePath];
      expect(task, isNotNull);
      expect(task!.status, equals('completed'));
      expect(task.progress, equals(1.0));
      expect(task.savedFile, isNotNull);
    });
  });
}
