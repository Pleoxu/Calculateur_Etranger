import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:calculateur_etranger/domain/fire/allocation/lineaire/linear_closure_allocator.dart';
import 'package:calculateur_etranger/domain/fire/allocation/zonal/zonal_shot_assignment.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/zonal/hardcoded/zonal_hardcoded_doctrine_models.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/zonal/zonal_doctrine_engine.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';
import 'package:calculateur_etranger/domain/fire/target_generation/zonal/zonal_fire_assignment.dart'
    show toUtm;

class FirePlanAllocator {
  const FirePlanAllocator();

  Map<String, int> completeCoupsMapWithDefaults({
    required List<PieceGeom> pieces,
    required Map<String, int> inputMap,
    required int defaultValue,
  }) {
    final out = <String, int>{
      for (final e in inputMap.entries) e.key: math.max<int>(0, e.value),
    };
    for (final p in pieces) {
      out.putIfAbsent(p.id, () => defaultValue);
    }
    return out;
  }

  Map<String, int> buildQuotasPositions({
    required List<PieceGeom> pieces,
    required Map<String, int> coupsParPieceById,
    required int totalPositions,
    required String pdId,
  }) {
    final out = <String, int>{for (final p in pieces) p.id: 0};
    if (totalPositions <= 0) return out;

    if (coupsParPieceById.isEmpty) {
      final base = totalPositions ~/ pieces.length;
      final rem = totalPositions % pieces.length;
      for (final p in pieces) {
        out[p.id] = base;
      }
      out[pdId] = (out[pdId] ?? 0) + rem;
      return out;
    }

    final activeIds = [
      for (final p in pieces)
        if ((coupsParPieceById[p.id] ?? 0) > 0) p.id,
    ];

    if (activeIds.isEmpty) {
      final base = totalPositions ~/ pieces.length;
      final rem = totalPositions % pieces.length;
      for (final p in pieces) {
        out[p.id] = base;
      }
      out[pdId] = (out[pdId] ?? 0) + rem;
      return out;
    }

    var remaining = totalPositions;

    if (totalPositions >= activeIds.length) {
      for (final id in activeIds) {
        out[id] = 1;
      }
      remaining -= activeIds.length;
    } else {
      final sorted = activeIds.toList()
        ..sort(
          (a, b) =>
              (coupsParPieceById[b] ?? 0).compareTo(coupsParPieceById[a] ?? 0),
        );
      for (var i = 0; i < totalPositions; i++) {
        out[sorted[i]] = 1;
      }
      return out;
    }

    var totalCoupsActifs = 0;
    for (final id in activeIds) {
      totalCoupsActifs += math.max<int>(0, coupsParPieceById[id] ?? 0);
    }
    if (totalCoupsActifs <= 0) {
      out[pdId] = (out[pdId] ?? 0) + remaining;
      return out;
    }

    final floors = <String, int>{};
    final fracs = <String, double>{};
    var sumFloors = 0;

    for (final id in activeIds) {
      final w = math.max<int>(0, coupsParPieceById[id] ?? 0);
      final exact = (remaining * w) / totalCoupsActifs;
      final fl = exact.floor();
      floors[id] = fl;
      fracs[id] = exact - fl;
      sumFloors += fl;
    }

    for (final id in activeIds) {
      out[id] = (out[id] ?? 0) + (floors[id] ?? 0);
    }

    var rem2 = remaining - sumFloors;
    if (rem2 > 0) {
      final order = activeIds.toList()
        ..sort((a, b) => (fracs[b] ?? 0).compareTo(fracs[a] ?? 0));
      var i = 0;
      while (rem2 > 0) {
        final id = order[i % order.length];
        out[id] = (out[id] ?? 0) + 1;
        rem2--;
        i++;
      }
    }

    final sum = out.values.fold<int>(0, (a, b) => a + b);
    if (sum < totalPositions) {
      out[pdId] = (out[pdId] ?? 0) + (totalPositions - sum);
    } else if (sum > totalPositions) {
      var extra = sum - totalPositions;
      for (final p in pieces.reversed) {
        if (extra <= 0) break;
        if (p.id == pdId) continue;
        final cur = out[p.id] ?? 0;
        final take = math.min(cur, extra);
        out[p.id] = cur - take;
        extra -= take;
      }
      if (extra > 0) {
        final cur = out[pdId] ?? 0;
        final take = math.min(cur, extra);
        out[pdId] = cur - take;
      }
    }

    return out;
  }

