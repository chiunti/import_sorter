// 🎯 Dart imports:
import 'dart:io';

/// Get all the dart files for the project and the contents
Map<String, File> dartFiles(String currentPath, List<String> args) {
  final dartFiles = <String, File>{};
  final allContents = [
    ..._readDir(currentPath, 'lib'),
    ..._readDir(currentPath, 'bin'),
    ..._readDir(currentPath, 'test'),
    ..._readDir(currentPath, 'tests'),
    ..._readDir(currentPath, 'test_driver'),
    ..._readDir(currentPath, 'integration_test'),
  ];

  for (final fileOrDir in allContents) {
    if (fileOrDir is File && fileOrDir.path.endsWith('.dart')) {
      dartFiles[fileOrDir.path] = fileOrDir;
    }
  }

  // If there are only certain files given via args filter the others out
  var onlyCertainFiles = false;
  for (final arg in args) {
    if (!onlyCertainFiles) {
      onlyCertainFiles = arg.endsWith('dart');
    }
  }

  if (onlyCertainFiles) {
    final patterns = args.where((arg) => !arg.startsWith('-'));
    final filesToKeep = <String, File>{};

    String normalizePath(String path) {
      // Convierte a absoluta si no lo es
      final absolute = path.startsWith('/') || path.contains(':') ? path : File(path).absolute.path;
      // Normaliza separadores
      var norm = absolute.replaceAll('\\', '/');
      if (norm.startsWith('./')) norm = norm.substring(2);
      return norm;
    }

    for (final fileName in dartFiles.keys) {
      var keep = false;
      final normFileName = normalizePath(fileName);
      for (final pattern in patterns) {
        final normPattern = normalizePath(pattern);
        if (normPattern == normFileName || RegExp(pattern).hasMatch(fileName)) {
          keep = true;
          break;
        }
      }
      if (keep) {
        filesToKeep[fileName] = File(fileName);
      }
    }
    return filesToKeep;
  }

  return dartFiles;
}


List<FileSystemEntity> _readDir(String currentPath, String name) {
  if (Directory('$currentPath/$name').existsSync()) {
    return Directory('$currentPath/$name').listSync(recursive: true);
  }
  return [];
}
