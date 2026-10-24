import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../services/gopro_constants.dart';
import '../../services/gopro_controller.dart';
import '../widgets/status_badge.dart';

class RemoteScreen extends StatefulWidget {
  final GoProController controller;
  final VoidCallback onNavigateToMedia;


  const RemoteScreen({
    super.key,
    required this.controller,
    required this.onNavigateToMedia,
  });

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _showGrid = false;
  // final videoController = previewServiceService.previewServicevideoController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isRecording = controller.status.isRecording;
    final mode = controller.currentMode;


    return Scaffold(
      backgroundColor: const Color(0xFF0D0F12),
      body: SafeArea(
        child: Column(
          children: [
            // Top Telemetry HUD
            _buildTelemetryHud(controller),

            // Camera Live Viewfinder Preview
            _buildLiveViewfinder(controller),

            // Mode Selector Bar (Video / Photo / Timelapse)
            const SizedBox(height: 12),
            _buildModeSelector(controller),
            const SizedBox(height: 12),

            // Live Recording Timer Display
            if (isRecording) ...[
              _buildRecordingTimer(controller),
              const SizedBox(height: 10),
            ] else if (mode == 'Photo') ...[
              const Text(
                'READY TO CAPTURE PHOTO',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
            ] else ...[
              const Text(
                'STANDBY - READY TO RECORD',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Shutter Button
            _buildShutterButton(controller),
            const SizedBox(height: 14),

            // Action Buttons (Tag Highlight, etc.)
            _buildSecondaryActions(controller),

            const Spacer(),

            // Last Created File Banner (if any)
            if (controller.lastCreatedFile != null)
              _buildLastCreatedFileBanner(controller),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveViewfinder(GoProController controller) {
    final previewService = controller.previewService;
    final isStreaming = previewService.isStreaming;
    final isConnecting = previewService.isConnecting;
    final videoController = previewService.videoController;


    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF14171E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isStreaming ? const Color(0xFF00A3E0) : const Color(0xFF222733),
          width: isStreaming ? 1.5 : 1.0,
        ),
        boxShadow: isStreaming
            ? [
                BoxShadow(
                  color: const Color(0xFF00A3E0).withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // WebView placeholder showing stream status
            if (isStreaming && videoController != null)
              SizedBox.expand(
                child: Video(
                  controller: videoController,
                  controls: NoVideoControls,
                  fit: BoxFit.cover,
                ),
              )
            else if (isConnecting)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF00A3E0)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Starting Live Camera Stream...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Connecting to stream: ${previewService.streamUrl ?? "Unknown"}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                ],
              )
            else
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C202C),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF2B3142)),
                    ),
                    child: const Icon(
                      Icons.videocam_outlined,
                      color: Color(0xFF00A3E0),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Camera Live Preview',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.isWifiConnected || controller.isDemoMode
                        ? 'Tap below to attempt preview stream'
                        : 'Requires phone connected to camera Wi-Fi',
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (!isStreaming) {
                        controller.startCameraPreview();
                      }
                    },
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Start Preview'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A3E0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),

            // Top Stream HUD Overlays
            if (isStreaming) ...[
              if (_showGrid) _buildGridOverlay(),

              Positioned(
                top: 10,
                left: 10,
                child: Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF3B30),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'RTMP Stream',
                        style: TextStyle(
                          color: Color(0xFF00A3E0),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                top: 6,
                right: 6,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _showGrid ? Icons.grid_on : Icons.grid_off,
                        color: Colors.white70,
                        size: 20,
                      ),
                      tooltip: 'Toggle Framing Grid',
                      onPressed: () => setState(() => _showGrid = !_showGrid),
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop_circle,
                          color: Colors.redAccent, size: 22),
                      tooltip: 'Stop Preview',
                      onPressed: () => controller.stopCameraPreview(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGridOverlay() {
    return IgnorePointer(
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: Container()),
                const VerticalDivider(color: Colors.white24, width: 1),
                Expanded(child: Container()),
                const VerticalDivider(color: Colors.white24, width: 1),
                Expanded(child: Container()),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          Expanded(
            child: Row(
              children: [
                Expanded(child: Container()),
                const VerticalDivider(color: Colors.white24, width: 1),
                Expanded(child: Container()),
                const VerticalDivider(color: Colors.white24, width: 1),
                Expanded(child: Container()),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          Expanded(
            child: Row(
              children: [
                Expanded(child: Container()),
                const VerticalDivider(color: Colors.white24, width: 1),
                Expanded(child: Container()),
                const VerticalDivider(color: Colors.white24, width: 1),
                Expanded(child: Container()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryHud(GoProController controller) {
    final status = controller.status;
    final isConnected =
        controller.isBleConnected || controller.isWifiConnected;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF14171E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF222733)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              StatusBadge(
                icon: Icons.battery_std,
                label: '${status.batteryPercent}%',
                color: status.batteryPercent > 20
                    ? const Color(0xFF4CAF50)
                    : Colors.redAccent,
              ),
              const SizedBox(width: 8),
              StatusBadge(
                icon: Icons.sd_storage,
                label: status.formattedRemainingStorage,
                color: const Color(0xFF00A3E0),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                icon: Icons.timer,
                label: status.formattedRemainingTime,
                color: Colors.purpleAccent,
              ),
            ],
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected ? const Color(0xFF4CAF50) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(GoProController controller) {
    final modes = ['Video', 'Photo', 'Timelapse'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF14171E),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF222733)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: modes.map((m) {
          final isSelected = controller.currentMode == m;
          return GestureDetector(
            onTap: controller.status.isRecording
                ? null
                : () => controller.setCaptureMode(m),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF00A3E0)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                m.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[400],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecordingTimer(GoProController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFF3B30),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x88FF3B30),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 10),
        Text(
          controller.formattedRecordingTime,
          style: const TextStyle(
            color: Color(0xFFFF3B30),
            fontSize: 34,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }

  Widget _buildShutterButton(GoProController controller) {
    final isRecording = controller.status.isRecording;
    final isPhoto = controller.currentMode == 'Photo';

    final buttonCore = GestureDetector(
      onTap: () {
        if (isPhoto) {
          controller.startRecording();
        } else {
          if (isRecording) {
            controller.stopRecording();
          } else {
            controller.startRecording();
          }
        }
      },
      child: Container(
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(color: Colors.white, width: 4.0),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: isRecording ? 30 : (isPhoto ? 62 : 62),
            height: isRecording ? 30 : (isPhoto ? 62 : 62),
            decoration: BoxDecoration(
              color: isPhoto ? Colors.white : const Color(0xFFFF3B30),
              borderRadius: BorderRadius.circular(isRecording ? 8 : 40),
            ),
            child: isPhoto
                ? const Icon(Icons.camera_alt, color: Colors.black87, size: 28)
                : null,
          ),
        ),
      ),
    );

    if (isRecording) {
      return ScaleTransition(
        scale: _pulseAnimation,
        child: buttonCore,
      );
    }
    return buttonCore;
  }

  Widget _buildSecondaryActions(GoProController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: (controller.isBleConnected || controller.isWifiConnected)
              ? () => controller.tagHighlight()
              : null,
          icon: const Icon(Icons.bookmark_add, size: 16),
          label: const Text('Hilight Moment'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E222D),
            foregroundColor: const Color(0xFFFFD54F),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF2C3242)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLastCreatedFileBanner(GoProController controller) {
    final file = controller.lastCreatedFile!;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF00A3E0).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF00A3E0).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              file.isVideo ? Icons.movie : Icons.photo,
              color: const Color(0xFF00A3E0),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Created on SD Card',
                  style: TextStyle(color: Color(0xFF00A3E0), fontSize: 11),
                ),
                Text(
                  file.filename,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  file.formattedSize,
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onNavigateToMedia();
              controller.retrieveFile(file);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A3E0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Retrieve', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
