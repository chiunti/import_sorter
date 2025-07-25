import 'dart:io';

void main() async {
  // Ejecuta el comando git para obtener la fecha del último commit en main
  // Intenta primero en master, luego en main si master falla
  var result = await Process.run('git', [
    'log',
    '-1',
    '--format=%cd',
    '--date=format:%Y%m%d%H%M%S',
    'master'
  ]);

  if (result.exitCode != 0) {
    // Si master falla, intenta con main
    result = await Process.run('git', [
      'log',
      '-1',
      '--format=%cd',
      '--date=format:%Y%m%d%H%M%S',
      'main'
    ]);
    if (result.exitCode != 0) {
      stderr.writeln('Error obteniendo la fecha del último commit en master ni en main: [${result.stderr}');
      exit(1);
    }
  }

  final commitDate = (result.stdout as String).trim();
  if (commitDate.isEmpty) {
    stderr.writeln('No se pudo obtener la fecha del commit.');
    exit(1);
  }

  // Modifica el pubspec.yaml para actualizar la versión con el nuevo build
final pubspecFile = File('pubspec.yaml');
if (!pubspecFile.existsSync()) {
  stderr.writeln('No se encontró pubspec.yaml');
  exit(1);
}

final pubspecLines = await pubspecFile.readAsLines();
final versionRegExp = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(\+([0-9]+))?');
bool versionFound = false;
final newLines = pubspecLines.map((line) {
  final match = versionRegExp.firstMatch(line);
  if (match != null) {
    versionFound = true;
    final baseVersion = match.group(1);
    return 'version: $baseVersion+$commitDate';
  }
  return line;
}).toList();

if (!versionFound) {
  stderr.writeln('No se encontró el campo version en pubspec.yaml');
  exit(1);
}

await pubspecFile.writeAsString(newLines.join('\n') + '\n');
stdout.writeln('Versión actualizada: ${newLines.firstWhere((l) => l.startsWith("version:"))}');
}
