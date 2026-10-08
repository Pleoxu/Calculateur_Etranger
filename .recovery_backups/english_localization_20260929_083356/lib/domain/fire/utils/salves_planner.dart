// lib/domain/fire/utils/salves_planner.dart

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart'
    show OffsetTarget, PieceGeom, PieceAllocation;

/// 0=auto / 1=droite / 2=gauche
enum SalveSidePreference { auto, droite, gauche }

class PlannedShot {
  final String pieceId;
  final bool isPd;
  final OffsetTarget target;

  const PlannedShot({
    required this.pieceId,
    required this.isPd,
    required this.target,
  });
}

class SalvePlan {
  final int index;
  final List<PlannedShot> shots;

  const SalvePlan({required this.index, required this.shots});

  int get nbCoups => shots.length;
}

class SalvesPlan {
  final List<SalvePlan> salves;

  const SalvesPlan({required this.salves});

  int get nbSalves => salves.length;

  int get nbCoupsTotal => salves.fold<int>(0, (a, s) => a + s.nbCoups);

  int get nbSalvesCompletes {
    if (salves.isEmpty) return 0;
    final maxLen = salves.map((s) => s.nbCoups).fold<int>(0, math.max);
    return salves.where((s) => s.nbCoups == maxLen).length;
  }

  int get coupsDerniereSalve => salves.isEmpty ? 0 : salves.last.nbCoups;
}

class SalvesPlanner {
  const SalvesPlanner._();

