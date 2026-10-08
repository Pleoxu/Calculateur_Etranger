import 'package:calculateur_etranger/domain/fire/doctrine/fire_doctrine_service.dart';
import 'package:calculateur_etranger/domain/fire/geometry/fire_geometry_service.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';

class FirePlanSpecial200x200Builder {
  final FireDoctrineService _doctrine = const FireDoctrineService();
  final FireGeometryService _geometry = const FireGeometryService();

  const FirePlanSpecial200x200Builder();

  bool isApplicable({
    required bool isZonal,
    required bool salvesOn,
    required double largeurM,
    required double profondeurM,
    required int piecesCount,
  }) {
    return _doctrine.isSpecial200x200Doctrine(
      isZonal: isZonal,
      salvesOn: salvesOn,
      largeurM: largeurM,
      profondeurM: profondeurM,
      piecesCount: piecesCount,
    );
  }

  Special200x200Plan build({
    required double prX,
    required double prY,
    required double azimutLargeurMil,
    required double azimutProfondeurMil,
    required double azimutTirMil,
    required int pointIdx,
    required double largeurM,
    required double profondeurM,
    required List<PieceGeom> pieces,
    required ZonalMode zonalMode,
    required double diametreEfficaceM,
  }) {
    final coups = zonalMode == ZonalMode.otan ? 8 : 9;

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
    );

    final plannedShots = <Special200x200PlannedShot>[
      for (var i = 0; i < assignments.length; i++)
        Special200x200PlannedShot(
          ordre: assignments[i].ordre,
          salve: assignments[i].salve,
          pieceId: assignments[i].pieceId,
          local: assignments[i].position,
          target: _geometry.buildTargetFromAssignment(
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
        ),
    ]..sort((a, b) {
        final bySalve = a.salve.compareTo(b.salve);
        if (bySalve != 0) return bySalve;
        return a.ordre.compareTo(b.ordre);
      });

    return Special200x200Plan(shots: plannedShots);
  }
}
