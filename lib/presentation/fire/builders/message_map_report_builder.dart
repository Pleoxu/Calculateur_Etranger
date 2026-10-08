// lib/presentation/fire/builders/message_map_report_builder.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:calculateur_etranger/presentation/fire/models/message_map_report_models.dart';
import 'package:calculateur_etranger/presentation/fire/utils/smoke_plume_generator.dart';

class MessageMapReportBuilder {
  /// Calcule le rayon d'emprise visuelle (en mètres) selon la munition.
  static double? getTheoreticalCircleRadiusForAmmo(String? ammoCode) {
    if (ammoCode == null) return null;
    final cleanCode = ammoCode.trim().toUpperCase();

    switch (cleanCode) {
      case 'M853A1':
        // Diamètre publié 1 200 m -> Rayon = 600 m (Correction bug 300 m)
        return 600.0;

      case 'M819':
        // Géré via un polygone de diffusion spécifique (Cône de fumée)
        return null;

      default:
        // Rayon HE standard si non spécifié
        return 17.5;
    }
  }

  /// Construit la configuration de vue pour la carte du compte-rendu.
  static MessageMapViewConfig buildConfig({
    required MessageMapViewKind kind,
    required String ammoCode,
    required LatLng? pdLatLng,
    required LatLng? rawObjLatLng,
    // Coordonnées UTM saisies/mises à jour à la volée (ex: Mode D/AZ)
    double? utmEast,
    double? utmNorth,
    String? utmZone,
    bool isNorthernHemisphere = true,
    double windBearingDeg = 45.0,
    double? zonalAzimutLargeurMil,
    double? zonalAzimutProfondeurMil,
    List<LatLng> targetGeometry = const [],
  }) {
    // UI/report layer: use the geographic position already supplied by the caller.
    // UTM fields remain in the signature for compatibility, but no conversion
    // is performed in this presentation-only builder.
    final LatLng? objLatLng = rawObjLatLng;

    final center = objLatLng ?? pdLatLng ?? const LatLng(0, 0);
    final ammoUpper = ammoCode.trim().toUpperCase();

    // 2. Gestion des enveloppes complexes (ex: M819 Smoke plume)
    final extraPolygons = <List<LatLng>>[];
    if (ammoUpper == 'M819' && objLatLng != null) {
      final smokePlume = SmokePlumeGenerator.generateSmokeEnvelope(
        origin: objLatLng,
        windBearingDeg: windBearingDeg,
        maxDistanceMeters: 250.0,
        dispersionAngleDeg: 20.0,
        initialRadiusMeters: 15.0,
        kDrag: 0.004,
      );
      extraPolygons.add(smokePlume);
    }

    // 3. Détermination du rayon théorique
    final theoreticalRadius = getTheoreticalCircleRadiusForAmmo(ammoCode);

    return MessageMapViewConfig(
      kind: kind,
      title: switch (kind) {
        MessageMapViewKind.batteryDeployment => 'Battery deployment',
        MessageMapViewKind.globalPdToObj => 'PD / Objective',
        MessageMapViewKind.impactZone => 'Impact zone',
        MessageMapViewKind.impactPlusRed => 'Impact / RED',
      },
      center: center,
      zoom: 14.0,
      pdLatLng: pdLatLng,
      objLatLng: objLatLng,
      impactLatLng: objLatLng,
      showPd: pdLatLng != null,
      showObj: objLatLng != null,
      showImpact: ammoUpper != 'M819',
      showImpactZone: kind == MessageMapViewKind.impactZone,
      showRedZone: kind == MessageMapViewKind.impactPlusRed,
      showTrajectory: pdLatLng != null && objLatLng != null,
    );
  }
}