  static SalvesPlan buildPlan({
    required List<PieceGeom> pieces,
    required List<PieceAllocation> allocations,
    required Map<String, int> shotsByPiece,
    required double prX,
    required double prY,
    required double azimutRefMil,
    int preferenceIdx = 0,
    bool lastSalveAroundPd = true,
  }) {
    if (pieces.isEmpty || allocations.isEmpty) {
      return const SalvesPlan(salves: []);
    }

    final pref = SalveSidePreference
        .values[preferenceIdx.clamp(0, SalveSidePreference.values.length - 1)];

    final allocById = {for (final a in allocations) a.piece.id: a};

    debugPrint(
      '[SALVES-V24] shotsByPiece=${shotsByPiece.entries.map((e) => '${e.key}:${e.value}').join(', ')}',
    );
    debugPrint(
      '[SALVES-V24] allocations=${allocations.map((a) => '${a.piece.id}:${a.targets.length}targets').join(', ')}',
    );

    final doctrinal400x500Plan = _tryBuildDoctrinal400x500Plan(
      pieces: pieces,
      allocations: allocations,
    );
    if (doctrinal400x500Plan != null) {
      debugPrint(
        '[SALVES-V24] doctrinal 400x500 plan used: '
        'salves=${doctrinal400x500Plan.salves.map((s) => '${s.index}:${s.nbCoups}').join(', ')}',
      );
      return doctrinal400x500Plan;
    }

    final doctrinal300x500Plan = _tryBuildDoctrinal300x500Plan(
      pieces: pieces,
      allocations: allocations,
    );
    if (doctrinal300x500Plan != null) {
      debugPrint(
        '[SALVES-V24] doctrinal 300x500 plan used: '
        'salves=${doctrinal300x500Plan.salves.map((s) => '${s.index}:${s.nbCoups}').join(', ')}',
      );
      return doctrinal300x500Plan;
    }

    final doctrinal300x400Plan = _tryBuildDoctrinal300x400Plan(
      pieces: pieces,
      allocations: allocations,
    );
    if (doctrinal300x400Plan != null) {
      debugPrint(
        '[SALVES-V24] doctrinal 300x400 plan used: '
        'salves=${doctrinal300x400Plan.salves.map((s) => '${s.index}:${s.nbCoups}').join(', ')}',
      );
      return doctrinal300x400Plan;
    }

    final pd = pieces.firstWhere((p) => p.isPd, orElse: () => pieces.first);

    final azRad = azimutRefMil * 2.0 * math.pi / 6400.0;
    final ux = math.sin(azRad);
    final uy = math.cos(azRad);

    double latFromPr(PieceGeom p) {
      final dx = p.x - prX;
      final dy = p.y - prY;
      return dx * ux + dy * uy;
    }

    double distToPd(PieceGeom p) {
      final dx = p.x - pd.x;
      final dy = p.y - pd.y;
      return math.sqrt(dx * dx + dy * dy);
    }

    final activePieces = <PieceGeom>[];
    for (final p in pieces) {
      final q = math.max(0, shotsByPiece[p.id] ?? 0);
      final allocation = allocById[p.id];

      if (q > 0 && allocation != null && allocation.targets.isNotEmpty) {
        activePieces.add(p);
      }
    }

    if (activePieces.isEmpty) {
      return const SalvesPlan(salves: []);
    }

    final fullOrder = [...activePieces]..sort((a, b) {
        final da = _doctrineRankSalves(a.id);
        final db = _doctrineRankSalves(b.id);
        if (da != db) return da.compareTo(db);

        final la = latFromPr(a);
        final lb = latFromPr(b);
        final byLat = la.compareTo(lb);
        if (byLat != 0) return byLat;

        if (a.isPd != b.isPd) return a.isPd ? -1 : 1;

        return a.id.compareTo(b.id);
      });

    final targetCursor = <String, int>{for (final p in activePieces) p.id: 0};

    // Pour les zonaux doctrinaux, allocations.targets est la source de vérité.
    // shotsByPiece est seulement une intention globale; l'utiliser comme plafond
    // par pièce tronquait le 400×500 OTAN : 26 offsets générés, mais seulement
    // 23 tirs consommés lorsque la répartition par pièce différait.
    final remaining = <String, int>{
      for (final p in activePieces)
        p.id: math.max(0, allocById[p.id]?.targets.length ?? 0),
    };

    int totalRemaining() => remaining.values.fold<int>(0, (a, b) => a + b);

    final salves = <SalvePlan>[];
    var salveIdx = 1;

    while (totalRemaining() > 0) {
      final available =
          fullOrder.where((p) => (remaining[p.id] ?? 0) > 0).toList();

      if (available.isEmpty) break;

      final maxThis = available.length;
      final total = totalRemaining();
      final isLastPartial = total < maxThis;

      final chosenPieces = isLastPartial
          ? _selectPiecesForPartialSalve(
              candidates: available,
              fullOrder: fullOrder,
              pd: pd,
              latFromPr: latFromPr,
              distToPd: distToPd,
              pref: pref,
              take: total,
              aroundPd: lastSalveAroundPd,
            )
          : available;

      final shots = <PlannedShot>[];

      for (final p in chosenPieces) {
        final r = remaining[p.id] ?? 0;
        if (r <= 0) continue;

        final allocation = allocById[p.id];
        final cursor = targetCursor[p.id] ?? 0;

        if (allocation == null || cursor >= allocation.targets.length) {
          continue;
        }

        shots.add(
          PlannedShot(
            pieceId: p.id,
            isPd: p.isPd,
            target: allocation.targets[cursor],
          ),
        );

        targetCursor[p.id] = cursor + 1;
        remaining[p.id] = r - 1;
      }

      if (shots.isEmpty) break;

      salves.add(SalvePlan(index: salveIdx, shots: shots));
      salveIdx++;
    }

    _ensureLastSingleSalveUsesCenterTarget(
      salves: salves,
      prX: prX,
      prY: prY,
      enabled: lastSalveAroundPd,
    );

    return SalvesPlan(salves: salves);
  }

  static SalvesPlan? _tryBuildDoctrinal400x500Plan({
    required List<PieceGeom> pieces,
    required List<PieceAllocation> allocations,
  }) {
    final shots = <PlannedShot>[];

    for (final allocation in allocations) {
      for (final target in allocation.targets) {
        shots.add(
          PlannedShot(
            pieceId: allocation.piece.id,
            isPd: allocation.piece.isPd,
            target: target,
          ),
        );
      }
    }

    // 400×500 : OTAN = 26 coups (8/8/8/2), forcé = 30 coups (8/8/8/6).
    if (shots.length != 26 && shots.length != 30) return null;

    final indices = shots.map((s) => s.target.index).toList()..sort();
    for (var i = 0; i < shots.length; i++) {
      if (indices[i] != i) return null;
    }

    final byIndex = <int, PlannedShot>{
      for (final shot in shots) shot.target.index: shot,
    };

    List<PlannedShot> range(int start, int endInclusive) {
      return [
        for (var i = start; i <= endInclusive; i++)
          if (byIndex[i] != null) byIndex[i]!,
      ];
    }

    List<PlannedShot> salveRange({
      required int start,
      required int endInclusive,
      required int salveIndex,
    }) {
      return _reassignUniquePiecesForSalve(
        pieces: pieces,
        salveIndex: salveIndex,
        shots: range(start, endInclusive),
      );
    }

    if (shots.length == 26) {
      return SalvesPlan(
        salves: [
          SalvePlan(
            index: 1,
            shots: salveRange(start: 0, endInclusive: 7, salveIndex: 1),
          ),
          SalvePlan(
            index: 2,
            shots: salveRange(start: 8, endInclusive: 15, salveIndex: 2),
          ),
          SalvePlan(
            index: 3,
            shots: salveRange(start: 16, endInclusive: 23, salveIndex: 3),
          ),
          SalvePlan(
            index: 4,
            shots: salveRange(start: 24, endInclusive: 25, salveIndex: 4),
          ),
        ],
      );
    }

    return SalvesPlan(
      salves: [
        SalvePlan(
          index: 1,
          shots: salveRange(start: 0, endInclusive: 7, salveIndex: 1),
        ),
        SalvePlan(
          index: 2,
          shots: salveRange(start: 8, endInclusive: 15, salveIndex: 2),
        ),
        SalvePlan(
          index: 3,
          shots: salveRange(start: 16, endInclusive: 23, salveIndex: 3),
        ),
        SalvePlan(
          index: 4,
          shots: salveRange(start: 24, endInclusive: 29, salveIndex: 4),
        ),
      ],
    );
  }

