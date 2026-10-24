import 'package:flutter/material.dart';

import '../../services/gopro_constants.dart';
import '../../services/gopro_controller.dart';
import '../widgets/status_badge.dart';

class ConnectScreen extends StatefulWidget {
  final GoProController controller;

  const ConnectScreen({super.key, required this.controller});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  late final TextEditingController _ipController;
  late final TextEditingController _passwordController;
  late final TextEditingController _ssidController;
  bool _showAdvancedSettings = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(
      text: widget.controller.currentDevice?.gatewayIp ??
          GoProConstants.defaultCameraIp,
    );
    _passwordController = TextEditingController(
      text: widget.controller.currentDevice?.wifiPassword ?? '',
    );
    _ssidController = TextEditingController(
      text: widget.controller.currentDevice?.wifiSsid ?? '',
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    _passwordController.dispose();
    _ssidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F12),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Demo Mode Banner
                  _buildDemoModeBanner(controller),
                  const SizedBox(height: 14),

                  // Active Auto-Connecting Progress HUD
                  if (controller.isAutoConnecting ||
                      controller.autoConnectStep != null)
                    _buildAutoConnectProgress(controller),

                  // Connection Overview Card
                  _buildActiveConnectionCard(controller),
                  const SizedBox(height: 20),

                  // 1-Click Connect & Discovered Cameras Section
                  _buildSectionHeader(
                    icon: Icons.flash_on,
                    title: '1-Click Direct Connect',
                    trailing: controller.isScanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Color(0xFF00A3E0)),
                            ),
                          )
                        : TextButton.icon(
                            onPressed: () => controller.startScan(),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Scan Nearby'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF00A3E0),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  _buildDiscoveredDevicesList(controller),
                  const SizedBox(height: 20),

                  // Advanced / Manual Setup Accordion
                  _buildAdvancedSettingsAccordion(controller),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoConnectProgress(GoProController controller) {
    final stepText = controller.autoConnectStep ?? '';
    final isError = stepText.toLowerCase().contains('error') ||
        stepText.toLowerCase().contains('failed');
    final isSuccess = stepText.contains('✅') || stepText.contains('success');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError
            ? const Color(0xFF2E1A1A)
            : isSuccess
                ? const Color(0xFF142E1F)
                : const Color(0xFF142436),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isError
              ? Colors.redAccent
              : isSuccess
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFF00A3E0),
        ),
      ),
      child: Row(
        children: [
          if (controller.isAutoConnecting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(Color(0xFF00A3E0)),
              ),
            )
          else
            Icon(
              isError
                  ? Icons.error_outline
                  : isSuccess
                      ? Icons.check_circle
                      : Icons.info_outline,
              color: isError
                  ? Colors.redAccent
                  : isSuccess
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF00A3E0),
              size: 22,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              stepText,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoModeBanner(GoProController controller) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: controller.isDemoMode
            ? const Color(0xFF1E2836)
            : const Color(0xFF161920),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: controller.isDemoMode
              ? const Color(0xFF00A3E0)
              : const Color(0xFF232730),
        ),
      ),
      child: Row(
        children: [
          Icon(
            controller.isDemoMode ? Icons.science : Icons.science_outlined,
            color: controller.isDemoMode
                ? const Color(0xFF00A3E0)
                : Colors.grey[500],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Simulator / Demo Mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  controller.isDemoMode
                      ? 'Simulating GoPro HERO12 with mock media files'
                      : 'Test without physical GoPro hardware nearby',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: controller.isDemoMode,
            activeTrackColor: const Color(0xFF00A3E0),
            onChanged: (val) => controller.toggleDemoMode(val),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveConnectionCard(GoProController controller) {
    final device = controller.currentDevice;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1E26), Color(0xFF12141A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262C38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A3E0).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.videocam,
                      color: Color(0xFF00A3E0),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device?.name ?? 'No GoPro Connected',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        device != null
                            ? (controller.isWifiConnected
                                ? 'Full Control (BLE + Wi-Fi HTTP)'
                                : controller.isBleConnected
                                    ? 'BLE Connected (Low-Power)'
                                    : 'Disconnected')
                            : 'Scan nearby & click 1-Click Connect',
                        style: TextStyle(
                          color: controller.isWifiConnected
                              ? const Color(0xFF4CAF50)
                              : Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (controller.isBleConnected || controller.isWifiConnected)
                IconButton(
                  icon: const Icon(Icons.link_off, color: Colors.redAccent),
                  tooltip: 'Disconnect',
                  onPressed: () => controller.disconnect(),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(
                icon: Icons.bluetooth,
                label: controller.isBleConnected
                    ? 'BLE Linked'
                    : 'BLE Disconnected',
                color: controller.isBleConnected
                    ? const Color(0xFF00A3E0)
                    : Colors.grey,
              ),
              StatusBadge(
                icon: Icons.wifi,
                label: controller.isWifiConnected
                    ? 'Wi-Fi HTTP Linked'
                    : 'Wi-Fi Standby',
                color: controller.isWifiConnected
                    ? const Color(0xFF4CAF50)
                    : Colors.grey,
              ),
              if (controller.isBleConnected || controller.isWifiConnected)
                StatusBadge(
                  icon: Icons.battery_charging_full,
                  label: '${controller.status.batteryPercent}% Battery',
                  color: controller.status.batteryPercent > 20
                      ? const Color(0xFF4CAF50)
                      : Colors.orangeAccent,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF00A3E0), size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        ?trailing,
      ],
    );
  }

  Widget _buildDiscoveredDevicesList(GoProController controller) {
    if (controller.discoveredDevices.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF14171E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF202530)),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.bluetooth_audio, size: 36, color: Colors.grey[600]),
              const SizedBox(height: 10),
              Text(
                controller.isScanning
                    ? 'Scanning for nearby GoPro cameras...'
                    : 'No GoPro cameras found yet.',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => controller.startScan(),
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Start Scan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A3E0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: controller.discoveredDevices.map((device) {
        final isSelected = controller.currentDevice?.id == device.id &&
            controller.isBleConnected;
        final isFullyConnected = isSelected && controller.isWifiConnected;
        final isThisConnecting = controller.isAutoConnecting &&
            controller.currentDevice?.id == device.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF161922),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isFullyConnected
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.6)
                  : isSelected
                      ? const Color(0xFF00A3E0)
                      : const Color(0xFF222733),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isFullyConnected
                        ? const Color(0xFF1E3A2F)
                        : isSelected
                            ? const Color(0xFF00A3E0)
                            : const Color(0xFF232834),
                    child: Icon(
                      isFullyConnected
                          ? Icons.check
                          : Icons.camera_alt,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'RSSI: ${device.rssi} dBm | ID: ${device.id}',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (isFullyConnected)
                    const Chip(
                      label: Text('Ready', style: TextStyle(fontSize: 11)),
                      backgroundColor: Color(0xFF1E3A2F),
                      labelStyle: TextStyle(color: Color(0xFF4CAF50)),
                      avatar: Icon(Icons.check,
                          size: 14, color: Color(0xFF4CAF50)),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: controller.isAutoConnecting
                          ? null
                          : () => controller.oneClickAutoConnect(
                                device,
                                manualPassword:
                                    _passwordController.text.trim(),
                              ),
                      icon: isThisConnecting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.flash_on, size: 16),
                      label: Text(
                        isThisConnecting
                            ? 'Connecting...'
                            : '1-Click Connect',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A3E0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAdvancedSettingsAccordion(GoProController controller) {
    // Keep SSID/Password field in sync with the controller's resolved creds
    if (_ssidController.text.isEmpty &&
        (controller.currentDevice?.wifiSsid?.isNotEmpty ?? false)) {
      _ssidController.text = controller.currentDevice!.wifiSsid!;
    }
    if (_passwordController.text.isEmpty &&
        (controller.currentDevice?.wifiPassword?.isNotEmpty ?? false)) {
      _passwordController.text = controller.currentDevice!.wifiPassword!;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14171E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF202530)),
      ),
      child: ExpansionTile(
        initiallyExpanded: _showAdvancedSettings,
        onExpansionChanged: (val) => setState(() => _showAdvancedSettings = val),
        leading: const Icon(Icons.tune, color: Color(0xFF00A3E0), size: 20),
        title: const Text(
          'Manual & Wi-Fi Credential Options',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Use if auto-connect fails or SSID was not read automatically',
          style: TextStyle(color: Colors.grey[500], fontSize: 11),
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          // ----- SSID Field -----
          TextField(
            controller: _ssidController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Camera Wi-Fi SSID (Network Name)',
              hintText: 'e.g. GP24928172 or GoPro 1234',
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 11),
              labelStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.wifi, color: Color(0xFF00A3E0), size: 18),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF0D0F13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF282E3A)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ----- Password Field -----
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Camera Wi-Fi Password',
              hintText: 'Enter camera Wi-Fi password if not auto-detected',
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 11),
              labelStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00A3E0), size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[500],
                  size: 18,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF0D0F13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF282E3A)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ----- Read Credentials from BLE -----
          if (controller.isBleConnected)
            OutlinedButton.icon(
              onPressed: () async {
                final creds = await controller.bleService.readWifiCredentials(retries: 3);
                if (creds['ssid']?.isNotEmpty == true) {
                  setState(() {
                    _ssidController.text = creds['ssid']!;
                    _passwordController.text = creds['password'] ?? '';
                  });
                }
              },
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Re-Read Credentials from Camera BLE'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00A3E0),
                side: const BorderSide(color: Color(0xFF00A3E0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

          const SizedBox(height: 12),

          // ----- Connect with manual SSID+Password -----
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (controller.isBleConnected &&
                      _ssidController.text.trim().isNotEmpty)
                  ? () {
                      final device = controller.currentDevice;
                      if (device != null) {
                        controller.oneClickAutoConnect(
                          device.copyWith(
                            wifiSsid: _ssidController.text.trim(),
                            wifiPassword: _passwordController.text.trim(),
                          ),
                          manualPassword: _passwordController.text.trim(),
                        );
                      }
                    }
                  : null,
              icon: const Icon(Icons.wifi_password, size: 16),
              label: const Text('Connect with Manual SSID + Password'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3A50),
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF00A3E0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          const Divider(color: Color(0xFF252A35), height: 28),

          // ----- Manual Wi-Fi Turn On Button -----
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: controller.isBleConnected
                  ? () => controller.enableWifiAp()
                  : null,
              icon: const Icon(Icons.power_settings_new, size: 16),
              label: const Text('Turn ON Camera Wi-Fi Hotspot (BLE)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4CAF50),
                side: const BorderSide(color: Color(0xFF4CAF50)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ----- Manual IP & Ping Gateway -----
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'GoPro Gateway IP',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.router, color: Color(0xFF00A3E0), size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF0D0F13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF282E3A)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => controller.connectWifiHttp(
                  host: _ipController.text.trim(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: controller.isWifiConnected
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF00A3E0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  controller.isWifiConnected ? 'Linked ✓' : 'Ping & Connect',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
