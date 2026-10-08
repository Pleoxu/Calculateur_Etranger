import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:calculateur_etranger/domain/fire/allocation/lineaire/linear_closure_allocator.dart';
import 'package:calculateur_etranger/domain/fire/allocation/zonal/zonal_shot_assignment.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/zonal/hardcoded/zonal_hardcoded_doctrine_models.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/zonal/zonal_overflow_ratio.dart';
import 'package:calculateur_etranger/domain/fire/models/tir_complet_input.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';
import 'package:calculateur_etranger/domain/fire/usecases/fire_plan_allocator.dart';
import 'package:calculateur_etranger/domain/fire/usecases/fire_plan_context.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';

class FirePlanAllocationResolver {
  const FirePlanAllocationResolver();

  static const bool _traceZonalStable = bool.fromEnvironment(
    'CALC_TRACE_ZONAL',
    defaultValue: false,
  );

  final FirePlanAllocator _allocator = const FirePlanAllocator();

  List<PieceAllocation> resolve({
    required FirePlanContext ctx,
    required List<PieceGeom> pieces,
    required List<OffsetTarget> allTargets,
    required List<OffsetWithCoords> offsetsWithCoords,
    required Map<String, int> quotasPositionsByPiece,
    required bool isDoctrinalZonal,
    required double azimutMilOut,
    required double azimutLargeurMil,
    required double azimutProfondeurMil,
    required int zonalPointIdx,
    required double zoneLargeurM,
    required double zoneProfondeurM,
    required int gridNL,
    required int gridNP,
    required int nbCoupsEffectif,
    required bool hasPieceWeights,
    required List<int>? doctrinalSequence,
    required Map<String, int> linearDesiredShots,
  }) {
    if (ctx.isZonal) {
      return _ZonalAllocationResolver(
        allocator: _allocator,
        traceEnabled: _traceZonalStable,
      ).resolve(
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
      );
    }

    return _LinearAllocationResolver(allocator: _allocator).resolve(
      ctx: ctx,
      pieces: pieces,
      allTargets: allTargets,
      offsetsWithCoords: offsetsWithCoords,
      quotasPositionsByPiece: quotasPositionsByPiece,
      hasPieceWeights: hasPieceWeights,
      doctrinalSequence: doctrinalSequence,
      linearDesiredShots: linearDesiredShots,
    );
  }
}

class _ZonalAllocationResolver {
  const _ZonalAllocationResolver({
    required FirePlanAllocator allocator,
    required bool traceEnabled,
  })  : _allocator = allocator,
        _traceEnabled = traceEnabled;

  final FirePlanAllocator _allocator;
  final bool _traceEnabled;

