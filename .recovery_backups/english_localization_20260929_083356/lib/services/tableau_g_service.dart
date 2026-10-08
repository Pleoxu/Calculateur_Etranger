// lib/services/tableau_g_service.dart

import 'package:flutter/foundation.dart';

import '../domain/fire/services/ballistic_asset_context.dart';
import '../models/charge_selection_models.dart';
import 'decoders/gtbl_decoder.dart';
import 'secure_asset_resolver.dart';
import 'secure_table_service.dart';

class TableauGService {
  final SystemeArme systeme;
  final String typeTir;
  final String charge;
  final bool? tirMontagne;
  final bool verbose;

  final SecureTableService _secureTable;
  final GtblDecoder _decoder;

  TableauGService({
    this.systeme = SystemeArme.caesar,
    required this.typeTir,
    required this.charge,
    this.tirMontagne,
    this.verbose = false,
    SecureTableService secureTable = const SecureTableService(),
    GtblDecoder decoder = const GtblDecoder(),
  })  : _secureTable = secureTable,
        _decoder = decoder;

  String? _usedPath;
  TableauGTable? _table;
  Future<TableauGTable>? _loading;

  String _canonType(String value) =>
      BallisticAssetContext.canonicalizeVariant(value);

  /// Conserve le type canonique.
  ///
  /// Les variantes *_ALL disposent de leurs propres tableaux G.
  String _canonGType(String value) {
    return _canonType(value);
  }

  /// Charge et décode le tableau G.
  ///
  /// Les appels suivants retournent la même instance mise en cache.
  /// Les appels concurrents partagent également le même chargement.
  Future<TableauGTable> load() {
    final cached = _table;
    if (cached != null) {
      return Future.value(cached);
    }

    final loading = _loading;
    if (loading != null) {
      return loading;
    }

    final future = _loadAndDecode();
    _loading = future;

    return future.whenComplete(() {
      _loading = null;
    });
  }

  Future<TableauGTable> _loadAndDecode() async {
    final canonicalType = _canonGType(typeTir);
    final canonicalCharge = charge.trim().toUpperCase();

    final encryptedPath = _secureTable.encryptedPath(
      systeme: systeme,
      famille: 'G',
      typeTir: canonicalType,
      charge: canonicalCharge,
      extension: 'gtbl',
    );

    late final Uint8List rawBytes;

    try {
      rawBytes = await _secureTable.loadDecompressedFromPath(encryptedPath);
      _usedPath = encryptedPath;

      if (kDebugMode || verbose) {
        debugPrint(
          '[SECURE] TableauG AES natif OK '
          '$_usedPath systeme=$systeme',
        );
      }
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StateError(
          '[SECURE] AES GTBL decrypt failed '
          '$encryptedPath : $error',
        ),
        stackTrace,
      );
    }

    final table = _decoder.decode(
      rawBytes,
      sourcePath: _usedPath,
      typeTir: canonicalType,
      charge: canonicalCharge,
    );

    if (table.rows.isEmpty) {
      throw StateError('[TableauG] Aucune ligne exploitable ($_usedPath)');
    }

    _table = table;

    if (kDebugMode || verbose) {
      debugPrint(
        '[TableauG] OK rows=${table.rows.length} '
        'via $_usedPath',
      );
    }

