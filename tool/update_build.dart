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

  final buildFile = File('build.txt');
  await buildFile.writeAsString(commitDate);
  stdout.writeln('Build actualizado: $commitDate');
}
