// lib/domain/report/message_pd_data.dart

import 'package:latlong2/latlong.dart';

/// Snapshot de données pour l'aperçu du compte rendu PD.
///
/// Cette version reste compatible avec l'API booléenne déjà utilisée dans
/// l'interface, tout en ajoutant les valeurs réelles, les positions formatées,
/// et les géométries simples nécessaires à l'aperçu cartographique.
class MessagePdData {
  const MessagePdData({
    required this.pieceDirectriceDisponible,
    required this.objectifDisponible,
    required this.carteDisponible,
    required this.distanceDisponible,
    required this.azimutDisponible,
    required this.deniveleeDisponible,
    required this.noireDisponible,
    required this.aqeDisponible,
    required this.chargeDisponible,
    required this.tempsDisponible,
    this.distance,
    this.azimut,
    this.denivelee,
    this.noire,
    this.aqe,
    this.charge,
    this.temps,
    this.systeme = '—',
    this.typeTir = '—',
    this.munition,
    this.fusee = '—',
    this.chargeOperateur,
    this.masse,
    this.tirSimilaire,
    this.meteo,
    this.piecePosition,
    this.objectifPosition,
    this.pieceLatLng,
    this.objectifLatLng,
    this.impactLatLng,
    this.impactPolygon = const <LatLng>[],
    this.redPolygon = const <LatLng>[],
    this.impactFocusRadiusM,
    this.displayEffectRadiusM,
    this.redFocusRadiusM,
    this.batteryPieces = const <MessageBatteryPieceData>[],
    this.targetGeometry = const <LatLng>[],
    this.targetGeometryClosed = false,
    this.targetLabels = const <String>[],
    this.targetPieceIds = const <String>[],
    this.pieceResults = const <MessagePieceResultData>[],
    this.zonalAzimutLargeurMil,
    this.zonalAzimutProfondeurMil,
    this.zonalLargeurM,
    this.zonalProfondeurM,
    this.zonalDebordementPct,
  });

  final bool pieceDirectriceDisponible;
  final bool objectifDisponible;
  final bool carteDisponible;
  final bool distanceDisponible;
  final bool azimutDisponible;
  final bool deniveleeDisponible;
  final bool noireDisponible;
  final bool aqeDisponible;
  final bool chargeDisponible;
  final bool tempsDisponible;

  final String? distance;
  final String? azimut;
  final String? denivelee;
  final String? noire;
  final String? aqe;
  final String? charge;
  final String? temps;

  final String systeme;
  final String typeTir;
  final String? munition;
  final String fusee;
  final String? chargeOperateur;
  final String? masse;
  final String? tirSimilaire;
  final String? meteo;

  final String? piecePosition;
  final String? objectifPosition;

  final LatLng? pieceLatLng;
  final LatLng? objectifLatLng;
  final LatLng? impactLatLng;
  final List<LatLng> impactPolygon;
  final List<LatLng> redPolygon;
  final double? impactFocusRadiusM;

  /// Rayon d'affichage nominal de l'effet dans le compte rendu.
  /// Il est fourni explicitement par le collecteur et ne doit pas être
  /// rededuit de l'ellipse balistique ou de l'emprise du polygone.
  final double? displayEffectRadiusM;

  final double? redFocusRadiusM;

  final List<MessageBatteryPieceData> batteryPieces;

  /// Centres cartographiques réellement utilisés par les calculs de coups.
  final List<LatLng> targetGeometry;
  final bool targetGeometryClosed;

  /// Numéro réel de salve affiché sur chaque centre d'impact.
  /// La liste est alignée sur [targetGeometry].
  final List<String> targetLabels;

  /// Identifiant de la pièce ayant tiré chaque impact.
  /// La liste est alignée sur [targetGeometry].
  final List<String> targetPieceIds;

  final List<MessagePieceResultData> pieceResults;

  /// Axes zonaux EXACTS saisis/utilisés par la doctrine.
  ///
  /// Ils servent uniquement à la restitution du CR. La carte ne doit plus
  /// tenter de redéduire l'orientation du zonal depuis le nuage de points.
  final double? zonalAzimutLargeurMil;
  final double? zonalAzimutProfondeurMil;

  /// Dimensions NOMINALES du zonal, issues directement de la saisie/doctrine.
  /// Ne jamais les reconstruire depuis l'emprise des centres d'impacts.
  final double? zonalLargeurM;
  final double? zonalProfondeurM;

  /// Débordement zonal saisi, exprimé en pourcentage (ex. 5.0 = 5 %).
  final double? zonalDebordementPct;

  bool get hasBatteryData => batteryPieces.isNotEmpty;
  bool get hasTargetGeometry => targetGeometry.length >= 2;
  bool get hasExplicitZonalAxes =>
      zonalAzimutLargeurMil != null && zonalAzimutProfondeurMil != null;

  bool get complet =>
      pieceDirectriceDisponible &&
      objectifDisponible &&
      distanceDisponible &&
      azimutDisponible &&
      deniveleeDisponible &&
      noireDisponible &&
      aqeDisponible &&
      chargeDisponible &&
      tempsDisponible;

  bool get hasMapData =>
      carteDisponible && pieceLatLng != null && objectifLatLng != null;
}

class MessageBatteryPieceData {
  const MessageBatteryPieceData({
    required this.label,
    this.latLng,
    this.distanceFromPdM,
    this.azimutFromPdMil,
    this.deltaZFromPdM,
  });

  final String label;
  final LatLng? latLng;
  final double? distanceFromPdM;
  final double? azimutFromPdMil;
  final double? deltaZFromPdM;
}

class MessagePieceResultData {
  const MessagePieceResultData({
    required this.label,
    this.noire,
    this.aqe,
    this.charge,
    this.temps,
    this.offsetM,
    this.numeroSalve,
  });

  final String label;
  final String? noire;
  final String? aqe;
  final String? charge;
  final String? temps;
  final double? offsetM;

  /// Numéro réel de salve porté par le coup.
  /// Null pour les restitutions anciennes / non zonales.
  final int? numeroSalve;
}
