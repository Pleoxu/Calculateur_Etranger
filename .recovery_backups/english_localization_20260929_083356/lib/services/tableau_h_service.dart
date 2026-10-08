// lib/services/tableau_h_service.dart

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../domain/fire/services/ballistic_asset_context.dart';
import 'secure_asset_resolver.dart';
import 'secure_table_service.dart';

class TableauHService {
  final SystemeArme systeme;
  final String typeTir;
  final String charge;
  final bool verbose;
  final bool debug;

  TableauHService({
    this.systeme = SystemeArme.caesar,
    required this.typeTir,
    required this.charge,
    this.verbose = false,
    this.debug = false,
  });

  bool _mainLoaded = false;
  bool _latLoaded = false;

  final SecureTableService _secureTable = const SecureTableService();

  final List<_HRow> _rows = <_HRow>[];
  final List<int> _columns = <int>[];
  final Map<int, double> _latFactors = <int, double>{};

  String _canonAssetType(String raw) =>
      BallisticAssetContext.canonicalizeVariant(raw);

  Future<double> rotxM({
    required double distance,
    required int gisementMil,
    required double latitudeDeg,
    required bool tirMontagne,

    /// Ex issu du tableau G lors de la sélection de charge.
    ///
    /// Le tableau H fournit un coefficient. La correction ROTx en mètres
    /// s'obtient en multipliant ce coefficient par Ex.
    double? ex,
  }) async {
    await _ensureLoaded();

    if (_rows.isEmpty || _columns.isEmpty) {
      final fallback = _fallbackRotx(
        distance: distance,
        gisementMil: gisementMil,
        latitudeDeg: latitudeDeg,
      );

      _log(
        '[TableauH] fallback physique '
        'distance=$distance '
        'gisement=$gisementMil '
        'latitude=$latitudeDeg -> $fallback',
      );

      return fallback;
    }

    final rows = _rows
        .where((r) => r.tirMontagne == tirMontagne)
        .toList(growable: false);

    final usableRows = rows.isEmpty ? _rows : rows;

    final byDistance = _interpDistance(
      rows: usableRows,
      distance: distance,
      gisementMil: gisementMil,
    );

    final factor = _latitudeFactor(latitudeDeg.abs());

    final coefficient = byDistance * factor;

    final value = coefficient;

    _log(
      '[TableauH] ROTx distance=$distance '
      'gisement=$gisementMil '
      'latitude=$latitudeDeg '
      'base=$byDistance '
      'factor=$factor '
      'coefficient=$coefficient '
      'Ex=$ex '
      '-> $value m',
    );

    return value;
  }

