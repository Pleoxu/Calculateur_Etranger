import 'package:calculateur_etranger/models/calcul_data.dart';

class TableauBCorrection {
  final double corrSiteM;
  final int? niveauB;

  const TableauBCorrection({required this.corrSiteM, required this.niveauB});
}

abstract class TableauBReader {
  const TableauBReader();

  Future<TableauBCorrection?> findCorrection({
    required TypeTir typeTir,
    required String charge,
    required double distance,
    required double denivelee,
    required bool tirMontagne,
  });
}
