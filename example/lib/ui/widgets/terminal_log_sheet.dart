import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TerminalLogSheet extends StatelessWidget {
  final List<String> logs;

  const TerminalLogSheet({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF101216),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.terminal, color: Color(0xFF00A3E0), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Open GoPro Protocol Logs',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.grey, size: 20),
                  tooltip: 'Copy all logs',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: logs.join('\n')));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logs copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF262A33), height: 1),
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      'No protocol activity yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final line = logs[index];
                      Color textColor = const Color(0xFFC7CDD6);
                      if (line.contains('BLE') || line.contains('0x')) {
                        textColor = const Color(0xFF64B5F6);
                      } else if (line.contains('HTTP') || line.contains('200')) {
                        textColor = const Color(0xFF81C784);
                      } else if (line.contains('Error') || line.contains('failed')) {
                        textColor = const Color(0xFFFF5252);
                      } else if (line.contains('created') || line.contains('saved')) {
                        textColor = const Color(0xFFFFD54F);
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          line,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            color: textColor,
                            height: 1.3,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
