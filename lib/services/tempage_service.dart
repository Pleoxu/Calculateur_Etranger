// lib/services/tempage_service.dart
//
// Compatibility-only surfaces.
// No fuze-time / tempage calculation is reconstructed in this build.

class TempageResult {
  final double tempageNominalViserS;
  final double corrVent;
  final double corrTb;
  final double corrDb;
  final double corrV0;
  final double corrRtc;
  final double corrMasse;
  final double corrDz;
  final double eclDzSeconds;
  final double dcfsSeconds;
  final double tempageFinalS;

  const TempageResult({
    this.tempageNominalViserS = 0.0,
    this.corrVent = 0.0,
    this.corrTb = 0.0,
    this.corrDb = 0.0,
    this.corrV0 = 0.0,
    this.corrRtc = 0.0,
    this.corrMasse = 0.0,
    this.corrDz = 0.0,
    this.eclDzSeconds = 0.0,
    this.dcfsSeconds = 0.0,
    this.tempageFinalS = 0.0,
  });
}

class TempageService {
  const TempageService();

  Future<TempageResult> compute({
    required String typeAssets,
    required String charge,
    required bool tirMontagne,
    required double distanceCorrigeeM,
    required double porteeViserM,
    required double deniveleeM,
    required double ventLongKn,
    required bool ventArriere,
    required double dtbPercent,
    required double ddbPercent,
    required double deltaV0,
    required double tempMunitionC,
    required Object fusee,
    required double deltaMasseCarreaux,
  }) async {
    throw UnsupportedError(
      'Tempage calculation is unavailable in this compatibility build.',
    );
  }

  Future<TempageResult> computeDepotage({
    required String typeAssets,
    required String charge,
    required double tempsEntreeS,
    required double tempsNominalViserS,
    required double correctionDeniveleePar100mS,
    required double deniveleeM,
    required double ventLongKn,
    required bool ventArriere,
    required double dtbPercent,
    required double ddbPercent,
    required double deltaV0,
    required double tempMunitionC,
  }) async {
    throw UnsupportedError(
      'Tempage calculation is unavailable in this compatibility build.',
    );
  }
}

class TableauTempageService {
  final String typeTir;
  final String charge;
  final bool verbose;

  const TableauTempageService({
    required this.typeTir,
    required this.charge,
    this.verbose = false,
  });

  Future<void> load() async {
    throw UnsupportedError(
      'Tempage table loading is unavailable in this compatibility build.',
    );
  }

  Future<double> getTempageAt(int distanceM) async {
    throw UnsupportedError(
      'Tempage lookup is unavailable in this compatibility build.',
    );
  }
}
