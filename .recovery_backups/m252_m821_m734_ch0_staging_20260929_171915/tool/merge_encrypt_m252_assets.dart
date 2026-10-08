// Merge the M252 CH3 manifest fragment into the project manifest and encrypt
// the generated binary assets in the same AES-256-GCM combined format used by
// the macOS runtime. The content key is read locally from SecureKey.swift and
// is never printed, copied, or embedded in this tool.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart' show randomBytes;

Future<void> main(List<String> arguments) async {
  var project = Directory.current;
  var bootstrapM252Only = false;
  for (var i = 0; i < arguments.length; i++) {
    switch (arguments[i]) {
      case '--project':
        if (i + 1 >= arguments.length) {
          throw ArgumentError('--project requires a directory path.');
        }
        project = Directory(arguments[++i]);
      case '--bootstrap-m252-only':
        bootstrapM252Only = true;
      case '--help':
      case '-h':
        stdout.writeln(
          'Usage: dart run tool/merge_encrypt_m252_assets.dart '
          '[--project PATH] [--bootstrap-m252-only]',
        );
        return;
      default:
        throw ArgumentError('Unknown argument: ${arguments[i]}');
    }
  }

  project = Directory(project.absolute.path);
  _require(File('${project.path}/pubspec.yaml'), 'Flutter project root');

  final clearRoot = Directory('${project.path}/assets/secure');
  final encryptedRoot = Directory('${project.path}/assets/secure_enc');
  final fragmentFile = File('${clearRoot.path}/manifest_foreign_m252_ch3.json');
  final encryptedManifest = File('${encryptedRoot.path}/manifest.json.enc');
  _require(fragmentFile, 'M252 clear manifest fragment');
  _require(encryptedManifest, 'existing encrypted project manifest');

  final key = SecretKey(await _readProjectKey(project));
  final algorithm = AesGcm.with256bits();

  final fragment =
      _jsonList(await fragmentFile.readAsString(), fragmentFile.path);
  final manifestBytes = await encryptedManifest.readAsBytes();
  late final List<Map<String, dynamic>> existing;
  if (manifestBytes.length < 28) {
    if (!bootstrapM252Only) {
      throw StateError(
        'The existing encrypted manifest is empty or incomplete. '
        'Refusing to replace it. Restore the current manifest first, or use '
        '--bootstrap-m252-only only for an isolated M252-only test bundle.',
      );
    }
    existing = <Map<String, dynamic>>[];
    stdout.writeln('WARNING: creating an isolated M252-only manifest.');
  } else {
    final existingJson = utf8.decode(
      await _decryptCombined(
        manifestBytes,
        algorithm: algorithm,
        key: key,
      ),
    );
    existing = _jsonList(existingJson, encryptedManifest.path);
  }

  existing.removeWhere((entry) {
    final id = entry['id'];
    return id is String && id.startsWith('foreign.m252.');
  });
  existing.addAll(fragment);

  final m252Root = Directory('${encryptedRoot.path}/tableaux/foreign/m252');
  if (m252Root.existsSync()) {
    await m252Root.delete(recursive: true);
  }

  for (final entry in fragment) {
    final path = entry['file'];
    if (path is! String ||
        !path.startsWith('tableaux/foreign/m252/') ||
        !path.endsWith('.gz')) {
      throw FormatException('Invalid M252 manifest file entry: $entry');
    }

    final clearFile = File('${clearRoot.path}/$path');
    _require(clearFile, 'clear M252 asset');
    final encryptedFile = File('${encryptedRoot.path}/$path.enc');
    await encryptedFile.parent.create(recursive: true);
    final combined = await _encryptCombined(
      await clearFile.readAsBytes(),
      algorithm: algorithm,
      key: key,
    );
    await encryptedFile.writeAsBytes(combined, flush: true);
    stdout.writeln('encrypted: $path.enc');
  }

  final merged = '${const JsonEncoder.withIndent('  ').convert(existing)}\n';
  await encryptedManifest.writeAsBytes(
    await _encryptCombined(
      utf8.encode(merged),
      algorithm: algorithm,
      key: key,
    ),
    flush: true,
  );

  stdout.writeln('M252 CH3 encrypted assets: ${fragment.length}');
  stdout.writeln('Merged encrypted manifest entries: ${existing.length}');
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
        'Could not locate a 256-bit content key in ${keyFile.path}.');
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
