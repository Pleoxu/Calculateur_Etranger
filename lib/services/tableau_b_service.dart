// lib/services/tableau_b_service.dart

import 'package:flutter/foundation.dart' show debugPrint;

import '../core/secure_assets/btbl_table.dart';
import '../core/secure_assets/secure_asset_loader.dart';
import '../domain/fire/services/ballistic_asset_context.dart';
import '../models/charge_selection_models.dart';
import 'secure_asset_resolver.dart';

enum TableauBStatus {
  ok,
  tableVide,
  horsDomaineDistance,
  horsDomaineDenivelee,
  celluleVide,
}

class TableauBRow {
  final double correctionSiteM;
  final int niveauMeteo;

  /// true si la correction vient d'une interpolation.
  final bool interpolation;

  /// true uniquement si la correction Tableau B est exploitable.
  final bool valid;

  /// Statut technique/doctrinal de la recherche.
  final TableauBStatus status;

  /// Message exploitable côté UI/log.
  final String? warning;

  const TableauBRow({
    required this.correctionSiteM,
    required this.niveauMeteo,
    this.interpolation = false,
    this.valid = true,
    this.status = TableauBStatus.ok,
    this.warning,
  });

  @override
  String toString() {
    return 'TableauBRow('
        'correctionSite: ${correctionSiteM.toStringAsFixed(1)}m, '
        'niveauMeteo: $niveauMeteo, '
        'interpolation: $interpolation, '
        'valid: $valid, '
        'status: $status, '
        'warning: $warning'
        ')';
  }
}

class _BPoint {
  final double distance;
  final double denivelee;
  final double correctionSite;
  final int niveauMeteo;
  final bool tirMontagne;

  const _BPoint({
    required this.distance,
    required this.denivelee,
    required this.correctionSite,
    required this.niveauMeteo,
    required this.tirMontagne,
  });
}

class TableauBService {
  final SystemeArme systeme;
  final String typeTir;
  final String charge;
  final bool tirMontagne;
  final bool verbose;

  /// ID sécurisé exact à utiliser lorsque le nom ne suit pas la nomenclature
  /// historique B_/MO_B_/MEPAC_B_. Utilisé notamment par le MO81 LLR.
  final String? assetIdOverride;

  TableauBService({
    this.systeme = SystemeArme.caesar,
    required this.typeTir,
    required this.charge,
    required this.tirMontagne,
    this.verbose = false,
    this.assetIdOverride,
  });

  bool _loaded = false;
  BtblTable? _table;

  final SecureAssetLoader _loader = SecureAssetLoader();
  final SecureAssetResolver _resolver = const SecureAssetResolver();

  String _canonVariant(String s) =>
      BallisticAssetContext.canonicalizeVariant(s);

  String _canonBVariant(String s) {
    return _canonVariant(s);
  }

  String _chargeLabel(String s) {
    final raw = s.trim();

    if (raw.toLowerCase().contains('horsportee')) {
      throw StateError('[TableauB] Invalid charge: $charge');
    }

    final x = raw
        .toUpperCase()
        .replaceAll('CHARGE.', '')
        .replaceAll('CH', '')
        .replaceAll(',', '.')
        .trim();

    final value = double.tryParse(x);

    if (value == null || value < 0 || value > 10) {
      throw StateError('[TableauB] Invalid charge: $charge');
    }

    final allowed = <double>[0, 0.5, 1, 1.5, 2, 2.5, 3, 4, 5, 6, 7, 8, 9, 10];

    final ok = allowed.any((v) => (v - value).abs() < 0.0001);
    if (!ok) {
      throw StateError('[TableauB] Invalid charge: $charge');
    }

    if ((value - value.roundToDouble()).abs() < 0.0001) {
      return 'CH${value.round()}';
    }

    final intPart = value.floor();
    return 'CH${intPart}_5';
  }

  String _assetId() {
    final override = assetIdOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }

    final variant = _canonBVariant(typeTir);
    final ch = _chargeLabel(charge);