  List<PieceAllocation> resolve({
    required FirePlanContext ctx,
    required List<PieceGeom> pieces,
    required List<OffsetTarget> allTargets,
    required List<OffsetWithCoords> offsetsWithCoords,
    required Map<String, int> quotasPositionsByPiece,
    required bool isDoctrinalZonal,
    required double azimutMilOut,
    required double azimutLargeurMil,
    required double azimutProfondeurMil,
    required int zonalPointIdx,
    required double zoneLargeurM,
    required double zoneProfondeurM,
    required int gridNL,
    required int gridNP,
    required int nbCoupsEffectif,
  }) {
    if (ctx.input.isZonalPreset) {
      return _assignPresetZonalOneShot(pieces: pieces, targets: allTargets);
    }

    // OECL zonal : doctrine spécifique éclairant.
    // On doit conserver TOUS les offsets produits par EclairantZonalEngine.
    // L'allocateur zonal générique peut tronquer à un coup par pièce ; ici,
    // on répartit simplement les offsets sur les pièces disponibles en cycle.
    if (ctx.input.typeTir == TypeTir.eclairant) {
      return _assignEclairantZonalAllTargets(
        pieces: pieces,
        targets: allTargets,
      );
    }

    final config = _ZonalDoctrineInputConfig.from(
      ctx.input,
      fallbackDiametreEfficaceM: ctx.input.systeme.diametreEfficaciteM,
    );

    // Diagnostic uniquement : ne modifie pas l'allocation.
    final uiDebordPct = ctx.input.pourcentageDebordement;
    final uiDebordRatio = ZonalOverflowRatio.fromInput(ctx.input);
    debugPrint(
      '[ZONAL-DEBORD TRACE] '
      'inputPct=$uiDebordPct '
      'inputRatio=$uiDebordRatio '
      'resolverRatio=${config.debordementRatio}',
    );

    final doctrineMode = ctx.input.zonalMode == ZonalMode.otan
        ? ZonalDoctrineMode.otan
        : ZonalDoctrineMode.force;

    final forceDeepZonalDoctrine = _isDeepZonalDoctrine(
      largeurM: zoneLargeurM,
      profondeurM: zoneProfondeurM,
      diametreEfficaceM: config.diametreEfficaceM,
    );

    // Sécurité doctrine 400×500 / 300×500 : certains chemins amont classent encore le
    // cas 400×500 / 300×500 comme "non doctrinal" et appellent alors allocateZonal(),
    // qui reconstruit une ancienne grille à 18 offsets. Pour le 5×6, on force
    // explicitement le chemin doctrinal avant ce fallback générique.
    if (!isDoctrinalZonal && !forceDeepZonalDoctrine) {
      return _allocator.allocateZonal(
        pieces: pieces,
        offsetsWithCoords: offsetsWithCoords,
        quotasPositionsByPiece: quotasPositionsByPiece,
        prX: ctx.prX,
        prY: ctx.prY,
        azimutLargeurMil: azimutLargeurMil,
        azimutProfondeurMil: azimutProfondeurMil,
        azimutTirMil: azimutMilOut,
        nL: gridNL,
        nP: gridNP,
        pointIdx: zonalPointIdx,
      );
    }

    final doctrineCoups = _doctrinalCoupsForDeepZonalOverride(
      largeurM: zoneLargeurM,
      profondeurM: zoneProfondeurM,
      requestedCoups: nbCoupsEffectif,
      diametreEfficaceM: config.diametreEfficaceM,
      mode: doctrineMode,
    );

    debugPrint(
      '[ZONAL-CALL] '
      'nbCoupsEffectif=$nbCoupsEffectif '
      'doctrineCoups=$doctrineCoups '
      'largeur=$zoneLargeurM '
      'profondeur=$zoneProfondeurM '
      'mode=$doctrineMode '
      'debord=${config.debordementRatio} '
      'recouv=${config.recouvrementMini} '
      'diametre=${config.diametreEfficaceM} '
      'isDoctrinalZonal=$isDoctrinalZonal',
    );

    final assignments = _allocator.doctrinalAssignmentsForZonal(
      pieces: pieces,
      prX: ctx.prX,
      prY: ctx.prY,
      azimutLargeurMil: azimutLargeurMil,
      azimutTirMil: azimutMilOut,
      largeurM: zoneLargeurM,
      profondeurM: zoneProfondeurM,
      coups: doctrineCoups,
      debordementRatio: config.debordementRatio,
      recouvrementMini: config.recouvrementMini,
      diametreEfficaceM: config.diametreEfficaceM,
      mode: doctrineMode,
    );

    return _ZonalStableAssigner(
      allocator: _allocator,
      traceEnabled: _traceEnabled,
    ).assign(
      assignments: assignments,
      pieces: pieces,
      prX: ctx.prX,
      prY: ctx.prY,
      azimutLargeurMil: azimutLargeurMil,
      azimutProfondeurMil: azimutProfondeurMil,
      zonalPointIdx: zonalPointIdx,
      zoneLargeurM: zoneLargeurM,
      zoneProfondeurM: zoneProfondeurM,
      quotasPositionsByPiece: quotasPositionsByPiece,
    );
  }