  static SalvesPlan? _tryBuildDoctrinal300x500Plan({
    required List<PieceGeom> pieces,
    required List<PieceAllocation> allocations,
  }) {
    final shots = <PlannedShot>[];

    for (final allocation in allocations) {
      for (final target in allocation.targets) {
        shots.add(
          PlannedShot(
            pieceId: allocation.piece.id,
            isPd: allocation.piece.isPd,
            target: target,
          ),
        );
      }
    }

    if (shots.length != 22 && shots.length != 24) return null;

    final indices = shots.map((s) => s.target.index).toList()..sort();
    for (var i = 0; i < shots.length; i++) {
      if (indices[i] != i) return null;
    }

    final byIndex = <int, PlannedShot>{
      for (final shot in shots) shot.target.index: shot,
    };

    List<PlannedShot> range(int start, int endInclusive) {
      return [
        for (var i = start; i <= endInclusive; i++)
          if (byIndex[i] != null) byIndex[i]!,
      ];
    }

    List<PlannedShot> salveRange({
      required int start,
      required int endInclusive,
      required int salveIndex,
    }) {
      return _reassignUniquePiecesForSalve(
        pieces: pieces,
        salveIndex: salveIndex,
        shots: range(start, endInclusive),
      );
    }

    // Les indices sont produits par ZonalDoctrineEngine dans l'ordre
    // salve/ordre doctrinal 300×500.
    // - OTAN : 22 coups = 8 + 8 + 6.
    // - Forcé : 24 coups = 8 + 8 + 8.
    // On préserve les offsets et l'ordre doctrinal, mais on réattribue les
    // pièces salve par salve pour garantir : 1 pièce = 1 coup max par salve.
    if (shots.length == 22) {
      return SalvesPlan(
        salves: [
          SalvePlan(
            index: 1,
            shots: salveRange(start: 0, endInclusive: 7, salveIndex: 1),
          ),
          SalvePlan(
            index: 2,
            shots: salveRange(start: 8, endInclusive: 15, salveIndex: 2),
          ),
          SalvePlan(
            index: 3,
            shots: salveRange(start: 16, endInclusive: 21, salveIndex: 3),
          ),
        ],
      );
    }

    return SalvesPlan(
      salves: [
        SalvePlan(
          index: 1,
          shots: salveRange(start: 0, endInclusive: 7, salveIndex: 1),
        ),
        SalvePlan(
          index: 2,
          shots: salveRange(start: 8, endInclusive: 15, salveIndex: 2),
        ),
        SalvePlan(
          index: 3,
          shots: salveRange(start: 16, endInclusive: 23, salveIndex: 3),
        ),
      ],
    );
  }

