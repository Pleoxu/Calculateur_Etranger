// lib/services/balistique_service.dart
//
// Orchestrateur : route vers les pipelines dédiés.

import '../models/calcul_data.dart';

import 'balistique_appui_service.dart';
import 'balistique_bonus_service.dart';
import 'balistique_eclairant_service.dart';
import 'balistique_mo120_appui_service.dart';
import 'balistique_mo120_eclairant_service.dart';
import 'balistique_mo81_llr_appui_service.dart';
import 'balistique_mo81_llr_eclairant_service.dart';
import 'ballistic_table_maintenance.dart';

class BalistiqueService {
  const BalistiqueService._();

  static Future<CalculResult> calculer(CalculInput input) {
    // MO81 L16 / éclairant : les tables A à F sont explicitement isolées
    // jusqu'à la fin de leur maintenance. Ne jamais laisser ce couple tomber
    // dans le pipeline générique OECL.
    BallisticTableMaintenance.ensureCalculationAvailable(input);

    if (input.systeme == Systeme.mo81Lrr) {
      switch (input.typeTir) {
        case TypeTir.appui:
          return BalistiqueMo81LlrAppuiService.calculer(input);
        case TypeTir.eclairant:
          return BalistiqueMo81LlrEclairantService.calculer(input);
      }
    }

    if (input.systeme == Systeme.mo120) {
      switch (input.typeTir) {
        case TypeTir.appui:
          return BalistiqueMo120AppuiService.calculer(input);
        case TypeTir.eclairant:
          return BalistiqueMo120EclairantService.calculer(input);
      }
    }

    switch (input.typeTir) {
      case TypeTir.appui:
        if (input.systeme == Systeme.caesar &&
            input.typeMunition == TypeMunition.bonusFr) {
          return BalistiqueBonusService.calculer(input);
        }
        return BalistiqueAppuiService.calculer(input);
      case TypeTir.eclairant:
        return BalistiqueEclairantService.calculer(input);
    }
  }
}
