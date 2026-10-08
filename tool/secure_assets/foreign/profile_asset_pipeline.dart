import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../table_builder.dart';

/// Generic profile-scoped packaging helper.
///
/// This layer is deliberately domain-agnostic: it verifies source hashes,
/// delegates binary encoding to existing TableBuilder implementations,
/// relocates the generated gzip asset under a profile-scoped path, and
/// rewrites manifest metadata. It does not perform runtime lookup or any
/// calculation.
class ForeignProfileAssetPipeline {
  ForeignProfileAssetPipeline({
    required this.systemSlug,
    required this.platformLabel,
    required this.project,
    required this.builders,
  });

  final String systemSlug;
  final String platformLabel;
  final Directory project;
  final List<TableBuilder> builders;

  Directory get profilesRoot => Directory(
        '${project.path}/maintenance/${platformLabel.toUpperCase()}/PROFILES',
      );

  Directory get clearRoot => Directory('${project.path}/assets/secure');

  String get registryPrefix => 'foreign.$systemSlug.profile.';

  Future<List<Map<String, dynamic>>> buildAll({bool clean = false}) async {
    _require(File('${project.path}/pubspec.yaml'), 'Flutter project root');
    if (!profilesRoot.existsSync()) {
      throw StateError('Missing profiles root: ${profilesRoot.path}');
    }

    final profileDirs = profilesRoot
        .listSync(followLinks: false)
        .whereType<Directory>()
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    if (profileDirs.isEmpty) {
      throw StateError('No profiles found under ${profilesRoot.path}');
    }

    final destinationRoot = Directory(
      '${clearRoot.path}/tableaux/foreign/$systemSlug/profiles',
    );
    if (clean && destinationRoot.existsSync()) {
      await destinationRoot.delete(recursive: true);
    }
    await destinationRoot.create(recursive: true);

    final unsupported = <String>[];
    final skippedIncompatible = <String>[];
    final entries = <Map<String, dynamic>>[];
    final ids = <String>{};

    for (final profileDir in profileDirs) {
      final profile = profileDir.uri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .last;
      final raw = Directory('${profileDir.path}/raw');
      if (!raw.existsSync()) {
        throw StateError('Missing raw directory: ${raw.path}');
      }

      await _verifyHashes(profileDir, raw);

      final files = raw
          .listSync(followLinks: false)
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      for (final source in files) {
        final prepared = await _prepareSourceForBuilder(source);
        try {
          var matches =
              builders.where((b) => b.supports(prepared.file)).toList();

          if (matches.isEmpty) {
            final sourceName = source.uri.pathSegments.last.toUpperCase();

            // Keep auxiliary SHARED JSON files that have no dedicated builder
            // out of the binary asset build. They remain hash-verified source
            // material but are not interpreted or transformed here.
            if (profile.toUpperCase() == 'SHARED' &&
                sourceName == 'VITESSES_INITIALES.JSON') {
              skippedIncompatible.add('${source.path} :: no dedicated builder');
              stderr.writeln(
                'SKIP auxiliary source without builder: ${source.path}',
              );
              continue;
            }

            unsupported.add(source.path);
            continue;
          }

          // Compatibility shim for legacy D builders whose supports() pattern
          // is broader than intended and also matches TABLEAU_DSPD_* files.
          // Routing here is based only on the structural filename prefix.
          if (matches.length > 1) {
            final sourceName =
                prepared.file.uri.pathSegments.last.toUpperCase();

            if (sourceName.startsWith('TABLEAU_DSPD_')) {
              final dspdMatches = matches
                  .where((b) => b.runtimeType.toString() == 'DspdBuilder')
                  .toList();

              if (dspdMatches.length == 1) {
                matches = dspdMatches;
              }
            }
          }

          if (matches.length > 1) {
            throw StateError(
              'Multiple builders support ${source.path}: '
              '${matches.map((e) => e.runtimeType).join(', ')}',
            );
          }

          final tmp = await Directory.systemTemp.createTemp('caesar_build_');
          try {
            Map<String, dynamic> built;
            try {
              built = await matches.single.build(prepared.file, tmp);
            } on FormatException catch (error) {
              final sourceName = source.uri.pathSegments.last.toUpperCase();
              final message = error.message.toString();

              // Some legacy ECL sources contain explicitly absent values that
              // the current builder format cannot encode. Treat those files as
              // structurally incompatible with the current binary format
              // instead of aborting the whole packaging pass.
              if (sourceName.startsWith('TABLEAU_ECL_') &&
                  message.contains(': null')) {
                skippedIncompatible.add('${source.path} :: $message');
                stderr.writeln(
                  'SKIP incompatible source: ${source.path}\n'
                  '  $message',
                );
                continue;
              }

              // Some legacy E-table sources use a source variant name that the
              // current ETBL builder deliberately rejects. Keep the packaging
              // pass content-agnostic: report and skip the incompatible source
              // rather than rewriting or guessing its metadata.
              if (sourceName.startsWith('TABLEAU_E_') &&
                  message.toLowerCase().contains('typetir non supporté')) {
                skippedIncompatible.add('${source.path} :: $message');
                stderr.writeln(
                  'SKIP incompatible source: ${source.path}\n'
                  '  $message',
                );
                continue;
              }

              // Legacy J/Jbis source payloads can differ structurally from the
              // current JTBL/JBISTBL builders. Do not reinterpret or rewrite
              // their payloads here; report them as incompatible and continue
              // packaging the remaining sources.
              if (sourceName.startsWith('TABLEAU_J_') ||
                  sourceName.startsWith('TABLEAU_JBIS_')) {
                skippedIncompatible.add('${source.path} :: $message');
                stderr.writeln(
                  'SKIP incompatible source: ${source.path}\n'
                  '  $message',
                );
                continue;
              }

              rethrow;
            }

            final rewritten = await _relocateEntry(
              profile: profile,
              source: source,
              tempRoot: tmp,
              built: built,
            );

            final id = rewritten['id'];
            if (id is! String || id.isEmpty) {
              throw StateError('Invalid registry ID for ${source.path}: $id');
            }
            if (!ids.add(id)) {
              throw StateError('Duplicate registry ID: $id');
            }
            entries.add(rewritten);
          } finally {
            if (tmp.existsSync()) await tmp.delete(recursive: true);
          }
        } finally {
          await prepared.dispose();
        }
      }
    }

    if (unsupported.isNotEmpty) {
      final lines = unsupported.map((e) => '  - $e').join('\n');
      throw UnsupportedError(
        'No builder found for ${unsupported.length} source file(s):\n$lines',
      );
    }

    if (skippedIncompatible.isNotEmpty) {
      stderr.writeln(
        'Skipped ${skippedIncompatible.length} structurally incompatible '
        'source file(s).',
      );
      for (final item in skippedIncompatible) {
        stderr.writeln('  - $item');
      }
    }

    entries.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    return entries;
  }

