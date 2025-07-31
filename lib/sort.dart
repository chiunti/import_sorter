// 🎯 Dart imports:
import 'dart:io';

/// Process custom order for imports
List<String> _processCustomOrder(List<String> customOrder, List<String> defaultOrder) {
  if (customOrder.isEmpty) {
    // Add blank lines between sections in default order, except between Project and Relative
    final result = <String>[];
    for (var i = 0; i < defaultOrder.length; i++) {
      // Don't add blank before the first section
      if (i > 0) {
        // Don't add blank between Project and Relative
        if (!(defaultOrder[i - 1] == 'Project' && defaultOrder[i] == 'Relative')) {
          result.add('Blank');
        }
      }
      result.add(defaultOrder[i]);
    }
    return result;
  }
  
  final result = <String>[];
  final seen = <String>{};
  
  // Add custom order items first
  for (final item in customOrder) {
    final normalizedItem = item.trim();
    if (normalizedItem == 'Blank' || normalizedItem == 'Blank Line') {
      result.add(normalizedItem);
    } else if (defaultOrder.contains(normalizedItem) && seen.add(normalizedItem)) {
      result.add(normalizedItem);
    }
  }
  
  // Add any remaining default items that weren't in custom order
  for (final item in defaultOrder) {
    if (seen.add(item)) {
      result.add(item);
    }
  }
  
  return result;
}

