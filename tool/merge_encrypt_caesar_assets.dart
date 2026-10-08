import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart' show randomBytes;

const _registryPrefix = 'foreign.caesar.profile.';
const _assetPrefix = 'tableaux/foreign/caesar/profiles/';

Future<void> main(List<String> arguments) async {
  var project = Directory.current;
  var pruneExistingCaesar = false;
  final fragmentNames = <String>[];

  for (var i = 0; i < arguments.length; i++) {
    switch (arguments[i]) {
      case '--project':
        if (i + 1 >= arguments.length) {
          throw ArgumentError('--project requires a directory path.');
        }
        project = Directory(arguments[++i]);
      case '--fragment':
        if (i + 1 >= arguments.length) {
          throw ArgumentError('--fragment requires a fragment file name.');
        }
        fragmentNames.add(arguments[++i]);
      case '--prune-existing-caesar':
        pruneExistingCaesar = true;
      case '--help':
      case '-h':
        _usage();
        return;
      default:
        throw ArgumentError('Unknown argument: ${arguments[i]}');
    }
  }

  project = Directory(project.absolute.path);
  _require(File('${project.path}/pubspec.yaml'), 'Flutter project root');

  final clearRoot = Directory('${project.path}/assets/secure');
  final encryptedRoot = Directory('${project.path}/assets/secure_enc');
  final encryptedManifest = File('${encryptedRoot.path}/manifest.json.enc');
  _require(encryptedManifest, 'existing encrypted project manifest');

  final incoming = await _loadFragments(clearRoot, fragmentNames);
  _assertIncoming(incoming);

  final key = SecretKey(await _readProjectKey(project));
  final algorithm = AesGcm.with256bits();

  final existingJson = utf8.decode(
    await _decryptCombined(
      await encryptedManifest.readAsBytes(),
      algorithm: algorithm,
      key: key,
    ),
  );
  final existing = _jsonList(existingJson, encryptedManifest.path);

  var invalidExistingCount = 0;
  for (final entry in existing) {
    final rows = entry['rows'];

    if (rows is! int || rows < 0) {
      invalidExistingCount++;
      stderr.writeln(
        'INVALID EXISTING ENTRY: '
        'id=${entry['id']} '
        'rows=$rows '
        'file=${entry['file']}',
      );
    }
  }

  if (invalidExistingCount > 0) {
    stderr.writeln(
      'Existing encrypted manifest contains '
      '$invalidExistingCount entr${invalidExistingCount == 1 ? 'y' : 'ies'} '
      'with missing/invalid rows metadata.',
    );
  }

  final incomingById = <String, Map<String, dynamic>>{
    for (final entry in incoming) entry['id'] as String: entry,
  };

  final obsoletePaths = <String>[];
  existing.removeWhere((entry) {
    final id = entry['id'];
    final replace = id is String && incomingById.containsKey(id);
    final prune =
        pruneExistingCaesar && id is String && id.startsWith(_registryPrefix);
    if (!replace && !prune) return false;

    final oldPath = entry['file'];
    final newPath = replace ? incomingById[id]!['file'] : null;
    if (oldPath is String && oldPath != newPath) obsoletePaths.add(oldPath);
    return true;
  });

  for (final path in obsoletePaths) {
    if (!path.startsWith(_assetPrefix)) continue;
    final encrypted = File('${encryptedRoot.path}/$path.enc');
    if (encrypted.existsSync()) {
      await encrypted.delete();
      stdout.writeln('removed obsolete CAESAR asset: $path.enc');
    }
  }

  for (final entry in incoming) {
    final path = _assetPath(entry);
    final clearFile = File('${clearRoot.path}/$path');
    _require(clearFile, 'clear CAESAR asset');

    final encryptedFile = File('${encryptedRoot.path}/$path.enc');
    await encryptedFile.parent.create(recursive: true);
    await encryptedFile.writeAsBytes(
      await _encryptCombined(
        await clearFile.readAsBytes(),
        algorithm: algorithm,
        key: key,
      ),
      flush: true,
    );
    stdout.writeln('encrypted: $path.enc');
  }

  existing.addAll(incoming);
  existing.sort((a, b) {
    final left = a['id'] as String? ?? '';
    final right = b['id'] as String? ?? '';
    return left.compareTo(right);
  });

  _assertUniqueIds(existing);

  final merged = '${const JsonEncoder.withIndent('  ').convert(existing)}\n';
  await encryptedManifest.writeAsBytes(
    await _encryptCombined(utf8.encode(merged), algorithm: algorithm, key: key),
    flush: true,
  );

  stdout.writeln('CAESAR encrypted entries: ${incoming.length}');
  stdout.writeln('Merged encrypted manifest entries: ${existing.length}');
}

