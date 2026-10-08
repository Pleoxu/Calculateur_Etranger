import 'dart:math' as math;

import 'package:calculateur_etranger/domain/assignment/shot_distribution_service.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/fire_doctrine_service.dart';
import 'package:calculateur_etranger/domain/fire/models/tir_complet_input.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan_kind.dart';
import 'package:calculateur_etranger/domain/fire/usecases/fire_plan_allocation_resolver.dart';
import 'package:calculateur_etranger/domain/fire/usecases/fire_plan_allocator.dart';
import 'package:calculateur_etranger/domain/fire/usecases/fire_plan_context.dart';
import 'package:calculateur_etranger/domain/fire/usecases/fire_plan_crossing_resolver.dart';
import 'package:calculateur_etranger/domain/fire/usecases/fire_plan_desired_shots_resolver.dart';
import 'package:calculateur_etranger/domain/fire/usecases/fire_plan_doctrinal_zonal_targets_builder.dart';
import 'package:calculateur_etranger/domain/fire/usecases/fire_plan_pieces_resolver.dart';
import 'package:calculateur_etranger/domain/fire/usecases/fire_plan_special_200x200_builder.dart';
import 'package:calculateur_etranger/domain/fire/usecases/fire_plan_targets_builder.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';

class BuildFirePlanUsecase {
  final ShotDistributionService _shotDistributionService =
      const ShotDistributionService();
  final FirePlanTargetsBuilder _targetsBuilder = const FirePlanTargetsBuilder();
  final FirePlanPiecesResolver _piecesResolver = const FirePlanPiecesResolver();
  final FirePlanAllocator _allocator = const FirePlanAllocator();
  final FirePlanCrossingResolver _crossingResolver =
      const FirePlanCrossingResolver();
  final FireDoctrineService _doctrine = const FireDoctrineService();
  final FirePlanDesiredShotsResolver _desiredShotsResolver =
      const FirePlanDesiredShotsResolver();
  final FirePlanSpecial200x200Builder _special200x200Builder =
      const FirePlanSpecial200x200Builder();
  final FirePlanAllocationResolver _allocationResolver =
      const FirePlanAllocationResolver();
  final FirePlanDoctrinalZonalTargetsBuilder _doctrinalTargetsBuilder =
      const FirePlanDoctrinalZonalTargetsBuilder();

  const BuildFirePlanUsecase();

