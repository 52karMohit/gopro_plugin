# gopro_plugin

A Flutter plugin for connecting, controlling, and managing media with GoPro cameras (HERO9, HERO10, HERO11, HERO12, HERO13, and MAX) using the official **Open GoPro BLE & HTTP specifications**.

---

## ⚡ Features

1. **Dual Connectivity (BLE + Wi-Fi HTTP)**:
   - **Bluetooth Low Energy (BLE)**: Scans for cameras, pairs, turns ON camera Wi-Fi Access Point (`0x17`), queries Wi-Fi credentials (`0x0002`, `0x0003`), and triggers low-power commands.
   - **Wi-Fi HTTP API**: Connects to the camera's HTTP gateway (`http://10.5.5.9:8080`), sends heartbeat keep-alives, and executes high-throughput media operations.

2. **Start & Stop Recording**:
   - Remote shutter start/stop via both BLE (`0x03, 0x01, 0x01, 0x01` / `0x00`) and HTTP (`/gopro/camera/shutter/start`, `/gopro/camera/shutter/stop`).
   - Mode switching: **Video**, **Photo**, and **Timelapse**.
   - Live recording stopwatch with pulsing indicator.
   - Highlight moment tagging (`/gopro/camera/tag_moment`).

3. **File Creation & Auto-Tracking**:
   - Captures video/photo trigger events.
   - Automatically tracks new files created on the camera's SD card (`GX01xxxx.MP4`, `GOPRxxxx.JPG`).
   - Quick "Last Created File" preview card with one-touch retrieval.

4. **File Retrieval & Local Storage**:
   - Queries media list from `/gopro/media/list`.
   - Displays file metadata: filename, directory (`100GOPRO`), file size (MB/GB), timestamps.
   - Streams chunked file downloads directly from `http://10.5.5.9:8080/videos/DCIM/<dir>/<filename>` into device application storage (`/GoProMedia`).
   - Live download progress bar, bytes received, and percentage.
   - Local saved files viewer with deletion and management.

5. **Built-in Hardware Simulator / Demo Mode**:
   - Allows instant testing and UI verification on any phone, emulator, or simulator even when a physical GoPro camera is not nearby.

---

## 📡 Open GoPro Protocol Reference

### 1. Bluetooth Low Energy (BLE)
- **GoPro Service UUID**: `0000fea6-0000-1000-8000-00805f9b34fb` (16-bit: `0xFEA6`)
- **Command Request Characteristic**: `b5f90072-aa8d-11e3-9046-0002a5d5c51b`
- **Command Response Characteristic**: `b5f90073-aa8d-11e3-9046-0002a5d5c51b`
- **Wi-Fi SSID Characteristic**: `b5f90002-aa8d-11e3-9046-0002a5d5c51b`
- **Wi-Fi Password Characteristic**: `b5f90003-aa8d-11e3-9046-0002a5d5c51b`

| Action | Characteristic | Byte Array Payload |
|---|---|---|
| **Shutter Start / Record** | `0x0072` (Command) | `[0x03, 0x01, 0x01, 0x01]` |
| **Shutter Stop / Record** | `0x0072` (Command) | `[0x03, 0x01, 0x01, 0x00]` |
| **Enable Wi-Fi Access Point** | `0x0072` (Command) | `[0x03, 0x17, 0x01, 0x01]` |
| **Disable Wi-Fi Access Point** | `0x0072` (Command) | `[0x03, 0x17, 0x01, 0x00]` |
| **Set Video Mode** | `0x0072` (Command) | `[0x04, 0x3E, 0x02, 0x00, 0x00]` |
| **Set Photo Mode** | `0x0072` (Command) | `[0x04, 0x3E, 0x02, 0x00, 0x01]` |
| **Tag Highlight Moment** | `0x0072` (Command) | `[0x01, 0x18]` |

---

### 2. Wi-Fi HTTP REST API
- **Default Camera Gateway IP**: `http://10.5.5.9:8080` (or `http://172.2X.1XX.51:8080` over USB)

