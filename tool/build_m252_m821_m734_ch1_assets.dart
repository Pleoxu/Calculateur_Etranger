// Build the M821 / M734 / CH1 reference tables as isolated clear assets.
// Runtime uses them only after the encrypted manifest has been merged and the
// M252 profile registry declares the precise 450–1875 m qualified domain.

import 'dart:convert';
import 'dart:io';

import 'm252_builders/aebtl_builder.dart';
import 'm252_builders/air_density_table_builder.dart';
import 'm252_builders/cebtl_builder.dart';
import 'm252_builders/debtl_builder.dart';
import 'm252_builders/eebtl_builder.dart';
import 'table_builder.dart';

const _profileId = 'M821_M734_CH1';
const _sourceRoot = 'maintenance/M252/PROFILES/M821_M734_CH1/raw';
const _sources = <String, String>{
  '$_sourceRoot/M252_M821_M734_CH1_TABLE_A.json':
      '13181cb07d0c4f3655ff01a0b47225fd6a189a382f2ce556d71af3033f74a746',
  '$_sourceRoot/M252_M821_M734_CH1_TABLE_B.json':
      '65dc8b5f90bf66baff5dbb1941331568eacbf35383d7c3b950402eea81161572',
  '$_sourceRoot/M252_M821_M734_CH1_TABLE_C.json':
      'e30dccb50a1dd738c0ccbba7dddb6d812e2c85dc0acbe1f0563872904cbdac26',
  '$_sourceRoot/M252_M821_M734_CH1_TABLE_D.json':
      'c9dc6f80c428492d171c38aa93776b00d2b1af0066efa8fc2551f8113e9aa1f1',
  '$_sourceRoot/M252_M821_M734_CH1_TABLE_E.json':
      '3fa4ce9392c730140e6bf7290e456f64684e38c0c07aa97e3a0db827655944d1',
};

Future<void> main(List<String> arguments) async {
  var project = Directory.current;
  var clean = false;

  for (var index = 0; index < arguments.length; index++) {
    switch (arguments[index]) {
      case '--project':
        if (index + 1 >= arguments.length) {
          throw ArgumentError('--project requires a directory path.');
        }
        project = Directory(arguments[++index]);
      case '--clean':
        clean = true;
      case '--help':
      case '-h':
        _usage();
        return;
      default:
        throw ArgumentError('Unknown argument: ${arguments[index]}');
    }
  }

  project = Directory(project.absolute.path);
  if (!File('${project.path}/pubspec.yaml').existsSync()) {
    throw StateError('Not a Flutter project root: ${project.path}');
  }
  await _verifySourceHashes(project);

  final clearRoot = Directory('${project.path}/assets/secure');
  final binaryRoot = Directory('${clearRoot.path}/tableaux');
  final profileRoot = Directory(
    '${binaryRoot.path}/foreign/m252/profiles/$_profileId',
  );
  final stageRoot = Directory(
    '${project.path}/.dart_tool/m252_asset_stage/$_profileId',
  );

  if (clean && profileRoot.existsSync()) {
    await profileRoot.delete(recursive: true);
  }
  if (stageRoot.existsSync()) {
    await stageRoot.delete(recursive: true);
  }
  await binaryRoot.create(recursive: true);
  await stageRoot.create(recursive: true);

  final builders = <TableBuilder>[
    AebtlBuilder.m252(),
    AirDensityTableBuilder(AirDensityTableProfiles.m252B),
    CebtlBuilder.m252(),
    DebtlBuilder(),
    EebtlBuilder(),
  ];

  final entries = <Map<String, dynamic>>[];
  for (final relativePath in _sources.keys) {
    final source = File('${project.path}/$relativePath');
    final candidates = builders.where((builder) => builder.supports(source));
    if (candidates.length != 1) {
      throw StateError(
        'Expected one builder for $relativePath, found ${candidates.length}.',
      );
    }

    final built = await candidates.single.build(source, stageRoot);
    entries.add(
      await _promoteProfileAsset(
        built,
        stageRoot: stageRoot,
        binaryRoot: binaryRoot,
      ),
    );
  }

  entries.sort(
    (left, right) => (left['id'] as String).compareTo(right['id'] as String),
  );
  final fragment = File(
    '${clearRoot.path}/manifest_foreign_m252_$_profileId.json',
  );
  await fragment.parent.create(recursive: true);
  await fragment.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(entries)}\n',
    flush: true,
  );

  await stageRoot.delete(recursive: true);
  stdout.writeln('M252 $_profileId clear assets built: ${entries.length}');
  for (final entry in entries) {
    stdout.writeln(' - ${entry['id']} -> ${entry['file']}');
  }
  stdout.writeln('Manifest fragment: ${fragment.path}');
  stdout.writeln(
    'Run merge_encrypt_m252_assets.dart to encrypt and register this fragment.',
  );
}

Future<Map<String, dynamic>> _promoteProfileAsset(
  Map<String, dynamic> entry, {
  required Directory stageRoot,
  required Directory binaryRoot,
}) async {
  final tableId = entry['tableId'] as String;
  final sourcePath = entry['file'] as String;
  const tablePrefix = 'tableaux/';
  if (!sourcePath.startsWith(tablePrefix)) {
    throw StateError('Unexpected builder asset path: $sourcePath');
  }
  final source = File(
    '${stageRoot.path}/${sourcePath.substring(tablePrefix.length)}',
  );
  if (!source.existsSync()) {
    throw StateError('Builder did not produce ${source.path}');
  }

  final targetName = source.uri.pathSegments.last;
  final targetPath =
      'tableaux/foreign/m252/profiles/$_profileId/$tableId/$targetName';
  final target = File('${binaryRoot.parent.path}/$targetPath');
  await target.parent.create(recursive: true);
  await source.copy(target.path);

  return <String, dynamic>{
    ...entry,
    'id': 'foreign.m252.profile.$_profileId.$tableId',
    'profile': _profileId,
    'file': targetPath,
  };
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
    'M252 $_profileId source SHA-256 verification: OK (${_sources.length} files).',
  );
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
  throw StateError('No SHA-256 command available for ${file.path}.');
}

void _usage() {
  stdout.writeln(
    'Usage: dart run tool/build_m252_m821_m734_ch1_assets.dart '
    '[--project PATH] [--clean]',
  );
}
