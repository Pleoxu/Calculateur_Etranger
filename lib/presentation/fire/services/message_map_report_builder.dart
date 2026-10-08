// lib/presentation/fire/services/message_map_report_builder.dart

import 'package:latlong2/latlong.dart';

import 'package:calculateur_etranger/presentation/fire/models/message_map_report_models.dart';

/// Presentation-only map report builder.
///
/// This class only composes already-available geographic points into map-view
/// configurations. It does not perform ballistic calculations or UTM solving.
class MessageMapReportBuilder {
  const MessageMapReportBuilder();

  MessageMapReportBundle build({
    required LatLng pdLatLng,
    required LatLng objLatLng,
    required LatLng impactLatLng,
    double? focusRadiusM,
    List<MessageBatteryMapPoint> batteryPieces =
        const <MessageBatteryMapPoint>[],
    List<LatLng> targetGeometry = const <LatLng>[],
    double? zonalAzimutLargeurMil,
    double? zonalAzimutProfondeurMil,
    List<LatLng> impactGeometry = const <LatLng>[],
    List<LatLng> redGeometry = const <LatLng>[],
  }) {
    final globalCenter = _average(<LatLng>[pdLatLng, objLatLng]);
    final impactCenter = _average(
      impactGeometry.isNotEmpty ? impactGeometry : <LatLng>[impactLatLng],
    );
    final redCenter = _average(
      redGeometry.isNotEmpty ? redGeometry : <LatLng>[impactLatLng],
    );

    final MessageMapViewConfig? batteryView = batteryPieces.isEmpty
        ? null
        : MessageMapViewConfig(
            kind: MessageMapViewKind.batteryDeployment,
            title: 'Battery deployment',
            center: _average(
              batteryPieces.map((piece) => piece.latLng).toList(),
            ),
            zoom: 15.0,
            batteryPoints: batteryPieces,
            showPd: true,
          );

    return MessageMapReportBundle(
      batteryView: batteryView,
      globalView: MessageMapViewConfig(
        kind: MessageMapViewKind.globalPdToObj,
        title: 'PD / Objective',
        center: globalCenter,
        zoom: 13.0,
        pdLatLng: pdLatLng,
        objLatLng: objLatLng,
        impactLatLng: impactLatLng,
        showPd: true,
        showObj: true,
        showImpact: true,
        showTrajectory: true,
      ),
      impactView: MessageMapViewConfig(
        kind: MessageMapViewKind.impactZone,
        title: 'Impact zone',
        center: impactCenter,
        zoom: 15.0,
        pdLatLng: pdLatLng,
        objLatLng: objLatLng,
        impactLatLng: impactLatLng,
        showPd: false,
        showObj: true,
        showImpact: true,
        showImpactZone: true,
      ),
      redView: MessageMapViewConfig(
        kind: MessageMapViewKind.impactPlusRed,
        title: 'Impact / RED',
        center: redCenter,
        zoom: 14.0,
        pdLatLng: pdLatLng,
        objLatLng: objLatLng,
        impactLatLng: impactLatLng,
        showPd: false,
        showObj: true,
        showImpact: true,
        showImpactZone: true,
        showRedZone: true,
      ),
    );
  }

  static LatLng _average(List<LatLng> points) {
    if (points.isEmpty) {
      return const LatLng(0.0, 0.0);
    }

    var lat = 0.0;
    var lon = 0.0;
    for (final point in points) {
      lat += point.latitude;
      lon += point.longitude;
    }

    return LatLng(lat / points.length, lon / points.length);
  }
}
