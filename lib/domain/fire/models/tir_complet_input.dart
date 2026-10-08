import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/domain/entities/meteo_row.dart';

enum LinearFiringMode { libre, sectionWithPd, sectionWithoutPd, batteryWithPd }

enum ObjectifInputMode { utm, daz, lat }

/// Mode de désignation de l'objectif par l'observateur
enum ObservateurObjMode { utm, daz }

class TirCompletInput {
  final Systeme systeme;
  final TypeTir typeTir;

  // ✅ Fusée (RALEC / FRAPPE / FUCHSIA etc.)
  final TypeFusee? fusee;

  // Coordonnées Pièce
  final bool pieceUtm;
  final double? xPiece;
  final double? yPiece;
  final double? zPiece;
  final String? zone;
  final double? latPiece;
  final double? lonPiece;
  final double? altPiece;

  // ─────────────────────── Observateur ───────────────────────

  /// Active le mode observateur (OFF = saisie directe de l'objectif)
  final bool observateurEnabled;

  /// Position UTM de l'observateur
  final double? obsX;
  final double? obsY;
  final double? obsZ;

  /// Mode de désignation de l'objectif par l'observateur
  final ObservateurObjMode observateurObjMode;

  /// Désignation DAZ depuis l'observateur
  final double? obsDistanceObj; // distance (m)
  final double? obsAzimutObj; // azimut (mil)
  final double? obsAltObj; // altitude de l'objectif (m)

  /// Désignation UTM depuis l'observateur (même que xObj/yObj/zObj mais
  /// saisis dans le cartouche observateur)
  final double? obsXObj;
  final double? obsYObj;
  final double? obsZObj;

  // Coordonnées Objectif
  final ObjectifInputMode objectifMode;
  final double? xObj;
  final double? yObj;
  final double? zObj;
  final double? distanceObj;
  final double? azimutObj;
  final double? altObj;
  final double? latObj;
  final double? lonObj;

  // Getters d'alias et de compatibilité
  TypeMunition? get munition => null;
  double? get pdX => xPiece;
  double? get pdY => yPiece;
  double? get pdZ => zPiece;
  double? get distanceM => distanceObj;
  double? get azimutMil => azimutObj;
  TypeTir get natureTir => typeTir;

  // Compatibilité lecture existante
  bool get objUtm => objectifMode == ObjectifInputMode.utm;
  bool get objDaz => objectifMode == ObjectifInputMode.daz;
  bool get objLat => objectifMode == ObjectifInputMode.lat;

  // Options de tir
  final bool tirVertical;
  final bool forcerCharge;
  final int? chargeForcee;

  // Nature objectif
  final bool natureEnabled;
  final int natureIdx; // 0 ponctuel, 1 linéaire, 2 zonal

  // Linéaire : longueur
  final double? longueurLineaire;

  // ✅ Zonal : longueur et profondeur
  final double? longueurZonale;
  final double? profondeurZonale;

  /// ✅ Mode doctrinal zonal
  final ZonalMode zonalMode;

  /// Vrai uniquement pour les presets UI Neutralisation/Interdiction/Destruction
  /// (100×100, 150×150 ou 200×200) afin de transporter explicitement
  /// l'intention métier jusqu'au moteur doctrinal.
  final bool isZonalPreset;

  final double? pourcentageDebordement;
  final double? pourcentageRecouvrement;

  /// Nombre de coups TOTAL (shots)
  final int? nbCoups;

  /// multiplicateur "Par"
  final int? lineairePar;

  // ───────────────────────── Salves / Doctrine ─────────────────────────

  /// Active le découpage en salves (complètes + dernière partielle)
  final bool salvesEnabled;

  /// Préférence côté pour la dernière salve incomplète :
  /// 0 = auto / 1 = droite / 2 = gauche
  final int salvesPreferenceIdx;

  /// Si dernière salve incomplète, tirer plutôt avec les pièces autour de PD
  final bool lastSalveAroundPd;

  /// point d'application = extrémité (linéaire)
  final bool? lineaireDepuisExtremite;

  /// azimut du linéaire (mil)
  final double? azimutLineaireMil;

  /// ✅ Zonal : point application + azimuts (largeur/profondeur)
  final PointZonal? pointZonal;
  final double? azimutLargeurMil;
  final double? azimutProfondeurMil;

  /// Répartition des coups par pièce (PD, PS1, ...)
  final Map<String, int>? coupsParPieceByPiece;

  /// Configuration doctrinale du linéaire
  final LinearFiringMode linearFiringMode;
  final List<String> selectedLinearRoles;

  // Masse obus
  final bool masseEnabled;
  final int carreaux;

  // Tir similaire
  final bool tirSimilaire;
  final int simCarreaux;
  final double? tPrev;
  final double? tAct;
  final double? v0Prev;

