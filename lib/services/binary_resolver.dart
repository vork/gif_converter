import 'dart:io';
import 'package:path/path.dart' as p;

class BinaryResolver {
  static String _resolveBundledPath(String binaryName) {
    final execDir = p.dirname(Platform.resolvedExecutable);

    if (Platform.isMacOS) {
      return p.join(execDir, '..', 'Resources', binaryName);
    } else if (Platform.isWindows) {
      return p.join(execDir, 'data', '$binaryName.exe');
    } else {
      return p.join(execDir, 'lib', binaryName);
    }
  }

  static Future<String?> _findInPath(String binaryName) async {
    try {
      final cmd = Platform.isWindows ? 'where' : 'which';
      final name =
          Platform.isWindows ? '$binaryName.exe' : binaryName;
      final result = await Process.run(cmd, [name]);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim().split('\n').first;
      }
    } catch (_) {}
    return null;
  }

  static Future<String> resolve(String binaryName) async {
    final bundled = _resolveBundledPath(binaryName);
    if (await File(bundled).exists()) {
      return bundled;
    }

    final systemPath = await _findInPath(binaryName);
    if (systemPath != null) {
      return systemPath;
    }

    throw Exception(
      '$binaryName not found. Looked at:\n'
      '  Bundled: $bundled\n'
      '  System PATH: not found\n'
      'Please install $binaryName or place it in the app bundle.',
    );
  }
}
