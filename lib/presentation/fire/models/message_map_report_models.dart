// lib/presentation/fire/models/message_map_report_models.dart

import 'package:latlong2/latlong.dart';

enum MessageMapViewKind {
  batteryDeployment,
  globalPdToObj,
  impactZone,
  impactPlusRed,
}

class MessageBatteryMapPoint {
  const MessageBatteryMapPoint({
    required this.label,
    required this.latLng,
    this.isPd = false,
  });

  final String label;
  final LatLng latLng;
  final bool isPd;
}

class MessageMapViewConfig {
  const MessageMapViewConfig({
    required this.kind,
    required this.title,
    required this.center,
    required this.zoom,
    this.pdLatLng,
    this.objLatLng,
    this.impactLatLng,
    this.batteryPoints = const <MessageBatteryMapPoint>[],
    this.rotationDeg = 0.0,
    this.scaleBarMeters,
    this.showPd = false,
    this.showObj = false,
    this.showImpact = false,
    this.showTrajectory = false,
    this.showImpactZone = false,
    this.showRedZone = false,
    this.minZoom,
    this.maxZoom,
  });

  final MessageMapViewKind kind;
  final String title;
  final LatLng center;
  final double zoom;

  final LatLng? pdLatLng;
  final LatLng? objLatLng;
  final LatLng? impactLatLng;

  /// Pièces affichées sur la carte d'implantation batterie.
  ///
  /// La PD doit porter [MessageBatteryMapPoint.isPd] à true.
  final List<MessageBatteryMapPoint> batteryPoints;

  /// Rotation de la carte en degrés.
  ///
  /// 0 = nord en haut. Pour l'implantation batterie, la carte est tournée afin
  /// que l'axe principal des pièces soit horizontal dans le cartouche.
  final double rotationDeg;

  /// Longueur représentée par la barre d'échelle, en mètres.
  final double? scaleBarMeters;

  final bool showPd;
  final bool showObj;
  final bool showImpact;
  final bool showTrajectory;
  final bool showImpactZone;
  final bool showRedZone;

  final double? minZoom;
  final double? maxZoom;
}

class MessageMapReportBundle {
  const MessageMapReportBundle({
    required this.globalView,
    required this.impactView,
    required this.redView,
    this.batteryView,
  });

  /// Carte d'implantation de la batterie.
  ///
  /// Null tant qu'aucune pièce secondaire exploitable n'est fournie.
  final MessageMapViewConfig? batteryView;

  final MessageMapViewConfig globalView;
  final MessageMapViewConfig impactView;
  final MessageMapViewConfig redView;
}