  Map<String, int> distributeShotsByWeights({
    required List<PieceGeom> pieces,
    required Map<String, int> weightsByPieceId,
    required int totalShots,
    required String pdId,
  }) {
    final out = <String, int>{for (final p in pieces) p.id: 0};
    if (totalShots <= 0) return out;

    final active = <String, int>{};
    for (final p in pieces) {
      final w = math.max<int>(0, weightsByPieceId[p.id] ?? 0);
      if (w > 0) active[p.id] = w;
    }

    if (active.isEmpty) {
      out[pdId] = totalShots;
      return out;
    }

    final totalW = active.values.fold<int>(0, (a, b) => a + b);
    if (totalW <= 0) {
      out[pdId] = totalShots;
      return out;
    }

    final floors = <String, int>{};
    final fracs = <String, double>{};
    var sumFloors = 0;

    for (final e in active.entries) {
      final exact = (totalShots * e.value) / totalW;
      final fl = exact.floor();
      floors[e.key] = fl;
      fracs[e.key] = exact - fl;
      sumFloors += fl;
    }

    for (final id in out.keys) {
      out[id] = floors[id] ?? 0;
    }

    var rem = totalShots - sumFloors;
    if (rem > 0) {
      final order = active.keys.toList()
        ..sort((a, b) => (fracs[b] ?? 0).compareTo(fracs[a] ?? 0));
      var i = 0;
      while (rem > 0) {
        final id = order[i % order.length];
        out[id] = (out[id] ?? 0) + 1;
        rem--;
        i++;
      }
    }

    final sum = out.values.fold<int>(0, (a, b) => a + b);
    if (sum != totalShots) {
      out[pdId] = (out[pdId] ?? 0) + (totalShots - sum);
    }

    return out;
  }

  Map<String, int> buildShotsQuotasFromAllocs({
    required List<PieceAllocation> allocs,
    required int totalShots,
    required int totalPositions,
    required String pdId,
  }) {
    final out = <String, int>{for (final a in allocs) a.piece.id: 0};
    if (totalShots <= 0 || totalPositions <= 0) return out;

    final floors = <String, int>{};
    final fracs = <String, double>{};
    var sumFloors = 0;

    for (final a in allocs) {
      final exact = (totalShots * a.targets.length) / totalPositions;
      final fl = exact.floor();
      floors[a.piece.id] = fl;
      fracs[a.piece.id] = exact - fl;
      sumFloors += fl;
    }

    for (final e in floors.entries) {
      out[e.key] = e.value;
    }

    var rem = totalShots - sumFloors;
    if (rem > 0 && out.isNotEmpty) {
      final order = out.keys.toList()
        ..sort((a, b) => (fracs[b] ?? 0).compareTo(fracs[a] ?? 0));
      var i = 0;
      while (rem > 0) {
        final id = order[i % order.length];
        out[id] = (out[id] ?? 0) + 1;
        rem--;
        i++;
      }
    }

    final sum = out.values.fold<int>(0, (a, b) => a + b);
    if (sum < totalShots) {
      out[pdId] = (out[pdId] ?? 0) + (totalShots - sum);
    } else if (sum > totalShots) {
      var extra = sum - totalShots;
      final ids = out.keys.toList()..sort((a, b) => a == pdId ? 1 : -1);
      for (final id in ids) {
        if (extra <= 0) break;
        if (id == pdId) continue;
        final cur = out[id] ?? 0;
        final take = math.min(cur, extra);
        out[id] = cur - take;
        extra -= take;
      }
      if (extra > 0) {
        final cur = out[pdId] ?? 0;
        final take = math.min(cur, extra);
        out[pdId] = cur - take;
      }
    }

    return out;
  }

  Map<String, int> desiredShotsFromSequence({
    required List<PieceGeom> pieces,
    required List<int> sequence,
    required double azimutLineaireMil,
  }) {
    final orderedPieces = _sortPiecesAlongLinearAxis(
      pieces: pieces,
      azimutLineaireMil: azimutLineaireMil,
    );

    final chunkSizes = _linearDoctrineChunkSizes(sequence.length);
    if (orderedPieces.length != 8 || chunkSizes == null) {
      return {for (final p in pieces) p.id: 1};
    }

    return {
      for (var i = 0; i < orderedPieces.length; i++)
        orderedPieces[i].id: chunkSizes[i],
    };
  }