    return _resolver.assetId(
      systeme: systeme,
      famille: 'B',
      typeTir: variant,
      charge: ch,
    );
  }

  Future<void> load() async {
    if (_loaded) return;

    final id = _assetId();

    try {
      _table = await _loader.loadBtblById(id);
    } catch (e) {
      throw StateError(
        '[TableauB] Secure asset not found for system=$systeme '
        '$typeTir/$charge (TM=$tirMontagne, id=$id) : $e',
      );
    }

    _loaded = true;

    if (verbose) {
      debugPrint('[TableauB] OK via secure asset id=$id');
      debugPrint('[TableauB] Rows: ${_table!.rows.length}');
    }
  }

  Future<TableauBRow?> chercher({
    required double distanceTopoM,
    required double deniveleeM,
  }) async {
    await load();

    final table = _table;
    if (table == null || table.rows.isEmpty) {
      return const TableauBRow(
        correctionSiteM: 0,
        niveauMeteo: 0,
        valid: false,
        status: TableauBStatus.tableVide,
        warning: 'Tableau B empty or not loaded.',
      );
    }

    final points = _normaliseRows(
      table.rows,
    ).where((p) => p.tirMontagne == tirMontagne).toList();

    if (points.isEmpty) {
      return TableauBRow(
        correctionSiteM: 0,
        niveauMeteo: 0,
        valid: false,
        status: TableauBStatus.celluleVide,
        warning: 'No Tableau B data for tirMontagne=$tirMontagne '
            '($typeTir/$charge).',
      );
    }

    final dists = points.map((p) => p.distance).toSet().toList()..sort();

    final dBounds = _boundsStrict(dists, distanceTopoM);
    if (dBounds == null) {
      return TableauBRow(
        correctionSiteM: 0,
        niveauMeteo: 0,
        valid: false,
        status: TableauBStatus.horsDomaineDistance,
        warning: 'Distance out of range for Tableau B '
            'for tirMontagne=$tirMontagne : '
            '${distanceTopoM.toStringAsFixed(1)} m '
            '(min=${dists.first.toStringAsFixed(1)}, '
            'max=${dists.last.toStringAsFixed(1)}).',
      );
    }

    final d1 = dBounds.$1;
    final d2 = dBounds.$2;
    final uD = dBounds.$3;

    final hAtD1 = _boundsDeniveleeAtDistance(points, d1, deniveleeM);
    if (hAtD1 == null) {
      return _missingDeniveleeResult(points, d1, deniveleeM);
    }

    final hAtD2 = _boundsDeniveleeAtDistance(points, d2, deniveleeM);
    if (hAtD2 == null) {
      return _missingDeniveleeResult(points, d2, deniveleeM);
    }

    final p11 = _point(points, d1, hAtD1.$1);
    final p12 = _point(points, d1, hAtD1.$2);
    final p21 = _point(points, d2, hAtD2.$1);
    final p22 = _point(points, d2, hAtD2.$2);

    if (p11 == null || p12 == null || p21 == null || p22 == null) {
      return TableauBRow(
        correctionSiteM: 0,
        niveauMeteo: 0,
        valid: false,
        status: TableauBStatus.celluleVide,
        warning: 'Empty Table B cell: interpolation impossible'
            'for distance=${distanceTopoM.toStringAsFixed(1)} m, '
            'elevation change=${deniveleeM.toStringAsFixed(1)} m, '
            'tirMontagne=$tirMontagne.',
      );
    }

    final uH1 = hAtD1.$3;
    final uH2 = hAtD2.$3;

    final vD1 = _lerp(p11.correctionSite, p12.correctionSite, uH1);
    final vD2 = _lerp(p21.correctionSite, p22.correctionSite, uH2);
    final correction = _lerp(vD1, vD2, uD);

    final niveau = _nearestLevel(
      [p11, p12, p21, p22],
      distanceTopoM: distanceTopoM,
      deniveleeM: deniveleeM,
    );

    final interpolation =
        (d1 != d2) || (hAtD1.$1 != hAtD1.$2) || (hAtD2.$1 != hAtD2.$2);

    final result = TableauBRow(
      correctionSiteM: correction,
      niveauMeteo: niveau,
      interpolation: interpolation,
      valid: true,
      status: TableauBStatus.ok,
    );

    if (verbose) {
      debugPrint('[Table B] Safe lookup without fallback');
      debugPrint(
        '[Table B] distance=$distanceTopoM elevation_change=$deniveleeM '
        'TM=$tirMontagne',
      );
      debugPrint('[Table B] result=$result');
    }

    return result;
  }

  List<_BPoint> _normaliseRows(List<dynamic> rows) {
    return rows.map((r) {
      final d = r as dynamic;

      bool tm;
      try {
        tm = d.tirMontagne == true;
      } catch (_) {
        tm = false;
      }

      return _BPoint(
        distance: d.distance.toDouble(),
        denivelee: d.denivelee.toDouble(),
        correctionSite: d.correctionSite.toDouble(),
        niveauMeteo: d.niveauMeteo.toInt(),
        tirMontagne: tm,
      );
    }).toList();
  }

  static (double, double, double)? _boundsStrict(List<double> xs, double x) {
    if (xs.isEmpty) return null;

    const eps = 0.0001;

    if (x < xs.first - eps || x > xs.last + eps) {
      return null;
    }

    if ((x - xs.first).abs() <= eps) {
      return (xs.first, xs.first, 0);
    }

    if ((x - xs.last).abs() <= eps) {
      return (xs.last, xs.last, 0);
    }

    for (var i = 0; i < xs.length - 1; i++) {
      final a = xs[i];
      final b = xs[i + 1];

      if (x >= a - eps && x <= b + eps) {
        if ((x - a).abs() <= eps) return (a, a, 0);
        if ((x - b).abs() <= eps) return (b, b, 0);

        return (a, b, (x - a) / (b - a));
      }
    }

    return null;
  }

  (double, double, double)? _boundsDeniveleeAtDistance(
    List<_BPoint> points,
    double distance,
    double denivelee,
  ) {
    final hs = points
        .where((p) => (p.distance - distance).abs() < 0.001)
        .map((p) => p.denivelee)
        .toSet()
        .toList()
      ..sort();

    return _boundsStrict(hs, denivelee);
  }

  _BPoint? _point(List<_BPoint> points, double distance, double denivelee) {
    for (final p in points) {
      if ((p.distance - distance).abs() < 0.001 &&
          (p.denivelee - denivelee).abs() < 0.001) {
        return p;
      }
    }

    return null;
  }

  TableauBRow _missingDeniveleeResult(
    List<_BPoint> points,
    double distance,
    double denivelee,
  ) {
    final hs = points
        .where((p) => (p.distance - distance).abs() < 0.001)
        .map((p) => p.denivelee)
        .toSet()
        .toList()
      ..sort();

    if (hs.isEmpty) {
      return TableauBRow(
        correctionSiteM: 0,
        niveauMeteo: 0,
        valid: false,
        status: TableauBStatus.celluleVide,
        warning: 'No Table B row for distance=${distance.toStringAsFixed(1)} m '
            'tirMontagne=$tirMontagne.',
      );
    }

    return TableauBRow(
      correctionSiteM: 0,
      niveauMeteo: 0,
      valid: false,
      status: TableauBStatus.horsDomaineDenivelee,
      warning:
          'Elevation out of Table B domain at distance=${distance.toStringAsFixed(1)} m '
          'for tirMontagne=$tirMontagne : '
          '${denivelee.toStringAsFixed(1)} m '
          '(min=${hs.first.toStringAsFixed(1)}, '
          'max=${hs.last.toStringAsFixed(1)}).',
    );
  }

  int _nearestLevel(
    List<_BPoint> candidates, {
    required double distanceTopoM,
    required double deniveleeM,
  }) {
    var best = candidates.first;
    var bestScore = double.infinity;

    for (final p in candidates) {
      final score =
          (p.distance - distanceTopoM).abs() + (p.denivelee - deniveleeM).abs();

      if (score < bestScore) {
        best = p;
        bestScore = score;
      }
    }

    return best.niveauMeteo;
  }

  static double _lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  void diagnostiquer() {
    final table = _table;

    if (!_loaded || table == null) {
      debugPrint('[Table B] Data not loaded. Call load() first.');
      return;
    }

    final points = _normaliseRows(table.rows);
    final normal = points.where((p) => !p.tirMontagne).length;
    final montagne = points.where((p) => p.tirMontagne).length;

    debugPrint('\n[TableauB] === DIAGNOSTIC ===');
    debugPrint('[TableauB] Systeme: $systeme');
    debugPrint('[Table B] Fire type: $typeTir');
    debugPrint('[Table B] Charge: $charge');
    debugPrint('[Table B] Mountain fire requested: $tirMontagne');
    debugPrint('[TableauB] ID: ${table.id}');
    debugPrint('[TableauB] Rows: ${table.rows.length}');
    debugPrint('[TableauB] Rows normal: $normal');
    debugPrint('[TableauB] Rows montagne: $montagne');
    debugPrint('[TableauB] === FIN DIAGNOSTIC ===\n');
  }
}