    return table;
  }

  Future<double> kAcs({
    required double distanceM,
    required double asMil,
    bool? tirMontagne,
  }) {
    return coefficientCorrectionSite(
      distanceM: distanceM,
      asMil: asMil,
      tirMontagne: tirMontagne ?? this.tirMontagne ?? false,
    );
  }

  Future<double> coefficientCorrectionSite({
    double? distance,
    double? distanceM,
    required double asMil,
    required bool tirMontagne,
  }) async {
    final resolvedDistance = distanceM ?? distance;

    if (resolvedDistance == null) {
      throw ArgumentError('distance ou distanceM requis pour TableauGService');
    }

    final row = await rowInterpolated(
      distanceM: resolvedDistance,
      tirMontagne: tirMontagne,
    );

    final coefficient = asMil >= 0
        ? row.correctionComplementSiteAnglePlus
        : row.correctionComplementSiteAngleMoins;

    if (kDebugMode || verbose) {
      debugPrint(
        '[TableauG] distance=$resolvedDistance '
        'asMil=$asMil '
        'kAcs=$coefficient '
        'TM=$tirMontagne',
      );
    }

    return coefficient;
  }

  /// Interpolation balistique avec bornage aux extrémités du domaine.
  Future<TableauGRow> rowInterpolated({
    double? distance,
    double? distanceM,
    bool? tirMontagne,
  }) async {
    final resolvedDistance = _resolveDistance(distance, distanceM);
    final rows = await _usableRows(tirMontagne);

    return _interpolateFromRows(rows, resolvedDistance);
  }

  /// Interpolation stricte pour la sélection de charge.
  ///
  /// Retourne null lorsque la distance est hors du domaine du tableau,
  /// lorsque la branche demandée n'existe pas, ou lorsqu'aucune ligne
  /// exploitable n'est disponible.
  Future<TableauGRow?> rowInterpolatedStrict({
    required double distanceM,
    bool? tirMontagne,
  }) async {
    _validateDistance(distanceM);

    final table = await load();
    final mountainFire = tirMontagne ?? this.tirMontagne ?? false;

    final rows = table.rows
        .where((row) => row.tirMontagne == mountainFire)
        .toList(growable: false)
      ..sort((a, b) => a.distance.compareTo(b.distance));

    if (rows.isEmpty) {
      return null;
    }

    const epsilon = 1e-9;
    final minimum = rows.first.distance;
    final maximum = rows.last.distance;

    if (distanceM < minimum - epsilon || distanceM > maximum + epsilon) {
      return null;
    }

    return _interpolateFromRows(rows, distanceM);
  }

  Future<TableauGRow> row(double distanceM) {
    return rowInterpolated(distanceM: distanceM);
  }

  double _resolveDistance(double? distance, double? distanceM) {
    final resolvedDistance = distanceM ?? distance;

    if (resolvedDistance == null) {
      throw ArgumentError('distance ou distanceM requis pour TableauGService');
    }

    _validateDistance(resolvedDistance);
    return resolvedDistance;
  }

  void _validateDistance(double distance) {
    if (!distance.isFinite || distance < 0) {
      throw ArgumentError.value(
        distance,
        'distance',
        'La distance doit être finie et positive ou nulle.',
      );
    }
  }

  Future<List<TableauGRow>> _usableRows(bool? requestedTirMontagne) async {
    final table = await load();
    final mountainFire = requestedTirMontagne ?? tirMontagne ?? false;

    final filteredRows = table.rows
        .where((row) => row.tirMontagne == mountainFire)
        .toList(growable: false)
      ..sort((a, b) => a.distance.compareTo(b.distance));

    if (filteredRows.isEmpty) {
      throw StateError(
        '[TableauG] Aucune ligne pour la branche '
        'tirMontagne=$mountainFire ($_usedPath)',
      );
    }

    return filteredRows;
  }

  TableauGRow _interpolateFromRows(List<TableauGRow> rows, double distance) {
    if (rows.isEmpty) {
      throw StateError('[TableauG] Aucune ligne pour interpolation.');
    }

    // Les lignes sont déjà triées une seule fois par GtblDecoder.
    if (distance <= rows.first.distance) {
      return rows.first;
    }

    if (distance >= rows.last.distance) {
      return rows.last;
    }

    var lower = rows.first;
    var upper = rows.last;

    for (var i = 1; i < rows.length; i++) {
      if (distance <= rows[i].distance) {
        lower = rows[i - 1];
        upper = rows[i];
        break;
      }
    }

    final lowerDistance = lower.distance;
    final upperDistance = upper.distance;
    final ratio = upperDistance == lowerDistance
        ? 0.0
        : (distance - lowerDistance) / (upperDistance - lowerDistance);

    double lerp(double a, double b) => a + (b - a) * ratio;

    return TableauGRow(
      distance: lerp(lower.distance, upper.distance),
      hausse: lerp(lower.hausse, upper.hausse),
      ecartProbablePortee: lerp(
        lower.ecartProbablePortee,
        upper.ecartProbablePortee,
      ),
      ecartProbableDirection: lerp(
        lower.ecartProbableDirection,
        upper.ecartProbableDirection,
      ),
      ecartProbableHauteurEclatement: lerp(
        lower.ecartProbableHauteurEclatement,
        upper.ecartProbableHauteurEclatement,
      ),
      ecartProbableDelaiEclatement: lerp(
        lower.ecartProbableDelaiEclatement,
        upper.ecartProbableDelaiEclatement,
      ),
      ecartProbablePorteeEclatement: lerp(
        lower.ecartProbablePorteeEclatement,
        upper.ecartProbablePorteeEclatement,
      ),
      angleChute: lerp(lower.angleChute, upper.angleChute),
      cotangenteAngleChute: lerp(
        lower.cotangenteAngleChute,
        upper.cotangenteAngleChute,
      ),
      vitesseRestante: lerp(lower.vitesseRestante, upper.vitesseRestante),
      fleche: lerp(lower.fleche, upper.fleche),
      correctionComplementSiteAnglePlus: lerp(
        lower.correctionComplementSiteAnglePlus,
        upper.correctionComplementSiteAnglePlus,
      ),
      correctionComplementSiteAngleMoins: lerp(
        lower.correctionComplementSiteAngleMoins,
        upper.correctionComplementSiteAngleMoins,
      ),
      tirMontagne: lower.tirMontagne,
    );
  }
}