/// Sort the imports
/// Returns the sorted file as a string at
/// index 0 and the number of sorted imports
/// at index 1
ImportSortData sortImports(
  List<String> lines,
  String packageName,
  bool emojis,
  bool exitIfChanged,
  bool noComments, {
  String? filePath,
  List<String> customOrder = const [],
}) {
  // Define default order and comments
  const defaultOrder = ['Dart', 'Flutter', 'Package', 'Project', 'Relative'];
  
  // Process custom order
  final effectiveOrder = _processCustomOrder(customOrder, defaultOrder);
  
  // Define section comments
  String dartImportComment(bool emojis) => '//${emojis ? ' 🎯 ' : ' '}Dart imports:';
  String flutterImportComment(bool emojis) => '//${emojis ? ' 🐦 ' : ' '}Flutter imports:';
  String packageImportComment(bool emojis) => '//${emojis ? ' 📦 ' : ' '}Package imports:';
  String projectImportComment(bool emojis) => '//${emojis ? ' 🌎 ' : ' '}Project imports:';
  
  // Map section names to their comments
  final sectionComments = {
    'Dart': dartImportComment(emojis),
    'Flutter': flutterImportComment(emojis),
    'Package': packageImportComment(emojis),
    'Project': projectImportComment(emojis),
  };

  final beforeImportLines = <String>[];
  final afterImportLines = <String>[];

  final dartImports = <String>[];
  final flutterImports = <String>[];
  final packageImports = <String>[];
  final projectRelativeImports = <String>[];
  final projectImports = <String>[];

  bool noImports() =>
      dartImports.isEmpty &&
      flutterImports.isEmpty &&
      packageImports.isEmpty &&
      projectImports.isEmpty &&
      projectRelativeImports.isEmpty;

  var isMultiLineString = false;

  for (var i = 0; i < lines.length; i++) {
    // Check if line is in multiline string
    if (_timesContained(lines[i], "'''") == 1 ||
        _timesContained(lines[i], '"""') == 1) {
      isMultiLineString = !isMultiLineString;
    }

    // If line is an import line
    if (lines[i].startsWith('import ') &&
        lines[i].endsWith(';') &&
        !isMultiLineString) {
      if (lines[i].contains('dart:')) {
        dartImports.add(lines[i]);
      } else if (lines[i].contains('package:flutter/')) {
        flutterImports.add(lines[i]);
      } else if (lines[i].contains('package:$packageName/')) {
        projectImports.add(lines[i]);
      } else if (lines[i].contains('package:')) {
        packageImports.add(lines[i]);
      } else {
        projectRelativeImports.add(lines[i]);
      }
    } else if (i != lines.length - 1 &&
        (lines[i] == dartImportComment(false) ||
            lines[i] == flutterImportComment(false) ||
            lines[i] == packageImportComment(false) ||
            lines[i] == projectImportComment(false) ||
            lines[i] == dartImportComment(true) ||
            lines[i] == flutterImportComment(true) ||
            lines[i] == packageImportComment(true) ||
            lines[i] == projectImportComment(true) ||
            lines[i] == '// 📱 Flutter imports:') &&
        lines[i + 1].startsWith('import ') &&
        lines[i + 1].endsWith(';')) {
    } else if (noImports()) {
      beforeImportLines.add(lines[i]);
    } else {
      afterImportLines.add(lines[i]);
    }
  }

  // If no imports return original string of lines
  if (noImports()) {
    var joinedLines = lines.join('\n');
    if (joinedLines.endsWith('\n') && !joinedLines.endsWith('\n\n')) {
      joinedLines += '\n';
    } else if (!joinedLines.endsWith('\n')) {
      joinedLines += '\n';
    }
    return ImportSortData(joinedLines, false);
  }

  // Remove spaces
  if (beforeImportLines.isNotEmpty) {
    if (beforeImportLines.last.trim() == '') {
      beforeImportLines.removeLast();
    }
  }

  final sortedLines = <String>[...beforeImportLines];

  // Add newline before first import section if there are any before-import lines
  if (beforeImportLines.isNotEmpty) {
    sortedLines.add('');
  }
  
  // Process imports based on custom order
  bool isFirstSection = true;
  
  for (final section in effectiveOrder) {
    if (section == 'Dart' && dartImports.isNotEmpty) {
      if (!noComments) sortedLines.add(sectionComments['Dart']!);
      dartImports.sort();
      sortedLines.addAll(dartImports);
      isFirstSection = false;
    } else if (section == 'Flutter' && flutterImports.isNotEmpty) {
      if (!noComments) sortedLines.add(sectionComments['Flutter']!);
      flutterImports.sort();
      sortedLines.addAll(flutterImports);
      isFirstSection = false;
    } else if (section == 'Package' && packageImports.isNotEmpty) {
      if (!noComments) sortedLines.add(sectionComments['Package']!);
      packageImports.sort();
      sortedLines.addAll(packageImports);
      isFirstSection = false;
    } else if (section == 'Project' && projectImports.isNotEmpty) {
      if (!noComments) sortedLines.add(sectionComments['Project']!);
      projectImports.sort();
      sortedLines.addAll(projectImports);
      isFirstSection = false;
    } else if (section == 'Relative' && projectRelativeImports.isNotEmpty) {
      projectRelativeImports.sort();
      sortedLines.addAll(projectRelativeImports);
      isFirstSection = false;
    } else if (section == 'Blank' || section == 'Blank Line') {
      if (!isFirstSection) sortedLines.add('');
      isFirstSection = true; // Next non-blank section will be treated as first
    }
  }

  if (!isFirstSection) sortedLines.add('');

  var addedCode = false;
  for (var j = 0; j < afterImportLines.length; j++) {
    if (afterImportLines[j] != '') {
      sortedLines.add(afterImportLines[j]);
      addedCode = true;
    }
    if (addedCode && afterImportLines[j] == '') {
      sortedLines.add(afterImportLines[j]);
    }
  }
  sortedLines.add('');

  final sortedFile = sortedLines.join('\n');
  final original = '${lines.join('\n')}\n';
  if (exitIfChanged && original != sortedFile) {
    if (filePath != null) {
      stdout
          .writeln('\n┗━━🚨 File $filePath does not have its imports sorted.');
    }
    exit(1);
  }
  if (original == sortedFile) {
    return ImportSortData(original, false);
  }

  return ImportSortData(sortedFile, true);
}

/// Get the number of times a string contains another
/// string
int _timesContained(String string, String looking) =>
    string.split(looking).length - 1;

/// Data to return from a sort
class ImportSortData {
  final String sortedFile;
  final bool updated;

  const ImportSortData(this.sortedFile, this.updated);
}
