// lib/services/tableau_f_service.dart

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:calculateur_etranger/security/native_secure_assets.dart';
import '../domain/fire/services/ballistic_asset_context.dart';
import 'secure_asset_resolver.dart';

@immutable
class FLongCoeffs {
  final double kVentPlus;
  final double kVentMoins;
  final double kTempPlus;
  final double kTempMoins;
  final double kV0Plus;
  final double kV0Moins;
  final double kPressionPlus;
  final double kPressionMoins;
  final double kMassePlus;
  final double kMasseMoins;

  const FLongCoeffs({
    required this.kVentPlus,
    required this.kVentMoins,
    required this.kTempPlus,
    required this.kTempMoins,
    required this.kV0Plus,
    required this.kV0Moins,
    required this.kPressionPlus,
    required this.kPressionMoins,
    required this.kMassePlus,
    required this.kMasseMoins,
  });
}

class TableauFService {
  final SystemeArme systeme;
  final String typeTir;
  final String charge;
  final bool verbose;

  /// Chemin AES exact, par exemple une table MO81 LLR hors nomenclature
  /// historique F_/MO_F_/MEPAC_F_.
  final String? encryptedPathOverride;

  TableauFService({
    this.systeme = SystemeArme.caesar,
    required this.typeTir,
    required this.charge,
    this.verbose = false,
    this.encryptedPathOverride,
  });

  static const int _headerSize = 9;
  static const int _rowSizeV1 = 75;
  static const int _rowSizeV2 = 79;
  static const int _flagTirMontagne = 1 << 0;
  static const Map<String, int> _validBits = {
    'dAE_per_100m': 0,
    'correctionV0Moins': 1,
    'correctionV0Plus': 2,
    'correctionVentMoins': 3,
    'correctionVentPlus': 4,
    'correctionTempMoins': 5,
    'correctionTempPlus': 6,
    'correctionPressionMoins': 7,
    'correctionPressionPlus': 8,
    'correctionMasseMoins': 9,
    'correctionMassePlus': 10,
  };

  bool _loaded = false;
  String? _usedPath;
  late List<Map<String, dynamic>> _rowsAll;

  String _canonType(String s) => BallisticAssetContext.canonicalizeVariant(s);

  String _canonAssetType(String s) {
    return _canonType(s);
  }

  Future<void> load() async {
    if (_loaded) return;

    final override = encryptedPathOverride?.trim();
    late final String encryptedPath;

    if (override != null && override.isNotEmpty) {
      encryptedPath = override;
    } else {
      final t = _canonAssetType(typeTir);
      final ch = charge.trim().toUpperCase();
      final resolver = const SecureAssetResolver();

      encryptedPath =
          'assets/secure_enc/${resolver.encryptedAsset(systeme: systeme, famille: 'F', typeTir: t, charge: ch, extension: 'ftbl')}';
    }

    Uint8List compressedBytes;

    try {
      compressedBytes = await NativeSecureAssets.decryptAsset(encryptedPath);

      _usedPath = encryptedPath;

      debugPrint('[SECURE] TableauF AES natif OK $_usedPath systeme=$systeme');
    } catch (e) {
      throw StateError(
        '[SECURE] AES FTBL decrypt failed '
        '$encryptedPath : $e',
      );
    }

    final rawBytes = Uint8List.fromList(gzip.decode(compressedBytes));

    _rowsAll = _decodeFtbl(
      rawBytes,
    )..sort((a, b) => _numOr0(a, 'distance').compareTo(_numOr0(b, 'distance')));

    if (_rowsAll.isEmpty) {
      throw StateError('[TableauF] Aucune ligne exploitable ($_usedPath)');
    }

    _loaded = true;

    if (kDebugMode || verbose) {
      final first = _rowsAll.first;

      debugPrint('[TableauF] OK ${_rowsAll.length} rows via $_usedPath');

      debugPrint(
        '[TableauF] first distance=${first['distance']} '
        'hausse=${first['hausse']} '
        'derive=${first['derive']} '
        'tempageS=${first['tempageS']} '
        'kWz=${first['correctionWz']} '
        'varH=${first['varHaussePour100m']}',
      );
    }
  }

  List<Map<String, dynamic>> _decodeFtbl(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);

    if (bytes.length < _headerSize) {
      throw const FormatException('[TableauF] FTBL trop court.');
    }

    final magic = String.fromCharCodes(bytes.sublist(0, 4));
    if (magic != 'FTBL') {
      throw FormatException('[TableauF] Magic invalide : $magic');
    }

    final version = data.getUint8(4);
    if (version != 1 && version != 2) {
      throw FormatException('[TableauF] Version non supportée : $version');
    }

