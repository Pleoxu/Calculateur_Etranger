// lib/services/balistique_service.dart
//
// Orchestrateur : route vers les pipelines dédiés.

import '../models/calcul_data.dart';

import 'balistique_appui_service.dart';
import 'balistique_bonus_service.dart';
import 'balistique_eclairant_service.dart';
import 'balistique_mo120_appui_service.dart';
import 'balistique_mo120_eclairant_service.dart';
import 'balistique_mo81_m252_appui_service.dart';
import 'balistique_mo81_m252_m853a1_service.dart';
import 'balistique_mo81_m252_m819_service.dart';
import 'balistique_mo81_llr_appui_service.dart';
import 'balistique_mo81_llr_eclairant_service.dart';

class BalistiqueService {
  const BalistiqueService._();

  static Future<CalculResult> calculer(CalculInput input) {
    if (input.systeme == Systeme.mo81M252) {
      switch (input.typeTir) {
        case TypeTir.appui:
          if (input.m252MunitionFamily == M252MunitionFamily.rpM819) {
            return BalistiqueMo81M252M819Service.calculer(input);
          }
          return BalistiqueMo81M252AppuiService.calculer(input);
        case TypeTir.appuiRtc:
          throw UnsupportedError(
            'RTC calculation is not connected in this compatibility build.',
          );
        case TypeTir.eclairant:
          if (input.m252MunitionFamily == M252MunitionFamily.illM853a1) {
            return BalistiqueMo81M252M853A1Service.calculer(input);
          }
          throw UnsupportedError('M252 illuminating tables are not loaded.');
      }
    }

    if (input.systeme == Systeme.mo81Lrr) {
      switch (input.typeTir) {
        case TypeTir.appui:
          return BalistiqueMo81LlrAppuiService.calculer(input);
        case TypeTir.appuiRtc:
          throw UnsupportedError(
            'RTC calculation is not connected in this compatibility build.',
          );
        case TypeTir.eclairant:
          return BalistiqueMo81LlrEclairantService.calculer(input);
      }
    }

    if (input.systeme == Systeme.mo120) {
      switch (input.typeTir) {
        case TypeTir.appui:
          return BalistiqueMo120AppuiService.calculer(input);
        case TypeTir.appuiRtc:
          throw UnsupportedError(
            'RTC calculation is not connected in this compatibility build.',
          );
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
      case TypeTir.appuiRtc:
        throw UnsupportedError(
          'RTC calculation is not connected in this compatibility build.',
        );
      case TypeTir.eclairant:
        return BalistiqueEclairantService.calculer(input);
    }
  }
}
