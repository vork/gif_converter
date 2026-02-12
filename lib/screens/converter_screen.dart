import 'dart:io';
import 'package:flutter/material.dart';
import '../models/conversion_settings.dart';
import '../models/conversion_job.dart';
import '../services/ffmpeg_service.dart';
import '../widgets/drop_zone.dart';
import '../widgets/file_list.dart';
import '../widgets/settings_panel.dart';
import '../widgets/gif_preview.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  final List<ConversionJob> _jobs = [];
  ConversionSettings _settings = const ConversionSettings();
  bool _isConverting = false;
  int? _previewIndex;
  final _ffmpegService = FfmpegService();

  void _addFiles(List<String> paths) {
    setState(() {
      for (final path in paths) {
        if (!_jobs.any((j) => j.inputPath == path)) {
          _jobs.add(ConversionJob(inputPath: path));
        }
      }
    });
  }

  void _removeJob(int index) {
    setState(() {
      if (_previewIndex == index) {
        _previewIndex = null;
      } else if (_previewIndex != null && _previewIndex! > index) {
        _previewIndex = _previewIndex! - 1;
      }
      _jobs.removeAt(index);
    });
  }

  void _clearAll() {
    setState(() {
      _jobs.clear();
      _previewIndex = null;
    });
  }

  Future<void> _startConversion() async {
    if (_jobs.isEmpty || _isConverting) return;

    setState(() {
      _isConverting = true;
      _previewIndex = null;
      for (final job in _jobs) {
        if (job.status != ConversionJobStatus.done) {
          job.status = ConversionJobStatus.pending;
          job.progress = 0;
          job.errorMessage = null;
          job.outputPath = null;
          job.outputFileSize = null;
        }
      }
    });

    for (int i = 0; i < _jobs.length; i++) {
      final job = _jobs[i];
      if (job.status == ConversionJobStatus.done) continue;

      setState(() {
        job.status = ConversionJobStatus.converting;
        job.progress = 0;
        job.statusText = 'Starting...';
      });

      try {
        final outputPath = await _ffmpegService.convertToGif(
          inputPath: job.inputPath,
          settings: _settings,
          onProgress: (progress, status) {
            setState(() {
              job.progress = progress;
              job.statusText = status;
              if (status.contains('lossy') || status.contains('Optimiz')) {
                job.status = ConversionJobStatus.optimizing;
              }
            });
          },
        );

        final outputFile = File(outputPath);
        setState(() {
          job.status = ConversionJobStatus.done;
          job.progress = 1.0;
          job.outputPath = outputPath;
          job.outputFileSize = outputFile.lengthSync();
          job.statusText = 'Done';
        });
      } catch (e) {
        setState(() {
          job.status = ConversionJobStatus.error;
          job.errorMessage = e.toString();
          job.statusText = 'Error';
        });
      }
    }

    setState(() {
      _isConverting = false;
    });
  }

  int get _pendingCount =>
      _jobs.where((j) => j.status != ConversionJobStatus.done).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GifDrop'),
        centerTitle: false,
        actions: [
          if (_jobs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed:
                    _isConverting || _pendingCount == 0
                        ? null
                        : _startConversion,
                icon: _isConverting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow, size: 20),
                label: Text(
                  _isConverting
                      ? 'Converting...'
                      : 'Convert${_pendingCount > 0 ? ' ($_pendingCount)' : ''}',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: theme.textTheme.labelLarge,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropZone(onFilesDropped: _addFiles),

                if (_jobs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  FileList(
                    jobs: _jobs,
                    selectedIndex: _previewIndex,
                    onSelect: (i) => setState(() => _previewIndex = i),
                    onRemove: _isConverting ? (_) {} : _removeJob,
                    onClearAll: _isConverting ? () {} : _clearAll,
                  ),
                ],

                const SizedBox(height: 16),
                SettingsPanel(
                  settings: _settings,
                  onSettingsChanged: (s) => setState(() => _settings = s),
                  enabled: !_isConverting,
                ),

                if (_previewIndex != null &&
                    _previewIndex! < _jobs.length &&
                    _jobs[_previewIndex!].outputPath != null) ...[
                  const SizedBox(height: 16),
                  GifPreview(
                    gifPath: _jobs[_previewIndex!].outputPath!,
                    onDismiss: () => setState(() => _previewIndex = null),
                  ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
