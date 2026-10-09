import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart' show randomBytes;

const _caesarPrefix = 'foreign.caesar.profile.';
const _globalFiles = <String>{
  'tableaux/C/C_GLOBAL.ctbl.gz',
  'tableaux/D/D_GLOBAL.dtbl.gz',
};

Future<void> main(List<String> args) async {
  var project = Directory.current;
  var fragmentName = 'manifest_foreign_caesar_profiles.json';
  var write = false;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--project':
        project = Directory(args[++i]);
      case '--fragment':
        fragmentName = args[++i];
      case '--write':
        write = true;
      default:
        throw ArgumentError('Unknown argument: ${args[i]}');
    }
  }

  project = Directory(project.absolute.path);
  _require(File('${project.path}/pubspec.yaml'), 'Flutter project root');

  final clearRoot = Directory('${project.path}/assets/secure');
  final encRoot = Directory('${project.path}/assets/secure_enc');
  final masterFile = File('${clearRoot.path}/manifest.json');
  final fragmentFile = File('${clearRoot.path}/$fragmentName');
  final encManifest = File('${encRoot.path}/manifest.json.enc');

  _require(masterFile, 'clear master manifest');
  _require(fragmentFile, 'CAESAR manifest fragment');
  _require(encManifest, 'encrypted manifest');

  final master = _jsonList(await masterFile.readAsString(), masterFile.path);
  final incoming = _jsonList(
    await fragmentFile.readAsString(),
    fragmentFile.path,
  );

  _validateRowsRequired(master, 'clear master manifest');
  _validateRowsRequired(incoming, 'CAESAR fragment');
  _validateUniqueIds(master, 'clear master manifest');
  _validateUniqueIds(incoming, 'CAESAR fragment');

  final masterByFile = {
    for (final e in master)
      if (e['file'] is String) e['file'] as String: e,
  };

  for (final path in _globalFiles) {
    final clear = File('${clearRoot.path}/$path');
    _require(clear, 'recovered clear global asset');
    final meta = masterByFile[path];
    if (meta == null) {
      throw StateError(
        'The clear master manifest has no entry for $path. '
        'No metadata will be invented.',
      );
    }
    final rows = meta['rows'];
    if (rows is! int || rows < 0) {
      throw FormatException('Invalid rows metadata for $path: $rows');
    }
  }

  final key = SecretKey(await _readProjectKey(project));
  final algorithm = AesGcm.with256bits();

  // The current encrypted manifest is the authoritative inventory of assets
  // that are actually packaged. The clear master manifest may still reference
  // retired flat-layout files, so it must not be used as the base inventory.
  final existingJson = utf8.decode(
    await _decryptCombined(
      await encManifest.readAsBytes(),
      algorithm: algorithm,
      key: key,
    ),
  );
  final previousEncrypted = _jsonList(existingJson, encManifest.path);

  var historicalMissingRows = 0;
  for (final entry in previousEncrypted) {
    final rows = entry['rows'];
    if (rows == null) {
      historicalMissingRows++;
      continue;
    }
    if (rows is! int || rows < 0) {
      throw FormatException(
        'Existing encrypted manifest has invalid published rows: '
        'id=${entry['id']} rows=$rows file=${entry['file']}',
      );
    }
  }

  // Preserve the packaged inventory. Historical entries are allowed to omit
  // rows, but when rows is present it must remain a valid non-negative integer.
  final existing = [
    for (final entry in previousEncrypted) Map<String, dynamic>.from(entry),
  ];

  // Ensure recovered globals are represented using their authoritative clear
  // master-manifest entries.
  for (final path in _globalFiles) {
    final authoritative = Map<String, dynamic>.from(masterByFile[path]!);
    final id = authoritative['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException('Invalid global manifest entry for $path');
    }
    existing.removeWhere((e) => e['id'] == id || e['file'] == path);
    existing.add(authoritative);
  }

  // Replace only the current profile-scoped CAESAR entries.
  final incomingIds = {for (final e in incoming) e['id'] as String};
  existing.removeWhere((e) {
    final id = e['id'];
    return id is String &&
        (incomingIds.contains(id) || id.startsWith(_caesarPrefix));
  });
  existing.addAll(incoming);

  _validateRowsOptional(existing, 'rebuilt encrypted manifest');
  _validateUniqueIds(existing, 'rebuilt encrypted manifest');
  _validatePaths(existing);

  // Re-encrypt recovered globals with the current project's key.
  for (final path in _globalFiles) {
    final clear = File('${clearRoot.path}/$path');
    final encrypted = File('${encRoot.path}/$path.enc');
    if (write) {
      await encrypted.parent.create(recursive: true);
      await encrypted.writeAsBytes(
        await _encryptCombined(
          await clear.readAsBytes(),
          algorithm: algorithm,
          key: key,
        ),
        flush: true,
      );
    }
  }

  // Validate that every manifest entry has a corresponding encrypted asset
  // before replacing manifest.json.enc.
  var checkedEncryptedAssets = 0;
  final missingEncryptedAssets = <String>[];
  for (final entry in existing) {
    final path = entry['file'];
    if (path is! String) continue;
    final encrypted = File('${encRoot.path}/$path.enc');
    if (!encrypted.existsSync()) {
      missingEncryptedAssets.add(path);
      continue;
    }
    checkedEncryptedAssets++;
  }

  if (missingEncryptedAssets.isNotEmpty) {
    stderr.writeln(
      'Missing encrypted assets referenced by rebuilt manifest: '
      '${missingEncryptedAssets.length}',
    );
    for (final path in missingEncryptedAssets.take(100)) {
      stderr.writeln('  - $path.enc');
    }
    if (missingEncryptedAssets.length > 100) {
      stderr.writeln('  ... ${missingEncryptedAssets.length - 100} more');
    }
    throw StateError(
      'Rebuilt manifest was NOT written because referenced encrypted assets '
      'are missing.',
    );
  }

  existing.sort(
    (a, b) => (a['id'] as String? ?? '').compareTo(b['id'] as String? ?? ''),
  );

  final mergedText =
      '${const JsonEncoder.withIndent('  ').convert(existing)}\n';

  if (write) {
    await encManifest.writeAsBytes(
      await _encryptCombined(
        utf8.encode(mergedText),
        algorithm: algorithm,
        key: key,
      ),
      flush: true,
    );

    // Immediate AES-GCM round-trip and schema revalidation.
    final roundTrip = utf8.decode(
      await _decryptCombined(
        await encManifest.readAsBytes(),
        algorithm: algorithm,
        key: key,
      ),
    );
    final decoded = _jsonList(roundTrip, encManifest.path);
    _validateRowsOptional(decoded, 'round-trip encrypted manifest');
    _validateUniqueIds(decoded, 'round-trip encrypted manifest');
    if (jsonEncode(decoded) != jsonEncode(existing)) {
      throw StateError('Encrypted manifest round-trip mismatch.');
    }
  }

  stdout.writeln(
    'historical encrypted entries with missing rows: $historicalMissingRows',
  );
  stdout.writeln(
    'clear master entries available for metadata: ${master.length}',
  );
  stdout.writeln('incoming CAESAR entries: ${incoming.length}');
  stdout.writeln('rebuilt manifest entries: ${existing.length}');
  stdout.writeln(
    'encrypted CAESAR/global assets verified: $checkedEncryptedAssets',
  );
  stdout.writeln(
    write
        ? 'manifest.json.enc rebuilt and AES-GCM round-trip validated'
        : 'AUDIT ONLY: rerun with --write to rebuild files',
  );
}

