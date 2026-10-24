/// Official Open GoPro Specification Constants for BLE and HTTP interfaces.
/// Supports GoPro HERO9 Black, HERO10 Black, HERO11 Black, HERO12 Black, HERO13 Black, and MAX.
class GoProConstants {
  // ---------------------------------------------------------------------------
  // Bluetooth Low Energy (BLE) UUIDs
  // ---------------------------------------------------------------------------

  /// GoPro primary BLE Service 16-bit UUID (FEA6) and 128-bit standard UUID
  /// This is the main Open GoPro command/settings/query service.
  static const String goproServiceUuid = '0000fea6-0000-1000-8000-00805f9b34fb';
  static const String goproServiceUuidShort = 'fea6';

  /// GoPro Wi-Fi AP Control Service UUID (b5f90001-...)
  /// This separate service houses the SSID and Password characteristics.
  static const String goproApControlServiceUuid = 'b5f90001-aa8d-11e3-9046-0002a5d5c51b';
  static const String goproApControlServiceUuidShort = 'b5f90001';

  /// BLE Characteristic: Command Request (Write / Write Without Response)
  static const String commandReqUuid = 'b5f90072-aa8d-11e3-9046-0002a5d5c51b';

  /// BLE Characteristic: Command Response (Notify)
  static const String commandRespUuid = 'b5f90073-aa8d-11e3-9046-0002a5d5c51b';

  /// BLE Characteristic: Settings Request (Write)
  static const String settingsReqUuid = 'b5f90074-aa8d-11e3-9046-0002a5d5c51b';

  /// BLE Characteristic: Settings Response (Notify)
  static const String settingsRespUuid = 'b5f90075-aa8d-11e3-9046-0002a5d5c51b';

  /// BLE Characteristic: Query Request (Write)
  static const String queryReqUuid = 'b5f90076-aa8d-11e3-9046-0002a5d5c51b';

  /// BLE Characteristic: Query Response (Notify)
  static const String queryRespUuid = 'b5f90077-aa8d-11e3-9046-0002a5d5c51b';

  /// BLE Characteristic: Wi-Fi Access Point SSID (Read/Write)
  /// UUID b5f90002 = SSID — confirmed by real GoPro hardware (e.g. GP24806793)
  static const String wifiSsidUuid = 'b5f90002-aa8d-11e3-9046-0002a5d5c51b';

  /// BLE Characteristic: Wi-Fi Access Point Password (Read/Write)
  /// UUID b5f90003 = PASSWORD — confirmed by real GoPro hardware
  static const String wifiPasswordUuid = 'b5f90003-aa8d-11e3-9046-0002a5d5c51b';

  // ---------------------------------------------------------------------------
  // BLE Command Byte Payloads
  // ---------------------------------------------------------------------------

  /// Shutter Start / Record Start: Length 3, Command 0x01, ParamLen 0x01, Val 0x01
  static const List<int> cmdShutterStart = [0x03, 0x01, 0x01, 0x01];

  /// Shutter Stop / Record Stop: Length 3, Command 0x01, ParamLen 0x01, Val 0x00
  static const List<int> cmdShutterStop = [0x03, 0x01, 0x01, 0x00];

  /// Enable Camera Wi-Fi Access Point: Length 3, Command 0x17, ParamLen 0x01, Val 0x01
  static const List<int> cmdEnableWifiAp = [0x03, 0x17, 0x01, 0x01];

  /// Disable Camera Wi-Fi Access Point: Length 3, Command 0x17, ParamLen 0x01, Val 0x00
  static const List<int> cmdDisableWifiAp = [0x03, 0x17, 0x01, 0x00];

  /// Switch Preset Mode to Video
  static const List<int> cmdSetPresetVideo = [0x04, 0x3E, 0x02, 0x00, 0x00];

  /// Switch Preset Mode to Photo
  static const List<int> cmdSetPresetPhoto = [0x04, 0x3E, 0x02, 0x00, 0x01];

  /// Switch Preset Mode to Timelapse
  static const List<int> cmdSetPresetTimelapse = [0x04, 0x3E, 0x02, 0x00, 0x02];

  /// Tag Highlight Moment in active recording
  static const List<int> cmdTagHighlight = [0x01, 0x18];

  // ---------------------------------------------------------------------------
  // Open GoPro HTTP API Endpoints
  // ---------------------------------------------------------------------------

  /// Default camera Wi-Fi Access Point IP address
  static const String defaultCameraIp = '10.5.5.9';

  /// Default Open GoPro HTTP server port
  static const int defaultCameraPort = 8080;

  /// Shutter Start endpoint: GET /gopro/camera/shutter/start
  static const String endpointShutterStart = '/gopro/camera/shutter/start';

  /// Shutter Stop endpoint: GET /gopro/camera/shutter/stop
  static const String endpointShutterStop = '/gopro/camera/shutter/stop';

  /// Camera State & Status query endpoint: GET /gopro/camera/state
  static const String endpointCameraState = '/gopro/camera/state';

  /// Heartbeat Keep-Alive endpoint: GET /gopro/camera/keep_alive
  static const String endpointKeepAlive = '/gopro/camera/keep_alive';

  /// Media List query endpoint: GET /gopro/media/list
  static const String endpointMediaList = '/gopro/media/list';

  /// Media File Info endpoint: `GET /gopro/media/info?path=<directory>/<filename>`
  static const String endpointMediaInfo = '/gopro/media/info';

  /// Media Thumbnail endpoint: `GET /gopro/media/thumbnail?path=<directory>/<filename>`
  static const String endpointMediaThumbnail = '/gopro/media/thumbnail';

  /// Media Screennail endpoint: `GET /gopro/media/screennail?path=<directory>/<filename>`
  static const String endpointMediaScreennail = '/gopro/media/screennail';

  /// Media Delete endpoint: `GET /gopro/media/delete/file?path=<directory>/<filename>`
  static const String endpointMediaDelete = '/gopro/media/delete/file';

  /// Tag Moment / Highlight: GET /gopro/camera/tag_moment
  static const String endpointTagMoment = '/gopro/camera/tag_moment';

  /// Load Preset: `GET /gopro/camera/presets/load?id=<preset_id>`
  static const String endpointPresetsLoad = '/gopro/camera/presets/load';

  /// Direct Media Download Base Path: `/videos/DCIM/<directory>/<filename>`
  static const String directDownloadBasePath = '/videos/DCIM';

  /// Live Stream / Preview Start: `GET /gopro/camera/stream/start`
  static const String endpointStreamStart = '/gopro/camera/stream/start';

  /// Live Stream / Preview Stop: `GET /gopro/camera/stream/stop`
  static const String endpointStreamStop = '/gopro/camera/stream/stop';

  /// Standard UDP stream port for GoPro MPEG-TS preview
  static const int defaultStreamPort = 8554;

  /// UDP keep-alive string packet sent periodically to maintain preview feed
  static const String udpStreamKeepAlivePacket = '_GPHD_:0:0:2:0.000000\n';
}
