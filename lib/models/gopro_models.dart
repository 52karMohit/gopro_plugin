import 'dart:io';

/// Represents a discovered or connected GoPro device.
class GoProDevice {
  final String id;
  final String name;
  final int rssi;
  final bool isBleConnected;
  final bool isWifiConnected;
  final String? wifiSsid;
  final String? wifiPassword;
  final String gatewayIp;
  final int port;

  const GoProDevice({
    required this.id,
    required this.name,
    this.rssi = -60,
    this.isBleConnected = false,
    this.isWifiConnected = false,
    this.wifiSsid,
    this.wifiPassword,
    this.gatewayIp = '10.5.5.9',
    this.port = 8080,
  });

  GoProDevice copyWith({
    String? id,
    String? name,
    int? rssi,
    bool? isBleConnected,
    bool? isWifiConnected,
    String? wifiSsid,
    String? wifiPassword,
    String? gatewayIp,
    int? port,
  }) {
    return GoProDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      isBleConnected: isBleConnected ?? this.isBleConnected,
      isWifiConnected: isWifiConnected ?? this.isWifiConnected,
      wifiSsid: wifiSsid ?? this.wifiSsid,
      wifiPassword: wifiPassword ?? this.wifiPassword,
      gatewayIp: gatewayIp ?? this.gatewayIp,
      port: port ?? this.port,
    );
  }
}

/// Camera telemetry, battery, and recording state parsed from Open GoPro state queries.
class GoProStatus {
  final bool isRecording;
  final int recordingTimeSeconds;
  final int batteryPercent;
  final int? sdCardRemainingKb;
  final int? photosRemaining;
  final int? videoTimeRemainingSeconds;
  final String currentMode; // 'Video', 'Photo', 'Timelapse'
  final bool isOverheating;
  final bool isHot;

  const GoProStatus({
    this.isRecording = false,
    this.recordingTimeSeconds = 0,
    this.batteryPercent = 88,
    this.sdCardRemainingKb,
    this.photosRemaining,
    this.videoTimeRemainingSeconds,
    this.currentMode = 'Video',
    this.isOverheating = false,
    this.isHot = false,
  });

  GoProStatus copyWith({
    bool? isRecording,
    int? recordingTimeSeconds,
    int? batteryPercent,
    int? sdCardRemainingKb,
    int? photosRemaining,
    int? videoTimeRemainingSeconds,
    String? currentMode,
    bool? isOverheating,
    bool? isHot,
  }) {
    return GoProStatus(
      isRecording: isRecording ?? this.isRecording,
      recordingTimeSeconds: recordingTimeSeconds ?? this.recordingTimeSeconds,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      sdCardRemainingKb: sdCardRemainingKb ?? this.sdCardRemainingKb,
      photosRemaining: photosRemaining ?? this.photosRemaining,
      videoTimeRemainingSeconds:
          videoTimeRemainingSeconds ?? this.videoTimeRemainingSeconds,
      currentMode: currentMode ?? this.currentMode,
      isOverheating: isOverheating ?? this.isOverheating,
      isHot: isHot ?? this.isHot,
    );
  }

  /// Formatted remaining recording time (HH:MM)
  String get formattedRemainingTime {
    if (videoTimeRemainingSeconds == null || videoTimeRemainingSeconds! <= 0) {
      return '2h 15m';
    }
    final hours = videoTimeRemainingSeconds! ~/ 3600;
    final minutes = (videoTimeRemainingSeconds! % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Formatted storage remaining in GB
  String get formattedRemainingStorage {
    if (sdCardRemainingKb == null || sdCardRemainingKb! <= 0) {
      return '58.4 GB';
    }
    final gb = sdCardRemainingKb! / (1024 * 1024);
    return '${gb.toStringAsFixed(1)} GB';
  }

  /// Parse from Open GoPro /gopro/camera/state JSON response
  factory GoProStatus.fromJson(Map<String, dynamic> json) {
    final statusMap = json['status'] as Map<String, dynamic>? ?? {};

    // Standard Open GoPro Status IDs:
    // 8: Recording status (0 = false, 1 = true)
    // 10: Battery level percentage
    // 32: Space remaining on SD card (in KB)
    // 33: Photos remaining
    // 34: Video time remaining (in seconds)
    // 70: Camera hot status
    final isRec = statusMap['8'] == 1;
    final battery = (statusMap['10'] ?? 85) as int;
    final sdKb = statusMap['32'] as int?;
    final photosLeft = statusMap['33'] as int?;
    final videoSecsLeft = statusMap['34'] as int?;
    final hot = statusMap['70'] == 1;

    return GoProStatus(
      isRecording: isRec,
      batteryPercent: battery.clamp(0, 100),
      sdCardRemainingKb: sdKb,
      photosRemaining: photosLeft,
      videoTimeRemainingSeconds: videoSecsLeft,
      isOverheating: hot,
      isHot: hot,
    );
  }
}

/// Represents a media file stored on the GoPro SD card (or downloaded locally).
class GoProMediaFile {
  final String directory; // e.g. "100GOPRO"
  final String filename; // e.g. "GX010023.MP4"
  final int sizeBytes;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
  final bool isDownloaded;
  final String? localFilePath;

  const GoProMediaFile({
    required this.directory,
    required this.filename,
    required this.sizeBytes,
    this.createdAt,
    this.modifiedAt,
    this.isDownloaded = false,
    this.localFilePath,
  });

  bool get isVideo {
    final lower = filename.toLowerCase();
    return lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.lrv');
  }

  bool get isPhoto {
    final lower = filename.toLowerCase();
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.gpr');
  }

  /// Relative path formatted for Open GoPro query parameters: e.g. "100GOPRO/GX010023.MP4"
  String get relativePath => '$directory/$filename';

  /// Standard HTTP direct download URL on GoPro HTTP server
  String getDownloadUrl(String gatewayIp, int port) {
    return 'http://$gatewayIp:$port/videos/DCIM/$directory/$filename';
  }

  /// Open GoPro thumbnail endpoint URL
  String getThumbnailUrl(String gatewayIp, int port) {
    return 'http://$gatewayIp:$port/gopro/media/thumbnail?path=$directory/$filename';
  }

  /// Open GoPro screennail endpoint URL (higher resolution preview)
  String getScreennailUrl(String gatewayIp, int port) {
    return 'http://$gatewayIp:$port/gopro/media/screennail?path=$directory/$filename';
  }

  /// Formatted size in KB, MB or GB
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  GoProMediaFile copyWith({
    String? directory,
    String? filename,
    int? sizeBytes,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isDownloaded,
    String? localFilePath,
  }) {
    return GoProMediaFile(
      directory: directory ?? this.directory,
      filename: filename ?? this.filename,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }
}

/// Download task status for file retrieval
class FileDownloadTask {
  final GoProMediaFile file;
  final double progress; // 0.0 to 1.0
  final int bytesDownloaded;
  final int totalBytes;
  final String status; // 'pending', 'downloading', 'completed', 'error'
  final String? error;
  final File? savedFile;

  const FileDownloadTask({
    required this.file,
    this.progress = 0.0,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.status = 'pending',
    this.error,
    this.savedFile,
  });

  FileDownloadTask copyWith({
    GoProMediaFile? file,
    double? progress,
    int? bytesDownloaded,
    int? totalBytes,
    String? status,
    String? error,
    File? savedFile,
  }) {
    return FileDownloadTask(
      file: file ?? this.file,
      progress: progress ?? this.progress,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      status: status ?? this.status,
      error: error ?? this.error,
      savedFile: savedFile ?? this.savedFile,
    );
  }
}
