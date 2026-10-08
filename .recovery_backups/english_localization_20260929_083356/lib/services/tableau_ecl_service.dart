// lib/services/tableau_ecl_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:calculateur_etranger/security/native_secure_assets.dart';
import '../domain/fire/services/ballistic_asset_context.dart';

/// Service de lecture des tables ECL chiffrées.
///
/// Compatibilité :
/// - ECLTBL_V1 historique (13 octets/ligne)
/// - ECLTBL_V2 actuel     (25 octets/ligne)
///
/// ECLTBL_V2 transporte :
/// - portee_m
/// - hausse_mil
/// - tempage_s (nom générique ; ancien JSON : event_fuchsia_s)
/// - corr_hausse_+50m_mil
/// - corr_tempage_+50m_s (ancien JSON : corr_event_+50m_s)
/// - distance_1er_depotage_m (nullable via flag V2)
/// - portee_non_fonctionnement_m (nullable via flag V2)
/// - tirMontagne
class TableauEclService {
  final String typeTir;
  final String charge;
  final bool tirMontagne;
  final bool verbose;
  final String? encryptedPathOverride;

  /// Autorise la lecture de l’autre branche uniquement si la branche demandée
  /// est complètement absente de l’asset. Cette option reste désactivée par
  /// défaut afin de préserver les contrôles stricts des autres systèmes.
  final bool allowBranchFallback;

  TableauEclService({
    required this.typeTir,
    required this.charge,
    required this.tirMontagne,
    this.verbose = false,
    this.encryptedPathOverride,
    this.allowBranchFallback = false,
  });

  static const int _headerSize = 9;
  static const int _rowSizeV1 = 13;
  static const int _rowSizeV2 = 25;

  static const int _flagTirMontagne = 0x01;
  static const int _flagCorrHausseNull = 0x02;
  static const int _flagCorrEventNull = 0x04;
  static const int _flagDistanceDepotageNull = 0x08;
  static const int _flagPorteeNonFonctionnementNull = 0x10;

  static const int _knownFlagsV2 = _flagTirMontagne |
      _flagCorrHausseNull |
      _flagCorrEventNull |
      _flagDistanceDepotageNull |
      _flagPorteeNonFonctionnementNull;

  bool _loaded = false;
  String? _usedPath;
  int? _formatVersion;

  List<_EclRow> _rows = const [];

  int? get formatVersion => _formatVersion;
  String? get usedPath => _usedPath;

  String _canonType(String s) {
    final t = BallisticAssetContext.canonicalizeVariant(s).toUpperCase();

    switch (t) {
      case 'OECL':
      case 'OECL_ALL':
        return 'OECL_ART392';
      default:
        return t;
    }
  }

  Future<void> load() async {
    if (_loaded) return;

    final t = _canonType(typeTir);
    final ch = charge.trim().toUpperCase();

    final encryptedPath = encryptedPathOverride ??
        'assets/secure_enc/tableaux/ECL/ECL_${t}_$ch.ecltbl.gz.enc';

    Uint8List compressedBytes;

    try {
      compressedBytes = await NativeSecureAssets.decryptAsset(encryptedPath);
      _usedPath = encryptedPath;

      if (kDebugMode || verbose) {
        debugPrint('[SECURE] TableauECL AES natif OK $_usedPath');
      }
    } catch (e) {
      throw StateError('[SECURE] AES ECL decrypt failed $encryptedPath : $e');
    }

    Uint8List rawBytes;

    try {
      rawBytes = Uint8List.fromList(gzip.decode(compressedBytes));
    } catch (e) {
      throw FormatException(
        '[ECL] GZIP invalide après déchiffrement de $encryptedPath : $e',
      );
    }

    final decoded = _decode(rawBytes);
    _formatVersion = decoded.version;

    _rows = decoded.rows
      ..sort((a, b) {
        final tm =
            a.tirMontagne == b.tirMontagne ? 0 : (a.tirMontagne ? 1 : -1);

        if (tm != 0) return tm;
        return a.porteeM.compareTo(b.porteeM);
      });

    _validateRows(_rows);

    _loaded = true;

    if (kDebugMode || verbose) {
      debugPrint(
        '[ECL] OK version=$_formatVersion rows=${_rows.length} '
        'type=$t charge=$ch via $_usedPath',
      );
    }
  }

  _DecodedEcl _decode(Uint8List bytes) {
    if (bytes.length < _headerSize) {
      throw const FormatException('[ECL] ECLTBL trop court.');
    }

    final data = ByteData.sublistView(bytes);
    final magic = ascii.decode(bytes.sublist(0, 4));

    if (magic != 'ECLT') {
      throw FormatException('[ECL] Magic invalide : $magic');
    }

    final version = data.getUint8(4);
    final rowCount = data.getUint32(5, Endian.little);

    switch (version) {
      case 1:
        return _DecodedEcl(version: 1, rows: _decodeV1(bytes, data, rowCount));

      case 2:
        return _DecodedEcl(version: 2, rows: _decodeV2(bytes, data, rowCount));

      default:
        throw FormatException('[ECL] Version ECLTBL non supportée : $version');
    }
  }

