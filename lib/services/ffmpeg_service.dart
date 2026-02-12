import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'binary_resolver.dart';
import '../models/conversion_settings.dart';

/// Thrown when conversion is stopped by user (Cancel).
class ConversionCancelledException implements Exception {
  @override
  String toString() => 'Conversion cancelled';
}

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

  /// Run a process, drain stderr, and return (exitCode, stderrText).
  /// If [cancelSignal] completes first, kills the process and throws [ConversionCancelledException].
  Future<(int, String)> _runProcess(
    String executable,
    List<String> args, {
    void Function(String chunk)? onStderr,
    Future<void>? cancelSignal,
  }) async {
    final process = await Process.start(executable, args);

    process.stdout.drain<void>();

    final stderrBuf = StringBuffer();
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .listen((chunk) {
          stderrBuf.write(chunk);
          onStderr?.call(chunk);
        })
        .asFuture<void>();

    int? exitCode;
    if (cancelSignal != null) {
      try {
        await Future.any([
          (() async {
            await stderrDone;
            exitCode = await process.exitCode;
          })(),
          cancelSignal.then((_) async {
            process.kill(ProcessSignal.sigterm);
            await process.exitCode;
            throw ConversionCancelledException();
          }),
        ]);
      } on ConversionCancelledException {
        rethrow;
      }
    } else {
      await stderrDone;
      exitCode = await process.exitCode;
    }
    return (exitCode!, stderrBuf.toString());
  }

  Future<double> getVideoDuration(String inputPath, {Future<void>? cancelSignal}) async {
    final ffmpeg = await ffmpegPath;
    final (_, stderr) = await _runProcess(ffmpeg, ['-i', inputPath], cancelSignal: cancelSignal);

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
    String palettePath, {
    Future<void>? cancelSignal,
  }) async {
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

    final (exitCode, stderr) = await _runProcess(ffmpeg, args, cancelSignal: cancelSignal);
    if (exitCode != 0) {
      throw Exception('Palette generation failed (exit $exitCode):\n$stderr');
    }
    return palettePath;
  }

  Future<void> _createGif(
    String inputPath,
    String palettePath,
    String outputPath,
    ConversionSettings settings,
    double totalDuration,
    void Function(double progress, String status) onProgress, {
    Future<void>? cancelSignal,
  }) async {
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

    final timeRegex = RegExp(r'time=(\d+):(\d+):(\d+)\.(\d+)');
    final (exitCode, stderr) = await _runProcess(ffmpeg, args,
        onStderr: (chunk) {
      final match = timeRegex.firstMatch(chunk);
      if (match != null && totalDuration > 0) {
        final current = int.parse(match.group(1)!) * 3600.0 +
            int.parse(match.group(2)!) * 60.0 +
            int.parse(match.group(3)!) +
            int.parse(match.group(4)!) / 100.0;
        final progress = (current / totalDuration).clamp(0.0, 1.0);
        onProgress(progress, 'Creating GIF...');
      }
    },
        cancelSignal: cancelSignal);

    if (exitCode != 0) {
      throw Exception('GIF creation failed (exit $exitCode):\n$stderr');
    }
  }

  Future<void> _optimizeWithGifsicle(
    String gifPath,
    ConversionSettings settings,
    void Function(double progress, String status) onProgress, {
    Future<void>? cancelSignal,
  }) async {
    final gifsicle = await gifsicklePath;

    onProgress(0.0, 'Optimizing with lossy compression...');

    final args = [
      '--lossy=${settings.lossyLevel}',
      '-O3',
      '-b',
      gifPath,
    ];

    final (exitCode, stderr) = await _runProcess(gifsicle, args, cancelSignal: cancelSignal);
    if (exitCode != 0) {
      throw Exception('Gifsicle optimization failed (exit $exitCode):\n$stderr');
    }

    onProgress(1.0, 'Optimization complete');
  }

  Future<String> convertToGif({
    required String inputPath,
    required ConversionSettings settings,
    required void Function(double progress, String status) onProgress,
    Future<void>? cancelSignal,
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
      final duration = await getVideoDuration(inputPath, cancelSignal: cancelSignal);

      onProgress(0.05, 'Generating color palette...');
      await _generatePalette(inputPath, settings, palettePath, cancelSignal: cancelSignal);

      onProgress(0.1, 'Creating GIF...');
      await _createGif(
        inputPath,
        palettePath,
        outputPath,
        settings,
        duration,
        (p, s) => onProgress(0.1 + p * 0.8, s),
        cancelSignal: cancelSignal,
      );

      if (settings.enableLossyCompression) {
        onProgress(0.9, 'Applying lossy compression...');
        await _optimizeWithGifsicle(
          outputPath,
          settings,
          (p, s) => onProgress(0.9 + p * 0.1, s),
          cancelSignal: cancelSignal,
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