    final rowSize = version == 2 ? _rowSizeV2 : _rowSizeV1;
    final rowCount = data.getUint32(5, Endian.little);
    final expectedSize = _headerSize + rowCount * rowSize;

    if (bytes.length != expectedSize) {
      throw FormatException(
        '[TableauF] Taille invalide : ${bytes.length} bytes, '
        'attendu $expectedSize bytes ($_headerSize + $rowCount × $rowSize)',
      );
    }

    final result = <Map<String, dynamic>>[];

    for (var i = 0; i < rowCount; i++) {
      var o = _headerSize + i * rowSize;

      double f32() {
        final v = data.getFloat32(o, Endian.little);
        o += 4;
        return v;
      }

      final distanceM = f32();
      final hausse = f32();
      final derive = f32();

      final correctionWz = f32();
      final dAEPer100m = f32();

      final correctionV0Moins = f32();
      final correctionV0Plus = f32();

      final correctionVentMoins = f32();
      final correctionVentPlus = f32();

      final correctionTempMoins = f32();
      final correctionTempPlus = f32();

      final correctionPressionMoins = f32();
      final correctionPressionPlus = f32();

      final correctionMasseMoins = f32();
      final correctionMassePlus = f32();

      final tempageS = f32();
      final varHaussePour100m = f32();

      // FTBL_V2 : flèche balistique F (m), nécessaire au calcul
      // du niveau météo spécifique MO81 LLR / OECL.
      final double? flecheM = version >= 2 ? f32() : null;

      final flags = data.getUint8(o);
      o += 1;

      final validMask = data.getUint32(o, Endian.little);
      o += 4;

      final reserved = data.getUint16(o, Endian.little);
      o += 2;

      if (o - (_headerSize + i * rowSize) != rowSize) {
        throw FormatException(
          '[TableauF] Erreur row size ligne $i : '
          '${o - (_headerSize + i * rowSize)} au lieu de $rowSize',
        );
      }

      result.add({
        'distance': distanceM,
        'hausse': hausse,
        'derive': derive,
        'correctionWz': correctionWz,
        'dAE_per_100m': dAEPer100m,
        'correctionV0Moins': correctionV0Moins,
        'correctionV0Plus': correctionV0Plus,
        'correctionVentMoins': correctionVentMoins,
        'correctionVentPlus': correctionVentPlus,
        'correctionTempMoins': correctionTempMoins,
        'correctionTempPlus': correctionTempPlus,
        'correctionPressionMoins': correctionPressionMoins,
        'correctionPressionPlus': correctionPressionPlus,
        'correctionMasseMoins': correctionMasseMoins,
        'correctionMassePlus': correctionMassePlus,
        'tempageS': tempageS,
        'varHaussePour100m': varHaussePour100m,
        'flecheM': flecheM,
        'tirMontagne': (flags & _flagTirMontagne) != 0,
        'flags': flags,
        'validMask': validMask,
        'reserved': reserved,
      });
    }