  // Météo
  final bool meteo;
  final String? meteoFileName;
  final List<MeteoRow>? meteoRows;
  final double? meteoStationAltM;

  // Autres pièces
  final bool autrePieces;
  final List<PieceSoutienInput> piecesSoutien;

  const TirCompletInput({
    required this.systeme,
    required this.typeTir,
    this.fusee,
    required this.pieceUtm,
    // Observateur
    this.observateurEnabled = false,
    this.obsX,
    this.obsY,
    this.obsZ,
    this.observateurObjMode = ObservateurObjMode.daz,
    this.obsDistanceObj,
    this.obsAzimutObj,
    this.obsAltObj,
    this.obsXObj,
    this.obsYObj,
    this.obsZObj,
    this.xPiece,
    this.yPiece,
    this.zPiece,
    this.zone,
    this.latPiece,
    this.lonPiece,
    this.altPiece,
    this.objectifMode = ObjectifInputMode.utm,
    this.xObj,
    this.yObj,
    this.zObj,
    this.distanceObj,
    this.azimutObj,
    this.altObj,
    this.latObj,
    this.lonObj,
    required this.tirVertical,
    required this.forcerCharge,
    this.chargeForcee,
    required this.natureEnabled,
    required this.natureIdx,
    this.longueurLineaire,
    this.longueurZonale,
    this.profondeurZonale,
    this.zonalMode = ZonalMode.otan,
    this.isZonalPreset = false,
    this.pointZonal,
    this.azimutLargeurMil,
    this.azimutProfondeurMil,
    this.pourcentageDebordement,
    this.pourcentageRecouvrement,
    this.nbCoups,
    this.lineairePar,
    this.salvesEnabled = false,
    this.salvesPreferenceIdx = 0,
    this.lastSalveAroundPd = true,
    this.lineaireDepuisExtremite,
    this.azimutLineaireMil,
    this.coupsParPieceByPiece,
    this.linearFiringMode = LinearFiringMode.libre,
    this.selectedLinearRoles = const [],
    required this.masseEnabled,
    required this.carreaux,
    required this.tirSimilaire,
    required this.simCarreaux,
    this.tPrev,
    this.tAct,
    this.v0Prev,
    required this.meteo,
    this.meteoFileName,
    this.meteoRows,
    this.meteoStationAltM,
    required this.autrePieces,
    this.piecesSoutien = const [],
  });

