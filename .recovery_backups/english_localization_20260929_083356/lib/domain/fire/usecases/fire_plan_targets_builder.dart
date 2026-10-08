import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/efficacite_systeme.dart';
import 'package:calculateur_etranger/domain/fire/models/tir_complet_input.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan_kind.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/zonal/hardcoded/zonal_hardcoded_doctrine_models.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/zonal/hardcoded/zonal_hardcoded_sequences.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/zonal/zonal_overflow_ratio.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/zonal/zonal_doctrine_engine.dart'
    show ZonalGeometry;
import 'package:calculateur_etranger/domain/fire/target_generation/lineaire/linear_fire_assignment.dart'
    show computeNbCoupsLineaire, computeOffsetsLineaire;
import 'package:calculateur_etranger/domain/fire/target_generation/zonal/zonal_fire_assignment.dart'
    show toUtm;
import 'package:calculateur_etranger/models/calcul_data.dart';

@immutable
class FirePlanTargetsData {
  final double zoneLargeurM;
  final double zoneProfondeurM;
  final double azimutMilOut;
  final double azimutLargeurMil;
  final double azimutProfondeurMil;
  final int zonalPointIdx;
  final int gridNL;
  final int gridNP;
  final List<OffsetTarget> allTargets;
  final bool isForcedSquare3x3;

  const FirePlanTargetsData({
    required this.zoneLargeurM,
    required this.zoneProfondeurM,
    required this.azimutMilOut,
    required this.azimutLargeurMil,
    required this.azimutProfondeurMil,
    required this.zonalPointIdx,
    required this.gridNL,
    required this.gridNP,
    required this.allTargets,
    required this.isForcedSquare3x3,
  });
}

class FirePlanTargetsBuilder {
  const FirePlanTargetsBuilder();

  static const double _square3x3Min = 160.0;
  static const double _square3x3Max = 230.0;
  static const double _squareTolerance = 10.0;

  static const double _coverageRecouvPct = 10.0;
  static const double _coverageDebordPct = 10.0;