  Future<_PreparedSource> _prepareSourceForBuilder(File source) async {
    final upper = source.uri.pathSegments.last.toUpperCase();

    // Existing C/D builders intentionally only accept their canonical names.
    // CAESAR legacy sources use Tableau_C_CAESAR / Tableau_D_CAESAR, so stage
    // a temporary canonical alias without changing the JSON payload.
    String? alias;
    if (upper == 'TABLEAU_C_CAESAR.JSON') alias = 'tableau_c.json';
    if (upper == 'TABLEAU_D_CAESAR.JSON') alias = 'tableau_d.json';
    if (alias == null) return _PreparedSource(source, null);

    final dir = await Directory.systemTemp.createTemp('caesar_alias_');
    final staged = File('${dir.path}/$alias');
    await source.copy(staged.path);
    return _PreparedSource(staged, dir);
  }

  Future<Map<String, dynamic>> _relocateEntry({
    required String profile,
    required File source,
    required Directory tempRoot,
    required Map<String, dynamic> built,
  }) async {
    final oldRelative = built['file'];
    final oldPath = built['path'];
    final oldId = built['id'];
    final declaredFamily = built['family'];
    final format = built['format'];
    final rows = built['rows'];

    final hasRelativeFile = oldRelative is String && oldRelative.isNotEmpty;
    final hasAbsolutePath = oldPath is String && oldPath.isNotEmpty;

    if (!hasRelativeFile && !hasAbsolutePath) {
      throw FormatException('Builder returned invalid file/path: $built');
    }
    if (oldId is! String || oldId.isEmpty) {
      throw FormatException('Builder returned invalid id: $built');
    }
    if (format is! String || format.isEmpty) {
      throw FormatException('Builder returned invalid format: $built');
    }
    if (rows is! int || rows < 0) {
      throw FormatException('Builder returned invalid rows metadata: $built');
    }

    File? generated;

    final candidates = <File>[];

    void addCandidate(String value) {
      if (value.isEmpty) return;

      final direct = File(value);
      if (direct.isAbsolute) {
        candidates.add(direct);
      } else {
        candidates.add(File('${tempRoot.path}/$value'));
      }

      if (value.startsWith('tableaux/')) {
        final stripped = value.substring('tableaux/'.length);
        candidates.add(File('${tempRoot.path}/$stripped'));
      }
    }

    if (hasRelativeFile) {
      addCandidate(oldRelative as String);
    }
    if (hasAbsolutePath) {
      addCandidate(oldPath as String);
    }

    for (final candidate in candidates) {
      if (candidate.existsSync()) {
        generated = candidate;
        break;
      }
    }

    // Last-resort structural lookup for legacy builders whose manifest path
    // convention does not match their actual output directory.
    if (generated == null) {
      final expectedName = [
        if (hasRelativeFile) (oldRelative as String),
        if (hasAbsolutePath) (oldPath as String),
      ]
          .map((value) => File(value).uri.pathSegments.last)
          .where((name) => name.isNotEmpty)
          .toSet();

      if (expectedName.isNotEmpty) {
        final matches = tempRoot
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((file) => expectedName.contains(file.uri.pathSegments.last))
            .toList();

        if (matches.length == 1) {
          generated = matches.single;
        } else if (matches.length > 1) {
          throw StateError(
            'Multiple builder outputs match $expectedName under '
            '${tempRoot.path}: ${matches.map((e) => e.path).join(', ')}',
          );
        }
      }
    }

    if (generated == null) {
      throw StateError(
        'Missing builder output. Metadata: $built; '
        'searched under ${tempRoot.path}',
      );
    }

    final fileName = generated.uri.pathSegments.last;

    // Prefer the builder-declared family. For legacy builders without that
    // metadata, use the generated file's immediate parent directory as a
    // purely structural packaging family.
    final family = declaredFamily is String && declaredFamily.isNotEmpty
        ? declaredFamily
        : generated.parent.uri.pathSegments
            .where((segment) => segment.isNotEmpty)
            .last;

    final normalizedFamily = _sanitizeSegment(family);
    final relative =
        'tableaux/foreign/$systemSlug/profiles/$profile/$normalizedFamily/$fileName';
    final destination = File('${clearRoot.path}/$relative');
    await destination.parent.create(recursive: true);
    await generated.copy(destination.path);

    final result = <String, dynamic>{...built};
    // Never persist a temporary/absolute builder path into the final manifest.
    result.remove('path');
    result['family'] = family;
    result['id'] = '$registryPrefix$profile.$oldId';
    result['sourceTableId'] = oldId;
    result['profile'] = profile;
    result['platform'] = platformLabel;
    result['assetFamily'] = 'foreign';
    result['file'] = relative;
    result['source'] = source.uri.pathSegments.last;
    result['keyVersion'] = built['keyVersion'] is int ? built['keyVersion'] : 0;
    return result;
  }