  static SalvesPlan? _tryBuildDoctrinal300x400Plan({
    required List<PieceGeom> pieces,
    required List<PieceAllocation> allocations,
  }) {
    final shots = <PlannedShot>[];

    for (final allocation in allocations) {
      for (final target in allocation.targets) {
        shots.add(
          PlannedShot(
            pieceId: allocation.piece.id,
            isPd: allocation.piece.isPd,
            target: target,
          ),
        );
      }
    }

    // 300×400 : OTAN = 18 coups (8/8/2), forcé = 20 coups (8/8/4).
    if (shots.length != 18 && shots.length != 20) return null;

    final indices = shots.map((s) => s.target.index).toList()..sort();
    for (var i = 0; i < shots.length; i++) {
      if (indices[i] != i) return null;
    }

    final byIndex = <int, PlannedShot>{
      for (final shot in shots) shot.target.index: shot,
    };

    List<PlannedShot> range(int start, int endInclusive) {
      return [
        for (var i = start; i <= endInclusive; i++)
          if (byIndex[i] != null) byIndex[i]!,
      ];
    }

    List<PlannedShot> salveRange({
      required int start,
      required int endInclusive,
      required int salveIndex,
    }) {
      return _reassignUniquePiecesForSalve(
        pieces: pieces,
        salveIndex: salveIndex,
        shots: range(start, endInclusive),
      );
    }

    if (shots.length == 18) {
      return SalvesPlan(
        salves: [
          SalvePlan(
            index: 1,
            shots: salveRange(start: 0, endInclusive: 7, salveIndex: 1),
          ),
          SalvePlan(
            index: 2,
            shots: salveRange(start: 8, endInclusive: 15, salveIndex: 2),
          ),
          SalvePlan(
            index: 3,
            shots: salveRange(start: 16, endInclusive: 17, salveIndex: 3),
          ),
        ],
      );
    }

    return SalvesPlan(
      salves: [
        SalvePlan(
          index: 1,
          shots: salveRange(start: 0, endInclusive: 7, salveIndex: 1),
        ),
        SalvePlan(
          index: 2,
          shots: salveRange(start: 8, endInclusive: 15, salveIndex: 2),
        ),
        SalvePlan(
          index: 3,
          shots: salveRange(start: 16, endInclusive: 19, salveIndex: 3),
        ),
      ],
    );
  }

  static List<PlannedShot> _reassignUniquePiecesForSalve({
    required List<PieceGeom> pieces,
    required int salveIndex,
    required List<PlannedShot> shots,
  }) {
    if (shots.isEmpty || pieces.isEmpty) return shots;

    final byId = <String, PieceGeom>{
      for (final p in pieces) p.id.trim().toUpperCase(): p,
    };

    const baseOrder = <String>[
      'PS7',
      'PS6',
      'PS5',
      'PD',
      'PS1',
      'PS2',
      'PS3',
      'PS4',
    ];

    final orderedPieces = <PieceGeom>[
      for (final id in baseOrder)
        if (byId.containsKey(id)) byId[id]!,
      for (final p in pieces)
        if (!baseOrder.contains(p.id.trim().toUpperCase())) p,
    ];

    // Rotation légère entre salves pour ne pas toujours donner les salves
    // partielles aux mêmes tubes, tout en conservant l'ordre tactique stable.
    final rotation = orderedPieces.isEmpty
        ? 0
        : ((salveIndex - 1) * shots.length) % orderedPieces.length;
    final salveOrder = <PieceGeom>[
      ...orderedPieces.skip(rotation),
      ...orderedPieces.take(rotation),
    ];

    final used = <String>{};
    final out = <PlannedShot>[];

    for (var i = 0; i < shots.length; i++) {
      PieceGeom? chosen;

      for (final p in salveOrder) {
        if (!used.contains(p.id)) {
          chosen = p;
          break;
        }
      }

      // Sécurité : si une salve dépasse le nombre de pièces disponibles, on
      // accepte la réutilisation seulement après épuisement de toutes les pièces.
      chosen ??= salveOrder[i % salveOrder.length];
      used.add(chosen.id);

      out.add(
        PlannedShot(
          pieceId: chosen.id,
          isPd: chosen.isPd,
          target: shots[i].target,
        ),
      );
    }

    return out;
  }

