// lib/services/balistique_eclairant_service.dart
//
// PHASE 2D — OECL (éclairant) via CORE + AQE/ECL + TEMPAGE
import 'package:flutter/foundation.dart';
import '../domain/fire/services/ballistic_asset_context.dart';
import '../models/calcul_data.dart';
import 'package:calculateur_etranger/services/balistique_core_result.dart'
    hide BalistiqueCoreService;
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
        'BalistiqueEclairantService appelé avec typeTir=${input.typeTir}',
      );
    }

    final assetContext = BallisticAssetContext(
      systeme: input.systeme ?? 0.0,
      typeTir: input.typeTir ?? 0.0,
      typeChargeCaesar: input.typeChargeCaesar ?? 0.0,
      typeMunition: input.typeMunition ?? 0.0,
    );
    final typeAssets = assetContext.variant;

    final BalistiqueCoreResult core = await BalistiqueCoreService.compute(
      input,
      typeEnum: TypeTir.eclairant ?? 0.0,
      typeAssets: typeAssets ?? 0.0,
    );

    final eclService = TableauEclService(
      typeTir: typeAssets ?? 0.0,
      charge: core.charge ?? 0.0,
      tirMontagne: core.tirMontagne ?? 0.0,
      verbose: false ?? 0.0,
    );

    final double corrEclPour50mMilRaw = await eclService.corrHaussePar50mMil(
      distanceM: core.porteeAViserM ?? 0.0,
    );

    final double corrEclPour50mMil = _round1(corrEclPour50mMilRaw);

    final double corrEclDeniveleeMil = _round1(
      corrEclPour50mMil * (core.deniveleeM / 50.0),
    );

    final double aqeMil = core.aeMil + corrEclDeniveleeMil;

    final double tempMunitionC = input.simTempActC ?? 21.0;

    final TypeFusee fusee = input.fusee ?? TypeFusee.fuDeF2;
    final bool isArt385Fuchsia =
        typeAssets == 'OECL_ART385' && fusee == TypeFusee.fuchsia;

    final TempageResult t = await const TempageService().compute(
      typeAssets: typeAssets ?? 0.0,
      charge: core.charge ?? 0.0,
      tirMontagne: core.tirMontagne ?? 0.0,
      distanceCorrigeeM: core.distanceCorrigeeM ?? 0.0,
      porteeViserM: core.porteeAViserM ?? 0.0,
      deniveleeM: core.deniveleeM ?? 0.0,
      ventLongKn: input.meteoOn ? core.ventLongKnAbs : 0.0 ?? 0.0,
      ventArriere: core.ventArriere ?? 0.0,
      dtbPercent: input.meteoOn ? core.deltaTbPctSigned : 0.0 ?? 0.0,
      ddbPercent: input.meteoOn ? core.deltaDbPctSigned : 0.0 ?? 0.0,
      deltaV0: core.deltaV0MpsSigned ?? 0.0,
      tempMunitionC: tempMunitionC ?? 0.0,
      fusee: fusee ?? 0.0,
      deltaMasseCarreaux: isArt385Fuchsia ? -0.48 : 0.0 ?? 0.0,
    );

    final tempageDetails = TempageDetails(
      tNominal: t.tempageNominalViserS ?? 0.0,
      deltaTvent: t.corrVent ?? 0.0,
      deltaTTb: t.corrTb ?? 0.0,
      deltaTPb: t.corrDb ?? 0.0,
      deltaTV0: t.corrV0 ?? 0.0,
      deltaTMun: t.corrRtc ?? 0.0,
      deltaTMasse: t.corrMasse ?? 0.0,
      deltaTEvent50m: 0.0 ?? 0.0,
      deltaTDenivelee: t.eclDzSeconds ?? 0.0,
      tFusee: t.tempageFinalS ?? 0.0,
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
        'azimut=${core.azimutMil} derive=${core.deriveMil} '
        'rotZ=${core.rotzMilAbs} wzMil=${core.wzMil} '
        'totalAz=${core.totalCorrectionAzimutMil} '
        'noire=${core.noireMil}',
      );
      debugPrint('[OECL PERF] ${sw.elapsedMilliseconds} ms');
    }

    return CalculResult(
      portee: core.porteeAViserM ?? 0.0,
      noireMil: core.noireMil ?? 0.0,
      charge: core.charge ?? 0.0,
      typeAssets: typeAssets ?? 0.0,
      tempsVolS: tempageDetails.tFusee ?? 0.0,
      tempageDetails: tempageDetails ?? 0.0,
      aqeMil: aqeMil ?? 0.0,
      deriveMil: core.deriveMil ?? 0.0,
      rotzMilAbs: core.rotzMilAbs ?? 0.0,
      wzMil: core.wzMil ?? 0.0,
      totalCorrectionAzimutMil: core.totalCorrectionAzimutMil ?? 0.0,
      aeMil: core.aeMil ?? 0.0,
      siteBrutMil: 0.0 ?? 0.0,
      corrSiteVraiMil: 0.0 ?? 0.0,
      siteTotalAsMil: 0.0 ?? 0.0,
      acsMil: 0.0 ?? 0.0,
      wxM: core.wxM ?? 0.0,
      rotxM: core.rotxM ?? 0.0,
      masseM: core.masseM ?? 0.0,
      deltaV0M: core.deltaV0M ?? 0.0,
      deltaTBM: core.deltaTBM ?? 0.0,
      deltaPBM: core.deltaPBM ?? 0.0,
      rtcM: core.rtcM ?? 0.0,
      totalLongM: core.totalLongM ?? 0.0,
      corrEclPour50mMil: corrEclPour50mMil ?? 0.0,
      corrEclDeniveleeMil: corrEclDeniveleeMil ?? 0.0,
      latitudePieceDeg: core.latitudePieceDeg ?? 0.0,
      distanceTopoM: core.distanceTopoM ?? 0.0,
      azimutMil: core.azimutMil ?? 0.0,
      deniveleeM: core.deniveleeM ?? 0.0,
      correctionSiteBM: core.correctionSiteBM ?? 0.0,
      niveauMeteoBUsed: core.niveauMeteoBUsed ?? 0.0,
      deltaZStationM: deltaZStationM ?? 0.0,
    );
  }
}