  int _doctrinalCoupsForDeepZonalOverride({
    required double largeurM,
    required double profondeurM,
    required int requestedCoups,
    required double diametreEfficaceM,
    required ZonalDoctrineMode mode,
  }) {
    // Sécurité doctrine 400×500 / 300×500 : l'ancien moteur générique peut encore
    // transmettre un nombre obsolète pour les grands zonaux profonds.
    // Pour les doctrines dédiées, le moteur d'offsets doit être appelé avec :
    // - 400×500 : 26 coups en OTAN / 30 en forcé ;
    // - 300×500 : 22 coups en OTAN / 24 en forcé.
    // OECL/éclairant conserve la grille complète via le
    // chemin spécifique TypeTir.eclairant plus haut.
    if (_isDeepZonal5x6(
      largeurM: largeurM,
      profondeurM: profondeurM,
      diametreEfficaceM: diametreEfficaceM,
    )) {
      return mode == ZonalDoctrineMode.otan ? 26 : 30;
    }

    if (_isDeepZonal3x6(
      largeurM: largeurM,
      profondeurM: profondeurM,
      diametreEfficaceM: diametreEfficaceM,
    )) {
      return mode == ZonalDoctrineMode.otan ? 22 : 24;
    }

    return requestedCoups;
  }

  bool _isDeepZonalDoctrine({
    required double largeurM,
    required double profondeurM,
    required double diametreEfficaceM,
  }) {
    return _isDeepZonal5x6(
          largeurM: largeurM,
          profondeurM: profondeurM,
          diametreEfficaceM: diametreEfficaceM,
        ) ||
        _isDeepZonal3x6(
          largeurM: largeurM,
          profondeurM: profondeurM,
          diametreEfficaceM: diametreEfficaceM,
        );
  }

  bool _isDeepZonal5x6({
    required double largeurM,
    required double profondeurM,
    required double diametreEfficaceM,
  }) {
    // Éclairant : pas d'économie OTAN HE ici.
    if (diametreEfficaceM >= 600.0) return false;

    return largeurM >= 380.0 &&
        largeurM <= 450.0 &&
        profondeurM >= 480.0 &&
        profondeurM <= 560.0;
  }

  bool _isDeepZonal3x6({
    required double largeurM,
    required double profondeurM,
    required double diametreEfficaceM,
  }) {
    // Éclairant : pas d'économie OTAN HE ici.
    if (diametreEfficaceM >= 600.0) return false;

    return largeurM >= 280.0 &&
        largeurM <= 340.0 &&
        profondeurM >= 480.0 &&
        profondeurM <= 560.0;
  }

  List<PieceAllocation> _assignEclairantZonalAllTargets({
    required List<PieceGeom> pieces,
    required List<OffsetTarget> targets,
  }) {
    if (pieces.isEmpty) {
      return const <PieceAllocation>[];
    }

    final targetsByPiece = <String, List<OffsetTarget>>{
      for (final p in pieces) p.id: <OffsetTarget>[],
    };

    if (targets.isEmpty) {
      return [
        for (final p in pieces) PieceAllocation(piece: p, targets: const []),
      ];
    }

    // Ordre tactique stable : PD/PS puis le reste.
    const preferredOrder = <String>[
      'PD',
      'PS1',
      'PS2',
      'PS3',
      'PS4',
      'PS5',
      'PS6',
      'PS7',
    ];

    final byId = <String, PieceGeom>{
      for (final p in pieces) p.id.trim().toUpperCase(): p,
    };

    final orderedPieces = <PieceGeom>[
      for (final id in preferredOrder)
        if (byId.containsKey(id)) byId[id]!,
      for (final p in pieces)
        if (!preferredOrder.contains(p.id.trim().toUpperCase())) p,
    ];

    for (var i = 0; i < targets.length; i++) {
      final piece = orderedPieces[i % orderedPieces.length];
      targetsByPiece[piece.id]!.add(targets[i]);
    }

    return [
      for (final p in pieces)
        PieceAllocation(
          piece: p,
          targets: List<OffsetTarget>.from(targetsByPiece[p.id] ?? const []),
        ),
    ];
  }

