import 'package:calculateur_etranger/domain/fire/doctrine/fire_doctrine_service.dart';
import 'package:calculateur_etranger/domain/fire/geometry/fire_geometry_service.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';
import 'package:calculateur_etranger/models/calcul_data.dart' show ZonalMode;

class FirePlanDoctrinalZonalTargetsBuilder {
  final FireDoctrineService _doctrine = const FireDoctrineService();
  final FireGeometryService _geometry = const FireGeometryService();

  const FirePlanDoctrinalZonalTargetsBuilder();

  List<OffsetTarget> build({
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
    required double diametreEfficaceM,
    ZonalMode zonalMode = ZonalMode.otan,
    bool isZonalPreset = false,
  }) {
    final assignments = _doctrine.computeAssignments(
      pieces: pieces,
      largeurM: largeurM,
      profondeurM: profondeurM,
      coups: coups,
      prX: prX,
      prY: prY,
      azimutLargeurMil: azimutLargeurMil,
      azimutTirMil: azimutTirMil,
      debordementRatio: 0.10,
      recouvrementMini: 0.10,
      diametreEfficaceM: diametreEfficaceM,
      zonalMode: zonalMode,
      isZonalPreset: isZonalPreset,
    );

    return [
      for (var i = 0; i < assignments.length; i++)
        _geometry.buildTargetFromAssignment(
          index: i,
          prX: prX,
          prY: prY,
          azimutLargeurMil: azimutLargeurMil,
          azimutProfondeurMil: azimutProfondeurMil,
          pointIdx: pointIdx,
          largeurM: largeurM,
          profondeurM: profondeurM,
          assignment: assignments[i],
        ),
    ];
  }
}