  Future<void> _ensureLoaded() async {
    if (_mainLoaded) return;

    Object? lastError;

    final t = _canonAssetType(typeTir);
    final ch = charge.trim().toUpperCase();

    final mainCandidates = <String>[
      _secureTable.encryptedPath(
        systeme: systeme,
        famille: 'H',
        typeTir: t,
        charge: ch,
        extension: 'htbl',
      ),
      // Compatibilité historique éventuelle : H_APPUI.htbl.gz.enc.
      'assets/secure_enc/tableaux/H/H_$t.htbl.gz.enc',
      'assets/secure_enc/tableaux/H/HTBL_${t}_$ch.htbl.gz.enc',
      'assets/secure_enc/tableaux/H/HTBL_$t.htbl.gz.enc',
    ];

    for (final encryptedPath in mainCandidates) {
      try {
        Uint8List raw;

        try {
          raw = await _secureTable.loadDecompressedFromPath(encryptedPath);

          _log(
            '[SECURE] TableauH AES natif OK '
            '$encryptedPath systeme=$systeme',
          );
        } catch (e) {
          throw StateError(
            '[SECURE] AES HTBL decrypt failed '
            '$encryptedPath : $e',
          );
        }

        _decodeMainOrFactor(raw, encryptedPath);

        _mainLoaded = _rows.isNotEmpty;

        if (_mainLoaded) {
          break;
        }
      } catch (e) {
        lastError = e;
      }
    }

    final factorCandidates = <String>[
      // Facteurs spécifiques au système si présents.
      if (systeme == SystemeArme.mo)
        'assets/secure_enc/tableaux/MO/H/MO_H_FACTEURLATITUDE.htbl.gz.enc',
      if (systeme == SystemeArme.mepac)
        'assets/secure_enc/tableaux/MEPAC/H/MEPAC_H_FACTEURLATITUDE.htbl.gz.enc',

      // Facteurs historiques communs CAESAR.
      'assets/secure_enc/tableaux/H/H_FACTEURLATITUDE.htbl.gz.enc',
      'assets/secure_enc/tableaux/H/H_FACTEUR_LATITUDE.htbl.gz.enc',
      'assets/secure_enc/tableaux/H/H_LATITUDE.htbl.gz.enc',
      'assets/secure_enc/tableaux/H/H_${t}_LATITUDE.htbl.gz.enc',
      'assets/secure_enc/tableaux/H/HTBL_LATITUDE.htbl.gz.enc',
    ];

    for (final encryptedPath in factorCandidates) {
      try {
        Uint8List raw;

        try {
          raw = await _secureTable.loadDecompressedFromPath(encryptedPath);

          _log(
            '[SECURE] TableauH latitude AES OK '
            '$encryptedPath systeme=$systeme',
          );
        } catch (e) {
          throw StateError(
            '[SECURE] AES HTBL latitude decrypt failed '
            '$encryptedPath : $e',
          );
        }

        _decodeMainOrFactor(raw, encryptedPath);

        if (_latFactors.isNotEmpty) {
          _latLoaded = true;
          break;
        }
      } catch (_) {}
    }

    _mainLoaded = true;

    if (_rows.isEmpty) {
      debugPrint(
        '[TableauH] aucun HTBL principal '
        'chargé: $lastError',
      );
    } else {
      _log(
        '[TableauH] OK rows=${_rows.length} '
        'columns=$_columns '
        'latFactors=${_latFactors.length} '
        'latLoaded=$_latLoaded',
      );
    }
  }

  void _decodeMainOrFactor(Uint8List bytes, String path) {
    if (bytes.length < 6) {
      throw FormatException(
        'HTBL trop court : '
        '${bytes.length} bytes',
      );
    }

    final data = ByteData.sublistView(bytes);

    var offset = 0;

    String readMagic() {
      final magic = String.fromCharCodes(bytes.sublist(offset, offset + 4));

      offset += 4;

      return magic;
    }

    int readUint8() {
      final v = data.getUint8(offset);

      offset += 1;

      return v;
    }

    int readUint16() {
      final v = data.getUint16(offset, Endian.little);

      offset += 2;

      return v;
    }

    int readInt16() {
      final v = data.getInt16(offset, Endian.little);

      offset += 2;

      return v;
    }

    double readFloat32() {
      final v = data.getFloat32(offset, Endian.little);

      offset += 4;

      return v;
    }

    final magic = readMagic();

    if (magic != 'HTBL') {
      throw FormatException(
        'Magic HTBL invalide '
        'dans $path : $magic',
      );
    }

    final version = readUint8();

    if (version != 1) {
      throw FormatException(
        'Version HTBL non supportée '
        'dans $path : $version',
      );
    }

    final subtype = readUint8();

    if (subtype == 1) {
      final rows = readUint16();

      for (var i = 0; i < rows; i++) {
        final latitude = readInt16();

        final factor = readFloat32();

        _latFactors[latitude] = factor;
      }

      _log(
        '[TableauH] facteurs latitude OK '
        'rows=$rows via $path',
      );

      return;
    }

    if (subtype != 0) {
      throw FormatException(
        'Subtype HTBL inconnu '
        'dans $path : $subtype',
      );
    }

    _rows.clear();

    _columns.clear();

    final rows = readUint16();

    final columnCount = readUint16();

    for (var i = 0; i < columnCount; i++) {
      _columns.add(readUint16());
    }

    final rowsOffset = offset;

    // Deux dispositions HTBL existent dans les assets historiques :
    //
    // CAESAR : distance, flags, colonnes...
    // MO/MEPAC récents : distance, colonnes..., flags
    //
    // Le choix est fait selon le système, avec repli automatique sur l'autre
    // disposition si la première ne passe pas les contrôles de cohérence.
    // Les HTBL générés par notre builder utilisent l'ordre :
    // distance -> flags -> colonnes.
    // On privilégie donc ce format pour tous les systèmes.
    const preferFlagsLast = false;

    List<_HRow>? decodedRows;
    Object? preferredError;

    try {
      decodedRows = _decodeMainRows(
        bytes: bytes,
        startOffset: rowsOffset,
        rowCount: rows,
        columns: _columns,
        flagsLast: preferFlagsLast,
        path: path,
      );
    } catch (e) {
      preferredError = e;
    }

    if (decodedRows == null) {
      try {
        decodedRows = _decodeMainRows(
          bytes: bytes,
          startOffset: rowsOffset,
          rowCount: rows,
          columns: _columns,
          flagsLast: !preferFlagsLast,
          path: path,
        );

        _log(
          '[TableauH] disposition HTBL alternative utilisée '
          'systeme=$systeme flagsLast=${!preferFlagsLast} via $path',
        );
      } catch (fallbackError) {
        throw FormatException(
          '[TableauH] Impossible de décoder les lignes HTBL dans $path. '
          'Disposition préférée: $preferredError ; '
          'disposition alternative: $fallbackError',
        );
      }
    }

    _rows.addAll(decodedRows);
    _rows.sort((a, b) => a.distance.compareTo(b.distance));

    _log(
      '[TableauH] principal OK '
      'rows=$rows '
      'columns=$_columns '
      'via $path',
    );
  }