  List<PieceAllocation> allocateLinearDoctrineBySequence({
    required List<PieceGeom> pieces,
    required List<OffsetTarget> targets,
    required double azimutLineaireMil,
  }) {
    final orderedPieces = _sortPiecesAlongLinearAxis(
      pieces: pieces,
      azimutLineaireMil: azimutLineaireMil,
    );

    final chunkSizes = _linearDoctrineChunkSizes(targets.length);
    if (orderedPieces.length != 8 || chunkSizes == null) {
      return LinearClosureAllocator.allocate(
        pieces: pieces,
        prX: 0.0,
        prY: 0.0,
        azimutLineaireMil: azimutLineaireMil,
        offsetsWithCoords: [
          for (final t in targets)
            OffsetWithCoords(offsetM: t.offsetM, x: t.x, y: t.y),
        ],
      );
    }

    final sortedTargets = [...targets]
      ..sort((a, b) => a.offsetM.compareTo(b.offsetM));

    final resultById = <String, List<OffsetTarget>>{
      for (final p in orderedPieces) p.id: <OffsetTarget>[],
    };

    final half = orderedPieces.length ~/ 2;
    var cursor = 0;
    for (var i = 0; i < orderedPieces.length; i++) {
      final size = chunkSizes[i];
      if (cursor + size > sortedTargets.length) {
        return LinearClosureAllocator.allocate(
          pieces: pieces,
          prX: 0.0,
          prY: 0.0,
          azimutLineaireMil: azimutLineaireMil,
          offsetsWithCoords: [
            for (final t in targets)
              OffsetWithCoords(offsetM: t.offsetM, x: t.x, y: t.y),
          ],
        );
      }

      final chunk = sortedTargets.sublist(cursor, cursor + size);
      resultById[orderedPieces[i].id] =
          (i >= half && size > 1) ? chunk.reversed.toList() : chunk;
      cursor += size;
    }

    if (cursor != sortedTargets.length) {
      return LinearClosureAllocator.allocate(
        pieces: pieces,
        prX: 0.0,
        prY: 0.0,
        azimutLineaireMil: azimutLineaireMil,
        offsetsWithCoords: [
          for (final t in targets)
            OffsetWithCoords(offsetM: t.offsetM, x: t.x, y: t.y),
        ],
      );
    }

    return [
      for (final piece in pieces)
        PieceAllocation(
          piece: piece,
          targets: List.unmodifiable(resultById[piece.id] ?? const []),
        ),
    ];
  }

  List<PieceAllocation> allocateLinearDoctrineByQuotas({
    required List<PieceGeom> pieces,
    required List<OffsetTarget> targets,
    required double azimutLineaireMil,
    required Map<String, int> quotasByPieceId,
  }) {
    final orderedPieces = _sortPiecesAlongLinearAxis(
      pieces: pieces,
      azimutLineaireMil: azimutLineaireMil,
    );

    if (orderedPieces.length != 8) {
      return LinearClosureAllocator.allocate(
        pieces: pieces,
        prX: 0.0,
        prY: 0.0,
        azimutLineaireMil: azimutLineaireMil,
        offsetsWithCoords: [
          for (final t in targets)
            OffsetWithCoords(offsetM: t.offsetM, x: t.x, y: t.y),
        ],
        coupsParPieceById: quotasByPieceId,
      );
    }

    final sortedTargets = [...targets]
      ..sort((a, b) => a.offsetM.compareTo(b.offsetM));

    final resultById = <String, List<OffsetTarget>>{
      for (final p in orderedPieces) p.id: <OffsetTarget>[],
    };

    final quotas = <String, int>{
      for (final p in orderedPieces)
        p.id: math.max<int>(0, quotasByPieceId[p.id] ?? 0),
    };

    final totalQuota = quotas.values.fold<int>(0, (a, b) => a + b);
    if (totalQuota != sortedTargets.length) {
      return LinearClosureAllocator.allocate(
        pieces: pieces,
        prX: 0.0,
        prY: 0.0,
        azimutLineaireMil: azimutLineaireMil,
        offsetsWithCoords: [
          for (final t in targets)
            OffsetWithCoords(offsetM: t.offsetM, x: t.x, y: t.y),
        ],
        coupsParPieceById: quotasByPieceId,
      );
    }

    final half = orderedPieces.length ~/ 2;
    var cursor = 0;
    for (var i = 0; i < orderedPieces.length; i++) {
      final piece = orderedPieces[i];
      final size = quotas[piece.id] ?? 0;
      if (cursor + size > sortedTargets.length) {
        return LinearClosureAllocator.allocate(
          pieces: pieces,
          prX: 0.0,
          prY: 0.0,
          azimutLineaireMil: azimutLineaireMil,
          offsetsWithCoords: [
            for (final t in targets)
              OffsetWithCoords(offsetM: t.offsetM, x: t.x, y: t.y),
          ],
          coupsParPieceById: quotasByPieceId,
        );
      }

      final chunk = sortedTargets.sublist(cursor, cursor + size);
      resultById[piece.id] =
          (i >= half && size > 1) ? chunk.reversed.toList() : chunk;
      cursor += size;
    }

    if (cursor != sortedTargets.length) {
      return LinearClosureAllocator.allocate(
        pieces: pieces,
        prX: 0.0,
        prY: 0.0,
        azimutLineaireMil: azimutLineaireMil,
        offsetsWithCoords: [
          for (final t in targets)
            OffsetWithCoords(offsetM: t.offsetM, x: t.x, y: t.y),
        ],
        coupsParPieceById: quotasByPieceId,
      );
    }

    return [
      for (final piece in pieces)
        PieceAllocation(
          piece: piece,
          targets: List.unmodifiable(resultById[piece.id] ?? const []),
        ),
    ];
  }

