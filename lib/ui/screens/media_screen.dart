import 'package:flutter/material.dart';

import '../../models/gopro_models.dart';
import '../../services/gopro_controller.dart';

class MediaScreen extends StatefulWidget {
  final GoProController controller;

  const MediaScreen({super.key, required this.controller});

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  String _filter = 'All'; // 'All', 'Videos', 'Photos', 'Retrieved'

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12141A),
        elevation: 0,
        title: const Text(
          'Camera Media & Retrieval',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: controller.isLoadingMedia
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF00A3E0)),
                    ),
                  )
                : const Icon(Icons.refresh, color: Color(0xFF00A3E0)),
            tooltip: 'Refresh media list',
            onPressed: () => controller.fetchMediaList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          _buildFilterBar(),

          // Main Content
          Expanded(
            child: _filter == 'Retrieved'
                ? _buildLocalSavedFilesList(controller)
                : _buildCameraMediaList(controller),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = ['All', 'Videos', 'Photos', 'Retrieved'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF12141A),
      child: Row(
        children: filters.map((f) {
          final isSelected = _filter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              selectedColor: const Color(0xFF00A3E0),
              backgroundColor: const Color(0xFF1E222D),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF00A3E0)
                    : const Color(0xFF282E3A),
              ),
              onSelected: (_) => setState(() => _filter = f),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCameraMediaList(GoProController controller) {
    if (controller.isLoadingMedia) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFF00A3E0)),
            ),
            SizedBox(height: 16),
            Text(
              'Querying media list from GoPro SD card...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final filtered = controller.mediaFiles.where((file) {
      if (_filter == 'Videos') return file.isVideo;
      if (_filter == 'Photos') return file.isPhoto;
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_library_outlined, size: 50, color: Colors.grey[600]),
              const SizedBox(height: 14),
              const Text(
                'No media files found on camera',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                controller.isWifiConnected
                    ? 'Start recording to capture videos or photos'
                    : 'Connect to camera Wi-Fi to list files',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => controller.fetchMediaList(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Fetch Files (/gopro/media/list)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A3E0),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.fetchMediaList(),
      color: const Color(0xFF00A3E0),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final file = filtered[index];
          final downloadTask = controller.activeDownloads[file.relativePath];
          return _buildMediaCard(file, downloadTask, controller);
        },
      ),
    );
  }

  Widget _buildMediaCard(
    GoProMediaFile file,
    FileDownloadTask? downloadTask,
    GoProController controller,
  ) {
    final isDownloading = downloadTask?.status == 'downloading';
    final isCompleted = downloadTask?.status == 'completed' || file.isDownloaded;
    final progress = downloadTask?.progress ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151821),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF2E7D32).withValues(alpha: 0.5)
              : const Color(0xFF222733),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Media Icon / Thumbnail placeholder
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: file.isVideo
                      ? const Color(0xFF00A3E0).withValues(alpha: 0.15)
                      : Colors.orangeAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  file.isVideo ? Icons.movie_creation : Icons.photo,
                  color: file.isVideo
                      ? const Color(0xFF00A3E0)
                      : Colors.orangeAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // File Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.filename,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          file.formattedSize,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•  ${file.directory}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action Buttons
              if (isDownloading)
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF00A3E0)),
                  ),
                )
              else if (isCompleted)
                const Chip(
                  label: Text('Saved', style: TextStyle(fontSize: 11)),
                  backgroundColor: Color(0xFF1E3A2F),
                  labelStyle: TextStyle(color: Color(0xFF4CAF50)),
                  avatar: Icon(Icons.check, size: 14, color: Color(0xFF4CAF50)),
                )
              else
                IconButton(
                  icon: const Icon(Icons.download, color: Color(0xFF00A3E0)),
                  tooltip: 'Retrieve file to device storage',
                  onPressed: () => controller.retrieveFile(file),
                ),
              // Delete from camera
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                color: const Color(0xFF1E222D),
                onSelected: (val) {
                  if (val == 'delete') {
                    _confirmDelete(context, file, controller);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.redAccent, size: 18),
                        SizedBox(width: 8),
                        Text('Delete from camera', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Download Progress Bar
          if (isDownloading) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF232833),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF00A3E0)),
              minHeight: 5,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Retrieving to phone storage...',
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFF00A3E0),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocalSavedFilesList(GoProController controller) {
    final localFiles = controller.localSavedFiles;

    if (localFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 12),
            const Text(
              'No retrieved files yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Downloaded GoPro files will be saved in mobile storage',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: localFiles.length,
      itemBuilder: (context, index) {
        final file = localFiles[index];
        final filename = file.uri.pathSegments.last;
        final sizeBytes = file.existsSync() ? file.lengthSync() : 0;
        final sizeMb = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF151821),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF222733)),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF1E3A2F),
              child: Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
            ),
            title: Text(
              filename,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              'Size: $sizeMb MB\nPath: ${file.path}',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: () async {
                if (await file.exists()) {
                  await file.delete();
                  controller.loadLocalSavedFiles();
                }
              },
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    GoProMediaFile file,
    GoProController controller,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C202B),
        title: const Text('Delete from Camera?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete ${file.filename} from the GoPro SD card?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.deleteFile(file);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