  List<_HRow> _decodeMainRows({
    required Uint8List bytes,
    required int startOffset,
    required int rowCount,
    required List<int> columns,
    required bool flagsLast,
    required String path,
  }) {
    final data = ByteData.sublistView(bytes);
    final rowSize = 4 + 1 + columns.length * 4;
    final expectedEnd = startOffset + rowCount * rowSize;

    if (expectedEnd != bytes.length) {
      throw FormatException(
        '[TableauH] Taille HTBL incohérente dans $path : '
        'attendu=$expectedEnd réel=${bytes.length}',
      );
    }

    final result = <_HRow>[];
    var offset = startOffset;
    double? previousDistance;

    for (var i = 0; i < rowCount; i++) {
      final distance = data.getFloat32(offset, Endian.little);
      offset += 4;

      if (!distance.isFinite || distance <= 0) {
        throw FormatException(
          '[TableauH] Distance invalide ligne $i dans $path : $distance',
        );
      }

      int flags;
      final values = <int, double>{};

      if (flagsLast) {
        for (final column in columns) {
          final value = data.getFloat32(offset, Endian.little);
          offset += 4;

          if (!value.isFinite) {
            throw FormatException(
              '[TableauH] Valeur non finie ligne $i colonne $column '
              'dans $path',
            );
          }

          values[column] = value;
        }

        flags = data.getUint8(offset);
        offset += 1;
      } else {
        flags = data.getUint8(offset);
        offset += 1;

        for (final column in columns) {
          final value = data.getFloat32(offset, Endian.little);
          offset += 4;

          if (!value.isFinite) {
            throw FormatException(
              '[TableauH] Valeur non finie ligne $i colonne $column '
              'dans $path',
            );
          }

          values[column] = value;
        }
      }

      if ((flags & ~0x01) != 0) {
        throw FormatException(
          '[TableauH] Flags inconnus ligne $i dans $path : $flags '
          '(flagsLast=$flagsLast)',
        );
      }

      // Les lignes sont normalement monotones. Une petite tolérance est
      // conservée pour les tables montagne qui peuvent être ordonnées dans
      // l'autre sens avant le tri final.
      if (previousDistance != null &&
          (distance - previousDistance).abs() > 100000) {
        throw FormatException(
          '[TableauH] Saut de distance incohérent ligne $i dans $path : '
          '$previousDistance -> $distance',
        );
      }

      previousDistance = distance;

      result.add(
        _HRow(
          distance: distance,
          tirMontagne: (flags & 0x01) != 0,
          values: values,
        ),
      );
    }

    return result;
  }