    return result;
  }

  Future<double?> tempageSeconds({
    required double distance,
    required bool tirMontagne,
  }) async {
    final row = await _rowInterpolated(
      distance: distance,
      tirMontagne: tirMontagne,
    );
    return _numOrNull(row, 'tempageS');
  }

  Future<double?> deriveMil({
    required double distance,
    required bool tirMontagne,
  }) async {
    final row = await _rowInterpolated(
      distance: distance,
      tirMontagne: tirMontagne,
    );

    final value = _numOrNull(row, 'derive');

    if (kDebugMode || verbose) {
      debugPrint(
        '[TableauF DERIVE] '
        'distance=$distance '
        'tirMontagne=$tirMontagne '
        'derive=$value',
      );
    }

    return value;
  }

  Future<double?> correctionWz({
    required double distance,
    required bool tirMontagne,
  }) async {
    final row = await _rowInterpolated(
      distance: distance,
      tirMontagne: tirMontagne,
    );
    return _numOrNull(row, 'correctionWz');
  }

  /// Flèche balistique F (m) interpolée à la portée demandée.
  ///
  /// Disponible dans FTBL_V2. Retourne null pour les anciennes tables V1.
  Future<double?> flecheM({
    required double distance,
    required bool tirMontagne,
  }) async {
    final row = await _rowInterpolated(
      distance: distance,
      tirMontagne: tirMontagne,
    );
    final value = _numOrNull(row, 'flecheM');

    if (kDebugMode || verbose) {
      debugPrint(
        '[TableauF FLECHE] distance=$distance '
        'tirMontagne=$tirMontagne flecheM=$value',
      );
    }

    return value;
  }

  Future<double?> hausseMil({
    required double distance,
    required bool tirMontagne,
  }) async {
    final row = await _rowInterpolated(
      distance: distance,
      tirMontagne: tirMontagne,
    );
    return _numOrNull(row, 'hausse');
  }

  /// Correction de hausse (mil) pour +100 m de variation d'altitude
  /// de l'objectif. La colonne FTBL `dAE_per_100m` est pilotée par le
  /// validMask et interpolée uniquement entre des valeurs valides.
  Future<double?> correctionAltitudeObjectifPour100mMil({
    required double distance,
    required bool tirMontagne,
  }) async {
    try {
      return await _interpolateValidField(
        distance: distance,
        tirMontagne: tirMontagne,
        field: 'dAE_per_100m',
      );
    } on StateError {
      return null;
    }
  }

  Future<double?> bondPorteeParMil({
    required double distance,
    required bool tirMontagne,
  }) async {
    final row = await _rowInterpolated(
      distance: distance,
      tirMontagne: tirMontagne,
    );
    final varH = _numOrNull(row, 'varHaussePour100m');
    if (varH == null || varH.abs() < 1e-9) return null;
    return 100.0 / varH;
  }

  /// Retourne directement la correction de portée liée à la masse.
  ///
  /// Les lignes où la colonne masse est absente sont ignorées grâce au
  /// `validMask` du FTBL. Une valeur binaire 0 avec bit de validité absent
  /// ne doit jamais être interprétée comme un coefficient réel.
  Future<double> correctionMasseM({
    required double distance,
    required bool tirMontagne,
    required double deltaCarreaux,
  }) async {
    if (deltaCarreaux.abs() < 1e-9) {
      return 0.0;
    }

    final field =
        deltaCarreaux < 0.0 ? 'correctionMasseMoins' : 'correctionMassePlus';

    final coefficient = await _interpolateValidField(
      distance: distance,
      tirMontagne: tirMontagne,
      field: field,
    );

    final correction = coefficient * deltaCarreaux.abs();

    if (kDebugMode || verbose) {
      debugPrint(
        '[TableauF MASSE] '
        'distance=$distance '
        'tirMontagne=$tirMontagne '
        'deltaCarreaux=$deltaCarreaux '
        'field=$field coefficient=$coefficient '
        'correction=$correction',
      );
    }

    return correction;
  }

  Future<double> _interpolateValidField({
    required double distance,
    required bool tirMontagne,
    required String field,
  }) async {
    await load();

    final branchRows = _rowsAll
        .where((row) => (row['tirMontagne'] == true) == tirMontagne)
        .toList(growable: false);

    final sourceRows = branchRows.isEmpty ? _rowsAll : branchRows;

    final rows = sourceRows
        .where((row) => _isFieldValid(row, field))
        .toList(growable: false)
      ..sort(
        (a, b) => _numOr0(a, 'distance').compareTo(_numOr0(b, 'distance')),
      );

    if (rows.isEmpty) {
      throw StateError(
        '[TableauF] aucune valeur valide pour $field '
        'tirMontagne=$tirMontagne asset=$_usedPath',
      );
    }

    if (distance <= _numOr0(rows.first, 'distance')) {
      return _numOr0(rows.first, field);
    }

    if (distance >= _numOr0(rows.last, 'distance')) {
      return _numOr0(rows.last, field);
    }

    Map<String, dynamic> lo = rows.first;
    Map<String, dynamic> hi = rows.last;

    for (var i = 1; i < rows.length; i++) {
      if (distance <= _numOr0(rows[i], 'distance')) {
        lo = rows[i - 1];
        hi = rows[i];
        break;
      }
    }

    final d0 = _numOr0(lo, 'distance');
    final d1 = _numOr0(hi, 'distance');
    final v0 = _numOr0(lo, field);
    final v1 = _numOr0(hi, field);
    final u = d1 == d0 ? 0.0 : (distance - d0) / (d1 - d0);
    final value = v0 + (v1 - v0) * u;

    if (kDebugMode || verbose) {
      debugPrint(
        '[TableauF FIELD] '
        'field=$field distance=$distance '
        'd0=$d0 v0=$v0 d1=$d1 v1=$v1 '
        'u=$u -> $value',
      );
    }

    return value;
  }

  bool _isFieldValid(Map<String, dynamic> row, String field) {
    final bit = _validBits[field];

    // Les champs obligatoires ne sont pas pilotés par validMask.
    if (bit == null) {
      return row[field] is num;
    }

    final maskValue = row['validMask'];
    final mask = maskValue is num ? maskValue.toInt() : 0;

    return (mask & (1 << bit)) != 0;
  }

  /// Lit un coefficient longitudinal individuel en respectant le validMask.
  ///
  /// Contrairement à [correctionsLongitudinales], cette méthode n'exige pas
  /// que toutes les colonnes +/- soient présentes. C'est nécessaire pour les
  /// tables MO81 LLR où certaines colonnes ne sont pas applicables.
  Future<double?> coefficientLongitudinal({
    required double distance,
    required bool tirMontagne,
    required String field,
  }) async {
    if (!_validBits.containsKey(field)) {
      throw ArgumentError.value(field, 'field', 'Coefficient FTBL inconnu');
    }

    try {
      return await _interpolateValidField(
        distance: distance,
        tirMontagne: tirMontagne,
        field: field,
      );
    } on StateError {
      return null;
    }
  }

  Future<FLongCoeffs?> correctionsLongitudinales({
    required double distance,
    required bool tirMontagne,
  }) async {
    return FLongCoeffs(
      kVentPlus: await _interpolateValidField(
        distance: distance,
        tirMontagne: tirMontagne,
        field: 'correctionVentPlus',
      ),
      kVentMoins: await _interpolateValidField(
        distance: distance,
        tirMontagne: tirMontagne,
        field: 'correctionVentMoins',
      ),
      kTempPlus: await _interpolateValidField(
        distance: distance,
        tirMontagne: tirMontagne,
        field: 'correctionTempPlus',
      ),
      kTempMoins: await _interpolateValidField(
        distance: distance,
        tirMontagne: tirMontagne,
        field: 'correctionTempMoins',
      ),
      kV0Plus: await _interpolateValidField(
        distance: distance,
        tirMontagne: tirMontagne,
        field: 'correctionV0Plus',
      ),
      kV0Moins: await _interpolateValidField(
        distance: distance,
        tirMontagne: tirMontagne,
        field: 'correctionV0Moins',
      ),
      kPressionPlus: await _interpolateValidField(
        distance: distance,
        tirMontagne: tirMontagne,
        field: 'correctionPressionPlus',
      ),
      kPressionMoins: await _interpolateValidField(
        distance: distance,
        tirMontagne: tirMontagne,
        field: 'correctionPressionMoins',
      ),
      kMassePlus: await _interpolateValidField(
        distance: distance,
        tirMontagne: tirMontagne,
        field: 'correctionMassePlus',
      ),
      kMasseMoins: await _interpolateValidField(
        distance: distance,
        tirMontagne: tirMontagne,
        field: 'correctionMasseMoins',
      ),
    );
  }

  Future<Map<String, dynamic>> _rowInterpolated({
    required double distance,
    required bool tirMontagne,
  }) async {
    await load();

    final rows = _rowsAll
        .where((r) => (r['tirMontagne'] == true) == tirMontagne)
        .toList();

    final usableRows = rows.isEmpty ? _rowsAll : rows;

    return _interpolateFromRows(usableRows, distance);
  }

  Map<String, dynamic> _interpolateFromRows(
    List<Map<String, dynamic>> rows,
    double distance,
  ) {
    if (rows.isEmpty) return <String, dynamic>{};

    rows.sort(
      (a, b) => _numOr0(a, 'distance').compareTo(_numOr0(b, 'distance')),
    );

    if (distance <= _numOr0(rows.first, 'distance')) {
      return Map<String, dynamic>.from(rows.first);
    }

    if (distance >= _numOr0(rows.last, 'distance')) {
      return Map<String, dynamic>.from(rows.last);
    }

    var lo = rows.first;
    var hi = rows.last;

    for (var i = 1; i < rows.length; i++) {
      if (distance <= _numOr0(rows[i], 'distance')) {
        lo = rows[i - 1];
        hi = rows[i];
        break;
      }
    }

    final d0 = _numOr0(lo, 'distance');
    final d1 = _numOr0(hi, 'distance');
    final t = d1 == d0 ? 0.0 : (distance - d0) / (d1 - d0);

    if (kDebugMode || verbose) {
      debugPrint(
        '[TableauF INTERP] '
        'distanceDemandee=$distance '
        'd0=$d0 d1=$d1 t=$t '
        'derive0=${_numOrNull(lo, 'derive')} '
        'derive1=${_numOrNull(hi, 'derive')}',
      );
    }

    final out = Map<String, dynamic>.from(lo);

    for (final key in hi.keys) {
      final a = lo[key];
      final b = hi[key];

      if (a is num && b is num) {
        out[key] = a.toDouble() + (b.toDouble() - a.toDouble()) * t;
      } else {
        out[key] = t < 0.5 ? a : b;
      }
    }

    if (kDebugMode || verbose) {
      debugPrint(
        '[TableauF INTERP] '
        'deriveInterp=${_numOrNull(out, 'derive')}',
      );
    }

    return out;
  }

  static double _numOr0(Map<String, dynamic> row, String key) {
    final v = row[key];
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.trim().replaceAll(',', '.')) ?? 0.0;
    }
    return 0.0;
  }

  static double? _numOrNull(Map<String, dynamic> row, String key) {
    final v = row[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim().replaceAll(',', '.'));
    return null;
  }
}
