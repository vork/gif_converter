import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'binary_resolver.dart';
import '../models/conversion_settings.dart';

class FfmpegService {
  String? _ffmpegPath;
  String? _gifsicklePath;

  Future<String> get ffmpegPath async {
    _ffmpegPath ??= await BinaryResolver.resolve('ffmpeg');
    return _ffmpegPath!;
  }

  Future<String> get gifsicklePath async {
    _gifsicklePath ??= await BinaryResolver.resolve('gifsicle');
    return _gifsicklePath!;
  }

  Future<double> getVideoDuration(String inputPath) async {
    final ffmpeg = await ffmpegPath;
    final result = await Process.run(ffmpeg, ['-i', inputPath], stderrEncoding: utf8);
    final stderr = result.stderr as String;

    final regex = RegExp(r'Duration:\s+(\d+):(\d+):(\d+)\.(\d+)');
    final match = regex.firstMatch(stderr);
    if (match != null) {
      return int.parse(match.group(1)!) * 3600.0 +
          int.parse(match.group(2)!) * 60.0 +
          int.parse(match.group(3)!) +
          int.parse(match.group(4)!) / 100.0;
    }
    return 0;
  }

  Future<String> _generatePalette(
    String inputPath,
    ConversionSettings settings,
    String palettePath,
  ) async {
    final ffmpeg = await ffmpegPath;

    final filters = <String>[];
    filters.add('fps=${settings.fps}');
    if (settings.width != null) {
      filters.add('scale=${settings.width}:-2:flags=lanczos');
    }
    final statsMode = settings.useLocalColorTables ? 'diff' : 'full';
    filters.add('palettegen=stats_mode=$statsMode');

    final args = [
      '-i', inputPath,
      '-vf', filters.join(','),
      '-y', palettePath,
    ];

    final process = await Process.start(ffmpeg, args);
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      final stderr = await process.stderr.transform(utf8.decoder).join();
      throw Exception('Palette generation failed (exit $exitCode): $stderr');
    }
    return palettePath;
  }

  Future<void> _createGif(
    String inputPath,
    String palettePath,
    String outputPath,
    ConversionSettings settings,
    double totalDuration,
    void Function(double progress, String status) onProgress,
  ) async {
    final ffmpeg = await ffmpegPath;

    final scaleAndFps = <String>[];
    scaleAndFps.add('fps=${settings.fps}');
    if (settings.width != null) {
      scaleAndFps.add('scale=${settings.width}:-2:flags=lanczos');
    }

    final paletteOpts = StringBuffer('paletteuse=dither=${settings.ditherMode}');
    if (settings.ditherMode == 'bayer') {
      paletteOpts.write(':bayer_scale=${settings.bayerScale}');
    }
    if (settings.useLocalColorTables) {
      paletteOpts.write(':diff_mode=rectangle:new=1');
    }

    final filterComplex =
        '${scaleAndFps.join(',')} [x]; [x][1:v] $paletteOpts';

    final args = [
      '-i', inputPath,
      '-i', palettePath,
      '-lavfi', filterComplex,
      '-loop', settings.loop ? '0' : '-1',
      '-y', outputPath,
    ];

    final process = await Process.start(ffmpeg, args);

    final timeRegex = RegExp(r'time=(\d+):(\d+):(\d+)\.(\d+)');
    process.stderr.transform(utf8.decoder).listen((data) {
      final match = timeRegex.firstMatch(data);
      if (match != null && totalDuration > 0) {
        final current = int.parse(match.group(1)!) * 3600.0 +
            int.parse(match.group(2)!) * 60.0 +
            int.parse(match.group(3)!) +
            int.parse(match.group(4)!) / 100.0;
        final progress = (current / totalDuration).clamp(0.0, 1.0);
        onProgress(progress, 'Creating GIF...');
      }
    });

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw Exception('GIF creation failed (exit $exitCode)');
    }
  }

  Future<void> _optimizeWithGifsicle(
    String gifPath,
    ConversionSettings settings,
    void Function(double progress, String status) onProgress,
  ) async {
    final gifsicle = await gifsicklePath;

    onProgress(0.0, 'Optimizing with lossy compression...');

    final args = [
      '--lossy=${settings.lossyLevel}',
      '-O3',
      '-b',
      gifPath,
    ];

    final process = await Process.start(gifsicle, args);
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      final stderr = await process.stderr.transform(utf8.decoder).join();
      throw Exception('Gifsicle optimization failed (exit $exitCode): $stderr');
    }

    onProgress(1.0, 'Optimization complete');
  }

  Future<String> convertToGif({
    required String inputPath,
    required ConversionSettings settings,
    required void Function(double progress, String status) onProgress,
  }) async {
    final outputDir = p.dirname(inputPath);
    final baseName = p.basenameWithoutExtension(inputPath);
    final outputPath = p.join(outputDir, '$baseName.gif');
    final palettePath = p.join(
      Directory.systemTemp.path,
      'gif_palette_${DateTime.now().millisecondsSinceEpoch}.png',
    );

    try {
      onProgress(0.0, 'Analyzing video...');
      final duration = await getVideoDuration(inputPath);

      onProgress(0.05, 'Generating color palette...');
      await _generatePalette(inputPath, settings, palettePath);

      onProgress(0.1, 'Creating GIF...');
      await _createGif(
        inputPath,
        palettePath,
        outputPath,
        settings,
        duration,
        (p, s) => onProgress(0.1 + p * 0.8, s),
      );

      if (settings.enableLossyCompression) {
        onProgress(0.9, 'Applying lossy compression...');
        await _optimizeWithGifsicle(
          outputPath,
          settings,
          (p, s) => onProgress(0.9 + p * 0.1, s),
        );
      }

      onProgress(1.0, 'Done!');
      return outputPath;
    } finally {
      try {
        await File(palettePath).delete();
      } catch (_) {}
    }
  }
}