  double _interpDistance({
    required List<_HRow> rows,
    required double distance,
    required int gisementMil,
  }) {
    final sorted = rows.toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));

    if (sorted.isEmpty) {
      throw StateError('[TableauH] Aucune ligne disponible pour interpolation');
    }

    if (distance <= sorted.first.distance) {
      return _interpGisement(sorted.first, gisementMil);
    }

    if (distance >= sorted.last.distance) {
      return _interpGisement(sorted.last, gisementMil);
    }

    _HRow lo = sorted.first;

    _HRow hi = sorted.last;

    for (var i = 1; i < sorted.length; i++) {
      if (distance <= sorted[i].distance) {
        lo = sorted[i - 1];
        hi = sorted[i];
        break;
      }
    }

    final d0 = lo.distance;

    final d1 = hi.distance;

    final u = d1 == d0 ? 0.0 : (distance - d0) / (d1 - d0);

    final v0 = _interpGisement(lo, gisementMil);

    final v1 = _interpGisement(hi, gisementMil);

    return v0 + (v1 - v0) * u;
  }

  double _interpGisement(_HRow row, int gisementMil) {
    if (_columns.isEmpty) {
      throw StateError('[TableauH] Aucune colonne de gisement disponible');
    }

    var g = gisementMil % 6400;

    if (g < 0) {
      g += 6400;
    }

    final cols = _columns.toList()..sort();

    if (g <= cols.first) {
      return _requiredValue(row, cols.first);
    }

    if (g >= cols.last) {
      return _requiredValue(row, cols.last);
    }

    int c0 = cols.first;

    int c1 = cols.last;

    for (var i = 1; i < cols.length; i++) {
      if (g <= cols[i]) {
        c0 = cols[i - 1];
        c1 = cols[i];
        break;
      }
    }

    final v0 = _requiredValue(row, c0);

    final v1 = _requiredValue(row, c1);

    final u = c1 == c0 ? 0.0 : (g - c0) / (c1 - c0);

    return v0 + (v1 - v0) * u;
  }

  double _requiredValue(_HRow row, int column) {
    final value = row.values[column];

    if (value == null) {
      throw StateError(
        '[TableauH] Valeur absente distance=${row.distance} '
        'colonne=$column tirMontagne=${row.tirMontagne}',
      );
    }

    return value;
  }

  double _latitudeFactor(double latitudeAbs) {
    if (_latFactors.isEmpty) {
      return 1.0;
    }

    final keys = _latFactors.keys.toList()..sort();

    if (latitudeAbs <= keys.first) {
      return _latFactors[keys.first] ?? 1.0;
    }

    if (latitudeAbs >= keys.last) {
      return _latFactors[keys.last] ?? 1.0;
    }

    int k0 = keys.first;

    int k1 = keys.last;

    for (var i = 1; i < keys.length; i++) {
      if (latitudeAbs <= keys[i]) {
        k0 = keys[i - 1];
        k1 = keys[i];
        break;
      }
    }

    final v0 = _latFactors[k0] ?? 1.0;

    final v1 = _latFactors[k1] ?? 1.0;

    final u = k1 == k0 ? 0.0 : (latitudeAbs - k0) / (k1 - k0);

    return v0 + (v1 - v0) * u;
  }

  double _fallbackRotx({
    required double distance,
    required int gisementMil,
    required double latitudeDeg,
  }) {
    final distanceKm = distance / 1000.0;

    final latRad = latitudeDeg * math.pi / 180.0;

    final gRad = gisementMil * 2.0 * math.pi / 6400.0;

    return -0.9 * distanceKm * math.sin(latRad) * math.cos(gRad);
  }

  void _log(String msg) {
    if (verbose || debug || kDebugMode) {
      debugPrint(msg);
    }
  }
}

class _HRow {
  final double distance;
  final bool tirMontagne;
  final Map<int, double> values;

  const _HRow({
    required this.distance,
    required this.tirMontagne,
    required this.values,
  });
}
