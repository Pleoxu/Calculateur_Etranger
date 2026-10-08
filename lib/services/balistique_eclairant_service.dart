// lib/services/balistique_eclairant_service.dart
//
// PHASE 2D — OECL (éclairant) via CORE + AQE/ECL + TEMPAGE
import 'package:flutter/foundation.dart';
import '../domain/fire/services/ballistic_asset_context.dart';
import '../models/calcul_data.dart';
import 'package:calculateur_etranger/services/balistique_core_result.dart';
import 'package:calculateur_etranger/services/balistique_core_service.dart';
import 'tableau_ecl_service.dart';
import 'tempage_service.dart';

class BalistiqueEclairantService {
  const BalistiqueEclairantService._();
  static double _round1(double v) => (v * 10.0).roundToDouble() / 10.0;
  static Future<CalculResult> calculer(CalculInput input) async {
    final sw = Stopwatch()..start();
    if (input.typeTir != TypeTir.eclairant) {
      throw StateError(
        'BalistiqueEclairantService called with typeTir=${input.typeTir}',
      );
    }

    final assetContext = BallisticAssetContext(
      systeme: input.systeme,
      typeTir: input.typeTir,
      typeChargeCaesar: input.typeChargeCaesar,
      typeMunition: input.typeMunition,
      m252MunitionFamily: input.m252MunitionFamily,
    );
    final typeAssets = assetContext.variant;

    final BalistiqueCoreResult core = await BalistiqueCoreService.compute(
      input,
      typeEnum: TypeTir.eclairant,
      typeAssets: typeAssets,
    );

    final eclService = TableauEclService(
      typeTir: typeAssets,
      charge: core.charge,
      tirMontagne: core.tirMontagne,
      verbose: false,
    );

    final double corrEclPour50mMilRaw = await eclService.corrHaussePar50mMil(
      distanceM: core.porteeAViserM,
    );

    final double corrEclPour50mMil = _round1(corrEclPour50mMilRaw);

    final double corrEclDeniveleeMil = _round1(
      corrEclPour50mMil * (core.deniveleeM / 50.0),
    );

    final double aqeMil = core.aeMil + corrEclDeniveleeMil;

    final double tempMunitionC = input.simTempActC ?? 21.0;

    final TypeFusee fusee = input.fusee ??
        (throw UnsupportedError(
          'An explicit fuze is required in this compatibility build.',
        ));
    final bool isArt385Fuchsia =
        typeAssets == 'OECL_ART385' && fusee == TypeFusee.fuchsia;

    final TempageResult t = await const TempageService().compute(
      typeAssets: typeAssets,
      charge: core.charge,
      tirMontagne: core.tirMontagne,
      distanceCorrigeeM: core.distanceCorrigeeM,
      porteeViserM: core.porteeAViserM,
      deniveleeM: core.deniveleeM,
      ventLongKn: input.meteoOn ? core.ventLongKnAbs : 0.0,
      ventArriere: core.ventArriere,
      dtbPercent: input.meteoOn ? core.deltaTbPctSigned : 0.0,
      ddbPercent: input.meteoOn ? core.deltaDbPctSigned : 0.0,
      deltaV0: core.deltaV0MpsSigned,
      tempMunitionC: tempMunitionC,
      fusee: fusee,
      deltaMasseCarreaux: isArt385Fuchsia ? -0.48 : 0.0,
    );

    final tempageDetails = TempageDetails(
      tNominal: t.tempageNominalViserS,
      deltaTvent: t.corrVent,
      deltaTTb: t.corrTb,
      deltaTPb: t.corrDb,
      deltaTV0: t.corrV0,
      deltaTMun: t.corrRtc,
      deltaTMasse: t.corrMasse,
      deltaTEvent50m: 0.0,
      deltaTDenivelee: t.eclDzSeconds,
      tFusee: t.tempageFinalS,
    );

    final double? deltaZStationM = (input.meteoStationAltM != null)
        ? (input.pdZ - input.meteoStationAltM!)
        : null;

    if (kDebugMode) {
      debugPrint(
        '[OECL] corePortee=${core.porteeAViserM.toStringAsFixed(0)} '
        'AE=${core.aeMil.toStringAsFixed(2)} '
        'ECL50=$corrEclPour50mMil '
        'ΔZ=${core.deniveleeM.toStringAsFixed(0)} '
        'ECLΔ=${corrEclDeniveleeMil.toStringAsFixed(1)} '
        '-> AQE=${aqeMil.toStringAsFixed(2)}',
      );
      debugPrint(
        '[OECL] TEMPAGE fusee=$fusee '
        'deltaMasseCarreaux=${isArt385Fuchsia ? -0.48 : 0.0} '
        'final=${tempageDetails.tFusee.toStringAsFixed(2)}s',
      );
      debugPrint(
        '[OECL:LATERAL FROM CORE] '
        'azimuth=${core.azimutMil} drift=${core.deriveMil} '
        'rotZ=${core.rotzMilAbs} wzMil=${core.wzMil} '
        'totalAz=${core.totalCorrectionAzimutMil} '
        'noire=${core.noireMil}',
      );
      debugPrint('[OECL PERF] ${sw.elapsedMilliseconds} ms');
    }

    return CalculResult(
      portee: core.porteeAViserM,
      noireMil: core.noireMil,
      charge: core.charge,
      typeAssets: typeAssets,
      tempsVolS: tempageDetails.tFusee,
      tempageDetails: tempageDetails,
      aqeMil: aqeMil,
      deriveMil: core.deriveMil,
      rotzMilAbs: core.rotzMilAbs,
      wzMil: core.wzMil,
      totalCorrectionAzimutMil: core.totalCorrectionAzimutMil,
      aeMil: core.aeMil,
      siteBrutMil: 0.0,
      corrSiteVraiMil: 0.0,
      siteTotalAsMil: 0.0,
      acsMil: 0.0,
      wxM: core.wxM,
      rotxM: core.rotxM,
      masseM: core.masseM,
      deltaV0M: core.deltaV0M,
      deltaTBM: core.deltaTBM,
      deltaPBM: core.deltaPBM,
      rtcM: core.rtcM,
      totalLongM: core.totalLongM,
      corrEclPour50mMil: corrEclPour50mMil,
      corrEclDeniveleeMil: corrEclDeniveleeMil,
      latitudePieceDeg: core.latitudePieceDeg,
      distanceTopoM: core.distanceTopoM,
      azimutMil: core.azimutMil,
      deniveleeM: core.deniveleeM,
      correctionSiteBM: core.correctionSiteBM,
      niveauMeteoBUsed: core.niveauMeteoBUsed,
      deltaZStationM: deltaZStationM ?? 0.0,
    );
  }
}