  FirePlanTargetsData build({
    required TirCompletInput input,
    required FirePlanKind kind,
    required double prX,
    required double prY,
    required double azimutMil,
    required int effectiveLinearPieceCount,
  }) {
    final isLineaire = kind.isLineaire;
    final isZonal = kind.isZonal;

    final recPct = (input.pourcentageRecouvrement ?? 10.0).toDouble();
    final debordementRatio = ZonalOverflowRatio.fromInput(input);
    final debPct = debordementRatio * 100.0;
    final isEclairant = input.typeTir == TypeTir.eclairant;

    final diametreEfficaciteM =
        isEclairant ? 600.0 : EfficaciteSysteme.diametre(input.systeme);

    double zoneLargeurM = 0.0;
    double zoneProfondeurM = 0.0;
    final azimutMilOut = azimutMil;

    var azimutLargeurMil = (azimutMil + 1600.0) % 6400.0;
    var azimutProfondeurMil = azimutMil;
    var zonalPointIdx = 2;

    var gridNL = 1;
    var gridNP = 1;
    List<OffsetTarget> allTargets;

    if (isLineaire) {
      final longueur = input.longueurLineaire ?? 0.0;
      zoneLargeurM = longueur;

      final isLongLinear = _isLongLinearMode(
        longueurM: longueur,
        diametreEfficaciteM: diametreEfficaciteM,
        nbPieces: effectiveLinearPieceCount,
      );
      debugPrint(
        '[LINEAIRE-LONG] longueur=$longueur nbPieces=$effectiveLinearPieceCount isLongLinear=$isLongLinear',
      );

      final nbPositionsDoctrine = computeNbCoupsLineaire(
        longueurM: longueur,
        diametreEfficaciteM: diametreEfficaciteM,
        recouvrementPourcent: recPct,
        debordementPourcent: debPct,
      );

      final nbPositionsMin = math.max<int>(
        nbPositionsDoctrine,
        effectiveLinearPieceCount,
      );

      final nbPositions =
          (input.nbCoups != null && input.nbCoups! > nbPositionsMin)
              ? input.nbCoups!
              : nbPositionsMin;

      final offsetsM = computeOffsetsLineaire(
        nbCoups: nbPositions,
        longueurM: longueur,
        diametreEfficaciteM: diametreEfficaciteM,
        recouvrementPourcent: recPct,
        debordementPourcent: debPct,
        depuisExtremite: input.lineaireDepuisExtremite ?? false,
      );

      final azLineaire = input.azimutLineaireMil ?? azimutMil;
      final azRad = azLineaire * 2.0 * math.pi / 6400.0;
      final ux = math.sin(azRad);
      final uy = math.cos(azRad);

      allTargets = [
        for (var i = 0; i < offsetsM.length; i++)
          OffsetTarget(
            index: i,
            offsetM: offsetsM[i],
            x: prX + offsetsM[i] * ux,
            y: prY + offsetsM[i] * uy,
          ),
      ];
    } else if (isZonal) {
      final zp = _readZonalParamsDynamic(input: input, defaultAzMil: azimutMil);

      zonalPointIdx = zp.pointIdx;
      zoneLargeurM =
          zp.longueurM <= 0 ? (input.longueurLineaire ?? 0.0) : zp.longueurM;
      zoneProfondeurM = zp.profondeurM;
      azimutLargeurMil = zp.azimutLargeurMil;
      azimutProfondeurMil = zp.azimutProfondeurMil;

      if (zoneLargeurM <= 0 || zoneProfondeurM <= 0) {
        allTargets = [OffsetTarget(index: 0, offsetM: 0.0, x: prX, y: prY)];
      } else if (isEclairant) {
        final oecl = _buildEclairantZonalLocalCenters(
          largeurM: zoneLargeurM,
          profondeurM: zoneProfondeurM,
          diametreM: diametreEfficaciteM,
          debordementPct: debPct,
          requestedCount: math.max(input.nbCoups ?? 0, 0),
        );

        gridNL = oecl.cols;
        gridNP = oecl.rows;

        allTargets = [
          for (var i = 0; i < oecl.centers.length; i++)
            _targetFromLocalOffset(
              index: i,
              local: oecl.centers[i],
              prX: prX,
              prY: prY,
              azimutLargeurMil: azimutLargeurMil,
              azimutProfondeurMil: azimutProfondeurMil,
            ),
        ];

        debugPrint(
          '[OECL-ZONAL] largeur=$zoneLargeurM profondeur=$zoneProfondeurM '
          'debord=$debPct diametre=$diametreEfficaciteM '
          'grid=${gridNL}x$gridNP targets=${allTargets.length}',
        );
      } else if (!input.isZonalPreset &&
          ZonalHardcodedSequences.isSupported(
            width: zoneLargeurM,
            height: zoneProfondeurM,
            debordementRatio: debordementRatio,
          )) {
        final geo = ZonalGeometry.compute(
          largeur: zoneLargeurM,
          profondeur: zoneProfondeurM,
          debordementRatio: debordementRatio,
          recouvrementMini: 0.10,
          diametreEfficaceM: 100.0,
        );

        gridNL = geo.nCols;
        gridNP = geo.nRows;

        final sequence = ZonalHardcodedSequences.resolve(
          width: zoneLargeurM,
          height: zoneProfondeurM,
          mode: input.zonalMode == ZonalMode.otan
              ? ZonalDoctrineMode.otan
              : ZonalDoctrineMode.force,
          debordementRatio: debordementRatio,
        );

        allTargets = [
          for (var i = 0; i < sequence.shots.length; i++)
            _targetFromLocalOffset(
              index: i,
              local: Offset(sequence.shots[i].x, sequence.shots[i].y),
              prX: prX,
              prY: prY,
              azimutLargeurMil: azimutLargeurMil,
              azimutProfondeurMil: azimutProfondeurMil,
            ),
        ];
      } else {
        final geo = ZonalGeometry.compute(
          largeur: zoneLargeurM,
          profondeur: zoneProfondeurM,
          debordementRatio: debordementRatio,
          recouvrementMini: recPct / 100.0,
          diametreEfficaceM: diametreEfficaciteM,
        );

        gridNL = 3;
        gridNP = geo.nRows;

        final localPositions = <Offset>[];

        for (var r = 0; r < geo.nRows; r++) {
          final y = geo.ys[r];

          final isExtreme = r == 0 || r == geo.nRows - 1;
          final xL = geo.nRows == 4 && !isExtreme ? geo.xLeftInner : geo.xLeft;
          final xR =
              geo.nRows == 4 && !isExtreme ? geo.xRightInner : geo.xRight;

          localPositions.add(Offset(xL, y));
          localPositions.add(Offset(xR, y));
        }

        if (geo.otanApplicable && input.zonalMode == ZonalMode.otan) {
          localPositions.add(Offset(0.0, geo.ys.first));
          localPositions.add(Offset(0.0, geo.ys.last));
        } else {
          for (var r = 0; r < geo.nRows; r++) {
            localPositions.add(Offset(0.0, geo.ys[r]));
          }
        }

        allTargets = [
          for (var i = 0; i < localPositions.length; i++)
            _targetFromLocalOffset(
              index: i,
              local: localPositions[i],
              prX: prX,
              prY: prY,
              azimutLargeurMil: azimutLargeurMil,
              azimutProfondeurMil: azimutProfondeurMil,
            ),
        ];
      }
    } else {
      allTargets = [OffsetTarget(index: 0, offsetM: 0.0, x: prX, y: prY)];
    }

    final isForcedSquare3x3 = isZonal &&
        !isEclairant &&
        _isSquare3x3Compatible(
          largeurM: zoneLargeurM,
          profondeurM: zoneProfondeurM,
        );

    return FirePlanTargetsData(
      zoneLargeurM: zoneLargeurM,
      zoneProfondeurM: zoneProfondeurM,
      azimutMilOut: azimutMilOut,
      azimutLargeurMil: azimutLargeurMil,
      azimutProfondeurMil: azimutProfondeurMil,
      zonalPointIdx: zonalPointIdx,
      gridNL: gridNL,
      gridNP: gridNP,
      allTargets: List.unmodifiable(allTargets),
      isForcedSquare3x3: isForcedSquare3x3,
    );
  }

