import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

class GifPreview extends StatelessWidget {
  final String gifPath;
  final VoidCallback onDismiss;

  const GifPreview({
    super.key,
    required this.gifPath,
    required this.onDismiss,
  });

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _saveAs() async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save GIF',
      fileName: p.basename(gifPath),
      type: FileType.custom,
      allowedExtensions: ['gif'],
    );
    if (result != null) {
      await File(gifPath).copy(result);
    }
  }

  Future<void> _showInFinder() async {
    if (Platform.isMacOS) {
      await Process.run('open', ['-R', gifPath]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', ['/select,', gifPath]);
    } else {
      await Process.run('xdg-open', [p.dirname(gifPath)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(gifPath);
    final exists = file.existsSync();
    final size = exists ? file.lengthSync() : 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Preview', style: theme.textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onDismiss,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (exists)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      file,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              )
            else
              Center(
                child: Text(
                  'File not found',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.data_usage,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatFileSize(size),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _saveAs,
                  icon: const Icon(Icons.save_alt, size: 18),
                  label: const Text('Save As...'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _showInFinder,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: Text(
                    Platform.isMacOS ? 'Show in Finder' : 'Show in Explorer',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