  /// Affecte aux pièces une doctrine zonale déjà calculée.
  ///
  /// Cette méthode ne recalcule jamais la géométrie ni la doctrine. La liste
  /// [assignments] constitue l'unique source de vérité pour les positions,
  /// l'ordre, les salves et les pièces.
  List<PieceAllocation> allocateZonalDoctrineFromAssignments({
    required List<PieceGeom> pieces,
    required List<ZonalShotAssignment> assignments,
    required double prX,
    required double prY,
    required double azimutLargeurMil,
    required double azimutProfondeurMil,
    required int pointIdx,
    required double largeurM,
    required double profondeurM,
  }) {
    final pieceById = <String, PieceGeom>{
      for (final piece in pieces) piece.id: piece,
    };

    final targetsByPiece = <String, List<OffsetTarget>>{
      for (final piece in pieces) piece.id: <OffsetTarget>[],
    };

    for (var i = 0; i < assignments.length; i++) {
      final assignment = assignments[i];
      final piece = pieceById[assignment.pieceId];

      if (piece == null) {
        throw StateError(
          'Affectation zonale invalide : pièce inconnue '
          '"${assignment.pieceId}".',
        );
      }

      final target = offsetTargetFromDoctrineAssignmentByPointIdx(
        index: i,
        prX: prX,
        prY: prY,
        azimutLargeurMil: azimutLargeurMil,
        azimutProfondeurMil: azimutProfondeurMil,
        pointIdx: pointIdx,
        largeurM: largeurM,
        profondeurM: profondeurM,
        assignment: assignment,
      );

      targetsByPiece[piece.id]!.add(target);
    }

    final allocatedCount = targetsByPiece.values.fold<int>(
      0,
      (sum, targets) => sum + targets.length,
    );

    if (allocatedCount != assignments.length) {
      throw StateError(
        'Allocation zonale incohérente : '
        '${assignments.length} affectations reçues, '
        '$allocatedCount cibles allouées.',
      );
    }

    if (kDebugMode) {
      debugPrint(
        '[ZONAL-ALLOC] assignments=${assignments.length} '
        'allocated=$allocatedCount pieces=${pieces.length}',
      );
    }

    return [
      for (final piece in pieces)
        PieceAllocation(
          piece: piece,
          targets: List<OffsetTarget>.unmodifiable(
            targetsByPiece[piece.id] ?? const <OffsetTarget>[],
          ),
        ),
    ];
  }

  /// Compatibilité temporaire avec les anciens appelants.
  ///
  /// À supprimer dès que les use cases transmettent directement les
  /// [ZonalShotAssignment] déjà produits par le builder doctrinal.
  @Deprecated(
    'Utiliser allocateZonalDoctrineFromAssignments pour éviter '
    'un second calcul de doctrine.',
  )
  List<PieceAllocation> allocateZonalDoctrine({
    required List<PieceGeom> pieces,
    required double prX,
    required double prY,
    required double azimutLargeurMil,
    required double azimutProfondeurMil,
    required double azimutTirMil,
    required int pointIdx,
    required double largeurM,
    required double profondeurM,
    required int coups,
    required double debordementRatio,
    required double recouvrementMini,
    required double diametreEfficaceM,
    required ZonalDoctrineMode mode,
  }) {
    final assignments = doctrinalAssignmentsForZonal(
      pieces: pieces,
      prX: prX,
      prY: prY,
      azimutLargeurMil: azimutLargeurMil,
      azimutTirMil: azimutTirMil,
      largeurM: largeurM,
      profondeurM: profondeurM,
      coups: coups,
      debordementRatio: debordementRatio,
      recouvrementMini: recouvrementMini,
      diametreEfficaceM: diametreEfficaceM,
      mode: mode,
    );

    return allocateZonalDoctrineFromAssignments(
      pieces: pieces,
      assignments: assignments,
      prX: prX,
      prY: prY,
      azimutLargeurMil: azimutLargeurMil,
      azimutProfondeurMil: azimutProfondeurMil,
      pointIdx: pointIdx,
      largeurM: largeurM,
      profondeurM: profondeurM,
    );
  }

  List<ZonalShotAssignment> doctrinalAssignmentsForZonal({
    required List<PieceGeom> pieces,
    required double prX,
    required double prY,
    required double azimutLargeurMil,
    required double azimutTirMil,
    required double largeurM,
    required double profondeurM,
    required int coups,
    required double debordementRatio,
    required double recouvrementMini,
    required double diametreEfficaceM,
    required ZonalDoctrineMode mode,
  }) {
    return _doctrinalAssignments(
      pieces: pieces,
      largeurM: largeurM,
      profondeurM: profondeurM,
      coups: coups,
      prX: prX,
      prY: prY,
      azimutLargeurMil: azimutLargeurMil,
      azimutTirMil: azimutTirMil,
      debordementRatio: debordementRatio,
      recouvrementMini: recouvrementMini,
      diametreEfficaceM: diametreEfficaceM,
      mode: mode,
    );
  }

