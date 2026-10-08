// Merge one or more M252 manifest fragments into the project manifest and
// encrypt their clear binary assets using the existing AES-256-GCM combined
// format. Existing profiles are preserved unless an incoming entry has the
// same registry ID. The project key is read locally and is never printed.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart' show randomBytes;

Future<void> main(List<String> arguments) async {
  var project = Directory.current;
  var bootstrapM252Only = false;
  final fragmentNames = <String>[];

  for (var index = 0; index < arguments.length; index++) {
    switch (arguments[index]) {
      case '--project':
        if (index + 1 >= arguments.length) {
          throw ArgumentError('--project requires a directory path.');
        }
        project = Directory(arguments[++index]);
      case '--fragment':
        if (index + 1 >= arguments.length) {
          throw ArgumentError('--fragment requires a fragment file name.');
        }
        fragmentNames.add(arguments[++index]);
      case '--bootstrap-m252-only':
        bootstrapM252Only = true;
      case '--help':
      case '-h':
        _usage();
        return;
      default:
        throw ArgumentError('Unknown argument: ${arguments[index]}');
    }
  }

  project = Directory(project.absolute.path);
  _require(File('${project.path}/pubspec.yaml'), 'Flutter project root');

  final clearRoot = Directory('${project.path}/assets/secure');
  final encryptedRoot = Directory('${project.path}/assets/secure_enc');
  final encryptedManifest = File('${encryptedRoot.path}/manifest.json.enc');
  _require(encryptedManifest, 'existing encrypted project manifest');

  final fragments = await _loadFragments(clearRoot, fragmentNames);
  final incoming = <Map<String, dynamic>>[
    for (final fragment in fragments) ...fragment.entries,
  ];
  _assertUniqueIds(incoming);

  final key = SecretKey(await _readProjectKey(project));
  final algorithm = AesGcm.with256bits();
  final manifestBytes = await encryptedManifest.readAsBytes();
  late final List<Map<String, dynamic>> existing;
  if (manifestBytes.length < 28) {
    if (!bootstrapM252Only) {
      throw StateError(
        'The existing encrypted manifest is empty or incomplete. Restore it, '
        'or use --bootstrap-m252-only only for an isolated M252 test bundle.',
      );
    }
    existing = <Map<String, dynamic>>[];
    stdout.writeln('WARNING: creating an isolated M252-only manifest.');
  } else {
    final existingJson = utf8.decode(
      await _decryptCombined(manifestBytes, algorithm: algorithm, key: key),
    );
    existing = _jsonList(existingJson, encryptedManifest.path);
  }

  final incomingById = <String, Map<String, dynamic>>{
    for (final entry in incoming) entry['id'] as String: entry,
  };
  final obsoletePaths = <String>[];
  existing.removeWhere((entry) {
    final id = entry['id'];
    if (id is! String || !incomingById.containsKey(id)) return false;
    final oldPath = entry['file'];
    final newPath = incomingById[id]!['file'];
    if (oldPath is String && oldPath != newPath) {
      obsoletePaths.add(oldPath);
    }
    return true;
  });

  for (final path in obsoletePaths) {
    final encryptedFile = File('${encryptedRoot.path}/$path.enc');
    if (encryptedFile.existsSync()) {
      await encryptedFile.delete();
      stdout.writeln('removed obsolete M252 asset: $path.enc');
    }
  }

  for (final entry in incoming) {
    final path = _assetPath(entry);
    final clearFile = File('${clearRoot.path}/$path');
    _require(clearFile, 'clear M252 asset');
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
  existing.sort((left, right) {
    final leftId = left['id'] as String? ?? '';
    final rightId = right['id'] as String? ?? '';
    return leftId.compareTo(rightId);
  });
  final merged = '${const JsonEncoder.withIndent('  ').convert(existing)}\n';
  await encryptedManifest.writeAsBytes(
    await _encryptCombined(utf8.encode(merged), algorithm: algorithm, key: key),
    flush: true,
  );

  stdout.writeln(
    'M252 encrypted entries: ${incoming.length} from ${fragments.length} fragment(s).',
  );
  stdout.writeln('Merged encrypted manifest entries: ${existing.length}');
}

class _Fragment {
  const _Fragment(this.file, this.entries);

  final File file;
  final List<Map<String, dynamic>> entries;
}

Future<List<_Fragment>> _loadFragments(
  Directory clearRoot,
  List<String> requestedNames,
) async {
  _require(clearRoot, 'clear secure-asset directory');
  final names = requestedNames.isEmpty
      ? clearRoot
          .listSync()
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .where(
            (name) =>
                name.startsWith('manifest_foreign_m252_') &&
                name.endsWith('.json'),
          )
          .toList()
      : requestedNames;
  names.sort();
  if (names.isEmpty) {
    throw StateError('No M252 manifest fragments found in ${clearRoot.path}.');
  }

  final fragments = <_Fragment>[];
  for (final name in names) {
    if (name.contains('/') || name.contains('\\')) {
      throw ArgumentError('--fragment accepts a file name, not a path: $name');
    }
    final file = File('${clearRoot.path}/$name');
    _require(file, 'M252 clear manifest fragment');
    fragments.add(_Fragment(
      file,
      _jsonList(await file.readAsString(), file.path),
    ));
  }
  return fragments;
}

void _assertUniqueIds(List<Map<String, dynamic>> entries) {
  final ids = <String>{};
  for (final entry in entries) {
    final id = entry['id'];
    if (id is! String || !id.startsWith('foreign.m252.')) {
      throw FormatException('Invalid M252 registry ID: $entry');
    }
    if (!ids.add(id)) {
      throw StateError('Duplicate M252 registry ID across fragments: $id');
    }
    _assetPath(entry);
  }
}

String _assetPath(Map<String, dynamic> entry) {
  final path = entry['file'];
  if (path is! String ||
      !path.startsWith('tableaux/foreign/m252/') ||
      !path.endsWith('.gz')) {
    throw FormatException('Invalid M252 manifest file entry: $entry');
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
  if (combined.length < 12 + 16) {
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
    'Usage: dart run tool/merge_encrypt_m252_assets.dart [--project PATH] '
    '[--fragment FILE]... [--bootstrap-m252-only]',
  );
}