  FirePlan build({
    required TirCompletInput input,
    required double prX,
    required double prY,
    required double azimutMil,
  }) {
    final ctx = FirePlanContext.create(
      input: input,
      prX: prX,
      prY: prY,
      azimutMil: azimutMil,
    );

    final isEclairant = ctx.input.typeTir == TypeTir.eclairant;

    final effectiveLinearPieceCount = _piecesResolver.effectiveLinearPieceCount(
      ctx.input,
    );

    final targetsData = _targetsBuilder.build(
      input: ctx.input,
      kind: ctx.kind,
      prX: ctx.prX,
      prY: ctx.prY,
      azimutMil: ctx.azimutMil,
      effectiveLinearPieceCount: effectiveLinearPieceCount,
    );

    final zoneLargeurM = targetsData.zoneLargeurM;
    final zoneProfondeurM = targetsData.zoneProfondeurM;
    final azimutMilOut = targetsData.azimutMilOut;
    final azimutLargeurMil = targetsData.azimutLargeurMil;
    final azimutProfondeurMil = targetsData.azimutProfondeurMil;
    final zonalPointIdx = targetsData.zonalPointIdx;
    final gridNL = targetsData.gridNL;
    final gridNP = targetsData.gridNP;
    final diametreEfficaciteM =
        isEclairant ? 600.0 : ctx.input.systeme.diametreEfficaciteM;
    var allTargets = targetsData.allTargets;
    final isForcedSquare3x3 = targetsData.isForcedSquare3x3;

    final wantNatureShots = ctx.isPonctuel || ctx.isZonal || ctx.isLineaire;

    if (!wantNatureShots) {
      return FirePlan.empty(
        kind: FirePlanKind.ponctuel,
        azimutMilOut: azimutMilOut,
        azimutLargeurMil: azimutLargeurMil,
        azimutProfondeurMil: azimutProfondeurMil,
      );
    }

    final pieces = ctx.isLineaire
        ? _piecesResolver.resolveLinearPieces(
            input: ctx.input,
            pdX: ctx.pdX,
            pdY: ctx.pdY,
          )
        : _piecesResolver.resolveZonalPieces(
            input: ctx.input,
            pdX: ctx.pdX,
            pdY: ctx.pdY,
          );

    // OECL zonal possède sa propre doctrine de génération des offsets dans
    // FirePlanTargetsBuilder. On ne doit surtout PAS repasser ensuite dans la
    // doctrine zonale HE/RTC, sinon elle reconstruit une grille différente et
    // supprime un offset.
    final isDoctrinalZonal = !isEclairant &&
        ctx.isZonal &&
        ctx.salvesEnabled &&
        (ctx.input.isZonalPreset || pieces.length == 8) &&
        _doctrine.isSmallDoctrinalZonal(
          largeurM: zoneLargeurM,
          profondeurM: zoneProfondeurM,
        );

    final nbCoupsEffectif = ctx.isLineaire
        ? allTargets.length
        : (ctx.hasManualNbCoups ? ctx.nbCoups! : allTargets.length);

    if (isDoctrinalZonal) {
      allTargets = _doctrinalTargetsBuilder.build(
        pieces: pieces,
        prX: ctx.prX,
        prY: ctx.prY,
        azimutLargeurMil: azimutLargeurMil,
        azimutProfondeurMil: azimutProfondeurMil,
        azimutTirMil: azimutMilOut,
        pointIdx: zonalPointIdx,
        largeurM: zoneLargeurM,
        profondeurM: zoneProfondeurM,
        coups: nbCoupsEffectif,
        diametreEfficaceM: diametreEfficaciteM,
        zonalMode: ctx.input.zonalMode,
        isZonalPreset: ctx.input.isZonalPreset,
      );

      if (ctx.input.isZonalPreset && ctx.input.salvesEnabled) {
        allTargets = _expandZonalPresetTargetsForSalves(
          targets: allTargets,
          prX: ctx.prX,
          prY: ctx.prY,
          salves: (ctx.input.lineairePar ?? 1).clamp(1, 3),
          azimutLargeurMil: azimutLargeurMil,
          azimutProfondeurMil: azimutProfondeurMil,
          diametreEfficaciteM: diametreEfficaciteM,
        );
      }
    }

    final nbPositions = allTargets.length;

    final nbCoupsTotal = (isForcedSquare3x3 || ctx.input.isZonalPreset)
        ? allTargets.length
        : (nbCoupsEffectif * ctx.par);

    final rawCoupsMap = ctx.rawCoupsMap;

    final hasPieceWeights = ctx.hasRawPieceWeights &&
        !isForcedSquare3x3 &&
        !ctx.input.isZonalPreset;

    final coupsMap = hasPieceWeights
        ? _allocator.completeCoupsMapWithDefaults(
            pieces: pieces,
            inputMap: rawCoupsMap,
            defaultValue: 1,
          )
        : const <String, int>{};

    final offsetsWithCoords = [
      for (final t in allTargets)
        OffsetWithCoords(offsetM: t.offsetM, x: t.x, y: t.y),
    ];

    final quotasPositionsByPiece = _allocator.buildQuotasPositions(
      pieces: pieces,
      coupsParPieceById: hasPieceWeights ? coupsMap : const {},
      totalPositions: allTargets.length,
      pdId: 'PD',
    );

    Map<String, int> linearDesiredShots = const {};
    if (ctx.isLineaire && !hasPieceWeights) {
      final orderedIds = pieces.map((p) => p.id).toList();
      final distribution = _shotDistributionService.distributeLinearShots(
        orderedPieces: orderedIds,
        pdPiece: 'PD',
        totalShots: nbCoupsTotal,
      );
      linearDesiredShots = distribution.shotsByPiece;
    }

    final doctrinalSequence =
        ctx.isLineaire ? _doctrine.linearSequence(nbPositions) : null;

    final allocs = _allocationResolver.resolve(
      ctx: ctx,
      pieces: pieces,
      allTargets: allTargets,
      offsetsWithCoords: offsetsWithCoords,
      quotasPositionsByPiece: quotasPositionsByPiece,
      isDoctrinalZonal: isDoctrinalZonal,
      azimutMilOut: azimutMilOut,
      azimutLargeurMil: azimutLargeurMil,
      azimutProfondeurMil: azimutProfondeurMil,
      zonalPointIdx: zonalPointIdx,
      zoneLargeurM: zoneLargeurM,
      zoneProfondeurM: zoneProfondeurM,
      gridNL: gridNL,
      gridNP: gridNP,
      nbCoupsEffectif: nbCoupsEffectif,
      hasPieceWeights: hasPieceWeights,
      doctrinalSequence: doctrinalSequence,
      linearDesiredShots: linearDesiredShots,
    );

    final resolved = isDoctrinalZonal
        ? (allocs: allocs, hasCrossings: false)
        : _crossingResolver.resolve(
            allocs: allocs,
            isLineaire: ctx.isLineaire,
            isZonal: ctx.isZonal,
            azimutLineaireMil: ctx.azimutLineaireMil,
          );

    final fixedAllocs = resolved.allocs;
    final hadCrossings = resolved.hasCrossings;

    final desiredShotsByPiece = isDoctrinalZonal
        ? {for (final a in fixedAllocs) a.piece.id: a.targets.length}
        : _desiredShotsResolver.resolve(
            ctx: ctx,
            pieces: pieces,
            fixedAllocs: fixedAllocs,
            isForcedSquare3x3: isForcedSquare3x3,
            isZonalPreset: ctx.input.isZonalPreset,
            hasPieceWeights: hasPieceWeights,
            coupsMap: coupsMap,
            nbCoupsTotal: nbCoupsTotal,
            nbPositions: nbPositions,
            doctrinalSequence: doctrinalSequence,
            linearDesiredShots: linearDesiredShots,
          );

    final isSpecial200x200 = !isEclairant &&
        !ctx.input.isZonalPreset &&
        _special200x200Builder.isApplicable(
          isZonal: ctx.isZonal,
          salvesOn: ctx.salvesEnabled,
          largeurM: zoneLargeurM,
          profondeurM: zoneProfondeurM,
          piecesCount: pieces.length,
        );

    final specialPlan = isSpecial200x200
        ? _special200x200Builder.build(
            prX: ctx.prX,
            prY: ctx.prY,
            azimutLargeurMil: azimutLargeurMil,
            azimutProfondeurMil: azimutProfondeurMil,
            azimutTirMil: azimutMilOut,
            pointIdx: zonalPointIdx,
            largeurM: zoneLargeurM,
            profondeurM: zoneProfondeurM,
            pieces: pieces,
            zonalMode: ctx.input.zonalMode,
            diametreEfficaceM: diametreEfficaciteM,
          )
        : null;

    return FirePlan(
      kind: ctx.kind,
      zoneLargeurM: zoneLargeurM,
      zoneProfondeurM: zoneProfondeurM,
      azimutMilOut: azimutMilOut,
      azimutLargeurMil: azimutLargeurMil,
      azimutProfondeurMil: azimutProfondeurMil,
      nbPositions: nbPositions,
      nbCoupsTotal: nbCoupsTotal,
      gridNL: gridNL,
      gridNP: gridNP,
      allTargets: allTargets,
      pieces: pieces,
      allocs: fixedAllocs,
      desiredShotsByPiece: desiredShotsByPiece,
      isSpecial200x200: isSpecial200x200,
      special200x200Plan: specialPlan,
      hasCrossings: hadCrossings,
    );
  }

