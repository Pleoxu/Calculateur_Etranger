// lib/models/calcul_data.dart

import 'package:flutter/foundation.dart';
import 'package:calculateur_etranger/domain/entities/meteo_row.dart';
import 'package:calculateur_etranger/domain/fire/models/type_charge_caesar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CLASSES & STRUCTURES DE CALCUL (RÉSULTATS ET ENTRÉES)
// ─────────────────────────────────────────────────────────────────────────────

/// Détails de tempage pour les fusées et éclairants.
@immutable
class TempageDetails {
  final double tNominal;
  final double deltaTvent;
  final double deltaTTb;
  final double deltaTPb;
  final double deltaTV0;
  final double deltaTMun;
  final double deltaTMasse;
  final double deltaTEvent50m;
  final double totalCorrectionsGlobal;
  final double deltaTDenivelee;
  final double tFusee;

  const TempageDetails({
    this.tNominal = 0.0,
    this.deltaTvent = 0.0,
    this.deltaTTb = 0.0,
    this.deltaTPb = 0.0,
    this.deltaTV0 = 0.0,
    this.deltaTMun = 0.0,
    this.deltaTMasse = 0.0,
    this.deltaTEvent50m = 0.0,
    this.totalCorrectionsGlobal = 0.0,
    this.deltaTDenivelee = 0.0,
    this.tFusee = 0.0,
  });
}

/// Résultat issu d'une opération ou d'un pipeline de calcul balistique.
@immutable
class CalculResult {
  final double hausseMil;
  final double azimutMil;
  final double gisementMil;
  final double tempsVolS;
  final double flecheM;
  final double porteeM;
  final double porteeCorrigeeM;
  final double portee;
  final double distanceTopoM;
  final double deniveleeM;
  final double vitesseInitialeMs;
  final double vitesseRestanteMps;
  final String charge;
  final String chargeLabel;
  final String messageErreur;
  final Map<String, dynamic> details;

  // Dérivations & corrections spécifiques UI / DÉCOMPOSITION
  final double aeMil;
  final double aqeMil;
  final double noireMil;
  final double deriveMil;
  final double rotzMilAbs;
  final double wzMil;
  final double wxM;
  final double deltaTBM;
  final double deltaPBM;
  final double deltaV0M;
  final double masseM;
  final double rtcM;
  final double rotxM;
  final double totalCorrectionAzimutMil;
  final double totalLongM;
  final double siteBrutMil;
  final double corrSiteVraiMil;
  final double siteTotalAsMil;
  final double acsMil;
  final double correctionSiteBM;
  final double deltaZStationM;
  final double latitudePieceDeg;
  final double corrEclPour50mMil;
  final double corrEclDeniveleeMil;
  final double ecartProbablePorteeM;
  final double ecartProbableDirectionM;
  final double angleChuteDeg;
  final double cotangenteAngleChute;
  final int niveauMeteoBUsed;
  final String typeAssets;
  final TempageDetails? tempageDetails;

  const CalculResult({
    this.hausseMil = 0.0,
    this.azimutMil = 0.0,
    this.gisementMil = 0.0,
    this.tempsVolS = 0.0,
    this.flecheM = 0.0,
    this.porteeM = 0.0,
    this.porteeCorrigeeM = 0.0,
    double? portee,
    this.distanceTopoM = 0.0,
    this.deniveleeM = 0.0,
    this.vitesseInitialeMs = 0.0,
    this.vitesseRestanteMps = 0.0,
    this.charge = '',
    this.chargeLabel = '',
    this.messageErreur = '',
    this.details = const {},
    this.aeMil = 0.0,
    this.aqeMil = 0.0,
    this.noireMil = 0.0,
    this.deriveMil = 0.0,
    this.rotzMilAbs = 0.0,
    this.wzMil = 0.0,
    this.wxM = 0.0,
    this.deltaTBM = 0.0,
    this.deltaPBM = 0.0,
    this.deltaV0M = 0.0,
    this.masseM = 0.0,
    this.rtcM = 0.0,
    this.rotxM = 0.0,
    this.totalCorrectionAzimutMil = 0.0,
    this.totalLongM = 0.0,
    this.siteBrutMil = 0.0,
    this.corrSiteVraiMil = 0.0,
    this.siteTotalAsMil = 0.0,
    this.acsMil = 0.0,
    this.correctionSiteBM = 0.0,
    this.deltaZStationM = 0.0,
    this.latitudePieceDeg = 0.0,
    this.corrEclPour50mMil = 0.0,
    this.corrEclDeniveleeMil = 0.0,
    this.ecartProbablePorteeM = 0.0,
    this.ecartProbableDirectionM = 0.0,
    this.angleChuteDeg = 0.0,
    this.cotangenteAngleChute = 0.0,
    this.niveauMeteoBUsed = 0,
    this.typeAssets = '',
    this.tempageDetails,
  }) : portee = portee ?? (porteeCorrigeeM != 0.0 ? porteeCorrigeeM : porteeM);

  bool get estValide => messageErreur.isEmpty;

  bool get isOECL => typeAssets.toUpperCase().contains('OECL');

  String get chargeStr => chargeLabel.isNotEmpty ? chargeLabel : charge;

  String get tempsFormate => '${tempsVolS.toStringAsFixed(1)}s';

