import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:calculateur_etranger/security/native_secure_assets.dart';
import '../domain/fire/services/ballistic_asset_context.dart';
import 'secure_asset_resolver.dart';

class TableauEService {
  final SystemeArme systeme;
  final String typeTir;
  final String charge;
  final bool verbose;

  /// Chemin AES exact lorsque la table ne suit pas la nomenclature E_ classique.
  final String? encryptedPathOverride;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  final SplayTreeMap<double, double> _temp = SplayTreeMap<double, double>();
  final Map<String, double> _perCarreaux = <String, double>{};

  double? _v0Tabulaire;

  TableauEService({
    this.systeme = SystemeArme.caesar,
    required this.typeTir,
    required this.charge,
    this.verbose = true,
    this.encryptedPathOverride,
  });

  String _canonType(String s) => BallisticAssetContext.canonicalizeVariant(s);

  String _canonAssetType(String s) {
    return _canonType(s);
  }

  Future<void> load([String? assetPath]) async {
    if (_loaded) return;

    final override = encryptedPathOverride?.trim();
    if (override != null && override.isNotEmpty) {
      try {
        final compressed = await NativeSecureAssets.decryptAsset(override);
        final raw = Uint8List.fromList(gzip.decode(compressed));
        _decodeEtbl(raw, override);
        _loaded = true;
        _logOk(override);
        return;
      } catch (e) {
        throw StateError(
          '[E] load: asset AES direct introuvable $override : $e',
        );
      }
    }

    final t = _canonAssetType(typeTir);
    final ch = charge.trim().toUpperCase().replaceAll(',', '_');

    final resolver = const SecureAssetResolver();

    final ext = resolver.clearAsset(
      systeme: systeme,
      famille: 'E',
      typeTir: t,
      charge: ch,
      extension: 'etbl',
    );

    if (kDebugMode) {
      debugPrint(
        '[E:RESOLVE] '
        'systeme=$systeme '
        'typeInput=$typeTir '
        'typeCanon=$t '
        'charge=$ch '
        'asset=$ext',
      );
    }

    final candidates = <String>[
      if (assetPath != null && assetPath.trim().isNotEmpty) assetPath,
      'assets/secure/$ext',
      if (t == 'APPUIRTC')
        'assets/secure/${resolver.clearAsset(systeme: systeme, famille: 'E', typeTir: 'APPUI', charge: ch, extension: 'etbl')}',
    ];

    Object? lastError;

    for (final candidate in candidates) {
      try {
        if (!candidate.endsWith('.etbl.gz')) {
          continue;
        }

        final encPath =
            'assets/secure_enc/${candidate.replaceFirst('assets/secure/', '')}.enc';

        final compressed = await NativeSecureAssets.decryptAsset(encPath);
        final raw = Uint8List.fromList(gzip.decode(compressed));

        _decodeEtbl(raw, candidate);

        _loaded = true;
        _logOk(encPath);
        return;
      } catch (e) {
        lastError = e;
      }
    }

    throw StateError('[E] load: asset AES introuvable Tableau E: $lastError');
  }

  void _decodeEtbl(Uint8List bytes, String path) {
    _temp.clear();
    _perCarreaux.clear();
    _v0Tabulaire = null;

    const headerSize = 11;
    const rowSize = 4;

    final reader = ByteData.sublistView(bytes);
    final magic = ascii.decode(bytes.sublist(0, 4));

    if (magic != 'ETBL') {
      throw FormatException('Magic ETBL invalide: $magic');
    }

    final version = reader.getUint8(4);

    if (version != 1) {
      throw FormatException('Version ETBL invalide: $version');
    }

    final rowCount = reader.getUint32(5, Endian.little);
    final deltaVPerCarreauRaw = reader.getInt16(9, Endian.little);
    final expectedSize = headerSize + rowCount * rowSize;

    if (bytes.length != expectedSize) {
      throw FormatException(
        'ETBL taille invalide: ${bytes.length}/$expectedSize',
      );
    }

    final deltaVPerCarreau = deltaVPerCarreauRaw / 10.0;
    _perCarreaux['*'] = deltaVPerCarreau;
    _perCarreaux[charge.trim().toUpperCase()] = deltaVPerCarreau;

    var offset = headerSize;

    for (var i = 0; i < rowCount; i++) {
      final tempPoudre = reader.getInt16(offset, Endian.little);
      offset += 2;

      final deltaVoTempRaw = reader.getInt16(offset, Endian.little);
      offset += 2;

      _temp[tempPoudre.toDouble()] = deltaVoTempRaw / 10.0;
    }
  }

  Future<double?> v0Tabulaire() async {
    await load();
    return _v0Tabulaire;
  }

  Future<double?> deltaVoTemp({required double tempPoudreC}) async {
    await load();

    if (_temp.isEmpty) return null;

    final keys = _temp.keys.toList();

    if (_temp.containsKey(tempPoudreC)) {
      return _temp[tempPoudreC]!;
    }

    if (tempPoudreC <= keys.first) {
      return _temp[keys.first]!;
    }

    if (tempPoudreC >= keys.last) {
      return _temp[keys.last]!;
    }

    for (var i = 0; i < keys.length - 1; i++) {
      final t0 = keys[i];
      final t1 = keys[i + 1];

      if (tempPoudreC >= t0 && tempPoudreC <= t1) {
        final v0 = _temp[t0]!;
        final v1 = _temp[t1]!;
        final u = (tempPoudreC - t0) / (t1 - t0);

        return v0 + (v1 - v0) * u;
      }
    }

    return 0.0;
  }

  Future<double?> deltaVoParCarreaux({
    required String charge,
    required double deltaCarreaux,
  }) async {
    await load();

    final k =
        _perCarreaux[charge.trim().toUpperCase()] ?? _perCarreaux['*'] ?? 0.0;

    return deltaCarreaux * k;
  }

  void _logOk(String path) {
    if (!verbose && !kDebugMode) return;

    final tempRange = _temp.isEmpty
        ? 'vide'
        : '${_temp.keys.first.toStringAsFixed(0)}...'
            '${_temp.keys.last.toStringAsFixed(0)}';

    final k = _perCarreaux[charge.trim().toUpperCase()] ?? _perCarreaux['*'];

    debugPrint(
      '[E] load: OK "$path" rows=${_temp.length} '
      'tempRange=$tempRange deltaV/carreau=$k',
    );
  }
}