  TirCompletInput copyWith({
    Systeme? systeme,
    TypeTir? typeTir,
    TypeFusee? fusee,
    bool? pieceUtm,
    // Observateur
    bool? observateurEnabled,
    double? obsX,
    double? obsY,
    double? obsZ,
    ObservateurObjMode? observateurObjMode,
    double? obsDistanceObj,
    double? obsAzimutObj,
    double? obsAltObj,
    double? obsXObj,
    double? obsYObj,
    double? obsZObj,
    double? xPiece,
    double? yPiece,
    double? zPiece,
    String? zone,
    double? latPiece,
    double? lonPiece,
    double? altPiece,
    ObjectifInputMode? objectifMode,
    double? xObj,
    double? yObj,
    double? zObj,
    double? distanceObj,
    double? azimutObj,
    double? altObj,
    double? latObj,
    double? lonObj,
    bool? tirVertical,
    bool? forcerCharge,
    int? chargeForcee,
    bool? natureEnabled,
    int? natureIdx,
    double? longueurLineaire,
    double? longueurZonale,
    double? profondeurZonale,
    ZonalMode? zonalMode,
    bool? isZonalPreset,
    PointZonal? pointZonal,
    double? azimutLargeurMil,
    double? azimutProfondeurMil,
    double? pourcentageDebordement,
    double? pourcentageRecouvrement,
    int? nbCoups,
    int? lineairePar,
    bool? salvesEnabled,
    int? salvesPreferenceIdx,
    bool? lastSalveAroundPd,
    bool? lineaireDepuisExtremite,
    double? azimutLineaireMil,
    Map<String, int>? coupsParPieceByPiece,
    LinearFiringMode? linearFiringMode,
    List<String>? selectedLinearRoles,
    bool? masseEnabled,
    int? carreaux,
    bool? tirSimilaire,
    int? simCarreaux,
    double? tPrev,
    double? tAct,
    double? v0Prev,
    bool? meteo,
    String? meteoFileName,
    List<MeteoRow>? meteoRows,
    double? meteoStationAltM,
    bool? autrePieces,
    List<PieceSoutienInput>? piecesSoutien,
  }) {
    return TirCompletInput(
      systeme: systeme ?? this.systeme,
      typeTir: typeTir ?? this.typeTir,
      fusee: fusee ?? this.fusee,
      pieceUtm: pieceUtm ?? this.pieceUtm,
      observateurEnabled: observateurEnabled ?? this.observateurEnabled,
      obsX: obsX ?? this.obsX,
      obsY: obsY ?? this.obsY,
      obsZ: obsZ ?? this.obsZ,
      observateurObjMode: observateurObjMode ?? this.observateurObjMode,
      obsDistanceObj: obsDistanceObj ?? this.obsDistanceObj,
      obsAzimutObj: obsAzimutObj ?? this.obsAzimutObj,
      obsAltObj: obsAltObj ?? this.obsAltObj,
      obsXObj: obsXObj ?? this.obsXObj,
      obsYObj: obsYObj ?? this.obsYObj,
      obsZObj: obsZObj ?? this.obsZObj,
      xPiece: xPiece ?? this.xPiece,
      yPiece: yPiece ?? this.yPiece,
      zPiece: zPiece ?? this.zPiece,
      zone: zone ?? this.zone,
      latPiece: latPiece ?? this.latPiece,
      lonPiece: lonPiece ?? this.lonPiece,
      altPiece: altPiece ?? this.altPiece,
      objectifMode: objectifMode ?? this.objectifMode,
      xObj: xObj ?? this.xObj,
      yObj: yObj ?? this.yObj,
      zObj: zObj ?? this.zObj,
      distanceObj: distanceObj ?? this.distanceObj,
      azimutObj: azimutObj ?? this.azimutObj,
      altObj: altObj ?? this.altObj,
      latObj: latObj ?? this.latObj,
      lonObj: lonObj ?? this.lonObj,
      tirVertical: tirVertical ?? this.tirVertical,
      forcerCharge: forcerCharge ?? this.forcerCharge,
      chargeForcee: chargeForcee ?? this.chargeForcee,
      natureEnabled: natureEnabled ?? this.natureEnabled,
      natureIdx: natureIdx ?? this.natureIdx,
      longueurLineaire: longueurLineaire ?? this.longueurLineaire,
      longueurZonale: longueurZonale ?? this.longueurZonale,
      profondeurZonale: profondeurZonale ?? this.profondeurZonale,
      zonalMode: zonalMode ?? this.zonalMode,
      isZonalPreset: isZonalPreset ?? this.isZonalPreset,
      pointZonal: pointZonal ?? this.pointZonal,
      azimutLargeurMil: azimutLargeurMil ?? this.azimutLargeurMil,
      azimutProfondeurMil: azimutProfondeurMil ?? this.azimutProfondeurMil,
      pourcentageDebordement:
          pourcentageDebordement ?? this.pourcentageDebordement,
      pourcentageRecouvrement:
          pourcentageRecouvrement ?? this.pourcentageRecouvrement,
      nbCoups: nbCoups ?? this.nbCoups,
      lineairePar: lineairePar ?? this.lineairePar,
      salvesEnabled: salvesEnabled ?? this.salvesEnabled,
      salvesPreferenceIdx: salvesPreferenceIdx ?? this.salvesPreferenceIdx,
      lastSalveAroundPd: lastSalveAroundPd ?? this.lastSalveAroundPd,
      lineaireDepuisExtremite:
          lineaireDepuisExtremite ?? this.lineaireDepuisExtremite,
      azimutLineaireMil: azimutLineaireMil ?? this.azimutLineaireMil,
      coupsParPieceByPiece: coupsParPieceByPiece ?? this.coupsParPieceByPiece,
      linearFiringMode: linearFiringMode ?? this.linearFiringMode,
      selectedLinearRoles: selectedLinearRoles ?? this.selectedLinearRoles,
      masseEnabled: masseEnabled ?? this.masseEnabled,
      carreaux: carreaux ?? this.carreaux,
      tirSimilaire: tirSimilaire ?? this.tirSimilaire,
      simCarreaux: simCarreaux ?? this.simCarreaux,
      tPrev: tPrev ?? this.tPrev,
      tAct: tAct ?? this.tAct,
      v0Prev: v0Prev ?? this.v0Prev,
      meteo: meteo ?? this.meteo,
      meteoFileName: meteoFileName ?? this.meteoFileName,
      meteoRows: meteoRows ?? this.meteoRows,
      meteoStationAltM: meteoStationAltM ?? this.meteoStationAltM,
      autrePieces: autrePieces ?? this.autrePieces,
      piecesSoutien: piecesSoutien ?? this.piecesSoutien,
    );
  }
}

class PieceSoutienInput {
  final String nom;
  final double azimutMil;
  final double distanceM;
  final double? zPS;

  const PieceSoutienInput({
    required this.nom,
    required this.azimutMil,
    required this.distanceM,
    this.zPS,
  });

  PieceSoutienInput copyWith({
    String? nom,
    double? azimutMil,
    double? distanceM,
    double? zPS,
  }) {
    return PieceSoutienInput(
      nom: nom ?? this.nom,
      azimutMil: azimutMil ?? this.azimutMil,
      distanceM: distanceM ?? this.distanceM,
      zPS: zPS ?? this.zPS,
    );
  }
}