  CalculResult copyWith({
    double? hausseMil,
    double? azimutMil,
    double? gisementMil,
    double? tempsVolS,
    double? flecheM,
    double? porteeM,
    double? porteeCorrigeeM,
    double? portee,
    double? distanceTopoM,
    double? deniveleeM,
    double? vitesseInitialeMs,
    double? vitesseRestanteMps,
    String? charge,
    String? chargeLabel,
    String? messageErreur,
    Map<String, dynamic>? details,
    double? aeMil,
    double? aqeMil,
    double? noireMil,
    double? deriveMil,
    double? rotzMilAbs,
    double? wzMil,
    double? wxM,
    double? deltaTBM,
    double? deltaPBM,
    double? deltaV0M,
    double? masseM,
    double? rtcM,
    double? rotxM,
    double? totalCorrectionAzimutMil,
    double? totalLongM,
    double? siteBrutMil,
    double? corrSiteVraiMil,
    double? siteTotalAsMil,
    double? acsMil,
    double? correctionSiteBM,
    double? deltaZStationM,
    double? latitudePieceDeg,
    double? corrEclPour50mMil,
    double? corrEclDeniveleeMil,
    double? ecartProbablePorteeM,
    double? ecartProbableDirectionM,
    double? angleChuteDeg,
    double? cotangenteAngleChute,
    int? niveauMeteoBUsed,
    String? typeAssets,
    TempageDetails? tempageDetails,
  }) {
    return CalculResult(
      hausseMil: hausseMil ?? this.hausseMil,
      azimutMil: azimutMil ?? this.azimutMil,
      gisementMil: gisementMil ?? this.gisementMil,
      tempsVolS: tempsVolS ?? this.tempsVolS,
      flecheM: flecheM ?? this.flecheM,
      porteeM: porteeM ?? this.porteeM,
      porteeCorrigeeM: porteeCorrigeeM ?? this.porteeCorrigeeM,
      portee: portee ?? this.portee,
      distanceTopoM: distanceTopoM ?? this.distanceTopoM,
      deniveleeM: deniveleeM ?? this.deniveleeM,
      vitesseInitialeMs: vitesseInitialeMs ?? this.vitesseInitialeMs,
      vitesseRestanteMps: vitesseRestanteMps ?? this.vitesseRestanteMps,
      charge: charge ?? this.charge,
      chargeLabel: chargeLabel ?? this.chargeLabel,
      messageErreur: messageErreur ?? this.messageErreur,
      details: details ?? this.details,
      aeMil: aeMil ?? this.aeMil,
      aqeMil: aqeMil ?? this.aqeMil,
      noireMil: noireMil ?? this.noireMil,
      deriveMil: deriveMil ?? this.deriveMil,
      rotzMilAbs: rotzMilAbs ?? this.rotzMilAbs,
      wzMil: wzMil ?? this.wzMil,
      wxM: wxM ?? this.wxM,
      deltaTBM: deltaTBM ?? this.deltaTBM,
      deltaPBM: deltaPBM ?? this.deltaPBM,
      deltaV0M: deltaV0M ?? this.deltaV0M,
      masseM: masseM ?? this.masseM,
      rtcM: rtcM ?? this.rtcM,
      rotxM: rotxM ?? this.rotxM,
      totalCorrectionAzimutMil:
          totalCorrectionAzimutMil ?? this.totalCorrectionAzimutMil,
      totalLongM: totalLongM ?? this.totalLongM,
      siteBrutMil: siteBrutMil ?? this.siteBrutMil,
      corrSiteVraiMil: corrSiteVraiMil ?? this.corrSiteVraiMil,
      siteTotalAsMil: siteTotalAsMil ?? this.siteTotalAsMil,
      acsMil: acsMil ?? this.acsMil,
      correctionSiteBM: correctionSiteBM ?? this.correctionSiteBM,
      deltaZStationM: deltaZStationM ?? this.deltaZStationM,
      latitudePieceDeg: latitudePieceDeg ?? this.latitudePieceDeg,
      corrEclPour50mMil: corrEclPour50mMil ?? this.corrEclPour50mMil,
      corrEclDeniveleeMil: corrEclDeniveleeMil ?? this.corrEclDeniveleeMil,
      ecartProbablePorteeM: ecartProbablePorteeM ?? this.ecartProbablePorteeM,
      ecartProbableDirectionM:
          ecartProbableDirectionM ?? this.ecartProbableDirectionM,
      angleChuteDeg: angleChuteDeg ?? this.angleChuteDeg,
      cotangenteAngleChute: cotangenteAngleChute ?? this.cotangenteAngleChute,
      niveauMeteoBUsed: niveauMeteoBUsed ?? this.niveauMeteoBUsed,
      typeAssets: typeAssets ?? this.typeAssets,
      tempageDetails: tempageDetails ?? this.tempageDetails,
    );
  }
}

/// Ensemble complet des paramètres d'entrée pour exécuter un calcul de tir.
@immutable
class CalculInput {
  final Systeme systeme;
  final TypeTir typeTir;
  final TypeMunition typeMunition;
  final TypeChargeCaesar typeChargeCaesar;
  final M252MunitionFamily? m252MunitionFamily;
  final LrrMunitionFamily? lrrMunitionFamily;
  final TypeFusee fusee;
  final double distanceM;
  final double deltaAltitudeM;
  final double azimutObjectifMil;
  final int? carreaux;
  final String? chargeForcee;
  final bool tirVertical;
  final NatureTirSelection natureTir;
  final MeteoRow? meteo;
  final List<MeteoRow>? meteoRows;

  // Propriétés géographiques & pièces
  final double pdX;
  final double pdY;
  final double pdZ;
  final String pdZone;
  final bool isUtmPd;
  final double pdLatitudeDeg;

  final double objX;
  final double objY;
  final double objZ;
  final bool isUtmObj;
  final double objA;
  final double objD;
  final double objAlt;
  final NatureObjectif? natureObjectif;

