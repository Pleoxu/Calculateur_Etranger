import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/models/effects/coverage_ellipse.dart';

class FireShotsResult {
  final List<TirLineaireShot> shots;
  final List<PieceSoutienOutput> psOutputs;

  final CalculResult? resultatPd;

  final double pdOffset;
  final double pdX;
  final double pdY;

  const FireShotsResult({
    required this.shots,
    required this.psOutputs,
    required this.resultatPd,
    required this.pdOffset,
    required this.pdX,
    required this.pdY,
  });
}

extension TirLineaireShotCoverage on TirLineaireShot {
  CoverageEllipse? get coverage => coverageEllipse;
}
