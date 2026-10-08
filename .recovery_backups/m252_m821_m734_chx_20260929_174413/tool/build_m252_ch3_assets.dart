// Build the validated M252 / M821A1 / CH3 source tables into gzipped binary
// assets. Encryption is deliberately a separate macOS step, performed with
// the project-local SecureKey, so that no key is embedded in this tool.

import 'dart:convert';
import 'dart:io';

import 'm252_builders/aebtl_builder.dart';
import 'm252_builders/air_density_table_builder.dart';
import 'm252_builders/cebtl_builder.dart';
import 'm252_builders/debtl_builder.dart';
import 'm252_builders/eebtl_builder.dart';
import 'table_builder.dart';

const _sources = <String, String>{
  'maintenance/M252/TABLE_A/M252_TABLE_A_WIND_COMPONENTS.json':
      '13181cb07d0c4f3655ff01a0b47225fd6a189a382f2ce556d71af3033f74a746',
  'maintenance/M252/TABLE_B/M252_TABLE_B_AIR_TEMP_DENSITY_CORRECTIONS.json':
      '65dc8b5f90bf66baff5dbb1941331568eacbf35383d7c3b950402eea81161572',
  'maintenance/M252/TABLE_C/M252_M821A1_TABLE_C_CH3.json':
      'd45b040f3a318c723057a68eb621e86b6d8e525032c4f0d7732156a819bdb4da',
  'maintenance/M252/TABLE_D/M252_M821A1_TABLE_D_CH3.json':
      '0d44aaa22d7e41605898c9021c7bbc16c4c5c068c51391553815d880410bbe32',
  'maintenance/M252/TABLE_E/M252_M821A1_TABLE_E_CH3.json':
      '3ff512c4888451b70b7da9ce6c133714e9c951a111b88e91e26a36ec4ce31321',
};

Future<void> main(List<String> arguments) async {
  var project = Directory.current;
  var clean = false;

  for (var i = 0; i < arguments.length; i++) {
    switch (arguments[i]) {
      case '--project':
        if (i + 1 >= arguments.length) {
          throw ArgumentError('--project requires a directory path.');
        }
        project = Directory(arguments[++i]);
      case '--clean':
        clean = true;
      case '--help':
      case '-h':
        _usage();
        return;
      default:
        throw ArgumentError('Unknown argument: ${arguments[i]}');
    }
  }

  project = Directory(project.absolute.path);
  if (!File('${project.path}/pubspec.yaml').existsSync()) {
    throw StateError('Not a Flutter project root: ${project.path}');
  }

  await _verifySourceHashes(project);

  final clearRoot = Directory('${project.path}/assets/secure');
  final binaryRoot = Directory('${clearRoot.path}/tableaux');
  final m252Root = Directory('${binaryRoot.path}/foreign/m252');

  if (clean && m252Root.existsSync()) {
    await m252Root.delete(recursive: true);
  }
  await binaryRoot.create(recursive: true);

  final builders = <TableBuilder>[
    AebtlBuilder.m252(),
    AirDensityTableBuilder(AirDensityTableProfiles.m252B),
    CebtlBuilder.m252(),
    DebtlBuilder(),
    EebtlBuilder(),
  ];

  final entries = <Map<String, dynamic>>[];
  for (final relativePath in _sources.keys) {
    final file = File('${project.path}/$relativePath');
    final candidates =
        builders.where((builder) => builder.supports(file)).toList();
    if (candidates.length != 1) {
      throw StateError(
        'Expected one builder for $relativePath, found ${candidates.length}.',
      );
    }
    entries.add(await candidates.single.build(file, binaryRoot));
  }

  entries.sort(
      (left, right) => (left['id'] as String).compareTo(right['id'] as String));

  final fragment = File('${clearRoot.path}/manifest_foreign_m252_ch3.json');
  await fragment.parent.create(recursive: true);
  await fragment.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(entries)}\n',
    flush: true,
  );

  stdout.writeln('M252 CH3 clear assets built: ${entries.length}');
  for (final entry in entries) {
    stdout.writeln(' - ${entry['id']} -> ${entry['file']}');
  }
  stdout.writeln('Manifest fragment: ${fragment.path}');
  stdout.writeln(
    'Next step: dart run tool/merge_encrypt_m252_assets.dart --project .',
  );
}

Future<void> _verifySourceHashes(Directory project) async {
  for (final entry in _sources.entries) {
    final source = File('${project.path}/${entry.key}');
    if (!source.existsSync()) {
      throw StateError('Missing M252 source: ${entry.key}');
    }
    final digest = await _sha256(source);
    if (digest != entry.value) {
      throw StateError(
        'SHA-256 mismatch for ${entry.key}: expected ${entry.value}, got $digest.',
      );
    }
  }
  stdout.writeln(
      'M252 CH3 source SHA-256 verification: OK (${_sources.length} files).');
}

Future<String> _sha256(File file) async {
  final result = await Process.run('shasum', ['-a', '256', file.path]);
  if (result.exitCode == 0) {
    return result.stdout.toString().trim().split(RegExp(r'\s+')).first;
  }
  final fallback = await Process.run('sha256sum', [file.path]);
  if (fallback.exitCode == 0) {
    return fallback.stdout.toString().trim().split(RegExp(r'\s+')).first;
  }
  throw StateError(
      'Neither shasum nor sha256sum is available to validate ${file.path}.');
}

void _usage() {
  stdout.writeln(
      'Usage: dart run tool/build_m252_ch3_assets.dart [--project PATH] [--clean]');
}