  // Simulation, météo & paramètres additionnels
  final int carreauxMasseObus;
  final bool meteoOn;
  final double meteoStationAltM;
  final int niveauMeteoB;
  final double? meteoAzVentMil;
  final double? meteoVKn;
  final double? metTempPercent;
  final double? metPressPercent;
  final bool tirMontagne;
  final double simCarreaux;
  final double simFusee;
  final double simTempActC;
  final double simTempPrevC;
  final double simV0Prev;
  final dynamic autresPieces;

  const CalculInput({
    this.systeme = Systeme.caesar,
    this.typeTir = TypeTir.appui,
    this.typeMunition = TypeMunition.oeF5Fr,
    this.typeChargeCaesar = TypeChargeCaesar.fr,
    this.m252MunitionFamily,
    this.lrrMunitionFamily,
    this.fusee = TypeFusee.frappe,
    this.distanceM = 0.0,
    this.deltaAltitudeM = 0.0,
    this.azimutObjectifMil = 0.0,
    this.carreaux,
    this.chargeForcee,
    this.tirVertical = false,
    this.natureTir = const NatureTirSelection(),
    this.meteo,
    this.meteoRows,
    this.pdX = 0.0,
    this.pdY = 0.0,
    this.pdZ = 0.0,
    this.pdZone = '',
    this.isUtmPd = false,
    this.pdLatitudeDeg = 0.0,
    this.objX = 0.0,
    this.objY = 0.0,
    this.objZ = 0.0,
    this.isUtmObj = false,
    this.objA = 0.0,
    this.objD = 0.0,
    this.objAlt = 0.0,
    this.natureObjectif,
    this.carreauxMasseObus = 0,
    this.meteoOn = false,
    this.meteoStationAltM = 0.0,
    this.niveauMeteoB = 0,
    this.meteoAzVentMil,
    this.meteoVKn,
    this.metTempPercent,
    this.metPressPercent,
    this.tirMontagne = false,
    this.simCarreaux = 0.0,
    this.simFusee = 0.0,
    this.simTempActC = 0.0,
    this.simTempPrevC = 0.0,
    this.simV0Prev = 0.0,
    this.autresPieces,
  });

  /// Getter de compatibilité
  TypeMunition get munition => typeMunition;

