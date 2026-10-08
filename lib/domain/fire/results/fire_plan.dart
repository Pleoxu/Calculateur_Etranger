import 'package:flutter/foundation.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan_kind.dart';

@immutable
class OffsetTarget {
  final int index;
  final double offsetM;
  final double x;
  final double y;

  const OffsetTarget({
    required this.index,
    required this.offsetM,
    required this.x,
    required this.y,
  });

  OffsetTarget copyWith({int? index, double? offsetM, double? x, double? y}) {
    return OffsetTarget(
      index: index ?? this.index,
      offsetM: offsetM ?? this.offsetM,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }
}

@immutable
class OffsetWithCoords {
  final double offsetM;
  final double x;
  final double y;

  const OffsetWithCoords({
    required this.offsetM,
    required this.x,
    required this.y,
  });

  OffsetWithCoords copyWith({double? offsetM, double? x, double? y}) {
    return OffsetWithCoords(
      offsetM: offsetM ?? this.offsetM,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }
}

@immutable
class PieceGeom {
  final String id;
  final double x;
  final double y;
  final double? z;
  final bool isPd;

  const PieceGeom({
    required this.id,
    required this.x,
    required this.y,
    this.z,
    required this.isPd,
  });

  PieceGeom copyWith({
    String? id,
    double? x,
    double? y,
    double? z,
    bool? isPd,
  }) {
    return PieceGeom(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      isPd: isPd ?? this.isPd,
    );
  }
}

@immutable
class PieceAllocation {
  final PieceGeom piece;
  final List<OffsetTarget> targets;

  PieceAllocation({required this.piece, required List<OffsetTarget> targets})
      : targets = List.unmodifiable(targets);

  PieceAllocation copyWith({PieceGeom? piece, List<OffsetTarget>? targets}) {
    return PieceAllocation(
      piece: piece ?? this.piece,
      targets: targets ?? this.targets,
    );
  }

  bool get hasTargets => targets.isNotEmpty;
  int get nbTargets => targets.length;
}

@immutable
class Special200x200PlannedShot {
  final int ordre;
  final int salve;
  final String pieceId;
  final Object local;
  final OffsetTarget target;

  const Special200x200PlannedShot({
    required this.ordre,
    required this.salve,
    required this.pieceId,
    required this.local,
    required this.target,
  });

  Special200x200PlannedShot copyWith({
    int? ordre,
    int? salve,
    String? pieceId,
    Object? local,
    OffsetTarget? target,
  }) {
    return Special200x200PlannedShot(
      ordre: ordre ?? this.ordre,
      salve: salve ?? this.salve,
      pieceId: pieceId ?? this.pieceId,
      local: local ?? this.local,
      target: target ?? this.target,
    );
  }
}

@immutable
class Special200x200Plan {
  final List<Special200x200PlannedShot> shots;

  Special200x200Plan({required List<Special200x200PlannedShot> shots})
      : shots = List.unmodifiable(shots);

  Special200x200Plan copyWith({List<Special200x200PlannedShot>? shots}) {
    return Special200x200Plan(shots: shots ?? this.shots);
  }

  bool get hasShots => shots.isNotEmpty;
  int get nbShots => shots.length;
}

@immutable
class FirePlan {
  final FirePlanKind kind;

  final double zoneLargeurM;
  final double zoneProfondeurM;

  final double azimutMilOut;
  final double azimutLargeurMil;
  final double azimutProfondeurMil;

  final int nbPositions;
  final int nbCoupsTotal;

  final int gridNL;
  final int gridNP;

  final List<OffsetTarget> allTargets;
  final List<PieceGeom> pieces;
  final List<PieceAllocation> allocs;

  final Map<String, int> desiredShotsByPiece;

  final bool isSpecial200x200;
  final Special200x200Plan? special200x200Plan;
  final bool hasCrossings;

  FirePlan({
    required this.kind,
    required this.zoneLargeurM,
    required this.zoneProfondeurM,
    required this.azimutMilOut,
    required this.azimutLargeurMil,
    required this.azimutProfondeurMil,
    required this.nbPositions,
    required this.nbCoupsTotal,
    required this.gridNL,
    required this.gridNP,
    List<OffsetTarget> allTargets = const <OffsetTarget>[],
    List<PieceGeom> pieces = const <PieceGeom>[],
    List<PieceAllocation> allocs = const <PieceAllocation>[],
    Map<String, int> desiredShotsByPiece = const <String, int>{},
    this.isSpecial200x200 = false,
    this.special200x200Plan,
    this.hasCrossings = false,
  })  : allTargets = List.unmodifiable(allTargets),
        pieces = List.unmodifiable(pieces),
        allocs = List.unmodifiable(allocs),
        desiredShotsByPiece = Map.unmodifiable(desiredShotsByPiece);

  const FirePlan.empty({
    required this.kind,
    required this.azimutMilOut,
    this.azimutLargeurMil = 0.0,
    this.azimutProfondeurMil = 0.0,
  })  : zoneLargeurM = 0.0,
        zoneProfondeurM = 0.0,
        nbPositions = 1,
        nbCoupsTotal = 0,
        gridNL = 1,
        gridNP = 1,
        allTargets = const <OffsetTarget>[],
        pieces = const <PieceGeom>[],
        allocs = const <PieceAllocation>[],
        desiredShotsByPiece = const <String, int>{},
        isSpecial200x200 = false,
        special200x200Plan = null,
        hasCrossings = false;

  bool get isPonctuel => kind.isPonctuel;
  bool get isNature => kind.isNature;

  bool get hasTargets => allTargets.isNotEmpty;
  bool get hasPieces => pieces.isNotEmpty;
  bool get hasAllocs => allocs.isNotEmpty;

  FirePlan copyWith({
    FirePlanKind? kind,
    double? zoneLargeurM,
    double? zoneProfondeurM,
    double? azimutMilOut,
    double? azimutLargeurMil,
    double? azimutProfondeurMil,
    int? nbPositions,
    int? nbCoupsTotal,
    int? gridNL,
    int? gridNP,
    List<OffsetTarget>? allTargets,
    List<PieceGeom>? pieces,
    List<PieceAllocation>? allocs,
    Map<String, int>? desiredShotsByPiece,
    bool? isSpecial200x200,
    Special200x200Plan? special200x200Plan,
    bool? hasCrossings,
  }) {
    return FirePlan(
      kind: kind ?? this.kind,
      zoneLargeurM: zoneLargeurM ?? this.zoneLargeurM,
      zoneProfondeurM: zoneProfondeurM ?? this.zoneProfondeurM,
      azimutMilOut: azimutMilOut ?? this.azimutMilOut,
      azimutLargeurMil: azimutLargeurMil ?? this.azimutLargeurMil,
      azimutProfondeurMil: azimutProfondeurMil ?? this.azimutProfondeurMil,
      nbPositions: nbPositions ?? this.nbPositions,
      nbCoupsTotal: nbCoupsTotal ?? this.nbCoupsTotal,
      gridNL: gridNL ?? this.gridNL,
      gridNP: gridNP ?? this.gridNP,
      allTargets: allTargets ?? this.allTargets,
      pieces: pieces ?? this.pieces,
      allocs: allocs ?? this.allocs,
      desiredShotsByPiece: desiredShotsByPiece ?? this.desiredShotsByPiece,
      isSpecial200x200: isSpecial200x200 ?? this.isSpecial200x200,
      special200x200Plan: special200x200Plan ?? this.special200x200Plan,
      hasCrossings: hasCrossings ?? this.hasCrossings,
    );
  }
}