  static _EclairantZonalLocalGrid _buildEclairantZonalLocalCenters({
    required double largeurM,
    required double profondeurM,
    required double diametreM,
    required double debordementPct,
    int requestedCount = 0,
  }) {
    final d = diametreM <= 0 ? 600.0 : diametreM;

    final largeurExt = largeurM * (1.0 + debordementPct / 100.0);
    final profondeurExt = profondeurM * (1.0 + debordementPct / 100.0);

    final baseCols = math.max(1, (largeurExt / d).ceil());
    final baseRows = math.max(1, (profondeurExt / d).ceil());
    final desiredCount = math.max(
      baseCols * baseRows,
      requestedCount <= 0 ? baseCols * baseRows : requestedCount,
    );

    var cols = baseCols;
    var rows = baseRows;

    while (cols * rows < desiredCount) {
      final cellWidth = largeurExt / cols;
      final cellHeight = profondeurExt / rows;

      if (cellWidth >= cellHeight) {
        cols += 1;
      } else {
        rows += 1;
      }
    }

    List<double> axis({required int count, required double extent}) {
      if (count <= 1) return const [0.0];

      final start = -extent / 2.0;
      final step = extent / count;

      return [for (var i = 0; i < count; i++) start + step * (i + 0.5)];
    }

    final xs = axis(count: cols, extent: largeurExt);
    final ys = axis(count: rows, extent: profondeurExt);

    final gridCenters = <Offset>[
      for (final y in ys)
        for (final x in xs) Offset(x, y),
    ];

    final removeCount = math.max(0, gridCenters.length - desiredCount);
    Set<int> removedIndexes = const <int>{};

    if (removeCount > 0) {
      final ranked = List<int>.generate(gridCenters.length, (i) => i)
        ..sort((a, b) {
          final da = gridCenters[a].distanceSquared;
          final db = gridCenters[b].distanceSquared;
          final cmp = da.compareTo(db);
          if (cmp != 0) return cmp;
          return a.compareTo(b);
        });

      removedIndexes = ranked.take(removeCount).toSet();
    }

    final centers = <Offset>[
      for (var i = 0; i < gridCenters.length; i++)
        if (!removedIndexes.contains(i)) gridCenters[i],
    ];

    return _EclairantZonalLocalGrid(cols: cols, rows: rows, centers: centers);
  }