  List<_EclRow> _decodeV2(Uint8List bytes, ByteData data, int rowCount) {
    final expectedSize = _headerSize + rowCount * _rowSizeV2;

    if (bytes.length != expectedSize) {
      throw FormatException(
        '[ECL] Taille V2 invalide : '
        '${bytes.length} bytes, attendu $expectedSize',
      );
    }

    final out = <_EclRow>[];
    var offset = _headerSize;

    for (var i = 0; i < rowCount; i++) {
      final porteeRaw = data.getUint32(offset, Endian.little);
      offset += 4;

      final hausseRaw = data.getInt32(offset, Endian.little);
      offset += 4;

      final tempageRaw = data.getInt32(offset, Endian.little);
      offset += 4;

      final corrHausseStored = data.getInt16(offset, Endian.little);
      offset += 2;

      final corrTempageStored = data.getInt16(offset, Endian.little);
      offset += 2;

      final distanceDepotageRaw = data.getUint32(offset, Endian.little);
      offset += 4;

      final porteeNonFonctionnementRaw = data.getUint32(offset, Endian.little);
      offset += 4;

      final flags = data.getUint8(offset);
      offset += 1;

      if ((flags & ~_knownFlagsV2) != 0) {
        throw FormatException('[ECL] Flags V2 inconnus ligne $i : $flags');
      }

      final corrHausseRaw =
          (flags & _flagCorrHausseNull) != 0 ? null : corrHausseStored;

      final corrTempageRaw =
          (flags & _flagCorrEventNull) != 0 ? null : corrTempageStored;

      final distanceDepotageM = (flags & _flagDistanceDepotageNull) != 0
          ? null
          : distanceDepotageRaw.toDouble();

      final porteeNonFonctionnementM =
          (flags & _flagPorteeNonFonctionnementNull) != 0
              ? null
              : porteeNonFonctionnementRaw.toDouble();

      out.add(
        _EclRow(
          formatVersion: 2,
          porteeM: porteeRaw / 10.0,
          hausseMil: hausseRaw / 100.0,
          tempageS: tempageRaw / 100.0,
          corrHaussePar50mMil:
              corrHausseRaw == null ? null : corrHausseRaw / 100.0,
          corrTempagePar50mS:
              corrTempageRaw == null ? null : corrTempageRaw / 100.0,
          distance1erDepotageM: distanceDepotageM,
          porteeNonFonctionnementM: porteeNonFonctionnementM,
          tirMontagne: (flags & _flagTirMontagne) != 0,
        ),
      );
    }

    return out;
  }

  /// Compatibilité avec les anciens ECLTBL_V1.
  ///
  /// V1 ne contient pas :
  /// - tempage_s (nom générique ; ancien JSON : event_fuchsia_s)
  /// - distance_1er_depotage_m
  /// - portee_non_fonctionnement_m
  List<_EclRow> _decodeV1(Uint8List bytes, ByteData data, int rowCount) {
    final expectedSize = _headerSize + rowCount * _rowSizeV1;

    if (bytes.length != expectedSize) {
      throw FormatException(
        '[ECL] Taille V1 invalide : '
        '${bytes.length} bytes, attendu $expectedSize',
      );
    }

    final out = <_EclRow>[];
    var offset = _headerSize;

    for (var i = 0; i < rowCount; i++) {
      final portee = data.getUint16(offset, Endian.little);
      offset += 2;

      final hausseRaw = data.getInt32(offset, Endian.little);
      offset += 4;

      final corrHausseRaw = data.getInt16(offset, Endian.little);
      offset += 2;

      final corrTempageRaw = data.getInt16(offset, Endian.little);
      offset += 2;

      final flags = data.getUint8(offset);
      offset += 1;

      final reserved = data.getUint16(offset, Endian.little);
      offset += 2;

      if ((flags & ~_flagTirMontagne) != 0) {
        throw FormatException('[ECL] Flags V1 inconnus ligne $i : $flags');
      }

      if (reserved != 0) {
        throw FormatException('[ECL] Reserved V1 non nul ligne $i : $reserved');
      }

      out.add(
        _EclRow(
          formatVersion: 1,
          porteeM: portee.toDouble(),
          hausseMil: hausseRaw / 100.0,
          tempageS: null,
          corrHaussePar50mMil: corrHausseRaw / 100.0,
          corrTempagePar50mS: corrTempageRaw / 100.0,
          distance1erDepotageM: null,
          porteeNonFonctionnementM: null,
          tirMontagne: (flags & _flagTirMontagne) != 0,
        ),
      );
    }

    return out;
  }