  List<OffsetTarget> _expandZonalPresetTargetsForSalves({
    required List<OffsetTarget> targets,
    required double prX,
    required double prY,
    required int salves,
    required double azimutLargeurMil,
    required double azimutProfondeurMil,
    required double diametreEfficaciteM,
  }) {
    if (targets.isEmpty || salves <= 1) return targets;

    final angles = _salveAnglesDeg(salves);
    final expanded = <OffsetTarget>[];

    for (final target in targets) {
      expanded.add(target.copyWith(index: expanded.length));
    }

    final azLRad = azimutLargeurMil * 2.0 * math.pi / 6400.0;
    final azPRad = azimutProfondeurMil * 2.0 * math.pi / 6400.0;

    final uLx = math.sin(azLRad);
    final uLy = math.cos(azLRad);
    final uPx = math.sin(azPRad);
    final uPy = math.cos(azPRad);

    final det = uLx * uPy - uLy * uPx;
    if (det.abs() < 1e-6) return targets;

    final double r = diametreEfficaciteM / 2.0;
    final double sNewFixed = r / 2.0;

    double hEstimate = 0.0;
    int axialCount = 0;
    final localS1 = <math.Point<double>>[];

    for (final target in targets) {
      final dx = target.x - prX;
      final dy = target.y - prY;

      final xW = (dx * uPy - dy * uPx) / det;
      final yP = (-dx * uLy + dy * uLx) / det;
      localS1.add(math.Point<double>(xW, yP));

      final isAxial = xW.abs() < 1.0 || yP.abs() < 1.0;
      if (isAxial) {
        hEstimate += math.sqrt(xW * xW + yP * yP);
        axialCount++;
      }
    }

    if (axialCount > 0) {
      hEstimate = hEstimate / axialCount + r;
    } else {
      for (final p in localS1) {
        hEstimate = math.max(hEstimate, math.sqrt(p.x * p.x + p.y * p.y));
      }
      hEstimate += r;
    }

    final dSalve1 = hEstimate - r / math.sqrt(2.0);

    for (var salveIdx = 1; salveIdx < angles.length; salveIdx++) {
      final angleRad = angles[salveIdx] * math.pi / 180.0;
      final c = math.cos(angleRad);
      final s = math.sin(angleRad);

      final factor = math.max((c - s).abs(), (s + c).abs());
      final dNew = factor > 1e-9 ? dSalve1 / factor : dSalve1;

      final localOffsets = [
        math.Point<double>(dNew, dNew),
        math.Point<double>(-dNew, dNew),
        math.Point<double>(-dNew, -dNew),
        math.Point<double>(dNew, -dNew),
        math.Point<double>(sNewFixed, 0.0),
        math.Point<double>(-sNewFixed, 0.0),
        math.Point<double>(0.0, sNewFixed),
        math.Point<double>(0.0, -sNewFixed),
      ];

      for (var i = 0; i < localOffsets.length && i < targets.length; i++) {
        final lx = localOffsets[i].x;
        final ly = localOffsets[i].y;

        final rx = lx * c - ly * s;
        final ry = lx * s + ly * c;

        final worldX = prX + rx * uLx + ry * uPx;
        final worldY = prY + rx * uLy + ry * uPy;

        expanded.add(
          targets[i].copyWith(
            index: expanded.length,
            x: worldX,
            y: worldY,
            offsetM: math.sqrt(rx * rx + ry * ry),
          ),
        );
      }
    }

    return expanded;
  }

  List<double> _salveAnglesDeg(int salves) {
    final safe = salves.clamp(1, 3);
    if (safe == 1) return const [0.0];
    if (safe == 2) return const [0.0, 45.0];
    return const [0.0, 120.0, 240.0];
  }
}
