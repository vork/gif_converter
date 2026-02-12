import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';

class DropZone extends StatefulWidget {
  final void Function(List<String> filePaths) onFilesDropped;

  const DropZone({super.key, required this.onFilesDropped});

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _isDragging = false;

  static const _videoExtensions = [
    'mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'wmv', 'm4v', 'mpg', 'mpeg',
  ];

  bool _isVideoFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return _videoExtensions.contains(ext);
  }

  /// Recursively collects all video file paths under [dirPath] (including subfolders).
  List<String> _collectVideosFromDirectory(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return [];
    final list = <String>[];
    try {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File && _isVideoFile(entity.path)) {
          list.add(entity.path);
        }
      }
    } catch (_) {
      // Skip directories we can't read (permissions, symlinks, etc.)
    }
    return list;
  }

  /// Expands paths: directories become all videos inside (recursive); files are included if video.
  List<String> _expandPathsToVideos(List<String> paths) {
    final out = <String>{};
    for (final path in paths) {
      final entity = File(path);
      final dir = Directory(path);
      if (dir.existsSync()) {
        out.addAll(_collectVideosFromDirectory(path));
      } else if (entity.existsSync() && _isVideoFile(path)) {
        out.add(path);
      }
    }
    return out.toList();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _videoExtensions,
      allowMultiple: true,
    );
    if (result != null) {
      final paths = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();
      if (paths.isNotEmpty) {
        widget.onFilesDropped(_expandPathsToVideos(paths));
      }
    }
  }

  Future<void> _pickFolder() async {
    final dirPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select folder with videos',
    );
    if (dirPath != null) {
      final videos = _collectVideosFromDirectory(dirPath);
      if (videos.isNotEmpty) {
        widget.onFilesDropped(videos);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = _isDragging
        ? theme.colorScheme.primary
        : theme.colorScheme.outline.withValues(alpha: 0.4);
    final bgColor = _isDragging
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerLow;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) {
        setState(() => _isDragging = false);
        final paths = details.files.map((f) => f.path).toList();
        final videos = _expandPathsToVideos(paths);
        if (videos.isNotEmpty) {
          widget.onFilesDropped(videos);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 180,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.video_file_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'Drop video files or a folder here',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Browse Files'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _pickFolder,
                    icon: const Icon(Icons.folder, size: 18),
                    label: const Text('Add Folder'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
