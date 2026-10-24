import 'package:flutter/material.dart';

import '../services/gopro_controller.dart';
import 'screens/connect_screen.dart';
import 'screens/media_screen.dart';
import 'screens/remote_screen.dart';
import 'widgets/terminal_log_sheet.dart';

class HomePage extends StatefulWidget {
  final GoProController controller;

  const HomePage({super.key, required this.controller});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final screens = [
          RemoteScreen(
            controller: controller,
            onNavigateToMedia: () => setState(() => _currentIndex = 1),
          ),
          MediaScreen(controller: controller),
          ConnectScreen(controller: controller),
        ];

        return Scaffold(
          backgroundColor: const Color(0xFF0D0F12),
          appBar: AppBar(
            backgroundColor: const Color(0xFF12141A),
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A3E0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.videocam, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GoPro Open API',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'BLE & Wi-Fi HTTP Controller',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              // Connection Quick Indicators
              Row(
                children: [
                  Tooltip(
                    message: controller.isBleConnected
                        ? 'BLE Connected'
                        : 'BLE Disconnected',
                    child: Icon(
                      Icons.bluetooth,
                      size: 20,
                      color: controller.isBleConnected
                          ? const Color(0xFF00A3E0)
                          : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: controller.isWifiConnected
                        ? 'Wi-Fi HTTP Connected'
                        : 'Wi-Fi Disconnected',
                    child: Icon(
                      Icons.wifi,
                      size: 20,
                      color: controller.isWifiConnected
                          ? const Color(0xFF4CAF50)
                          : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              // Logs Sheet Button
              IconButton(
                icon: const Icon(Icons.terminal, color: Color(0xFF00A3E0)),
                tooltip: 'Open GoPro Protocol Logs',
                onPressed: () => _openLogSheet(context, controller),
              ),
            ],
          ),
          body: screens[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: const Color(0xFF12141A),
            selectedItemColor: const Color(0xFF00A3E0),
            unselectedItemColor: Colors.grey[500],
            selectedFontSize: 12,
            unselectedFontSize: 12,
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.camera_alt),
                activeIcon: Icon(Icons.camera_alt, color: Color(0xFF00A3E0)),
                label: 'Remote',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  children: [
                    const Icon(Icons.photo_library),
                    if (controller.activeDownloads.values.any((d) => d.status == 'downloading'))
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00A3E0),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                label: 'Media',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  children: [
                    const Icon(Icons.bluetooth_connected),
                    if (controller.isBleConnected || controller.isWifiConnected)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                label: 'Connect',
              ),
            ],
          ),
        );
      },
    );
  }

  void _openLogSheet(BuildContext context, GoProController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TerminalLogSheet(logs: controller.logs),
    );
  }
}
