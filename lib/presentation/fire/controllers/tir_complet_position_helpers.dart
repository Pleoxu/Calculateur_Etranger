import 'package:flutter/material.dart';

import 'package:calculateur_etranger/domain/fire/models/tir_complet_input.dart'
    as tc;
import 'package:calculateur_etranger/presentation/fire/controllers/tir_complet_form_controllers.dart';
import 'package:calculateur_etranger/services/position/utm_converter.dart';

abstract final class TirCompletPositionHelpers {
  static double? parseDoubleField(TextEditingController ctrl) {
    final txt = ctrl.text.trim().replaceAll(',', '.');
    if (txt.isEmpty) return null;
    return double.tryParse(txt);
  }

  static ({int zone, String band})? parseUtmZoneText(String raw) {
    final match = RegExp(
      r'^(\d{1,2})([C-HJ-NP-X])?$',
    ).firstMatch(raw.trim().toUpperCase());

    if (match == null) return null;

    final zone = int.tryParse(match.group(1)!);
    if (zone == null || zone < 1 || zone > 60) return null;

    // Band par défaut volontairement nord-France/Europe si l'utilisateur
    // saisit seulement "30" ou "31". Le picker réécrira ensuite la zone
    // complète avec sa bande réelle.
    return (zone: zone, band: match.group(2) ?? 'T');
  }

  static LatLonPosition? currentPieceLatLon(TirCompletFormControllers form) {
    final zone = parseUtmZoneText(form.zoneCtrl.text);
    final x = parseDoubleField(form.xCtrl);
    final y = parseDoubleField(form.yCtrl);
    final z = parseDoubleField(form.zCtrl) ?? 0.0;

    if (zone == null || x == null || y == null) return null;

    try {
      return UtmConverter.toLatLon(
        zone: zone.zone,
        band: zone.band,
        x: x,
        y: y,
        z: z,
      );
    } catch (_) {
      return null;
    }
  }

  static LatLonPosition? currentObjectifLatLon({
    required TirCompletFormControllers form,
    required tc.ObjectifInputMode mode,
  }) {
    final z = parseDoubleField(form.zObjCtrl) ??
        parseDoubleField(form.altObjCtrl) ??
        0.0;

    if (mode == tc.ObjectifInputMode.lat) {
      final lat = parseDoubleField(form.xObjCtrl);
      final lon = parseDoubleField(form.yObjCtrl);
      if (lat == null || lon == null) return null;

      return LatLonPosition(latitude: lat, longitude: lon, altitude: z);
    }

    final zone = parseUtmZoneText(form.zoneCtrl.text);
    final x = parseDoubleField(form.xObjCtrl);
    final y = parseDoubleField(form.yObjCtrl);

    if (zone == null || x == null || y == null) return null;

    try {
      return UtmConverter.toLatLon(
        zone: zone.zone,
        band: zone.band,
        x: x,
        y: y,
        z: z,
      );
    } catch (_) {
      return null;
    }
  }

  static LatLonPosition? currentObserverLatLon(TirCompletFormControllers form) {
    final zone = parseUtmZoneText(form.zoneCtrl.text);
    final x = parseDoubleField(form.obsXCtrl);
    final y = parseDoubleField(form.obsYCtrl);
    final z = parseDoubleField(form.obsZCtrl) ?? 0.0;

    if (zone == null || x == null || y == null) return null;

    try {
      return UtmConverter.toLatLon(
        zone: zone.zone,
        band: zone.band,
        x: x,
        y: y,
        z: z,
      );
    } catch (_) {
      return null;
    }
  }

  static LatLonPosition? currentObserverObjectifLatLon(
    TirCompletFormControllers form,
  ) {
    final zone = parseUtmZoneText(form.zoneCtrl.text);
    final x = parseDoubleField(form.obsXObjCtrl);
    final y = parseDoubleField(form.obsYObjCtrl);
    final z = parseDoubleField(form.obsZObjCtrl) ??
        parseDoubleField(form.obsAltObjCtrl) ??
        0.0;

    if (zone == null || x == null || y == null) return null;

    try {
      return UtmConverter.toLatLon(
        zone: zone.zone,
        band: zone.band,
        x: x,
        y: y,
        z: z,
      );
    } catch (_) {
      return null;
    }
  }

  static UtmPosition utmInPieceZone({
    required TirCompletFormControllers form,
    required double latitude,
    required double longitude,
    required double altitude,
  }) {
    final preferredZone = parseUtmZoneText(form.zoneCtrl.text);

    if (preferredZone == null) {
      return UtmConverter.fromLatLon(
        latitude: latitude,
        longitude: longitude,
        altitude: altitude,
      );
    }

    return UtmConverter.fromLatLonInZone(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      zone: preferredZone.zone,
      band: preferredZone.band,
    );
  }
}
