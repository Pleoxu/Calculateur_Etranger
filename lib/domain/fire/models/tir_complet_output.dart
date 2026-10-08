import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/models/effects/coverage_ellipse.dart';

class TirLineaireShot {
  final String nomPiece;
  final double offsetM;
  final double objX;
  final double objY;
  final CalculResult resultat;
  final int? numeroSalve;
  final int count;
  final CoverageEllipse? coverageEllipse;

  const TirLineaireShot({
    required this.nomPiece,
    required this.offsetM,
    required this.objX,
    required this.objY,
    required this.resultat,
    this.numeroSalve,
    this.count = 1,
    this.coverageEllipse,
  });

  TirLineaireShot copyWith({
    String? nomPiece,
    double? offsetM,
    double? objX,
    double? objY,
    CalculResult? resultat,
    int? numeroSalve,
    int? count,
    CoverageEllipse? coverageEllipse,
  }) {
    return TirLineaireShot(
      nomPiece: nomPiece ?? this.nomPiece,
      offsetM: offsetM ?? this.offsetM,
      objX: objX ?? this.objX,
      objY: objY ?? this.objY,
      resultat: resultat ?? this.resultat,
      numeroSalve: numeroSalve ?? this.numeroSalve,
      count: count ?? this.count,
      coverageEllipse: coverageEllipse ?? this.coverageEllipse,
    );
  }
}

class PieceSoutienOutput {
  final String nom;
  final double xPS;
  final double yPS;
  final double? zPS;
  final double offsetM;
  final double objX;
  final double objY;
  final CalculResult resultat;

  const PieceSoutienOutput({
    required this.nom,
    required this.xPS,
    required this.yPS,
    this.zPS,
    required this.offsetM,
    required this.objX,
    required this.objY,
    required this.resultat,
  });
}

class TirCompletOutput {
  final CalculResult? resultatPrincipal;

  final CalculResult? resultatPd;
  final List<PieceSoutienOutput> psOutputs;

  final List<TirLineaireShot> shots;
  final FirePlan firePlan;

  final double pdOffset;
  final double pdX;
  final double pdY;

  final double prX;
  final double prY;

  final int coups;
  final double debordPct;

  final double latitudePieceDeg;
  final double deltaAltMet;
  final double niveauBLocal;
  final double siteBLocalM;

  const TirCompletOutput({
    required this.resultatPrincipal,
    required this.resultatPd,
    required this.psOutputs,
    required this.shots,
    required this.firePlan,
    required this.pdOffset,
    required this.pdX,
    required this.pdY,
    required this.prX,
    required this.prY,
    this.coups = 0,
    this.debordPct = 0.0,
    this.latitudePieceDeg = 0.0,
    this.deltaAltMet = 0.0,
    this.niveauBLocal = 0.0,
    this.siteBLocalM = 0.0,
  });

  double get pdOffsetM => pdOffset;

  double get pdObjX => pdX;

  double get pdObjY => pdY;

  CalculResult? get resultatPdAffecte => resultatPd;

  List<PieceSoutienOutput> get resultatsPS => psOutputs;

  bool get hasShots => shots.isNotEmpty;

  bool get hasResultatsPS => psOutputs.isNotEmpty;

  int get totalShots {
    var total = 0;
    for (final shot in shots) {
      total += shot.count;
    }
    return total;
  }

  int get totalShotsCount => totalShots;
}
