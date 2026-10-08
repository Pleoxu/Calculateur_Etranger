// lib/services/balistique_core_result.dart
//
// PHASE 2D — CORE RESULT (stable DTO)
// DTO commun Appui / AppuiRTC / OECL.
// Tous les champs sont optionnels (avec défauts) pour migration douce.
//
// IMPORTANT : les noms des paramètres doivent matcher ceux utilisés dans
// BalistiqueCoreService (metAzMil, metVKn, metTbK, metPressHpa, etc).

import '../models/calcul_data.dart' show TypeTir;

class BalistiqueCoreResult {
  // -----------------------------
  // Identité / contexte
  // -----------------------------
  final String typeAssets; // "Appui", "AppuiRTC", "OECL"
  final TypeTir typeEnum; // enum
  final bool tirMontagne;
  final String charge;

  // -----------------------------
  // Géométrie
  // -----------------------------
  final double distanceTopoM;
  final double deniveleeM;
  final double azimutMil;
  final double latitudePieceDeg;

  // -----------------------------
  // Tableau B
  // -----------------------------
  final double correctionSiteBM; // m
  final int niveauMeteoBUsed;
  final double distanceCorrigeeM; // distanceTopo + corrSite

  // -----------------------------
  // Météo (niveau B sélectionné)
  // -----------------------------
  final double? metAzMil; // direction vent (mil)
  final double? metVKn; // vitesse vent (kn)
  final double? metTbK; // TB (K)
  final double? metPressHpa; // pression (hPa)

  // -----------------------------
  // Transversal
  // -----------------------------
  final double deriveMil;
  final double rotzMilAbs;
  final double wzMil;
  final double totalCorrectionAzimutMil;
  final double noireMil;

  // -----------------------------
  // Longitudinal
  // -----------------------------
  final double wxM;
  final double rotxM;
  final double masseM;

  // Corrections météo portée (m)
  final double deltaTBM;
  final double deltaPBM;

  // Doctrine (signés, utilisés par Tempage OECL)
  final double deltaTbPctSigned; // ΔTB% signé
  final double deltaDbPctSigned; // ΔDB% (ΔPB%) signé
  final double deltaV0MpsSigned; // ΔV0 total signé (m/s)

  // Vent longitudinal utile tempage
  final double ventLongKnAbs; // abs en kn
  final bool ventArriere;

  // Usure / v0 portée
  final double deltaV0M;

  // RTC portée (m)
  final double rtcM;

  // Totaux portée
  final double totalLongM;
  final double porteeAViserM;

  // AE
  final double aeMil;

  // OECL optionnels
  final double? corrEclPour50mMil;
  final double? corrEclDeniveleeMil;

  const BalistiqueCoreResult({
    // identité
    required this.typeAssets,
    required this.typeEnum,
    required this.tirMontagne,
    required this.charge,

    // géométrie
    required this.distanceTopoM,
    required this.deniveleeM,
    required this.azimutMil,
    required this.latitudePieceDeg,

    // tableau B
    required this.correctionSiteBM,
    required this.niveauMeteoBUsed,
    required this.distanceCorrigeeM,

    // météo (✅ ces noms doivent exister)
    this.metAzMil,
    this.metVKn,
    this.metTbK,
    this.metPressHpa,

    // transversal
    this.deriveMil = 0.0,
    this.rotzMilAbs = 0.0,
    this.wzMil = 0.0,
    this.totalCorrectionAzimutMil = 0.0,
    this.noireMil = 0.0,

    // longitudinal
    this.wxM = 0.0,
    this.rotxM = 0.0,
    this.masseM = 0.0,

    // météo portée
    this.deltaTBM = 0.0,
    this.deltaPBM = 0.0,

    // doctrine signée
    this.deltaTbPctSigned = 0.0,
    this.deltaDbPctSigned = 0.0,
    this.deltaV0MpsSigned = 0.0,

    // vent tempage
    this.ventLongKnAbs = 0.0,
    this.ventArriere = false,

    // v0/rtc
    this.deltaV0M = 0.0,
    this.rtcM = 0.0,

    // totaux
    this.totalLongM = 0.0,
    this.porteeAViserM = 0.0,

    // AE
    this.aeMil = 0.0,

    // OECL
    this.corrEclPour50mMil,
    this.corrEclDeniveleeMil,
  });

  @override
  String toString() {
    return 'BalistiqueCoreResult('
        'typeAssets=$typeAssets, typeEnum=$typeEnum, charge=$charge, montagne=$tirMontagne, '
        'dTopo=${distanceTopoM.toStringAsFixed(1)}, dCorr=${distanceCorrigeeM.toStringAsFixed(1)}, '
        'noire=${noireMil.toStringAsFixed(2)}, portee=${porteeAViserM.toStringAsFixed(1)}'
        ')';
  }
}