| Operation | HTTP Method | Endpoint | Description |
|---|---|---|---|
| **Start Recording** | `GET` | `/gopro/camera/shutter/start` | Starts video encoding or takes photo |
| **Stop Recording** | `GET` | `/gopro/camera/shutter/stop` | Stops video recording |
| **Camera State** | `GET` | `/gopro/camera/state` | Returns battery %, SD card space, remaining recording time |
| **Keep-Alive Heartbeat**| `GET` | `/gopro/camera/keep_alive` | Prevents camera Wi-Fi from turning off (sent every 3s) |
| **List Media Files** | `GET` | `/gopro/media/list` | Returns JSON of all directories and files on SD card |
| **File Retrieval** | `GET` | `/videos/DCIM/<dir>/<file>` | Direct binary media download (e.g. `GX010045.MP4`) |
| **File Thumbnail** | `GET` | `/gopro/media/thumbnail?path=...` | Retrieves image/video thumbnail |
| **Delete File** | `GET` | `/gopro/media/delete/file?path=...` | Deletes file from SD card |
| **Tag Moment** | `GET` | `/gopro/camera/tag_moment` | Inserts highlight tag in active recording |

---

## 🚀 Mobile Connection Workflow

```
┌─────────────────────────────────┐
│ 1. Mobile BLE Discovery         │ -> Scans for "GoPro XXXX" (FEA6)
└────────────────┬────────────────┘
                 │
┌────────────────▼────────────────┐
│ 2. BLE Pairing & Characteristics│ -> Discovers Command (0x0072), SSID & Password
└────────────────┬────────────────┘
                 │
┌────────────────▼────────────────┐
│ 3. Enable Wi-Fi Hotspot         │ -> Writes [0x03, 0x17, 0x01, 0x01] over BLE
└────────────────┬────────────────┘
                 │
┌────────────────▼────────────────┐
│ 4. Mobile Connects to Camera AP │ -> SSID & Password retrieved via BLE / Camera Info
└────────────────┬────────────────┘
                 │
┌────────────────▼────────────────┐
│ 5. Open GoPro HTTP Session      │ -> Pings http://10.5.5.9:8080, sends Keep-Alive
└────────────────┬────────────────┘
                 │
┌────────────────▼────────────────┐
│ 6. Full Control & Retrieval     │ -> Start/Stop Recording, /gopro/media/list, Download
└─────────────────────────────────┘
```

---

## 📦 Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  gopro_plugin:
    git:
      url: https://github.com/52karMohit/gopro_plugin.git
```

Or install it from a local path:

```yaml
dependencies:
  gopro_plugin:
    path: ../gopro_plugin
```

Then run:

```bash
flutter pub get
```

## 🚀 Usage

### Basic Setup

```dart
import 'package:gopro_plugin/gopro_plugin.dart';

final controller = GoProController();
```

### Scan and Connect

```dart
// Start scanning for GoPro devices
await controller.startScan()

// Connect to a device
await controller.oneClickAutoConnect(device)
```

### Control Recording

```dart
// Start recording
await controller.startRecording()

// Stop recording
await controller.stopRecording()

// Tag a highlight moment
await controller.tagHighlight()
```

### Media Management

```dart
// Fetch media list from camera
await controller.fetchMediaList()

// Download a file
await controller.retrieveFile(mediaFile);

// Delete a file
await controller.deleteFile(mediaFile);
```

### Demo Mode

Test without a physical camera:

```dart
controller.toggleDemoMode(true);
```

## 🛠️ Project Structure

```
lib/
├── gopro_plugin.dart                  # Main plugin export
├── models/
│   └── gopro_models.dart              # GoProDevice, GoProStatus, GoProMediaFile, FileDownloadTask
└── services/
    ├── gopro_constants.dart           # Open GoPro UUIDs, Byte arrays, and HTTP Endpoints
    ├── gopro_ble_service.dart         # BLE scanning, pairing, shutter, and Wi-Fi AP control
    ├── gopro_http_service.dart        # HTTP REST API client, chunked file downloading
    ├── gopro_wifi_service.dart        # Wi-Fi connection management
    ├── gopro_preview_service.dart     # Camera preview streaming
    └── gopro_controller.dart         # High-level state orchestrator & Hardware Simulator

example/
├── lib/
│   ├── main.dart                      # Example app entry point
│   └── ui/                           # Example UI implementation
└── android/                          # Example Android app
└── ios/                              # Example iOS app
```

## 🧪 Testing

Run the example app to test the plugin:

```bash
cd example
flutter run
```

## 📝 Requirements

- **Android**: minSdk 21, Bluetooth and Location permissions
- **iOS**: iOS 12.0+, Bluetooth and Local Network permissions

## 📄 License

See the [LICENSE](LICENSE) file for details.
