import 'package:calculateur_etranger/domain/entities/meteo_row.dart';
import 'package:calculateur_etranger/domain/fire/models/type_charge_caesar.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';

enum FireTargetMode { utm, daz, latLon }

enum FireNature { ponctuel, lineaire, zonal }

enum FireLinearReferencePoint { center, extremity, left, right }

enum FireLinearFiringMode {
  libre,
  sectionWithPd,
  sectionWithoutPd,
  batteryWithPd,
}

class FireRequest {
  final Systeme systeme;
  final TypeTir typeTir;
  final TypeMunition? typeMunition;

  /// Famille de munition M252 choisie dans l'interface.
  ///
  /// Le profil Part 6 / CH3 raccordé couvre M821A1/M734 et M821A2/M734A1.
  final M252MunitionFamily? m252MunitionFamily;
  final TypeChargeCaesar typeChargeCaesar;
  final TypeFusee? fusee;

  final FirePieceInput piece;
  final FireTargetInput target;

  final bool tirVertical;
  final bool forcerCharge;
  final int? chargeForcee;

  /// Charge forcée en String pour MO-120 (ex. 'CH0', 'CH1/2').
  /// Prioritaire sur [chargeForcee] quand non null.
  final String? chargeForceeStr;

  final FireDoctrineInput doctrine;
  final FireSalvoOptions salves;

  final bool masseEnabled;
  final int carreaux;

  final bool tirSimilaire;
  final int simCarreaux;
  final TypeFusee? simFusee;
  final double? tPrev;
  final double? tAct;
  final double? v0Prev;

  final FireMeteoInput? meteo;

  final List<FireSupportPieceInput> supportPieces;

  const FireRequest({
    required this.systeme,
    required this.typeTir,
    this.typeMunition,
    this.m252MunitionFamily,
    this.typeChargeCaesar = TypeChargeCaesar.fr,
    required this.piece,
    required this.target,
    required this.doctrine,
    required this.salves,
    required this.tirVertical,
    required this.forcerCharge,
    required this.masseEnabled,
    required this.carreaux,
    required this.tirSimilaire,
    required this.simCarreaux,
    this.simFusee,
    this.fusee,
    this.chargeForcee,
    this.chargeForceeStr,
    this.tPrev,
    this.tAct,
    this.v0Prev,
    this.meteo,
    this.supportPieces = const [],
  });

  FireRequest copyWith({
    Systeme? systeme,
    TypeTir? typeTir,
    TypeMunition? typeMunition,
    M252MunitionFamily? m252MunitionFamily,
    TypeChargeCaesar? typeChargeCaesar,
    TypeFusee? fusee,
    FirePieceInput? piece,
    FireTargetInput? target,
    bool? tirVertical,
    bool? forcerCharge,
    int? chargeForcee,
    String? chargeForceeStr,
    FireDoctrineInput? doctrine,
    FireSalvoOptions? salves,
    bool? masseEnabled,
    int? carreaux,
    bool? tirSimilaire,
    int? simCarreaux,
    TypeFusee? simFusee,
    double? tPrev,
    double? tAct,
    double? v0Prev,
    FireMeteoInput? meteo,
    List<FireSupportPieceInput>? supportPieces,
  }) {
    return FireRequest(
      systeme: systeme ?? this.systeme,
      typeTir: typeTir ?? this.typeTir,
      typeMunition: typeMunition ?? this.typeMunition,
      m252MunitionFamily: m252MunitionFamily ?? this.m252MunitionFamily,
      typeChargeCaesar: typeChargeCaesar ?? this.typeChargeCaesar,
      fusee: fusee ?? this.fusee,
      piece: piece ?? this.piece,
      target: target ?? this.target,
      tirVertical: tirVertical ?? this.tirVertical,
      forcerCharge: forcerCharge ?? this.forcerCharge,
      chargeForcee: chargeForcee ?? this.chargeForcee,
      chargeForceeStr: chargeForceeStr ?? this.chargeForceeStr,
      doctrine: doctrine ?? this.doctrine,
      salves: salves ?? this.salves,
      masseEnabled: masseEnabled ?? this.masseEnabled,
      carreaux: carreaux ?? this.carreaux,
      tirSimilaire: tirSimilaire ?? this.tirSimilaire,
      simCarreaux: simCarreaux ?? this.simCarreaux,
      simFusee: simFusee ?? this.simFusee,
      tPrev: tPrev ?? this.tPrev,
      tAct: tAct ?? this.tAct,
      v0Prev: v0Prev ?? this.v0Prev,
      meteo: meteo ?? this.meteo,
      supportPieces: supportPieces ?? this.supportPieces,
    );
  }
}