  List<ZonalShotAssignment> _doctrinalAssignments({
    required List<PieceGeom> pieces,
    required double largeurM,
    required double profondeurM,
    required int coups,
    required double prX,
    required double prY,
    required double azimutLargeurMil,
    required double azimutTirMil,
    required double debordementRatio,
    required double recouvrementMini,
    required double diametreEfficaceM,
    required ZonalDoctrineMode mode,
  }) {
    final assignments = ZonalDoctrineEngine.computeAssignments(
      largeur: largeurM,
      profondeur: profondeurM,
      pieces: pieces,
      coups: coups,
      prX: prX,
      prY: prY,
      azimutLargeurMil: azimutLargeurMil,
      azimutTirMil: azimutTirMil,
      debordementRatio: debordementRatio,
      recouvrementMini: recouvrementMini,
      diametreEfficaceM: diametreEfficaceM,
      mode: mode,
    )..sort((a, b) {
        final bySalve = a.salve.compareTo(b.salve);
        if (bySalve != 0) return bySalve;
        return a.ordre.compareTo(b.ordre);
      });

    final normalized = _forceSingleBatterySalve8(
      assignments: assignments,
      pieces: pieces,
      coups: coups,
    );

    debugPrint('[ZONAL] doctrine assignments RAW count=${assignments.length}');
    for (final a in assignments) {
      debugPrint(
        '[ZONAL-ASSIGN-RAW] '
        'piece=${a.pieceId} '
        'salve=${a.salve} '
        'ordre=${a.ordre} '
        'x=${a.position.dx.toStringAsFixed(1)} '
        'y=${a.position.dy.toStringAsFixed(1)}',
      );
    }

    debugPrint(
      '[ZONAL] doctrine assignments NORMALIZED count=${normalized.length}',
    );
    for (final a in normalized) {
      debugPrint(
        '[ZONAL-ASSIGN-NORM] '
        'piece=${a.pieceId} '
        'salve=${a.salve} '
        'ordre=${a.ordre} '
        'x=${a.position.dx.toStringAsFixed(1)} '
        'y=${a.position.dy.toStringAsFixed(1)}',
      );
    }

    return normalized;
  }

  List<ZonalShotAssignment> _forceSingleBatterySalve8({
    required List<ZonalShotAssignment> assignments,
    required List<PieceGeom> pieces,
    required int coups,
  }) {
    if (coups != 8 || assignments.length != 8) return assignments;

    const roles = <String>[
      'PD',
      'PS1',
      'PS2',
      'PS3',
      'PS4',
      'PS5',
      'PS6',
      'PS7',
    ];

    final pieceIdByRole = <String, String>{
      for (final p in pieces) p.id.trim().toUpperCase(): p.id,
    };

    if (!roles.every(pieceIdByRole.containsKey)) return assignments;

    final present =
        assignments.map((a) => a.pieceId.trim().toUpperCase()).toList();
    final missing = roles.where((r) => !present.contains(r)).toList();

    final seen = <String>{};
    var missingIdx = 0;

    return [
      for (var i = 0; i < assignments.length; i++)
        (() {
          final a = assignments[i];
          final currentRole = a.pieceId.trim().toUpperCase();

          var pieceId = a.pieceId;
          if (!roles.contains(currentRole) || seen.contains(currentRole)) {
            if (missingIdx < missing.length) {
              pieceId = pieceIdByRole[missing[missingIdx]]!;
              missingIdx++;
            }
          }

          seen.add(pieceId.trim().toUpperCase());

          return ZonalShotAssignment(
            pieceId: pieceId,
            salve: 1,
            ordre: i + 1,
            position: a.position,
            point: a.point,
          );
        })(),
    ];
  }