  CalculInput copyWith({
    Systeme? systeme,
    TypeTir? typeTir,
    TypeMunition? typeMunition,
    TypeChargeCaesar? typeChargeCaesar,
    M252MunitionFamily? m252MunitionFamily,
    LrrMunitionFamily? lrrMunitionFamily,
    TypeFusee? fusee,
    double? distanceM,
    double? deltaAltitudeM,
    double? azimutObjectifMil,
    int? carreaux,
    String? chargeForcee,
    bool? tirVertical,
    NatureTirSelection? natureTir,
    MeteoRow? meteo,
    List<MeteoRow>? meteoRows,
    double? pdX,
    double? pdY,
    double? pdZ,
    String? pdZone,
    bool? isUtmPd,
    double? pdLatitudeDeg,
    double? objX,
    double? objY,
    double? objZ,
    bool? isUtmObj,
    double? objA,
    double? objD,
    double? objAlt,
    NatureObjectif? natureObjectif,
    int? carreauxMasseObus,
    bool? meteoOn,
    double? meteoStationAltM,
    int? niveauMeteoB,
    double? meteoAzVentMil,
    double? meteoVKn,
    double? metTempPercent,
    double? metPressPercent,
    bool? tirMontagne,
    double? simCarreaux,
    double? simFusee,
    double? simTempActC,
    double? simTempPrevC,
    double? simV0Prev,
    dynamic autresPieces,
  }) {
    return CalculInput(
      systeme: systeme ?? this.systeme,
      typeTir: typeTir ?? this.typeTir,
      typeMunition: typeMunition ?? this.typeMunition,
      typeChargeCaesar: typeChargeCaesar ?? this.typeChargeCaesar,
      m252MunitionFamily: m252MunitionFamily ?? this.m252MunitionFamily,
      lrrMunitionFamily: lrrMunitionFamily ?? this.lrrMunitionFamily,
      fusee: fusee ?? this.fusee,
      distanceM: distanceM ?? this.distanceM,
      deltaAltitudeM: deltaAltitudeM ?? this.deltaAltitudeM,
      azimutObjectifMil: azimutObjectifMil ?? this.azimutObjectifMil,
      carreaux: carreaux ?? this.carreaux,
      chargeForcee: chargeForcee ?? this.chargeForcee,
      tirVertical: tirVertical ?? this.tirVertical,
      natureTir: natureTir ?? this.natureTir,
      meteo: meteo ?? this.meteo,
      meteoRows: meteoRows ?? this.meteoRows,
      pdX: pdX ?? this.pdX,
      pdY: pdY ?? this.pdY,
      pdZ: pdZ ?? this.pdZ,
      pdZone: pdZone ?? this.pdZone,
      isUtmPd: isUtmPd ?? this.isUtmPd,
      pdLatitudeDeg: pdLatitudeDeg ?? this.pdLatitudeDeg,
      objX: objX ?? this.objX,
      objY: objY ?? this.objY,
      objZ: objZ ?? this.objZ,
      isUtmObj: isUtmObj ?? this.isUtmObj,
      objA: objA ?? this.objA,
      objD: objD ?? this.objD,
      objAlt: objAlt ?? this.objAlt,
      natureObjectif: natureObjectif ?? this.natureObjectif,
      carreauxMasseObus: carreauxMasseObus ?? this.carreauxMasseObus,
      meteoOn: meteoOn ?? this.meteoOn,
      meteoStationAltM: meteoStationAltM ?? this.meteoStationAltM,
      niveauMeteoB: niveauMeteoB ?? this.niveauMeteoB,
      meteoAzVentMil: meteoAzVentMil ?? this.meteoAzVentMil,
      meteoVKn: meteoVKn ?? this.meteoVKn,
      metTempPercent: metTempPercent ?? this.metTempPercent,
      metPressPercent: metPressPercent ?? this.metPressPercent,
      tirMontagne: tirMontagne ?? this.tirMontagne,
      simCarreaux: simCarreaux ?? this.simCarreaux,
      simFusee: simFusee ?? this.simFusee,
      simTempActC: simTempActC ?? this.simTempActC,
      simTempPrevC: simTempPrevC ?? this.simTempPrevC,
      simV0Prev: simV0Prev ?? this.simV0Prev,
      autresPieces: autresPieces ?? this.autresPieces,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS & TYPES SYSTÈMES
// ─────────────────────────────────────────────────────────────────────────────

enum Systeme { caesar, mepac, mo120, mo81M252, mo81Lrr }

extension SystemeX on Systeme {
  String get label {
    switch (this) {
      case Systeme.caesar:
        return 'CAESAR';
      case Systeme.mepac:
        return 'MEPAC';
      case Systeme.mo120:
        return 'MO-120';
      case Systeme.mo81M252:
        return 'MO81 M252';
      case Systeme.mo81Lrr:
        return 'MO81 LLR';
    }
  }

  bool get calculConnecte {
    switch (this) {
      case Systeme.caesar:
      case Systeme.mepac:
      case Systeme.mo120:
      case Systeme.mo81Lrr:
        return true;
      case Systeme.mo81M252:
        return false;
    }
  }

  Systeme get next {
    switch (this) {
      case Systeme.caesar:
        return Systeme.mepac;
      case Systeme.mepac:
        return Systeme.mo120;
      case Systeme.mo120:
        return Systeme.mo81M252;
      case Systeme.mo81M252:
        return Systeme.mo81Lrr;
      case Systeme.mo81Lrr:
        return Systeme.caesar;
    }
  }

  List<TypeTir> get typesDisponibles {
    switch (this) {
      case Systeme.caesar:
        return TypeTir.values;
      case Systeme.mepac:
      case Systeme.mo120:
      case Systeme.mo81M252:
      case Systeme.mo81Lrr:
        return const <TypeTir>[TypeTir.appui, TypeTir.eclairant];
    }
  }

  double get diametreEfficaciteM {
    switch (this) {
      case Systeme.caesar:
        return 100.0;
      case Systeme.mepac:
      case Systeme.mo120:
        return 50.0;
      case Systeme.mo81Lrr:
      case Systeme.mo81M252:
        return 35.0;
    }
  }

  double get diametreEfficaciteAfficheM {
    switch (this) {
      case Systeme.caesar:
        return 100.0;
      case Systeme.mepac:
      case Systeme.mo120:
        return 50.0;
      case Systeme.mo81M252:
      case Systeme.mo81Lrr:
        return 35.0;
    }
  }

  int get carreauxReference {
    switch (this) {
      case Systeme.caesar:
        return 4;
      case Systeme.mepac:
      case Systeme.mo120:
        return 2;
      case Systeme.mo81M252:
      case Systeme.mo81Lrr:
        throw UnsupportedError(
          'carreauxReference unavailable for a disconnected MO81 system.',
        );
    }
  }

  (int, int) get carreauxPlage {
    switch (this) {
      case Systeme.caesar:
        return (1, 8);
      case Systeme.mepac:
      case Systeme.mo120:
        return (1, 3);
      case Systeme.mo81M252:
      case Systeme.mo81Lrr:
        throw UnsupportedError(
          'carreauxPlage unavailable for a disconnected MO81 system.',
        );
    }
  }

  bool get tirVerticalParDefaut {
    switch (this) {
      case Systeme.caesar:
        return false;
      case Systeme.mepac:
      case Systeme.mo120:
      case Systeme.mo81Lrr:
      case Systeme.mo81M252:
        return true;
    }
  }

  String get labelTirVertical {
    switch (this) {
      case Systeme.caesar:
        return 'Vertical fire';
      case Systeme.mepac:
      case Systeme.mo120:
        return 'Branche basse';
      case Systeme.mo81M252:
      case Systeme.mo81Lrr:
        return 'Branche';
    }
  }
}

enum TypeTir { appui, eclairant }

/// Catalogue UI du MO81 M252 avec alias de compatibilité.
enum M252MunitionFamily {
  m821,
  m821a1,
  m821a2,
  m889,
  m889a1,
  tpM879,
  rpM819,
  illM853a1;

  static const M252MunitionFamily he = M252MunitionFamily.m821a1;
  static const M252MunitionFamily rsmk = M252MunitionFamily.rpM819;
  static const M252MunitionFamily tp = M252MunitionFamily.tpM879;
  static const M252MunitionFamily illum = M252MunitionFamily.illM853a1;
  static const M252MunitionFamily irIllum = M252MunitionFamily.illM853a1;
}

extension M252MunitionFamilyX on M252MunitionFamily {
  String get label {
    switch (this) {
      case M252MunitionFamily.m821:
        return 'M821';
      case M252MunitionFamily.m821a1:
        return 'M821A1';
      case M252MunitionFamily.m821a2:
        return 'M821A2';
      case M252MunitionFamily.m889:
        return 'M889';
      case M252MunitionFamily.m889a1:
        return 'M889A1';
      case M252MunitionFamily.tpM879:
        return 'TP M879';
      case M252MunitionFamily.rpM819:
        return 'RP M819';
      case M252MunitionFamily.illM853a1:
        return 'ILL M853A1';
    }
  }

  String get defaultFuze {
    switch (this) {
      case M252MunitionFamily.m821:
      case M252MunitionFamily.m821a1:
        return 'M734';
      case M252MunitionFamily.m821a2:
        return 'M734A1';
      case M252MunitionFamily.m889:
      case M252MunitionFamily.m889a1:
        return 'M935';
      case M252MunitionFamily.tpM879:
        return 'M751';
      case M252MunitionFamily.rpM819:
      case M252MunitionFamily.illM853a1:
        return 'M772';
    }
  }
}

List<M252MunitionFamily> m252MunitionsDisponiblesPour(TypeTir typeTir) {
  switch (typeTir) {
    case TypeTir.appui:
      return const <M252MunitionFamily>[
        M252MunitionFamily.m821a1,
        M252MunitionFamily.m821a2,
        M252MunitionFamily.m821,
        M252MunitionFamily.m889a1,
        M252MunitionFamily.m889,
        M252MunitionFamily.tpM879,
        M252MunitionFamily.rpM819,
      ];
    case TypeTir.eclairant:
      return const <M252MunitionFamily>[
        M252MunitionFamily.illM853a1,
      ];
  }
}

enum LrrMunitionFamily { he, smk, prac, illum, illumIr }

extension LrrMunitionFamilyX on LrrMunitionFamily {
  String get label {
    switch (this) {
      case LrrMunitionFamily.he:
        return 'HE';
      case LrrMunitionFamily.smk:
        return 'SMK';
      case LrrMunitionFamily.prac:
        return 'PRAC';
      case LrrMunitionFamily.illum:
        return 'ILLUM';
      case LrrMunitionFamily.illumIr:
        return 'ILLUM-IR';
    }
  }
}

List<LrrMunitionFamily> lrrMunitionsDisponiblesPour(TypeTir typeTir) {
  switch (typeTir) {
    case TypeTir.appui:
      return const <LrrMunitionFamily>[
        LrrMunitionFamily.he,
        LrrMunitionFamily.smk,
        LrrMunitionFamily.prac,
      ];
    case TypeTir.eclairant:
      return const <LrrMunitionFamily>[
        LrrMunitionFamily.illum,
        LrrMunitionFamily.illumIr,
      ];
  }
}

enum TypeMunition {
  oe155F1Fr,
  oe155F2Fr,
  oeF5Fr,
  oeF8Fr,
  bonusFr,
  oeSemonceF6Fr,
  ofum155F2AFr,
  ox155F1Fr,
  oeF5All,
  oeclF1Fr,
  oeclF2RtcFr,
  oeclF2ReductionCulotFr,
  oeclF1All,
  oe81F1,
  oe81Fa32,
  oe81F2,
  ofum81Fa32,
  ox81F1,
  ox81F2,
  oecl81F1,
  oecl81F3,
  oeclIr81F2,
  oe120F1,
  ofum120F1,
  ox120F1,
  oecl120F1,
  @Deprecated('Utiliser oeF5Fr ou oeF5All.')
  oe155F5,
  @Deprecated('Utiliser oeclF1Fr ou oeclF1All.')
  oecl155F1,
  @Deprecated('Utiliser oeclF2RtcFr.')
  oecl155F2Rtc,
}

@immutable
class MunitionDefinition {
  final String label;
  final TypeTir typeTir;
  final TypeChargeCaesar typeChargeCaesar;
  final String? artReference;
  final bool isRtc;
  final bool isEclairante;
  final String? fuseeReference;
  final bool fuchsiaOnly;
  final FuseeCompatibility fuseeCompatibility;
  final bool isLegacy;

  const MunitionDefinition({
    required this.label,
    required this.typeTir,
    required this.typeChargeCaesar,
    required this.artReference,
    required this.isRtc,
    required this.isEclairante,
    this.fuseeReference,
    this.fuchsiaOnly = false,
    this.fuseeCompatibility = FuseeCompatibility.frappeEtRalec,
    this.isLegacy = false,
  });
}

const Map<TypeMunition, MunitionDefinition> munitionDefinitions = {
  TypeMunition.oe155F1Fr: MunitionDefinition(
    label: 'OE 155 F1',
    typeTir: TypeTir.appui,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: 'ART387',
    isRtc: false,
    isEclairante: false,
    fuseeCompatibility: FuseeCompatibility.frappeEtRalec,
  ),
  TypeMunition.oe155F2Fr: MunitionDefinition(
    label: 'OE 155 F2',
    typeTir: TypeTir.appui,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: 'ART387',
    isRtc: false,
    isEclairante: false,
    fuseeCompatibility: FuseeCompatibility.frappeEtRalec,
  ),
  TypeMunition.oeF5Fr: MunitionDefinition(
    label: 'OE 155 F5',
    typeTir: TypeTir.appui,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: 'ART390',
    isRtc: false,
    isEclairante: false,
  ),
  TypeMunition.oeF8Fr: MunitionDefinition(
    label: 'OE 155 F8',
    typeTir: TypeTir.appui,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: 'ART390',
    isRtc: false,
    isEclairante: false,
  ),
  TypeMunition.bonusFr: MunitionDefinition(
    label: 'OE 155 BONUS',
    typeTir: TypeTir.appui,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: 'ART389',
    isRtc: true,
    isEclairante: false,
  ),
  TypeMunition.oeSemonceF6Fr: MunitionDefinition(
    label: 'OSMC 155 F6',
    typeTir: TypeTir.appui,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: 'ART390',
    isRtc: false,
    isEclairante: false,
  ),
  TypeMunition.ofum155F2AFr: MunitionDefinition(
    label: 'OFUM 155 F2A',
    typeTir: TypeTir.appui,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: 'ART387',
    isRtc: false,
    isEclairante: false,
    fuseeCompatibility: FuseeCompatibility.frappeEtRalec,
  ),
  TypeMunition.ox155F1Fr: MunitionDefinition(
    label: 'OX 155 F1',
    typeTir: TypeTir.appui,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: 'ART387',
    isRtc: false,
    isEclairante: false,
    fuseeCompatibility: FuseeCompatibility.frappeEtRalec,
  ),
  TypeMunition.oeF5All: MunitionDefinition(
    label: 'OE F5 ALL',
    typeTir: TypeTir.appui,
    typeChargeCaesar: TypeChargeCaesar.allemande,
    artReference: 'ART378',
    isRtc: false,
    isEclairante: false,
  ),
  TypeMunition.oeclF1Fr: MunitionDefinition(
    label: 'OECL 155 F1',
    typeTir: TypeTir.eclairant,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: 'ART385',
    isRtc: false,
    isEclairante: true,
    fuseeReference: 'FU DE F2',
    fuchsiaOnly: false,
    fuseeCompatibility: FuseeCompatibility.art385,
  ),
  TypeMunition.oeclF2RtcFr: MunitionDefinition(
    label: 'OECL 155 F2 RTC',
    typeTir: TypeTir.eclairant,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: 'ART392',
    isRtc: true,
    isEclairante: true,
    fuchsiaOnly: true,
    fuseeCompatibility: FuseeCompatibility.fuchsiaUniquement,
  ),
  TypeMunition.oeclF2ReductionCulotFr: MunitionDefinition(
    label: 'OECL 155 F2 RTC',
    typeTir: TypeTir.eclairant,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: 'ART392',
    isRtc: true,
    isEclairante: true,
    fuchsiaOnly: true,
    fuseeCompatibility: FuseeCompatibility.fuchsiaUniquement,
  ),
  TypeMunition.oeclF1All: MunitionDefinition(
    label: 'OECL F1 ALL',
    typeTir: TypeTir.eclairant,
    typeChargeCaesar: TypeChargeCaesar.allemande,
    artReference: 'ART376',
    isRtc: false,
    isEclairante: true,
    fuseeCompatibility: FuseeCompatibility.fuchsiaUniquement,
  ),
  TypeMunition.oe81F1: MunitionDefinition(
    label: 'OE 81 F1',
    typeTir: TypeTir.appui,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: null,
    isRtc: false,
    isEclairante: false,
  ),
  TypeMunition.oe81Fa32: MunitionDefinition(
    label: 'OE 81 FA32',
    typeTir: TypeTir.appui,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: null,
    isRtc: false,
    isEclairante: false,
  ),
  TypeMunition.oe81F2: MunitionDefinition(
    label: 'OE 81 F2',
    typeTir: TypeTir.appui,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: null,
    isRtc: false,
    isEclairante: false,
  ),
  TypeMunition.ofum81Fa32: MunitionDefinition(
    label: 'OFUM 81 FA32',
    typeTir: TypeTir.appui,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: null,
    isRtc: false,
    isEclairante: false,
  ),
  TypeMunition.ox81F1: MunitionDefinition(
    label: 'OX 81 F1',
    typeTir: TypeTir.appui,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: null,
    isRtc: false,
    isEclairante: false,
  ),
  TypeMunition.ox81F2: MunitionDefinition(
    label: 'OX 81 F2',
    typeTir: TypeTir.appui,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: null,
    isRtc: false,
    isEclairante: false,
  ),
  TypeMunition.oecl81F1: MunitionDefinition(
    label: 'OECL 81 F1',
    typeTir: TypeTir.eclairant,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: null,
    isRtc: false,
    isEclairante: true,
  ),
  TypeMunition.oecl81F3: MunitionDefinition(
    label: 'OECL 81 F3',
    typeTir: TypeTir.eclairant,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: null,
    isRtc: false,
    isEclairante: true,
  ),
  TypeMunition.oeclIr81F2: MunitionDefinition(
    label: 'OECL IR 81 F2',
    typeTir: TypeTir.eclairant,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: null,
    isRtc: false,
    isEclairante: true,
  ),
  TypeMunition.oe120F1: MunitionDefinition(
    label: 'OE 120 F1',
    typeTir: TypeTir.appui,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: null,
    isRtc: false,
    isEclairante: false,
    fuseeCompatibility: FuseeCompatibility.mo120Appui,
  ),
  TypeMunition.ofum120F1: MunitionDefinition(
    label: 'OFUM 120 F1',
    typeTir: TypeTir.appui,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: null,
    isRtc: false,
    isEclairante: false,
    fuseeCompatibility: FuseeCompatibility.mo120Appui,
  ),
  TypeMunition.ox120F1: MunitionDefinition(
    label: 'OX 120 F1',
    typeTir: TypeTir.appui,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: null,
    isRtc: false,
    isEclairante: false,
    fuseeCompatibility: FuseeCompatibility.mo120Appui,
  ),
  TypeMunition.oecl120F1: MunitionDefinition(
    label: 'OECL 120 F1',
    typeTir: TypeTir.eclairant,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: null,
    isRtc: false,
    isEclairante: true,
    fuseeCompatibility: FuseeCompatibility.mo120Eclairant,
  ),
  TypeMunition.oe155F5: MunitionDefinition(
    label: 'OE F5',
    typeTir: TypeTir.appui,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: null,
    isRtc: false,
    isEclairante: false,
    isLegacy: true,
  ),
  TypeMunition.oecl155F1: MunitionDefinition(
    label: 'OECL F1',
    typeTir: TypeTir.eclairant,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: null,
    isRtc: false,
    isEclairante: true,
    fuseeCompatibility: FuseeCompatibility.fuchsiaUniquement,
    isLegacy: true,
  ),
  TypeMunition.oecl155F2Rtc: MunitionDefinition(
    label: 'OECL F2 RTC',
    typeTir: TypeTir.eclairant,
    typeChargeCaesar: TypeChargeCaesar.fr,
    artReference: null,
    isRtc: false,
    isEclairante: true,
    fuseeCompatibility: FuseeCompatibility.fuchsiaUniquement,
    isLegacy: true,
  ),
};

extension TypeMunitionX on TypeMunition {
  MunitionDefinition get definition {
    final value = munitionDefinitions[this];
    assert(value != null, 'Ammunition definition missing for $this');
    return value!;
  }

  String get label => definition.label;
  TypeTir get typeTir => definition.typeTir;
  TypeChargeCaesar get typeChargeCaesar => definition.typeChargeCaesar;
  String? get artReference => definition.artReference;
  bool get isRtc => definition.isRtc;
  bool get isEclairante => definition.isEclairante;
  String? get fuseeReference => definition.fuseeReference;
  bool get fuchsiaOnly => definition.fuchsiaOnly;
  FuseeCompatibility get fuseeCompatibility => definition.fuseeCompatibility;
  bool get isLegacy => definition.isLegacy;
}

List<TypeMunition> munitionsDisponiblesPour({
  required Systeme systeme,
  required TypeTir typeTir,
}) {
  if (systeme == Systeme.mo81Lrr) {
    switch (typeTir) {
      case TypeTir.appui:
        return const <TypeMunition>[
          TypeMunition.oe81F1,
          TypeMunition.oe81Fa32,
          TypeMunition.oe81F2,
          TypeMunition.ofum81Fa32,
          TypeMunition.ox81F1,
          TypeMunition.ox81F2,
        ];
      case TypeTir.eclairant:
        return const <TypeMunition>[
          TypeMunition.oecl81F1,
          TypeMunition.oecl81F3,
          TypeMunition.oeclIr81F2,
        ];
    }
  }

  if (systeme == Systeme.mo120) {
    switch (typeTir) {
      case TypeTir.appui:
        return const <TypeMunition>[
          TypeMunition.oe120F1,
          TypeMunition.ofum120F1,
          TypeMunition.ox120F1,
        ];
      case TypeTir.eclairant:
        return const <TypeMunition>[TypeMunition.oecl120F1];
    }
  }

  if (systeme != Systeme.caesar) {
    return const <TypeMunition>[];
  }

  switch (typeTir) {
    case TypeTir.appui:
      return const <TypeMunition>[
        TypeMunition.oe155F1Fr,
        TypeMunition.oe155F2Fr,
        TypeMunition.oeF5Fr,
        TypeMunition.oeF8Fr,
        TypeMunition.bonusFr,
        TypeMunition.oeSemonceF6Fr,
        TypeMunition.ofum155F2AFr,
        TypeMunition.ox155F1Fr,
      ];
    case TypeTir.eclairant:
      return const <TypeMunition>[
        TypeMunition.oeclF1Fr,
        TypeMunition.oeclF2ReductionCulotFr,
      ];
  }
}

TypeMunition? munitionParDefautPour({
  required Systeme systeme,
  required TypeTir typeTir,
}) {
  final disponibles = munitionsDisponiblesPour(
    systeme: systeme,
    typeTir: typeTir,
  );

  if (disponibles.isEmpty) {
    return null;
  }

  if (systeme == Systeme.mo81Lrr) {
    switch (typeTir) {
      case TypeTir.appui:
        return TypeMunition.oe81F2;
      case TypeTir.eclairant:
        return TypeMunition.oecl81F1;
    }
  }

  if (systeme == Systeme.mo120) {
    switch (typeTir) {
      case TypeTir.appui:
        return TypeMunition.oe120F1;
      case TypeTir.eclairant:
        return TypeMunition.oecl120F1;
    }
  }

  switch (typeTir) {
    case TypeTir.appui:
      return TypeMunition.oeF5Fr;
    case TypeTir.eclairant:
      return TypeMunition.oeclF1Fr;
  }
}

enum NatureObjectif { ponctuel, lineaire, surface }

enum TypeFusee { frappe, ralec, fuDeF2, fuchsia, fuRalec120F4, pdm557, fr55B }

extension TypeFuseeX on TypeFusee {
  String get label {
    switch (this) {
      case TypeFusee.frappe:
        return 'Frappe';
      case TypeFusee.ralec:
        return 'Ralec';
      case TypeFusee.fuDeF2:
        return 'FU DE F2';
      case TypeFusee.fuchsia:
        return 'FUCHSIA';
      case TypeFusee.fuRalec120F4:
        return 'FU RALEC 120 F4';
      case TypeFusee.pdm557:
        return 'PDM 557';
      case TypeFusee.fr55B:
        return 'FR 55 B';
    }
  }

  int? get masseGNullable {
    switch (this) {
      case TypeFusee.frappe:
        return 730;
      case TypeFusee.ralec:
        return 630;
      case TypeFusee.fuDeF2:
        return null;
      case TypeFusee.fuchsia:
        return 710;
      case TypeFusee.fuRalec120F4:
      case TypeFusee.pdm557:
      case TypeFusee.fr55B:
        return null;
    }
  }

  int get masseG {
    final value = masseGNullable;
    if (value == null) {
      throw StateError(
        'Fuze mass not defined for $this: use system-specific logic.',
      );
    }
    return value;
  }
}

@immutable
class FuseeCompatibility {
  final List<TypeFusee> autorisees;
  final TypeFusee reference;

  const FuseeCompatibility({required this.autorisees, required this.reference});

  bool get estVerrouillee => autorisees.length == 1;

  bool accepte(TypeFusee fusee) => autorisees.contains(fusee);

  TypeFusee normalise(TypeFusee fusee) {
    return accepte(fusee) ? fusee : reference;
  }

  static const frappeEtRalec = FuseeCompatibility(
    autorisees: [TypeFusee.frappe, TypeFusee.ralec],
    reference: TypeFusee.frappe,
  );

  static const frappeUniquement = FuseeCompatibility(
    autorisees: [TypeFusee.frappe],
    reference: TypeFusee.frappe,
  );

  static const mo120Appui = FuseeCompatibility(
    autorisees: [TypeFusee.fuRalec120F4, TypeFusee.pdm557],
    reference: TypeFusee.fuRalec120F4,
  );

  static const mo120Eclairant = FuseeCompatibility(
    autorisees: [TypeFusee.fr55B],
    reference: TypeFusee.fr55B,
  );

  static const art385 = FuseeCompatibility(
    autorisees: [TypeFusee.fuDeF2, TypeFusee.fuchsia],
    reference: TypeFusee.fuDeF2,
  );

  static const fuchsiaUniquement = FuseeCompatibility(
    autorisees: [TypeFusee.fuchsia],
    reference: TypeFusee.fuchsia,
  );
}

FuseeCompatibility fuseeCompatibilityPour({
  required Systeme systeme,
  required TypeTir typeTir,
  TypeMunition? munition,
}) {
  final effectiveMunition =
      munition ?? munitionParDefautPour(systeme: systeme, typeTir: typeTir);

  if (effectiveMunition != null) {
    return effectiveMunition.fuseeCompatibility;
  }

  if (systeme == Systeme.mo120) {
    switch (typeTir) {
      case TypeTir.appui:
        return FuseeCompatibility.mo120Appui;
      case TypeTir.eclairant:
        return FuseeCompatibility.mo120Eclairant;
    }
  }

  if (typeTir == TypeTir.eclairant) {
    return FuseeCompatibility.fuchsiaUniquement;
  }

  return FuseeCompatibility.frappeEtRalec;
}

// ─────────────────────────────────────────────────────────────────────────────
// NATURE DE TIR (LOGIQUE & UI)
// ─────────────────────────────────────────────────────────────────────────────

enum NatureTirType { ponctuel, lineaire, zonal }

enum PointApplicationLineaire { gauche, centre, droite, extremite }

enum PointZonal { coin, milieu, centre }

enum ZonalMode { otan, force }

/// Sélection Nature du tir (UI)
@immutable
class NatureTirSelection {
  final bool enabled;
  final NatureTirType nature;
  final int? nbCoups;
  final double? longueurM;
  final double? longueurZonaleM;
  final double? profondeurM;
  final PointApplicationLineaire? pointApplicationLineaire;
  final PointZonal? pointZonal;
  final ZonalMode zonalMode;
  final int? lineairePar;
  final double? azimutMil;
  final double? azimutLargeurMil;
  final double? azimutProfondeurMil;
  final double? pourcentageDebordement;
  final double? pourcentageRecouvrement;
  final bool salvesEnabled;
  final int salvesPreferenceIdx;
  final bool lastSalveAroundPd;

  const NatureTirSelection({
    this.enabled = false,
    this.nature = NatureTirType.ponctuel,
    this.nbCoups,
    this.longueurM,
    this.longueurZonaleM,
    this.profondeurM,
    this.pointApplicationLineaire,
    this.pointZonal,
    this.zonalMode = ZonalMode.otan,
    this.lineairePar,
    this.azimutMil,
    this.azimutLargeurMil,
    this.azimutProfondeurMil,
    this.pourcentageDebordement,
    this.pourcentageRecouvrement,
    this.salvesEnabled = false,
    this.salvesPreferenceIdx = 0,
    this.lastSalveAroundPd = true,
  });

  NatureTirSelection copyWith({
    bool? enabled,
    NatureTirType? nature,
    int? nbCoups,
    double? longueurM,
    double? longueurZonaleM,
    double? profondeurM,
    PointApplicationLineaire? pointApplicationLineaire,
    PointZonal? pointZonal,
    ZonalMode? zonalMode,
    int? lineairePar,
    double? azimutMil,
    double? azimutLargeurMil,
    double? azimutProfondeurMil,
    double? pourcentageDebordement,
    double? pourcentageRecouvrement,
    bool? salvesEnabled,
    int? salvesPreferenceIdx,
    bool? lastSalveAroundPd,
  }) {
    return NatureTirSelection(
      enabled: enabled ?? this.enabled,
      nature: nature ?? this.nature,
      nbCoups: nbCoups ?? this.nbCoups,
      longueurM: longueurM ?? this.longueurM,
      longueurZonaleM: longueurZonaleM ?? this.longueurZonaleM,
      profondeurM: profondeurM ?? this.profondeurM,
      pointApplicationLineaire:
          pointApplicationLineaire ?? this.pointApplicationLineaire,
      pointZonal: pointZonal ?? this.pointZonal,
      zonalMode: zonalMode ?? this.zonalMode,
      lineairePar: lineairePar ?? this.lineairePar,
      azimutMil: azimutMil ?? this.azimutMil,
      azimutLargeurMil: azimutLargeurMil ?? this.azimutLargeurMil,
      azimutProfondeurMil: azimutProfondeurMil ?? this.azimutProfondeurMil,
      pourcentageDebordement:
          pourcentageDebordement ?? this.pourcentageDebordement,
      pourcentageRecouvrement:
          pourcentageRecouvrement ?? this.pourcentageRecouvrement,
      salvesEnabled: salvesEnabled ?? this.salvesEnabled,
      salvesPreferenceIdx: salvesPreferenceIdx ?? this.salvesPreferenceIdx,
      lastSalveAroundPd: lastSalveAroundPd ?? this.lastSalveAroundPd,
    );
  }
}