  Future<void> _verifyHashes(Directory profileDir, Directory raw) async {
    final manifest = File('${profileDir.path}/SOURCES.sha256');
    _require(manifest, 'source hash manifest');

    final expectedFiles = <String>{};
    for (final line in await manifest.readAsLines()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final match = RegExp(r'^([0-9a-fA-F]{64})\s+(.+)$').firstMatch(trimmed);
      if (match == null) {
        throw FormatException(
          'Invalid source hash line in ${manifest.path}: $line',
        );
      }

      var relative = match.group(2)!;
      if (relative.startsWith('raw/')) relative = relative.substring(4);
      if (relative.contains('..') || relative.startsWith('/')) {
        throw FormatException('Unsafe source hash path: $relative');
      }

      final source = File('${raw.path}/$relative');
      _require(source, 'hashed source');
      final actual = sha256.convert(await source.readAsBytes()).toString();
      if (actual.toLowerCase() != match.group(1)!.toLowerCase()) {
        throw StateError(
          'SHA-256 mismatch for ${source.path}: expected ${match.group(1)}, got $actual',
        );
      }
      expectedFiles.add(source.absolute.path);
    }

    final actualFiles = raw
        .listSync(followLinks: false)
        .whereType<File>()
        .map((e) => e.absolute.path)
        .toSet();
    final untracked = actualFiles.difference(expectedFiles);
    if (untracked.isNotEmpty) {
      throw StateError(
        'Untracked file(s) in ${raw.path}:\n${untracked.map((e) => '  - $e').join('\n')}',
      );
    }
  }

  String _sanitizeSegment(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    if (cleaned.isEmpty) throw FormatException('Invalid path segment: $value');
    return cleaned;
  }

  void _require(FileSystemEntity entity, String label) {
    if (!entity.existsSync()) {
      throw StateError('Missing $label: ${entity.path}');
    }
  }
}

class _PreparedSource {
  const _PreparedSource(this.file, this.tempDirectory);

  final File file;
  final Directory? tempDirectory;

  Future<void> dispose() async {
    final dir = tempDirectory;
    if (dir != null && dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }
}
