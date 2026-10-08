import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:calculateur_etranger/domain/fire/allocation/zonal/zonal_shot_assignment.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';
import 'package:calculateur_etranger/domain/fire/target_generation/zonal/zonal_fire_assignment.dart'
    show toUtm;

class FireGeometryService {
  const FireGeometryService();

  Offset zonalAnchorShift({
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

  OffsetTarget buildTargetFromAssignment({
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
    final rebase = zonalAnchorShift(
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
}