void _validateRowsRequired(List<Map<String, dynamic>> entries, String label) {
  for (final e in entries) {
    final rows = e['rows'];
    if (rows is! int || rows < 0) {
      throw FormatException('$label: missing/invalid rows for id=${e['id']}');
    }
  }
}

void _validateRowsOptional(List<Map<String, dynamic>> entries, String label) {
  for (final e in entries) {
    if (!e.containsKey('rows') || e['rows'] == null) {
      continue;
    }
    final rows = e['rows'];
    if (rows is! int || rows < 0) {
      throw FormatException('$label: invalid published rows for id=${e['id']}');
    }
  }
}

void _validateUniqueIds(List<Map<String, dynamic>> entries, String label) {
  final ids = <String>{};
  for (final e in entries) {
    final id = e['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException('$label: invalid id: $e');
    }
    if (!ids.add(id)) {
      throw StateError('$label: duplicate id=$id');
    }
  }
}

void _validatePaths(List<Map<String, dynamic>> entries) {
  for (final e in entries) {
    final path = e['file'];
    if (path is! String || path.isEmpty) {
      throw FormatException('Invalid manifest file path: $e');
    }
    if (path.startsWith('/') || path.contains('..') || path.contains('\\')) {
      throw FormatException('Unsafe manifest file path: $path');
    }
  }
}

List<Map<String, dynamic>> _jsonList(String source, String path) {
  final decoded = jsonDecode(source);
  if (decoded is! List) {
    throw FormatException('A JSON list is required in $path.');
  }
  return decoded.map((item) {
    if (item is! Map) {
      throw FormatException('Manifest entry is not an object in $path.');
    }
    return Map<String, dynamic>.from(item);
  }).toList();
}

void _require(FileSystemEntity entity, String label) {
  if (!entity.existsSync()) {
    throw StateError('Missing $label: ${entity.path}');
  }
}

Future<List<int>> _readProjectKey(Directory project) async {
  final keyFile = File('${project.path}/macos/Runner/SecureKey.swift');
  _require(keyFile, 'macOS SecureKey.swift');
  final source = await keyFile.readAsString();
  final match = RegExp(
    r'contentKeyHex\s*=\s*"([0-9a-fA-F]{64})"',
  ).firstMatch(source);
  if (match == null) {
    throw StateError('Could not locate project content key.');
  }
  final hex = match.group(1)!;
  return List<int>.generate(
    32,
    (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
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
  return (BytesBuilder(copy: false)
        ..add(box.nonce)
        ..add(box.cipherText)
        ..add(box.mac.bytes))
      .takeBytes();
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