  void _validateRows(List<_EclRow> rows) {
    if (rows.isEmpty) {
      throw const FormatException('[ECL] Aucune ligne.');
    }

    final seen = <String>{};

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];

      if (!row.porteeM.isFinite ||
          !row.hausseMil.isFinite ||
          (row.tempageS != null && !row.tempageS!.isFinite) ||
          (row.corrHaussePar50mMil != null &&
              !row.corrHaussePar50mMil!.isFinite) ||
          (row.corrTempagePar50mS != null &&
              !row.corrTempagePar50mS!.isFinite) ||
          (row.distance1erDepotageM != null &&
              (!row.distance1erDepotageM!.isFinite ||
                  row.distance1erDepotageM! < 0)) ||
          (row.porteeNonFonctionnementM != null &&
              (!row.porteeNonFonctionnementM!.isFinite ||
                  row.porteeNonFonctionnementM! < 0))) {
        throw FormatException('[ECL] Valeur invalide ligne $i.');
      }

      final key = '${row.tirMontagne ? 1 : 0}:${row.porteeM}';

      if (!seen.add(key)) {
        throw FormatException(
          '[ECL] Doublon ligne $i : '
          'tirMontagne=${row.tirMontagne} portee=${row.porteeM}',
        );
      }
    }
  }

  /// Hausse interpolée à la distance demandée.
  Future<double> hausseMil({required double distanceM}) async {
    final row = await _rowInterpolated(distanceM);
    return row?.hausseMil ?? 0.0;
  }

  /// Tempage nominal porté par la table ECL.
  ///
  /// Retourne null pour une table V1, car ce champ n'existe pas dans V1.
  Future<double?> tempageS({required double distanceM}) async {
    final row = await _rowInterpolated(distanceM);
    return row?.tempageS;
  }

  /// Alias historique pour les branches 155 mm existantes.
  @Deprecated('Utiliser tempageS().')
  Future<double?> eventFuchsiaS({required double distanceM}) =>
      tempageS(distanceM: distanceM);

  /// Correction de hausse par +50 m.
  ///
  /// Conserve l'API historique : 0.0 si la valeur est indisponible/null.
  Future<double> corrHaussePar50mMil({required double distanceM}) async {
    final row = await _rowInterpolated(distanceM);
    return row?.corrHaussePar50mMil ?? 0.0;
  }

  /// Variante nullable si l'appelant doit distinguer "0" de "absent".
  Future<double?> corrHaussePar50mMilOrNull({required double distanceM}) async {
    final row = await _rowInterpolated(distanceM);
    return row?.corrHaussePar50mMil;
  }

  /// Correction de tempage par +50 m.
  ///
  /// Conserve l'API historique : 0.0 si la valeur est indisponible/null.
  Future<double> corrTempagePar50mS({required double distanceM}) async {
    final row = await _rowInterpolated(distanceM);
    return row?.corrTempagePar50mS ?? 0.0;
  }

  /// Alias historique pour compatibilité.
  @Deprecated('Utiliser corrTempagePar50mS().')
  Future<double> corrEventPar50mS({required double distanceM}) =>
      corrTempagePar50mS(distanceM: distanceM);

  /// Variante nullable si l'appelant doit distinguer "0" de "absent".
  Future<double?> corrTempagePar50mSOrNull({required double distanceM}) async {
    final row = await _rowInterpolated(distanceM);
    return row?.corrTempagePar50mS;
  }

  /// Alias historique nullable pour compatibilité.
  @Deprecated('Utiliser corrTempagePar50mSOrNull().')
  Future<double?> corrEventPar50mSOrNull({required double distanceM}) =>
      corrTempagePar50mSOrNull(distanceM: distanceM);

  /// Distance au premier dépotage.
  ///
  /// Valeur interpolée en mètres. Null pour ECLTBL_V1.
  Future<double?> distance1erDepotageM({required double distanceM}) async {
    final row = await _rowInterpolated(distanceM);
    return row?.distance1erDepotageM;
  }

  /// Portée au point d'impact en cas de non-fonctionnement de la fusée.
  ///
  /// Valeur interpolée en mètres. Null pour ECLTBL_V1.
  Future<double?> porteeNonFonctionnementM({required double distanceM}) async {
    final row = await _rowInterpolated(distanceM);
    return row?.porteeNonFonctionnementM;
  }

  /// Indique si la portée appartient au domaine couvert par la branche ECL
  /// effectivement résolue. À la différence des méthodes interpolées, ce
  /// contrôle ne borne jamais la demande à la première ou dernière ligne.
  Future<bool> couvrePortee({required double distanceM}) async {
    await load();

    if (!distanceM.isFinite) {
      throw ArgumentError.value(
        distanceM,
        'distanceM',
        'La distance doit être finie.',
      );
    }

    var resolvedTirMontagne = tirMontagne;
    var filtered =
        _rows.where((r) => r.tirMontagne == resolvedTirMontagne).toList();

    if (filtered.isEmpty && allowBranchFallback) {
      resolvedTirMontagne = !tirMontagne;
      filtered =
          _rows.where((r) => r.tirMontagne == resolvedTirMontagne).toList();
    }

    if (filtered.isEmpty) return false;

    filtered.sort((a, b) => a.porteeM.compareTo(b.porteeM));
    return distanceM >= filtered.first.porteeM &&
        distanceM <= filtered.last.porteeM;
  }

  Future<_EclRow?> _rowInterpolated(double distanceM) async {
    await load();

    if (!distanceM.isFinite) {
      throw ArgumentError.value(
        distanceM,
        'distanceM',
        'La distance doit être finie.',
      );
    }

    var resolvedTirMontagne = tirMontagne;
    var filtered =
        _rows.where((r) => r.tirMontagne == resolvedTirMontagne).toList();

    // Certains assets ECL IR F2 ne portent qu’une seule branche. Le repli est
    // opt-in et ne s’active que lorsqu’aucune ligne de la branche demandée
    // n’existe, jamais pour choisir une autre ligne à l’intérieur d’une
    // branche disponible.
    if (filtered.isEmpty && allowBranchFallback) {
      resolvedTirMontagne = !tirMontagne;
      filtered =
          _rows.where((r) => r.tirMontagne == resolvedTirMontagne).toList();
      if (filtered.isNotEmpty && (kDebugMode || verbose)) {
        debugPrint(
          '[ECL] repli de branche $tirMontagne -> $resolvedTirMontagne '
          'type=${_canonType(typeTir)} charge=${charge.trim().toUpperCase()}',
        );
      }
    }

    if (filtered.isEmpty) {
      throw StateError(
        '[ECL] Aucune ligne pour tirMontagne=$tirMontagne '
        'type=${_canonType(typeTir)} charge=${charge.trim().toUpperCase()}',
      );
    }

    filtered.sort((a, b) => a.porteeM.compareTo(b.porteeM));

    if (distanceM <= filtered.first.porteeM) {
      return filtered.first;
    }

    if (distanceM >= filtered.last.porteeM) {
      return filtered.last;
    }

    var lo = filtered.first;
    var hi = filtered.last;

    for (var i = 1; i < filtered.length; i++) {
      if (distanceM <= filtered[i].porteeM) {
        lo = filtered[i - 1];
        hi = filtered[i];
        break;
      }
    }

    final denom = hi.porteeM - lo.porteeM;
    final t = denom.abs() < 1e-12 ? 0.0 : (distanceM - lo.porteeM) / denom;

    return _EclRow(
      formatVersion: lo.formatVersion,
      porteeM: distanceM,
      hausseMil: _lerp(lo.hausseMil, hi.hausseMil, t),
      tempageS: _lerpNullable(lo.tempageS, hi.tempageS, t),
      corrHaussePar50mMil: _lerpNullable(
        lo.corrHaussePar50mMil,
        hi.corrHaussePar50mMil,
        t,
      ),
      corrTempagePar50mS: _lerpNullable(
        lo.corrTempagePar50mS,
        hi.corrTempagePar50mS,
        t,
      ),
      distance1erDepotageM: _lerpNullable(
        lo.distance1erDepotageM,
        hi.distance1erDepotageM,
        t,
      ),
      porteeNonFonctionnementM: _lerpNullable(
        lo.porteeNonFonctionnementM,
        hi.porteeNonFonctionnementM,
        t,
      ),
      tirMontagne: resolvedTirMontagne,
    );
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  double? _lerpNullable(double? a, double? b, double t) {
    if (a == null || b == null) {
      return null;
    }
    return _lerp(a, b, t);
  }
}

@immutable
class _DecodedEcl {
  final int version;
  final List<_EclRow> rows;

  const _DecodedEcl({required this.version, required this.rows});
}

@immutable
class _EclRow {
  final int formatVersion;

  final double porteeM;
  final double hausseMil;
  final double? tempageS;
  final double? corrHaussePar50mMil;
  final double? corrTempagePar50mS;
  final double? distance1erDepotageM;
  final double? porteeNonFonctionnementM;
  final bool tirMontagne;

  const _EclRow({
    required this.formatVersion,
    required this.porteeM,
    required this.hausseMil,
    required this.tempageS,
    required this.corrHaussePar50mMil,
    required this.corrTempagePar50mS,
    required this.distance1erDepotageM,
    required this.porteeNonFonctionnementM,
    required this.tirMontagne,
  });
}