  List<PieceAllocation> allocateZonal({
    required List<PieceGeom> pieces,
    required List<OffsetWithCoords> offsetsWithCoords,
    required Map<String, int> quotasPositionsByPiece,
    required double prX,
    required double prY,
    required double azimutLargeurMil,
    required double azimutProfondeurMil,
    required double azimutTirMil,
    required int nL,
    required int nP,
    required int pointIdx,
  }) {
    if (pieces.isEmpty || offsetsWithCoords.isEmpty) return const [];

    final nCols = nL <= 0 ? 1 : nL;
    final nRows = nP <= 0 ? 1 : nP;
    final uLargeur = _unitFromAzMil(azimutLargeurMil);

    double latOfPiece(PieceGeom p) =>
        (p.x - prX) * uLargeur.ux + (p.y - prY) * uLargeur.uy;

    double latOfTarget(OffsetWithCoords t) =>
        (t.x - prX) * uLargeur.ux + (t.y - prY) * uLargeur.uy;

    final orderedPieces = [...pieces]
      ..sort((a, b) => latOfPiece(a).compareTo(latOfPiece(b)));

    final n = orderedPieces.length;

    final annotated = <({OffsetWithCoords target, int col, int row, int idx})>[
      for (var k = 0; k < offsetsWithCoords.length; k++)
        (target: offsetsWithCoords[k], col: k % nCols, row: k ~/ nCols, idx: k),
    ];

    final centerCol = (nCols - 1) ~/ 2;
    final doctrineTargets = List<List<OffsetTarget>>.generate(n, (_) => []);
    final salveOrders = List<List<int>>.generate(n, (_) => []);
    final reserved = <int>{};

    void addTarget(
      int pieceIdx,
      ({OffsetWithCoords target, int col, int row, int idx}) ann,
      int salveOrd,
    ) {
      if (pieceIdx < 0 || pieceIdx >= n) return;
      if (reserved.contains(ann.idx)) return;

      doctrineTargets[pieceIdx].add(
        OffsetTarget(
          index: ann.idx,
          offsetM: ann.target.offsetM,
          x: ann.target.x,
          y: ann.target.y,
        ),
      );
      salveOrders[pieceIdx].add(salveOrd);
      reserved.add(ann.idx);
    }

    int pieceIdx(PieceGeom p) => orderedPieces.indexOf(p);

    ({OffsetWithCoords target, int col, int row, int idx})? targetAt(
      int row,
      int col,
    ) {
      try {
        return annotated.firstWhere((a) => a.row == row && a.col == col);
      } catch (_) {
        return null;
      }
    }

    final useRowMode = nRows > 4;

    if (useRowMode) {
      final half = n ~/ 2;

      final topGroupStart = (half - nCols).clamp(0, n);
      final topGroupEnd = half.clamp(0, n);
      final topGroup = orderedPieces.sublist(topGroupStart, topGroupEnd);

      final bottomGroupStart = half.clamp(0, n);
      final bottomGroupEnd = (half + nCols).clamp(0, n);
      final bottomGroup = orderedPieces.sublist(
        bottomGroupStart,
        bottomGroupEnd,
      );

      final leftover = <PieceGeom>[
        ...orderedPieces.sublist(0, topGroupStart),
        ...orderedPieces.sublist(bottomGroupEnd, n),
      ];

      final leftoverLeft = leftover.where((p) => latOfPiece(p) < 0).toList();
      final leftoverRight = leftover.where((p) => latOfPiece(p) >= 0).toList();

      for (var i = 0; i < topGroup.length && i < nCols; i++) {
        final t = targetAt(0, i);
        if (t != null) addTarget(pieceIdx(topGroup[i]), t, 0);
      }

      for (var i = 0; i < bottomGroup.length && i < nCols; i++) {
        final t = targetAt(nRows - 1, i);
        if (t != null) addTarget(pieceIdx(bottomGroup[i]), t, 0);
      }

      if (leftoverLeft.isNotEmpty && nRows >= 2) {
        final t = targetAt(1, 0);
        if (t != null) addTarget(pieceIdx(leftoverLeft.first), t, 0);
      }

      if (leftoverRight.isNotEmpty && nRows >= 2) {
        final t = targetAt(nRows - 2, nCols - 1);
        if (t != null) addTarget(pieceIdx(leftoverRight.first), t, 0);
      }

      if (nRows >= 4) {
        for (var i = 0; i < topGroup.length - 1 && (i + 1) < nCols; i++) {
          final t = targetAt(1, i + 1);
          if (t != null) addTarget(pieceIdx(topGroup[i]), t, 1);
        }

        for (var i = 1; i < bottomGroup.length && (i - 1) < nCols; i++) {
          final t = targetAt(nRows - 2, i - 1);
          if (t != null) addTarget(pieceIdx(bottomGroup[i]), t, 1);
        }

        if (leftoverLeft.isNotEmpty && nRows >= 3) {
          final t = targetAt(2, 0);
          if (t != null) addTarget(pieceIdx(leftoverLeft.first), t, 1);
        }

        if (topGroup.isNotEmpty && nRows >= 3) {
          final t = targetAt(2, nCols - 1);
          if (t != null) addTarget(pieceIdx(topGroup.last), t, 1);
        }

        if (bottomGroup.isNotEmpty && nRows >= 3) {
          final t = targetAt(nRows - 3, 0);
          if (t != null) addTarget(pieceIdx(bottomGroup.first), t, 1);
        }

        if (leftoverRight.isNotEmpty && nRows >= 3) {
          final t = targetAt(nRows - 3, nCols - 1);
          if (t != null) addTarget(pieceIdx(leftoverRight.first), t, 1);
        }
      }

      if (nRows.isOdd) {
        final midRow = nRows ~/ 2;

        final pdIndex = orderedPieces.indexWhere((p) => p.id == 'PD');
        final pdPiece = pdIndex >= 0 ? orderedPieces[pdIndex] : null;
        final leftOfPd = pdIndex > 0 ? orderedPieces[pdIndex - 1] : null;
        final rightOfPd = (pdIndex >= 0 && pdIndex < orderedPieces.length - 1)
            ? orderedPieces[pdIndex + 1]
            : null;

        void addMid(int col, PieceGeom? piece, int salveOrd) {
          if (piece == null) return;
          final t = targetAt(midRow, col);
          if (t != null) addTarget(pieceIdx(piece), t, salveOrd);
        }

        addMid(0, leftOfPd, 2);
        addMid(centerCol, pdPiece, 2);
        addMid(nCols - 1, rightOfPd, 2);
      }
    } else {
      final useLignesMode = (n ~/ 2) == nCols && (n ~/ 2) != nRows;

      if (useLignesMode) {
        final nPairs = nRows ~/ 2;

        for (var salveOrd = 0; salveOrd < nPairs; salveOrd++) {
          final rowTop = salveOrd;
          final rowBottom = nRows - 1 - salveOrd;

          for (var c = 0; c < nCols; c++) {
            final pieceI = c;
            if (pieceI >= n) break;

            final t = targetAt(rowTop, c);
            if (t != null) addTarget(pieceI, t, salveOrd);
          }

          for (var c = 0; c < nCols; c++) {
            final pieceI = nCols + c;
            if (pieceI >= n) break;

            final mirroredCol = nCols - 1 - c;
            final t = targetAt(rowBottom, mirroredCol);
            if (t != null) addTarget(pieceI, t, salveOrd);
          }
        }
      } else {
        final centralAnnotated = annotated
            .where((a) => a.col == centerCol)
            .toList()
          ..sort(
            (a, b) => latOfTarget(a.target).compareTo(latOfTarget(b.target)),
          );

        final latCentre =
            orderedPieces.map(latOfPiece).fold(0.0, (a, b) => a + b) / n;

        final leftGroup = orderedPieces.sublist(0, math.min(nRows, n));
        final leftSorted = leftGroup.toList()
          ..sort((a, b) {
            final da = (latOfPiece(a) - latCentre).abs();
            final db = (latOfPiece(b) - latCentre).abs();
            return da.compareTo(db);
          });

        final rightGroup = orderedPieces.sublist(math.max(0, n - nRows));
        final rightSorted = rightGroup.toList()
          ..sort((a, b) {
            final da = (latOfPiece(a) - latCentre).abs();
            final db = (latOfPiece(b) - latCentre).abs();
            return da.compareTo(db);
          });

        for (var r = 0; r < leftSorted.length; r++) {
          final t = targetAt(r, 0);
          if (t != null) {
            final pieceI = orderedPieces.indexOf(leftSorted[r]);
            addTarget(pieceI, t, 0);
          }
        }

        for (var r = 0; r < rightSorted.length; r++) {
          final t = targetAt(r, nCols - 1);
          if (t != null) {
            final pieceI = orderedPieces.indexOf(rightSorted[r]);
            addTarget(pieceI, t, 0);
          }
        }

        final k = centralAnnotated.length;
        if (k > 0) {
          final pdPiece = orderedPieces.firstWhere(
            (p) => p.id == 'PD',
            orElse: () => orderedPieces[n ~/ 2],
          );

          final byDistToPD = List<int>.generate(n, (i) => i)
            ..sort((ia, ib) {
              final pa = orderedPieces[ia];
              final pb = orderedPieces[ib];

              final da = (pa.x - pdPiece.x) * (pa.x - pdPiece.x) +
                  (pa.y - pdPiece.y) * (pa.y - pdPiece.y);
              final db = (pb.x - pdPiece.x) * (pb.x - pdPiece.x) +
                  (pb.y - pdPiece.y) * (pb.y - pdPiece.y);

              return da.compareTo(db);
            });

          final selectedIdx = byDistToPD.take(k).toList()
            ..sort(
              (ia, ib) => latOfPiece(
                orderedPieces[ia],
              ).compareTo(latOfPiece(orderedPieces[ib])),
            );

          for (var j = 0; j < selectedIdx.length && j < k; j++) {
            final i = selectedIdx[j];
            addTarget(i, centralAnnotated[j], 1);
          }
        }
      }
    }

    for (var i = 0; i < n; i++) {
      if (doctrineTargets[i].length > 1) {
        final pairs = List.generate(
          doctrineTargets[i].length,
          (j) => (t: doctrineTargets[i][j], s: salveOrders[i][j]),
        )..sort((a, b) => a.s.compareTo(b.s));

        doctrineTargets[i] = pairs.map((p) => p.t).toList();
        salveOrders[i] = pairs.map((p) => p.s).toList();
      }
    }

    if (reserved.length < annotated.length) {
      final remaining =
          annotated.where((a) => !reserved.contains(a.idx)).toList();

      final counts = <int, int>{
        for (var i = 0; i < n; i++) i: doctrineTargets[i].length,
      };

      int quotaFor(int pieceI) => math.max<int>(
            0,
            quotasPositionsByPiece[orderedPieces[pieceI].id] ?? 0,
          );

      for (final ann in remaining) {
        final candidates = List<int>.generate(n, (i) => i)
          ..sort((ia, ib) {
            final qa = quotaFor(ia);
            final qb = quotaFor(ib);

            final ca = counts[ia] ?? 0;
            final cb = counts[ib] ?? 0;

            final needA = qa - ca;
            final needB = qb - cb;
            if (needA != needB) return needB.compareTo(needA);

            final da =
                (latOfPiece(orderedPieces[ia]) - latOfTarget(ann.target)).abs();
            final db =
                (latOfPiece(orderedPieces[ib]) - latOfTarget(ann.target)).abs();
            if (da != db) return da.compareTo(db);

            return ia.compareTo(ib);
          });

        final chosen = candidates.first;
        addTarget(chosen, ann, 99);
        counts[chosen] = (counts[chosen] ?? 0) + 1;
      }
    }

    return [
      for (var i = 0; i < n; i++)
        PieceAllocation(
          piece: orderedPieces[i],
          targets: List<OffsetTarget>.from(doctrineTargets[i]),
        ),
    ];
  }

