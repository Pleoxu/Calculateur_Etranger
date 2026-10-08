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
        ArgumentError('L’identifiant de table ne peut pas être vide.'),
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
      throw StateError('Table introuvable dans le manifest : $id');
    }

    if (entry.format != 'BTBL_V1') {
      throw StateError('Format non supporté pour $id : ${entry.format}');
    }

    final relativeFile = _validateBtblManifestFile(entry.file);
    final encryptedPath = 'assets/secure_enc/$relativeFile.enc';

    final compressedBytes = await NativeSecureAssets.decryptAsset(
      encryptedPath,
    );

    debugPrint(
      '[SECURE] table AES chargée : '
      '$id (${compressedBytes.length} octets compressés)',
    );

    final List<int> decompressed;
    try {
      decompressed = gzip.decode(compressedBytes);
    } on Object catch (error) {
      throw FormatException('Décompression gzip impossible pour $id : $error');
    }

    final rawBytes = Uint8List.fromList(decompressed);

    final table = _btblDecoder.decode(id: entry.id, bytes: rawBytes);

    if (table.rows.length != entry.rows) {
      throw StateError(
        'Row count incohérent pour $id : '
        'manifest=${entry.rows}, table=${table.rows.length}',
      );
    }

    _tableCache[id] = table;

    debugPrint('[SECURE] table prête : $id (${table.rows.length} lignes)');

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
      throw FormatException('Manifest UTF-8 invalide : $error');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on Object catch (error) {
      throw FormatException('Manifest JSON invalide : $error');
    }

    if (decoded is! List) {
      throw const FormatException('Manifest invalide : liste attendue.');
    }

    final entriesById = <String, SecureManifestEntry>{};

    for (var index = 0; index < decoded.length; index++) {
      final item = decoded[index];

      if (item is! Map) {
        throw FormatException('Manifest invalide : entrée $index non objet.');
      }

      final entry = SecureManifestEntry.fromJson(
        Map<String, dynamic>.from(item),
      );

      if (entriesById.containsKey(entry.id)) {
        throw FormatException(
          'Manifest invalide : identifiant dupliqué "${entry.id}".',
        );
      }

      _validateManifestPath(entry.file);
      entriesById[entry.id] = entry;
    }

    debugPrint(
      '[SECURE] manifest chargé depuis AES natif : '
      '${entriesById.length} entrées',
    );

    return Map<String, SecureManifestEntry>.unmodifiable(entriesById);
  }

  String _validateManifestPath(String file) {
    final normalized = file.replaceAll('\\', '/').trim();

    if (normalized.isEmpty) {
      throw const FormatException(
        'Manifest invalide : chemin de fichier vide.',
      );
    }

    if (normalized.startsWith('/') ||
        normalized.contains('../') ||
        normalized.contains('/..') ||
        normalized.contains('://')) {
      throw FormatException('Manifest invalide : chemin interdit "$file".');
    }

    return normalized;
  }

  String _validateBtblManifestFile(String file) {
    final normalized = _validateManifestPath(file);

    if (!normalized.endsWith('.btbl.gz')) {
      throw FormatException(
        'Manifest invalide : fichier BTBL attendu, reçu "$file".',
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