  List<PieceAllocation> _assignPresetZonalOneShot({
    required List<PieceGeom> pieces,
    required List<OffsetTarget> targets,
  }) {
    const doctrinalOrder = <String>[
      'PS7',
      'PS6',
      'PS5',
      'PD',
      'PS1',
      'PS2',
      'PS3',
      'PS4',
    ];

    final byId = <String, PieceGeom>{
      for (final p in pieces) p.id.trim().toUpperCase(): p,
    };

    final orderedPieces = <PieceGeom>[
      for (final id in doctrinalOrder)
        if (byId.containsKey(id)) byId[id]!,
      for (final p in pieces)
        if (!doctrinalOrder.contains(p.id.trim().toUpperCase())) p,
    ];

    final targetsByPiece = <String, List<OffsetTarget>>{
      for (final p in pieces) p.id: <OffsetTarget>[],
    };

    if (orderedPieces.isEmpty || targets.isEmpty) {
      return [
        for (final p in pieces) PieceAllocation(piece: p, targets: const []),
      ];
    }

    final cycle = math.min(8, orderedPieces.length);
    for (var i = 0; i < targets.length; i++) {
      final piece = orderedPieces[i % cycle];
      targetsByPiece[piece.id]!.add(targets[i]);
    }

    return [
      for (final p in pieces)
        PieceAllocation(
          piece: p,
          targets: List<OffsetTarget>.from(targetsByPiece[p.id] ?? const []),
        ),
    ];
  }
}

class _ZonalStableAssigner {
  const _ZonalStableAssigner({
    required FirePlanAllocator allocator,
    required bool traceEnabled,
  })  : _allocator = allocator,
        _traceEnabled = traceEnabled;

  final FirePlanAllocator _allocator;
  final bool _traceEnabled;

  List<PieceAllocation> assign({
    required List<ZonalShotAssignment> assignments,
    required List<PieceGeom> pieces,
    required double prX,
    required double prY,
    required double azimutLargeurMil,
    required double azimutProfondeurMil,
    required int zonalPointIdx,
    required double zoneLargeurM,
    required double zoneProfondeurM,
    required Map<String, int> quotasPositionsByPiece,
  }) {
    if (pieces.isEmpty || assignments.isEmpty) {
      return [
        for (final p in pieces) PieceAllocation(piece: p, targets: const []),
      ];
    }

    final piecesLocal = _buildLocalPieces(
      pieces: pieces,
      prX: prX,
      prY: prY,
      azimutLargeurMil: azimutLargeurMil,
    );

    final desiredShots = <String, int>{
      for (final p in pieces)
        p.id: math.max(0, quotasPositionsByPiece[p.id] ?? 0),
    };

    final namedShots = _countNamedShots(
      assignments: assignments,
      pieces: pieces,
    );

    final remainingAnonymousShots = <String, int>{
      for (final p in pieces)
        p.id: math.max(0, (desiredShots[p.id] ?? 0) - (namedShots[p.id] ?? 0)),
    };

    final anonymousCandidates = piecesLocal
        .where((p) => (remainingAnonymousShots[p.piece.id] ?? 0) > 0)
        .toList()
      ..sort(_compareLocalPieces);

    final totalDesiredShots = desiredShots.values.fold<int>(0, (a, b) => a + b);

    // IMPORTANT — zonal doctrinal :
    // Les quotas de positions peuvent provenir de l'ancien moteur générique
    // et rester à 18 pour un 400x500, alors que la doctrine OTAN 5x6 génère
    // bien 26 assignments. On ne doit donc jamais tronquer les assignments
    // doctrinaux avec totalDesiredShots. Sinon on retombe sur le bug :
    // "26 annoncés / 18 réels".
    final orderedAssignments = ([...assignments]..sort((a, b) {
            final bySalve = a.salve.compareTo(b.salve);
            if (bySalve != 0) return bySalve;
            return a.ordre.compareTo(b.ordre);
          }))
        .toList(growable: false);

    if (totalDesiredShots != orderedAssignments.length) {
      debugPrint(
        '[ZONAL-STABLE] quota mismatch ignored: '
        'quotas=$totalDesiredShots assignments=${orderedAssignments.length}',
      );
    }

    final resolvedPieceBySlot = _resolvePieceBySlot(
      orderedAssignments: orderedAssignments,
      anonymousCandidates: anonymousCandidates,
      remainingAnonymousShots: remainingAnonymousShots,
    );

    final targetsByPiece = <String, List<OffsetTarget>>{
      for (final p in pieces) p.id: <OffsetTarget>[],
    };

    var globalIndex = 0;

    for (final assignment in orderedAssignments) {
      final pid = resolvedPieceBySlot[_ZonalSlotKey.from(assignment)];
      if (pid == null || pid.isEmpty) continue;

      final piece = pieces.firstWhere((p) => p.id == pid);

      final target = _allocator.offsetTargetFromDoctrineAssignmentByPointIdx(
        index: globalIndex++,
        prX: prX,
        prY: prY,
        azimutLargeurMil: azimutLargeurMil,
        azimutProfondeurMil: azimutProfondeurMil,
        pointIdx: zonalPointIdx,
        largeurM: zoneLargeurM,
        profondeurM: zoneProfondeurM,
        assignment: assignment,
      );

      targetsByPiece[piece.id]!.add(target);
    }

    _trace(
      pieces: pieces,
      desiredShots: desiredShots,
      namedShots: namedShots,
      remainingAnonymousShots: remainingAnonymousShots,
      anonymousCandidates: anonymousCandidates,
      orderedAssignments: orderedAssignments,
      resolvedPieceBySlot: resolvedPieceBySlot,
    );

    return [
      for (final p in pieces)
        PieceAllocation(
          piece: p,
          targets: List<OffsetTarget>.from(targetsByPiece[p.id] ?? const []),
        ),
    ];
  }