Future<List<Map<String, dynamic>>> _loadFragments(
  Directory clearRoot,
  List<String> requestedNames,
) async {
  if (!clearRoot.existsSync()) {
    throw StateError('Missing clear secure-asset directory: ${clearRoot.path}');
  }

  final names = requestedNames.isEmpty
      ? clearRoot
          .listSync(followLinks: false)
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .where(
            (name) =>
                name.startsWith('manifest_foreign_caesar_') &&
                name.endsWith('.json'),
          )
          .toList()
      : [...requestedNames];
  names.sort();

  if (names.isEmpty) {
    throw StateError(
      'No CAESAR manifest fragments found in ${clearRoot.path}.',
    );
  }

  final entries = <Map<String, dynamic>>[];
  for (final name in names) {
    if (name.contains('/') || name.contains('\\')) {
      throw ArgumentError('--fragment accepts a file name, not a path: $name');
    }
    final file = File('${clearRoot.path}/$name');
    _require(file, 'CAESAR clear manifest fragment');
    entries.addAll(_jsonList(await file.readAsString(), file.path));
  }
  return entries;
}

void _assertIncoming(List<Map<String, dynamic>> entries) {
  final ids = <String>{};
  for (final entry in entries) {
    final id = entry['id'];
    final profile = entry['profile'];
    final platform = entry['platform'];
    final rows = entry['rows'];
    if (id is! String || !id.startsWith(_registryPrefix)) {
      throw FormatException('Invalid CAESAR registry ID: $entry');
    }
    if (!ids.add(id)) throw StateError('Duplicate CAESAR registry ID: $id');
    if (profile is! String || profile.isEmpty) {
      throw FormatException('Missing CAESAR profile: $entry');
    }
    if (platform != 'CAESAR') {
      throw FormatException('Invalid CAESAR platform metadata: $entry');
    }
    if (rows is! int || rows < 0) {
      throw FormatException('Missing/invalid rows metadata: $entry');
    }
    _assetPath(entry);
  }
}

void _assertUniqueIds(List<Map<String, dynamic>> entries) {
  final ids = <String>{};
  for (final entry in entries) {
    final id = entry['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException('Manifest entry has invalid id: $entry');
    }
    if (!ids.add(id)) throw StateError('Duplicate manifest id: $id');
  }
}

String _assetPath(Map<String, dynamic> entry) {
  final path = entry['file'];
  if (path is! String ||
      !path.startsWith(_assetPrefix) ||
      !path.endsWith('.gz')) {
    throw FormatException('Invalid CAESAR manifest file entry: $entry');
  }
  if (path.contains('..') || path.startsWith('/')) {
    throw FormatException('Unsafe CAESAR asset path: $path');
  }
  return path;
}

void _require(FileSystemEntity entity, String label) {
  if (!entity.existsSync()) {
    throw StateError('Missing $label: ${entity.path}');
  }
}

List<Map<String, dynamic>> _jsonList(String source, String path) {
  final decoded = jsonDecode(source);
  if (decoded is! List) {
    throw FormatException('A JSON list is required in $path.');
  }
  return decoded.map((item) {
    if (item is! Map) {
      throw FormatException('Manifest entry is not an object in $path: $item');
    }
    return Map<String, dynamic>.from(item);
  }).toList();
}

Future<List<int>> _readProjectKey(Directory project) async {
  final keyFile = File('${project.path}/macos/Runner/SecureKey.swift');
  _require(keyFile, 'macOS SecureKey.swift');
  final source = await keyFile.readAsString();
  final match = RegExp(
    r'contentKeyHex\s*=\s*"([0-9a-fA-F]{64})"',
  ).firstMatch(source);
  if (match == null) {
    throw StateError(
      'Could not locate a 256-bit content key in ${keyFile.path}.',
    );
  }

  final hex = match.group(1)!;
  return List<int>.generate(
    32,
    (index) => int.parse(hex.substring(index * 2, index * 2 + 2), radix: 16),
    growable: false,
  );
}

Future<List<int>> _encryptCombined(
  List<int> clear, {
  required AesGcm algorithm,
  required SecretKey key,
}) async {
  final nonce = randomBytes(12);
  final box = await algorithm.encrypt(clear, secretKey: key, nonce: nonce);
  final bytes = BytesBuilder(copy: false)
    ..add(box.nonce)
    ..add(box.cipherText)
    ..add(box.mac.bytes);
  return bytes.takeBytes();
}

Future<List<int>> _decryptCombined(
  List<int> combined, {
  required AesGcm algorithm,
  required SecretKey key,
}) async {
  if (combined.length < 28) {
    throw const FormatException('Invalid AES-GCM combined payload.');
  }
  final nonce = combined.sublist(0, 12);
  final mac = combined.sublist(combined.length - 16);
  final cipherText = combined.sublist(12, combined.length - 16);
  return algorithm.decrypt(
    SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
    secretKey: key,
  );
}

void _usage() {
  stdout.writeln(
    'Usage: dart run tool/merge_encrypt_caesar_assets.dart '
    '[--project PATH] [--fragment FILE]... [--prune-existing-caesar]',
  );
}
