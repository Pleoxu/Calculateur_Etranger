import 'dart:math' as math;

import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';
import 'package:calculateur_etranger/domain/fire/usecases/fire_plan_allocator.dart';
import 'package:calculateur_etranger/domain/fire/usecases/fire_plan_context.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';

class FirePlanDesiredShotsResolver {
  final FirePlanAllocator _allocator = const FirePlanAllocator();

  const FirePlanDesiredShotsResolver();

  Map<String, int> resolve({
    required FirePlanContext ctx,
    required List<PieceGeom> pieces,
    required List<PieceAllocation> fixedAllocs,
    required bool isForcedSquare3x3,
    required bool isZonalPreset,
    required bool hasPieceWeights,
    required Map<String, int> coupsMap,
    required int nbCoupsTotal,
    required int nbPositions,
    required List<int>? doctrinalSequence,
    required Map<String, int> linearDesiredShots,
  }) {
    if (isZonalPreset) {
      return _resolvePreset8Shots(pieces: pieces);
    }

    final sumMap = hasPieceWeights
        ? coupsMap.values.fold<int>(0, (a, b) => a + math.max<int>(0, b))
        : 0;

    final isZonalRectangulaire = ctx.isZonal && !isForcedSquare3x3;

    if (isForcedSquare3x3 && !isZonalPreset) {
      return _resolveForcedSquare3x3(
        pieces: pieces,
        zonalMode: ctx.input.zonalMode,
      );
    }

    if (ctx.isLineaire) {
      return _resolveLinear(
        ctx: ctx,
        pieces: pieces,
        hasPieceWeights: hasPieceWeights,
        coupsMap: coupsMap,
        nbCoupsTotal: nbCoupsTotal,
        sumMap: sumMap,
        doctrinalSequence: doctrinalSequence,
        linearDesiredShots: linearDesiredShots,
      );
    }

    if (isZonalRectangulaire) {
      if (hasPieceWeights) {
        return sumMap == nbCoupsTotal
            ? {
                for (final p in pieces)
                  p.id: math.max<int>(0, coupsMap[p.id] ?? 0),
              }
            : _allocator.distributeShotsByWeights(
                pieces: pieces,
                weightsByPieceId: coupsMap,
                totalShots: nbCoupsTotal,
                pdId: 'PD',
              );
      }

      return {for (final a in fixedAllocs) a.piece.id: a.targets.length};
    }

    if (hasPieceWeights) {
      return sumMap == nbCoupsTotal
          ? {
              for (final p in pieces)
                p.id: math.max<int>(0, coupsMap[p.id] ?? 0),
            }
          : _allocator.distributeShotsByWeights(
              pieces: pieces,
              weightsByPieceId: coupsMap,
              totalShots: nbCoupsTotal,
              pdId: 'PD',
            );
    }

    return _allocator.buildShotsQuotasFromAllocs(
      allocs: fixedAllocs,
      totalShots: nbCoupsTotal,
      totalPositions: nbPositions,
      pdId: 'PD',
    );
  }

  Map<String, int> _resolvePreset8Shots({required List<PieceGeom> pieces}) {
    final result = <String, int>{};

    for (int i = 0; i < pieces.length && i < 8; i++) {
      result[pieces[i].id] = 1;
    }

    return result;
  }

  Map<String, int> _resolveForcedSquare3x3({
    required List<PieceGeom> pieces,
    required ZonalMode zonalMode,
  }) {
    if (zonalMode == ZonalMode.otan) {
      return {for (final p in pieces) p.id: 1}
        ..update('PD', (v) => 1, ifAbsent: () => 1);
    }

    return {for (final p in pieces) p.id: 1}
      ..update('PD', (v) => v + 1, ifAbsent: () => 2);
  }

  Map<String, int> _resolveLinear({
    required FirePlanContext ctx,
    required List<PieceGeom> pieces,
    required bool hasPieceWeights,
    required Map<String, int> coupsMap,
    required int nbCoupsTotal,
    required int sumMap,
    required List<int>? doctrinalSequence,
    required Map<String, int> linearDesiredShots,
  }) {
    if (hasPieceWeights) {
      return sumMap == nbCoupsTotal
          ? {
              for (final p in pieces)
                p.id: math.max<int>(0, coupsMap[p.id] ?? 0),
            }
          : _allocator.distributeShotsByWeights(
              pieces: pieces,
              weightsByPieceId: coupsMap,
              totalShots: nbCoupsTotal,
              pdId: 'PD',
            );
    }

    if (doctrinalSequence != null) {
      return _allocator.desiredShotsFromSequence(
        pieces: pieces,
        sequence: doctrinalSequence,
        azimutLineaireMil: ctx.azimutLineaireMil,
      );
    }

    return linearDesiredShots;
  }
}
