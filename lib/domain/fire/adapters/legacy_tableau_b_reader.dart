// lib/domain/fire/adapters/legacy_tableau_b_reader.dart

import 'package:calculateur_etranger/domain/fire/ports/tableau_b_reader.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/services/tableau_b_service.dart'
    as legacy_b;

class LegacyTableauBReader implements TableauBReader {
  const LegacyTableauBReader();

  String _typeAssetsFor(TypeTir typeTir) {
    switch (typeTir) {
      case TypeTir.appui:
        return 'Appui';
      case TypeTir.appuiRtc:
        throw UnsupportedError(
          'RTC ballistic-table lookup is not connected in this compatibility build.',
        );
      case TypeTir.eclairant:
        return 'OECL';
    }
  }

  @override
  Future<TableauBCorrection?> findCorrection({
    required TypeTir typeTir,
    required String charge,
    required double distance,
    required double denivelee,
    required bool tirMontagne,
  }) async {
    final service = legacy_b.TableauBService(
      typeTir: _typeAssetsFor(typeTir),
      charge: charge,
      tirMontagne: tirMontagne,
    );

    final row = await service.chercher(
      distanceTopoM: distance,
      deniveleeM: denivelee,
    );

    if (row == null) return null;

    return TableauBCorrection(
      corrSiteM: row.correctionSiteM,
      niveauB: row.niveauMeteo,
    );
  }
}