  List<int>? _linearDoctrineChunkSizes(int nbCoups) {
    switch (nbCoups) {
      case 11:
        return const [1, 1, 2, 2, 2, 1, 1, 1];
      case 12:
        return const [1, 1, 2, 2, 2, 2, 1, 1];
      case 13:
        return const [1, 2, 2, 2, 2, 2, 1, 1];
      case 14:
        return const [1, 2, 2, 2, 2, 2, 2, 1];
      case 15:
        return const [1, 2, 2, 2, 2, 2, 2, 2];
      case 16:
        return const [2, 2, 2, 2, 2, 2, 2, 2];
      default:
        return null;
    }
  }

  List<PieceGeom> _sortPiecesAlongLinearAxis({
    required List<PieceGeom> pieces,
    required double azimutLineaireMil,
  }) {
    final pdList = pieces.where((p) => p.isPd).toList();
    final ref = pdList.isNotEmpty ? pdList.first : pieces[pieces.length ~/ 2];

    final azRad = azimutLineaireMil * 2.0 * math.pi / 6400.0;
    final ux = math.sin(azRad);
    final uy = math.cos(azRad);

    final annotated = pieces.map((piece) {
      final dx = piece.x - ref.x;
      final dy = piece.y - ref.y;
      final along = dx * ux + dy * uy;
      return (piece: piece, along: along);
    }).toList();

    annotated.sort((a, b) {
      final cmp = a.along.compareTo(b.along);
      if (cmp != 0) return cmp;
      return a.piece.id.compareTo(b.piece.id);
    });

    return annotated.map((e) => e.piece).toList(growable: false);
  }

  OffsetTarget offsetTargetFromDoctrineAssignmentByPointIdx({
    required int index,
    required double prX,
    required double prY,
    required double azimutLargeurMil,
    required double azimutProfondeurMil,
    required int pointIdx,
    required double largeurM,
    required double profondeurM,
    required ZonalShotAssignment assignment,
  }) {
    final rebase = _zonalAnchorShiftFromPointIdx(
      pointIdx: pointIdx,
      largeurM: largeurM,
      profondeurM: profondeurM,
    );

    final local = assignment.position + rebase;

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

  Offset _zonalAnchorShiftFromPointIdx({
    required int pointIdx,
    required double largeurM,
    required double profondeurM,
  }) {
    switch (pointIdx) {
      case 0:
        return Offset(largeurM / 2.0, profondeurM / 2.0);
      case 1:
        return Offset(0.0, profondeurM / 2.0);
      case 2:
      default:
        return Offset.zero;
    }
  }
}

class _Axis2 {
  final double ux;
  final double uy;

  const _Axis2(this.ux, this.uy);
}

_Axis2 _unitFromAzMil(double azMil) {
  final azRad = azMil * 2.0 * math.pi / 6400.0;
  return _Axis2(math.sin(azRad), math.cos(azRad));
}
