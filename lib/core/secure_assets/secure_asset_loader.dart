import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:calculateur_etranger/security/native_secure_assets.dart';

import 'btbl_decoder.dart';
import 'btbl_table.dart';
import 'secure_manifest.dart';

class SecureAssetLoader {
  SecureAssetLoader({BtblDecoder? btblDecoder})
      : _btblDecoder = btblDecoder ?? BtblDecoder();

  static const String _manifestAssetPath =
      'assets/secure_enc/manifest.json.enc';

  final BtblDecoder _btblDecoder;

  Future<Map<String, SecureManifestEntry>>? _manifestFuture;

  final Map<String, BtblTable> _tableCache = <String, BtblTable>{};

  final Map<String, Future<BtblTable>> _tableLoads =
      <String, Future<BtblTable>>{};

  Future<void> testNativeEncryptedAsset() async {
    final bytes = await NativeSecureAssets.decryptAsset(_manifestAssetPath);
    debugPrint('[SECURE_TEST] manifest decrypted bytes=${bytes.length}');
  }

  Future<List<SecureManifestEntry>> loadManifest() async {
    final entriesById = await _loadManifestById();
    return List<SecureManifestEntry>.unmodifiable(entriesById.values);
  }

  /// Recherche structurelle d'entrées dans le manifest.
  ///
  /// Cette méthode ne décode aucune table et n'interprète aucune donnée
  /// balistique. Elle sert uniquement à vérifier le packaging et le routage
  /// d'assets.
  Future<List<SecureManifestEntry>> findManifestEntries({
    required String idContains,
  }) async {
    final needle = idContains.trim().toUpperCase();
    if (needle.isEmpty) {
      return const <SecureManifestEntry>[];
    }

    final entries = await loadManifest();
    final matches = entries
        .where((entry) => entry.id.toUpperCase().contains(needle))
        .toList(growable: false);

    debugPrint(
      '[SECURE MANIFEST] filtre=$needle correspondances=${matches.length}',
    );

    return List<SecureManifestEntry>.unmodifiable(matches);
  }

  Future<BtblTable> loadBtblById(String id) {
    final normalizedId = id.trim();

    if (normalizedId.isEmpty) {
      return Future<BtblTable>.error(
        ArgumentError('Table identifier cannot be empty.'),
      );
    }

    final cached = _tableCache[normalizedId];
    if (cached != null) {
      return SynchronousFuture<BtblTable>(cached);
    }

    final inProgress = _tableLoads[normalizedId];
    if (inProgress != null) {
      return inProgress;
    }

    final future = _loadBtblUncached(normalizedId);
    _tableLoads[normalizedId] = future;

    future.whenComplete(() {
      _tableLoads.remove(normalizedId);
    });

    return future;
  }

  Future<BtblTable> _loadBtblUncached(String id) async {
    final manifestById = await _loadManifestById();

    final entry = manifestById[id];
    if (entry == null) {
      throw StateError('Table not found in manifest: $id');
    }

    if (entry.format != 'BTBL_V1') {
      throw StateError('Unsupported format for $id: ${entry.format}');
    }

    final relativeFile = _validateBtblManifestFile(entry.file);
    final encryptedPath = 'assets/secure_enc/$relativeFile.enc';

    final compressedBytes = await NativeSecureAssets.decryptAsset(
      encryptedPath,
    );

    debugPrint(
      '[SECURE] AES table loaded: '
      '$id (${compressedBytes.length} compressed bytes)',
    );

    final List<int> decompressed;
    try {
      decompressed = gzip.decode(compressedBytes);
    } on Object catch (error) {
      throw FormatException('Gzip decompression failed for $id: $error');
    }

    final rawBytes = Uint8List.fromList(decompressed);

    final table = _btblDecoder.decode(id: entry.id, bytes: rawBytes);

    final declaredRows = entry.rows;
    if (declaredRows != null && table.rows.length != declaredRows) {
      throw StateError(
        'Inconsistent row count for $id: '
        'manifest=$declaredRows, table=${table.rows.length}',
      );
    }

    _tableCache[id] = table;

    debugPrint('[SECURE] table ready: $id (${table.rows.length} rows)');

    return table;
  }

  Future<Map<String, SecureManifestEntry>> _loadManifestById() {
    return _manifestFuture ??= _readManifestById();
  }

  Future<Map<String, SecureManifestEntry>> _readManifestById() async {
    final bytes = await NativeSecureAssets.decryptAsset(_manifestAssetPath);

    final String text;
    try {
      text = utf8.decode(bytes);
    } on Object catch (error) {
      throw FormatException('Invalid manifest UTF-8: $error');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on Object catch (error) {
      throw FormatException('Invalid manifest JSON: $error');
    }

    if (decoded is! List) {
      throw const FormatException('Invalid manifest: list expected.');
    }

    final entriesById = <String, SecureManifestEntry>{};

    for (var index = 0; index < decoded.length; index++) {
      final item = decoded[index];

      if (item is! Map) {
        throw FormatException(
          'Invalid manifest: entry $index is not an object.',
        );
      }

      final entry = SecureManifestEntry.fromJson(
        Map<String, dynamic>.from(item),
      );

      if (entriesById.containsKey(entry.id)) {
        throw FormatException(
          'Invalid manifest: duplicate identifier "${entry.id}".',
        );
      }

      _validateManifestPath(entry.file);
      entriesById[entry.id] = entry;
    }

    debugPrint(
      '[SECURE] manifest loaded from native AES: '
      '${entriesById.length} entries',
    );

    return Map<String, SecureManifestEntry>.unmodifiable(entriesById);
  }

  String _validateManifestPath(String file) {
    final normalized = file.replaceAll('\\', '/').trim();

    if (normalized.isEmpty) {
      throw const FormatException('Invalid manifest: empty file path.');
    }

    if (normalized.startsWith('/') ||
        normalized.contains('../') ||
        normalized.contains('/..') ||
        normalized.contains('://')) {
      throw FormatException('Invalid manifest: forbidden path "$file".');
    }

    return normalized;
  }

  String _validateBtblManifestFile(String file) {
    final normalized = _validateManifestPath(file);

    if (!normalized.endsWith('.btbl.gz')) {
      throw FormatException(
        'Invalid manifest: BTBL file expected, got "$file".',
      );
    }

    return normalized;
  }

  bool isTableCached(String id) => _tableCache.containsKey(id);

  void evictTable(String id) {
    _tableCache.remove(id);
  }

  void clearTableCache() {
    _tableCache.clear();
  }

  void clearAllCaches() {
    _tableCache.clear();
    _tableLoads.clear();
    _manifestFuture = null;
  }
}