  List<_LocalPiece> _buildLocalPieces({
    required List<PieceGeom> pieces,
    required double prX,
    required double prY,
    required double azimutLargeurMil,
  }) {
    final azLargeurRad = _milToRad(azimutLargeurMil);
    final uLx = math.sin(azLargeurRad);
    final uLy = math.cos(azLargeurRad);

    _LocalPiece local(PieceGeom p) {
      final dx = p.x - prX;
      final dy = p.y - prY;
      final x = dx * uLx + dy * uLy;
      final dist = math.sqrt(dx * dx + dy * dy);
      return _LocalPiece(piece: p, x: x, dist: dist);
    }

    return [for (final p in pieces) local(p)];
  }

  Map<String, int> _countNamedShots({
    required List<ZonalShotAssignment> assignments,
    required List<PieceGeom> pieces,
  }) {
    final namedShots = <String, int>{for (final p in pieces) p.id: 0};

    for (final assignment in assignments) {
      final pid = assignment.pieceId.trim();
      if (pid.isEmpty) continue;
      if (namedShots.containsKey(pid)) {
        namedShots[pid] = (namedShots[pid] ?? 0) + 1;
      }
    }

    return namedShots;
  }

  Map<_ZonalSlotKey, String> _resolvePieceBySlot({
    required List<ZonalShotAssignment> orderedAssignments,
    required List<_LocalPiece> anonymousCandidates,
    required Map<String, int> remainingAnonymousShots,
  }) {
    final resolved = <_ZonalSlotKey, String>{};
    final remainingPool = <String, int>{
      for (final e in remainingAnonymousShots.entries) e.key: e.value,
    };

    for (final assignment in orderedAssignments) {
      final key = _ZonalSlotKey.from(assignment);
      final pid = assignment.pieceId.trim();

      if (pid.isNotEmpty) {
        resolved[key] = pid;
        continue;
      }

      final chosen = anonymousCandidates
          .where((p) => (remainingPool[p.piece.id] ?? 0) > 0)
          .firstOrNull
          ?.piece
          .id;

      if (chosen == null) {
        throw StateError(
          'ZONAL-STABLE: impossible de résoudre le slot anonyme '
          '${assignment.salve}/${assignment.ordre}/'
          'r${assignment.point.row}c${assignment.point.col}',
        );
      }

      resolved[key] = chosen;
      remainingPool[chosen] = (remainingPool[chosen] ?? 0) - 1;
    }

    return resolved;
  }

