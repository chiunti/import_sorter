// 🎯 Dart imports:
import 'dart:io';

// 📦 Package imports:
import 'package:args/args.dart';
import 'package:tint/tint.dart';
import 'package:yaml/yaml.dart';

// 🌎 Project imports:
import 'package:import_sorter/args.dart' as local_args;
import 'package:import_sorter/files.dart' as files;
import 'package:import_sorter/sort.dart' as sort;
import 'package:import_sorter/version.dart';

void main(List<String> args) {
  // Parsing arguments
  final parser = ArgParser();
  parser.addFlag('emojis', abbr: 'e', negatable: false);
  parser.addFlag('ignore-config', negatable: false);
  parser.addFlag('help', abbr: 'h', negatable: false);
  parser.addFlag('exit-if-changed', negatable: false);
  parser.addFlag('no-comments', negatable: false);
  parser.addFlag('all', negatable: false, help: 'Procesa todos los archivos .dart');
  parser.addFlag('version', negatable: false, help: 'Muestra la versión del paquete');
  parser.addFlag('sort-staged', negatable: false, help: 'Ordena solo los archivos staged en git');
  final parsed = parser.parse(args); // parsed es ArgResults
  final argResults = parsed.arguments;
  if (argResults.contains('-h') || argResults.contains('--help')) {
    local_args.outputHelp();
    exit(0);
  }
  if (argResults.contains('--version')) {
  stdout.writeln('import_sorter version: $importSorterVersion');
  exit(0);
}

  final currentPath = Directory.current.path;
  /*
  Getting the package name and dependencies/dev_dependencies
  Package name is one factor used to identify project imports
  Dependencies/dev_dependencies names are used to identify package imports
  */
  final pubspecYamlFile = File('$currentPath/pubspec.yaml');
  final pubspecYaml = loadYaml(pubspecYamlFile.readAsStringSync());

  // Getting all dependencies and project package name
  final packageName = pubspecYaml['name'];
  final dependencies = [];

  final stopwatch = Stopwatch();
  stopwatch.start();

  final pubspecLockFile = File('$currentPath/pubspec.lock');
  final pubspecLock = loadYaml(pubspecLockFile.readAsStringSync());
  dependencies.addAll(pubspecLock['packages'].keys);

  var emojis = false;
  var noComments = false;
  var exitOnChange = false;
  final ignoredFiles = [];
  List<String> customOrder = [];

  // Determine which config file to use (in order of priority)
  final configFile = File('$currentPath/.import_sorter.yaml').existsSync()
      ? File('$currentPath/.import_sorter.yaml')
      : File('$currentPath/import_sorter.yaml').existsSync()
          ? File('$currentPath/import_sorter.yaml')
          : File('$currentPath/pubspec.yaml');

  // Read config if not ignored
  if (!argResults.contains('--ignore-config')) {
    final configContent = loadYaml(configFile.readAsStringSync());
    final config = configContent['import_sorter'];

    if (config != null && config is Map) {
      if (config.containsKey('emojis')) emojis = config['emojis'];
      if (config.containsKey('comments')) noComments = !config['comments'];
      // if (config.containsKey('exit_if_changed')) exitOnChange = config['exit_if_changed'];
      if (config.containsKey('ignored_files')) {
        ignoredFiles.addAll(config['ignored_files']);
      }
      if (config.containsKey('custom_order') && config['custom_order'] is List) {
        // Process custom order, removing duplicates while preserving order
        final seen = <String>{};
        customOrder = (config['custom_order'] as List)
            .map((e) => e.toString().trim())
            .where((item) => item.isNotEmpty)
            .where((item) => seen.add(item) || item == 'Blank' || item == 'Blank Line')
            .toList();
      }
    }
  }

  // Setting values from args
  if (!emojis) emojis = argResults.contains('-e');
  if (!noComments) noComments = argResults.contains('--no-comments');
  if (!exitOnChange) exitOnChange = argResults.contains('--exit-if-changed');

  // Validación de argumentos para decidir qué archivos procesar
  final bool allFlag = parsed['all'] == true;
  final bool sortStagedFlag = parsed['sort-staged'] == true;
  final filesFromArgs = parsed.rest.where((a) => a.endsWith('.dart')).toList();

  List<String> stagedFiles = [];
  if (sortStagedFlag) {
    // Obtener archivos staged de git
    try {
      final result = Process.runSync('git', ['diff', '--name-only', '--cached']);
      if (result.exitCode == 0) {
        stagedFiles = (result.stdout as String)
            .split('\n')
            .where((f) => f.trim().endsWith('.dart') && File(f.trim()).existsSync())
            .map((f) => f.trim())
            .toList();
      } else {
        stderr.writeln('No se pudieron obtener los archivos staged de git.');
        exit(1);
      }
    } catch (e) {
      stderr.writeln('Error ejecutando git: $e');
      exit(1);
    }
    if (stagedFiles.isEmpty) {
      stdout.writeln('No hay archivos .dart staged para ordenar.');
      exit(0);
    }
  }

  if (!allFlag && filesFromArgs.isEmpty && !sortStagedFlag) {
    local_args.outputHelp();
    exit(0);
  }

  // Obtener los archivos a procesar
  final dartFiles = sortStagedFlag
      ? files.dartFiles(currentPath, stagedFiles)
      : files.dartFiles(currentPath, allFlag ? [] : filesFromArgs);
  final containsFlutter = dependencies.contains('flutter');
  final containsRegistrant = dartFiles
      .containsKey('$currentPath/lib/generated_plugin_registrant.dart');

  stdout.writeln('contains flutter: $containsFlutter');
  stdout.writeln('contains registrant: $containsRegistrant');

  if (containsFlutter && containsRegistrant) {
    dartFiles.remove('$currentPath/lib/generated_plugin_registrant.dart');
  }

  String globToRegExp(String glob) {
    // Escapa caracteres especiales de regex
    String escaped = RegExp.escape(glob);
    // Reemplaza los globs por sus equivalentes en regex
    escaped = escaped.replaceAll(r'\*\*', '.*'); // '**' → '.*'
    escaped = escaped.replaceAll(r'\*', '[^/]*'); // '*' → '[^/]*'
    escaped = escaped.replaceAll(r'\?', '.'); // '?' → '.'
    // Opcional: asegura coincidencia completa
    return '^$escaped\$';
  }

  for (final pattern in ignoredFiles) {
    if (pattern == null || pattern.trim().isEmpty) continue;
    final regexPattern = globToRegExp(pattern);
    try {
      dartFiles.removeWhere((key, _) =>
          RegExp(regexPattern).hasMatch(key.replaceFirst(currentPath, '')));
    } catch (e) {
      stderr.writeln('Advertencia: patrón glob inválido "$pattern". Error: $e');
    }
  }


  stdout.write('┏━━ Sorting ${dartFiles.length} dart files');

  // Sorting and writing to files
  final sortedFiles = [];
  final success = '✔'.green();

  for (final filePath in dartFiles.keys) {
    final file = dartFiles[filePath];
    if (file == null) {
      continue;
    }

    final sortedFile = sort.sortImports(
        file.readAsLinesSync(), packageName, emojis, exitOnChange, noComments,
        filePath: file.path.startsWith(Directory.current.path)
          ? file.path.substring(Directory.current.path.length + 1)
          : file.path,
        customOrder: customOrder,
    );
    if (!sortedFile.updated) {
      continue;
    }
    dartFiles[filePath]?.writeAsStringSync(sortedFile.sortedFile);
    sortedFiles.add(filePath);
  }

  stopwatch.stop();

  // Outputting results
  if (sortedFiles.length > 1) {
    stdout.write('\n');
  }
  for (int i = 0; i < sortedFiles.length; i++) {
    final file = dartFiles[sortedFiles[i]];
    stdout.write(
        '${sortedFiles.length == 1 ? '\n' : ''}┃  ${i == sortedFiles.length - 1 ? '┗' : '┣'}━━ $success Sorted imports for ${file?.path.replaceFirst(currentPath, '')}/');
    String filename = file!.path.split(Platform.pathSeparator).last;
    stdout.write('$filename\n');
  }

  if (sortedFiles.isEmpty) {
    stdout.write('\n');
  }
  stdout.write(
      '┗━━ $success Sorted ${sortedFiles.length} files in ${stopwatch.elapsed.inSeconds}.${stopwatch.elapsedMilliseconds} seconds\n');
}