  static double _computeLinearCoverageFor8Pieces({
    required double diametreEfficaciteM,
  }) {
    final offsets = computeOffsetsLineaire(
      nbCoups: 8,
      longueurM: 100000.0,
      diametreEfficaciteM: diametreEfficaciteM,
      recouvrementPourcent: _coverageRecouvPct,
      debordementPourcent: _coverageDebordPct,
      depuisExtremite: false,
    );

    if (offsets.isEmpty) return 0.0;

    final minOffset = offsets.reduce(math.min);
    final maxOffset = offsets.reduce(math.max);
    return maxOffset - minOffset;
  }

  static bool _isLongLinearMode({
    required double longueurM,
    required double diametreEfficaciteM,
    required int nbPieces,
  }) {
    if (nbPieces != 8) return false;
    if (longueurM <= 0) return false;

    final maxCoverage = _computeLinearCoverageFor8Pieces(
      diametreEfficaciteM: diametreEfficaciteM,
    );

    return longueurM > maxCoverage;
  }

  static bool _isSquare3x3Compatible({
    required double largeurM,
    required double profondeurM,
  }) {
    final isSquare = (largeurM - profondeurM).abs() <= _squareTolerance;
    return isSquare &&
        largeurM >= _square3x3Min &&
        largeurM <= _square3x3Max &&
        profondeurM >= _square3x3Min &&
        profondeurM <= _square3x3Max;
  }

  static _ZonalParams _readZonalParamsDynamic({
    required TirCompletInput input,
    required double defaultAzMil,
  }) {
    final longueur = input.longueurZonale ?? input.longueurLineaire ?? 0.0;
    final profondeur = input.profondeurZonale ?? 0.0;
    final azP = input.azimutProfondeurMil ?? defaultAzMil;
    final azL = input.azimutLargeurMil ?? ((azP + 1600.0) % 6400.0);
    final pIdx = (input.pointZonal?.index ?? 2).clamp(0, 2);

    return _ZonalParams(
      longueurM: longueur,
      profondeurM: profondeur,
      azimutLargeurMil: azL,
      azimutProfondeurMil: azP,
      pointIdx: pIdx,
    );
  }

  static OffsetTarget _targetFromLocalOffset({
    required int index,
    required Offset local,
    required double prX,
    required double prY,
    required double azimutLargeurMil,
    required double azimutProfondeurMil,
  }) {
    final utm = toUtm(
      prX: prX,
      prY: prY,
      xW: local.dx,
      yP: local.dy,
      azLargeurMil: azimutLargeurMil,
      azProfondeurMil: azimutProfondeurMil,
    );

    final dx = utm['x']! - prX;
    final dy = utm['y']! - prY;

    return OffsetTarget(
      index: index,
      offsetM: math.sqrt(dx * dx + dy * dy),
      x: utm['x']!,
      y: utm['y']!,
    );
  }
}

class _EclairantZonalLocalGrid {
  final int cols;
  final int rows;
  final List<Offset> centers;

  const _EclairantZonalLocalGrid({
    required this.cols,
    required this.rows,
    required this.centers,
  });
}

class _ZonalParams {
  final double longueurM;
  final double profondeurM;
  final double azimutLargeurMil;
  final double azimutProfondeurMil;
  final int pointIdx;

  const _ZonalParams({
    required this.longueurM,
    required this.profondeurM,
    required this.azimutLargeurMil,
    required this.azimutProfondeurMil,
    required this.pointIdx,
  });
}