  int _compareLocalPieces(_LocalPiece a, _LocalPiece b) {
    final byX = a.x.compareTo(b.x);
    if (byX != 0) return byX;

    final byDist = a.dist.compareTo(b.dist);
    if (byDist != 0) return byDist;

    if (a.piece.isPd != b.piece.isPd) {
      return a.piece.isPd ? -1 : 1;
    }

    return a.piece.id.compareTo(b.piece.id);
  }

  void _trace({
    required List<PieceGeom> pieces,
    required Map<String, int> desiredShots,
    required Map<String, int> namedShots,
    required Map<String, int> remainingAnonymousShots,
    required List<_LocalPiece> anonymousCandidates,
    required List<ZonalShotAssignment> orderedAssignments,
    required Map<_ZonalSlotKey, String> resolvedPieceBySlot,
  }) {
    if (!_traceEnabled) return;

    final debugDesired =
        pieces.map((p) => '${p.id}:${desiredShots[p.id] ?? 0}').join(', ');
    debugPrint('[ZONAL-STABLE] desiredShots=$debugDesired');

    final debugNamed =
        pieces.map((p) => '${p.id}:${namedShots[p.id] ?? 0}').join(', ');
    debugPrint('[ZONAL-STABLE] doctrinalNamedShots=$debugNamed');

    final debugRemaining = pieces
        .map((p) => '${p.id}:${remainingAnonymousShots[p.id] ?? 0}')
        .join(', ');
    debugPrint('[ZONAL-STABLE] remainingAnonymousShots=$debugRemaining');

    final debugCandidates = anonymousCandidates
        .map(
          (p) =>
              '${p.piece.id}(x=${p.x.toStringAsFixed(1)},dist=${p.dist.toStringAsFixed(1)})',
        )
        .join(' | ');
    debugPrint('[ZONAL-STABLE] anonymousCandidates=$debugCandidates');

    final debugResolved = orderedAssignments.map((a) {
      final pid = resolvedPieceBySlot[_ZonalSlotKey.from(a)] ?? '-';
      return '${a.salve}/${a.ordre}/r${a.point.row}c${a.point.col}:$pid'
          '@(${a.position.dx.toStringAsFixed(1)},${a.position.dy.toStringAsFixed(1)})';
    }).join(' | ');
    debugPrint('[ZONAL-STABLE] resolved=$debugResolved');
  }

  static double _milToRad(double mil) {
    return mil * 2.0 * math.pi / 6400.0;
  }
}

class _LinearAllocationResolver {
  const _LinearAllocationResolver({required FirePlanAllocator allocator})
      : _allocator = allocator;

  final FirePlanAllocator _allocator;