class FirePieceInput {
  final double? utmX;
  final double? utmY;
  final double? altitude;
  final String? utmZone;

  final double? latitude;
  final double? longitude;

  const FirePieceInput({
    this.utmX,
    this.utmY,
    this.altitude,
    this.utmZone,
    this.latitude,
    this.longitude,
  });

  FirePieceInput copyWith({
    double? utmX,
    double? utmY,
    double? altitude,
    String? utmZone,
    double? latitude,
    double? longitude,
  }) {
    return FirePieceInput(
      utmX: utmX ?? this.utmX,
      utmY: utmY ?? this.utmY,
      altitude: altitude ?? this.altitude,
      utmZone: utmZone ?? this.utmZone,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

class FireTargetInput {
  final FireTargetMode mode;

  final double? utmX;
  final double? utmY;
  final double? altitude;

  final double? distanceM;
  final double? azimutMil;

  final double? latitude;
  final double? longitude;

  const FireTargetInput({
    required this.mode,
    this.utmX,
    this.utmY,
    this.altitude,
    this.distanceM,
    this.azimutMil,
    this.latitude,
    this.longitude,
  });

  FireTargetInput copyWith({
    FireTargetMode? mode,
    double? utmX,
    double? utmY,
    double? altitude,
    double? distanceM,
    double? azimutMil,
    double? latitude,
    double? longitude,
  }) {
    return FireTargetInput(
      mode: mode ?? this.mode,
      utmX: utmX ?? this.utmX,
      utmY: utmY ?? this.utmY,
      altitude: altitude ?? this.altitude,
      distanceM: distanceM ?? this.distanceM,
      azimutMil: azimutMil ?? this.azimutMil,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

class FireDoctrineInput {
  final FireNature nature;
  final FireShotPlanInput shotPlan;
  final FireZonalDoctrineInput zonal;
  final FireLinearDoctrineInput lineaire;

  const FireDoctrineInput({
    required this.nature,
    required this.shotPlan,
    this.zonal = const FireZonalDoctrineInput(),
    this.lineaire = const FireLinearDoctrineInput(),
  });

  int get nbCoups => shotPlan.nbCoups;
  int get par => shotPlan.par;
  Map<String, int> get coupsParPiece => shotPlan.coupsParPiece;

  FireDoctrineInput copyWith({
    FireNature? nature,
    FireShotPlanInput? shotPlan,
    FireZonalDoctrineInput? zonal,
    FireLinearDoctrineInput? lineaire,
  }) {
    return FireDoctrineInput(
      nature: nature ?? this.nature,
      shotPlan: shotPlan ?? this.shotPlan,
      zonal: zonal ?? this.zonal,
      lineaire: lineaire ?? this.lineaire,
    );
  }
}

class FireShotPlanInput {
  final int nbCoups;
  final int par;
  final Map<String, int> coupsParPiece;

  const FireShotPlanInput({
    required this.nbCoups,
    required this.par,
    this.coupsParPiece = const {},
  });

  FireShotPlanInput copyWith({
    int? nbCoups,
    int? par,
    Map<String, int>? coupsParPiece,
  }) {
    return FireShotPlanInput(
      nbCoups: nbCoups ?? this.nbCoups,
      par: par ?? this.par,
      coupsParPiece: coupsParPiece ?? this.coupsParPiece,
    );
  }
}

class FireZonalDoctrineInput {
  final double? longueurM;
  final double? profondeurM;

  final double? debordementPct;
  final double? recouvrementPct;

  final ZonalMode zonalMode;
  final PointZonal? pointZonal;
  final double? azimutLargeurMil;
  final double? azimutProfondeurMil;

  /// Vrai uniquement pour les presets UI Neutralisation/Interdiction/Destruction
  /// (100×100, 150×150 ou 200×200) afin d'éviter que le moteur zonal
  /// hardcodé ou standard ne recalcule le nombre de coups.
  final bool isZonalPreset;

  const FireZonalDoctrineInput({
    this.longueurM,
    this.profondeurM,
    this.debordementPct,
    this.recouvrementPct,
    this.zonalMode = ZonalMode.otan,
    this.pointZonal,
    this.azimutLargeurMil,
    this.azimutProfondeurMil,
    this.isZonalPreset = false,
  });

  FireZonalDoctrineInput copyWith({
    double? longueurM,
    double? profondeurM,
    double? debordementPct,
    double? recouvrementPct,
    ZonalMode? zonalMode,
    PointZonal? pointZonal,
    double? azimutLargeurMil,
    double? azimutProfondeurMil,
    bool? isZonalPreset,
  }) {
    return FireZonalDoctrineInput(
      longueurM: longueurM ?? this.longueurM,
      profondeurM: profondeurM ?? this.profondeurM,
      debordementPct: debordementPct ?? this.debordementPct,
      recouvrementPct: recouvrementPct ?? this.recouvrementPct,
      zonalMode: zonalMode ?? this.zonalMode,
      pointZonal: pointZonal ?? this.pointZonal,
      azimutLargeurMil: azimutLargeurMil ?? this.azimutLargeurMil,
      azimutProfondeurMil: azimutProfondeurMil ?? this.azimutProfondeurMil,
      isZonalPreset: isZonalPreset ?? this.isZonalPreset,
    );
  }
}

class FireLinearDoctrineInput {
  final double? longueurM;
  final FireLinearReferencePoint? referencePoint;
  final double? azimutLineaireMil;
  final FireLinearFiringMode firingMode;
  final List<String> selectedRoles;

  const FireLinearDoctrineInput({
    this.longueurM,
    this.referencePoint,
    this.azimutLineaireMil,
    this.firingMode = FireLinearFiringMode.libre,
    this.selectedRoles = const [],
  });

  FireLinearDoctrineInput copyWith({
    double? longueurM,
    FireLinearReferencePoint? referencePoint,
    double? azimutLineaireMil,
    FireLinearFiringMode? firingMode,
    List<String>? selectedRoles,
  }) {
    return FireLinearDoctrineInput(
      longueurM: longueurM ?? this.longueurM,
      referencePoint: referencePoint ?? this.referencePoint,
      azimutLineaireMil: azimutLineaireMil ?? this.azimutLineaireMil,
      firingMode: firingMode ?? this.firingMode,
      selectedRoles: selectedRoles ?? this.selectedRoles,
    );
  }
}

class FireSalvoOptions {
  final bool enabled;
  final int preferenceIdx;
  final bool lastSalveAroundPd;

  const FireSalvoOptions({
    required this.enabled,
    required this.preferenceIdx,
    required this.lastSalveAroundPd,
  });

  FireSalvoOptions copyWith({
    bool? enabled,
    int? preferenceIdx,
    bool? lastSalveAroundPd,
  }) {
    return FireSalvoOptions(
      enabled: enabled ?? this.enabled,
      preferenceIdx: preferenceIdx ?? this.preferenceIdx,
      lastSalveAroundPd: lastSalveAroundPd ?? this.lastSalveAroundPd,
    );
  }
}

class FireMeteoInput {
  final String? fileName;
  final List<MeteoRow> rows;
  final double? stationAltM;

  const FireMeteoInput({this.fileName, required this.rows, this.stationAltM});

  FireMeteoInput copyWith({
    String? fileName,
    List<MeteoRow>? rows,
    double? stationAltM,
  }) {
    return FireMeteoInput(
      fileName: fileName ?? this.fileName,
      rows: rows ?? this.rows,
      stationAltM: stationAltM ?? this.stationAltM,
    );
  }
}

class FireSupportPieceInput {
  final String pieceId;
  final double distanceM;
  final double azimutMil;

  /// Différence d'altitude saisie par rapport à la PD.
  ///
  /// Donnée de snapshot / présentation. Le moteur peut continuer à utiliser
  /// [zPS] qui reste l'altitude absolue.
  final double? deltaZPd;

  /// Altitude absolue de la pièce secondaire.
  final double? zPS;

  const FireSupportPieceInput({
    required this.pieceId,
    required this.distanceM,
    required this.azimutMil,
    this.deltaZPd,
    this.zPS,
  });

  FireSupportPieceInput copyWith({
    String? pieceId,
    double? distanceM,
    double? azimutMil,
    double? deltaZPd,
    double? zPS,
  }) {
    return FireSupportPieceInput(
      pieceId: pieceId ?? this.pieceId,
      distanceM: distanceM ?? this.distanceM,
      azimutMil: azimutMil ?? this.azimutMil,
      deltaZPd: deltaZPd ?? this.deltaZPd,
      zPS: zPS ?? this.zPS,
    );
  }
}