  /// Correction doctrinale :
  ///
  /// Pour les tirs zonaux appui en salves, lorsqu'il reste une
  /// dernière salve partielle d'un seul coup, cette salve doit porter le point
  /// central de la zone si ce point existe dans le plan.
  ///
  /// Le moteur doctrinal peut générer le centre avant la dernière salve, puis le
  /// SalvesPlanner consomme les cibles par pièce. Cette méthode remet simplement
  /// le point central dans la dernière salve en échangeant sa cible avec celle
  /// qui était prévue en dernière salve. Elle ne change ni le nombre de coups,
  /// ni les pièces, ni les calculs balistiques attendus.
  static void _ensureLastSingleSalveUsesCenterTarget({
    required List<SalvePlan> salves,
    required double prX,
    required double prY,
    required bool enabled,
  }) {
    if (!enabled || salves.length < 2 || salves.last.shots.length != 1) {
      return;
    }

    var bestSalveIndex = -1;
    var bestShotIndex = -1;
    var bestD2 = double.infinity;

    for (var s = 0; s < salves.length; s++) {
      final shots = salves[s].shots;
      for (var i = 0; i < shots.length; i++) {
        final t = shots[i].target;
        final dx = t.x - prX;
        final dy = t.y - prY;
        final d2 = dx * dx + dy * dy;

        if (d2 < bestD2) {
          bestD2 = d2;
          bestSalveIndex = s;
          bestShotIndex = i;
        }
      }
    }

    if (bestSalveIndex < 0 || bestShotIndex < 0) return;

    // Ne pas appliquer ce correctif s'il n'y a pas de vrai point central.
    // Un mètre de tolérance suffit pour absorber les imprécisions numériques.
    if (math.sqrt(bestD2) > 1.0) return;

    final lastSalveIndex = salves.length - 1;
    if (bestSalveIndex == lastSalveIndex && bestShotIndex == 0) return;

    final centerShot = salves[bestSalveIndex].shots[bestShotIndex];
    final lastShot = salves[lastSalveIndex].shots.first;

    salves[bestSalveIndex].shots[bestShotIndex] = PlannedShot(
      pieceId: centerShot.pieceId,
      isPd: centerShot.isPd,
      target: lastShot.target,
    );

    salves[lastSalveIndex].shots[0] = PlannedShot(
      pieceId: lastShot.pieceId,
      isPd: lastShot.isPd,
      target: centerShot.target,
    );

    debugPrint(
      '[SALVES-V24] last single salve recentered: '
      'center moved from salve=${bestSalveIndex + 1} to salve=${lastSalveIndex + 1}',
    );
  }

  static int _doctrineRankSalves(String id) {
    const doctrineOrderSalves = [
      'PS7',
      'PS6',
      'PS5',
      'PD',
      'PS1',
      'PS2',
      'PS3',
      'PS4',
    ];

    final idx = doctrineOrderSalves.indexOf(id);
    return idx >= 0 ? idx : 999;
  }

  static List<PieceGeom> _selectPiecesForPartialSalve({
    required List<PieceGeom> candidates,
    required List<PieceGeom> fullOrder,
    required PieceGeom pd,
    required double Function(PieceGeom) latFromPr,
    required double Function(PieceGeom) distToPd,
    required SalveSidePreference pref,
    required int take,
    required bool aroundPd,
  }) {
    final k = math.max(0, math.min(take, candidates.length));
    if (k <= 0) return const [];

    final pool = [...candidates]..sort((a, b) {
        final la = latFromPr(a);
        final lb = latFromPr(b);
        final byLat = la.compareTo(lb);
        if (byLat != 0) return byLat;

        if (a.isPd != b.isPd) return a.isPd ? -1 : 1;

        return a.id.compareTo(b.id);
      });

    if (pref != SalveSidePreference.auto) {
      final pdLat = latFromPr(pd);
      final wantRight = pref == SalveSidePreference.droite;

      bool isPreferred(PieceGeom p) {
        final l = latFromPr(p);
        return wantRight ? l >= pdLat : l <= pdLat;
      }

      final preferred = pool.where(isPreferred).toList();
      final others = pool.where((p) => !isPreferred(p)).toList();

      return [...preferred, ...others].take(k).toList();
    }

    if (!aroundPd) {
      return pool.take(k).toList();
    }

    final candidateIds = pool.map((p) => p.id).toSet();
    final orderedPool =
        fullOrder.where((p) => candidateIds.contains(p.id)).toList();

    if (orderedPool.length <= k) {
      return orderedPool;
    }

    final pdIndex = orderedPool.indexWhere((p) => p.id == pd.id);
    if (pdIndex < 0) {
      final byDist = [...orderedPool]
        ..sort((a, b) => distToPd(a).compareTo(distToPd(b)));

      final selected = byDist.take(k).toList()
        ..sort((a, b) => latFromPr(a).compareTo(latFromPr(b)));

      return selected;
    }

    var start = pdIndex - ((k - 1) ~/ 2);
    var end = start + k - 1;

    if (start < 0) {
      end += -start;
      start = 0;
    }

    if (end >= orderedPool.length) {
      start -= end - orderedPool.length + 1;
      end = orderedPool.length - 1;
    }

    if (start < 0) start = 0;

    return orderedPool.sublist(start, start + k);
  }
}