  List<PieceAllocation> resolve({
    required FirePlanContext ctx,
    required List<PieceGeom> pieces,
    required List<OffsetTarget> allTargets,
    required List<OffsetWithCoords> offsetsWithCoords,
    required Map<String, int> quotasPositionsByPiece,
    required bool hasPieceWeights,
    required List<int>? doctrinalSequence,
    required Map<String, int> linearDesiredShots,
  }) {
    if (ctx.isPonctuel && allTargets.length == 1) {
      final target = allTargets.first;
      return [
        for (final p in pieces) PieceAllocation(piece: p, targets: [target]),
      ];
    }

    if (doctrinalSequence != null) {
      if (hasPieceWeights) {
        return _allocator.allocateLinearDoctrineByQuotas(
          pieces: pieces,
          targets: allTargets,
          azimutLineaireMil: ctx.azimutLineaireMil,
          quotasByPieceId: quotasPositionsByPiece,
        );
      }

      return _allocator.allocateLinearDoctrineBySequence(
        pieces: pieces,
        targets: allTargets,
        azimutLineaireMil: ctx.azimutLineaireMil,
      );
    }

    return LinearClosureAllocator.allocate(
      pieces: pieces,
      prX: 0.0,
      prY: 0.0,
      azimutLineaireMil: ctx.azimutLineaireMil,
      offsetsWithCoords: offsetsWithCoords,
      coupsParPieceById:
          hasPieceWeights ? quotasPositionsByPiece : linearDesiredShots,
      isPdNomade:
          ctx.input.linearFiringMode == LinearFiringMode.sectionWithoutPd &&
              pieces.any((p) => p.isPd),
    );
  }
}

class _ZonalDoctrineInputConfig {
  final double debordementRatio;
  final double recouvrementMini;
  final double diametreEfficaceM;

  const _ZonalDoctrineInputConfig({
    required this.debordementRatio,
    required this.recouvrementMini,
    required this.diametreEfficaceM,
  });

  factory _ZonalDoctrineInputConfig.from(
    dynamic input, {
    required double fallbackDiametreEfficaceM,
  }) {
    return _ZonalDoctrineInputConfig(
      debordementRatio: ZonalOverflowRatio.fromInput(input),
      recouvrementMini: _readDoubleCandidates(input, const [
            'recouvrementMini',
            'zonalRecouvrementMini',
            'recouvrementMiniRatio',
            'zonalOverlapRatio',
          ]) ??
          0.10,
      diametreEfficaceM: _readDoubleCandidates(input, const [
            'diametreEfficaceM',
            'zonalDiametreEfficaceM',
            'diametreEffM',
          ]) ??
          fallbackDiametreEfficaceM,
    );
  }

  static double? _readDoubleCandidates(dynamic input, List<String> names) {
    for (final name in names) {
      final value = _tryReadDynamicProperty(input, name);
      final asDouble = _toDoubleOrNull(value);
      if (asDouble != null) return asDouble;
    }
    return null;
  }

  static dynamic _tryReadDynamicProperty(dynamic input, String name) {
    try {
      switch (name) {
        case 'debordementRatio':
          return input.debordementRatio;
        case 'zonalDebordementRatio':
          return input.zonalDebordementRatio;
        case 'zonalOverflowRatio':
          return input.zonalOverflowRatio;
        case 'recouvrementMini':
          return input.recouvrementMini;
        case 'zonalRecouvrementMini':
          return input.zonalRecouvrementMini;
        case 'recouvrementMiniRatio':
          return input.recouvrementMiniRatio;
        case 'zonalOverlapRatio':
          return input.zonalOverlapRatio;
        case 'diametreEfficaceM':
          return input.diametreEfficaceM;
        case 'zonalDiametreEfficaceM':
          return input.zonalDiametreEfficaceM;
        case 'diametreEffM':
          return input.diametreEffM;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return null;
  }
}

class _LocalPiece {
  final PieceGeom piece;
  final double x;
  final double dist;

  const _LocalPiece({required this.piece, required this.x, required this.dist});
}

class _ZonalSlotKey {
  final int salve;
  final int ordre;
  final int row;
  final int col;

  const _ZonalSlotKey({
    required this.salve,
    required this.ordre,
    required this.row,
    required this.col,
  });

  factory _ZonalSlotKey.from(ZonalShotAssignment assignment) {
    return _ZonalSlotKey(
      salve: assignment.salve,
      ordre: assignment.ordre,
      row: assignment.point.row,
      col: assignment.point.col,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _ZonalSlotKey &&
        other.salve == salve &&
        other.ordre == ordre &&
        other.row == row &&
        other.col == col;
  }

  @override
  int get hashCode => Object.hash(salve, ordre, row, col);
}
