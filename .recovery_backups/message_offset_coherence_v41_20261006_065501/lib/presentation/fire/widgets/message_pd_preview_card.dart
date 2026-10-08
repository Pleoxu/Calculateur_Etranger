// lib/presentation/fire/widgets/message_pd_preview_card.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:calculateur_etranger/domain/report/message_pd_data.dart';
import 'package:calculateur_etranger/presentation/fire/models/message_map_report_models.dart';
import 'package:calculateur_etranger/presentation/fire/services/message_map_report_builder.dart';
import 'package:calculateur_etranger/presentation/fire/services/message_pd_report_capture.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/message_map_report_view.dart';

class MessagePdPreviewCard extends StatelessWidget {
  const MessagePdPreviewCard({
    super.key,
    required this.data,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.dark,
    this.reportCapture,
  });

  final MessagePdData data;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final bool dark;
  final MessagePdReportCapture? reportCapture;

  Widget _title(String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 7),
      child: Text(
        value,
        style: TextStyle(
          color: textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _valueRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(
                color: textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value ?? '—',
              style: TextStyle(
                color: textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _positionPanel(String title, String? content) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0E1116) : const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            content ?? '—',
            style: TextStyle(
              color: textPrimary,
              fontSize: 12.5,
              height: 1.32,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapUnavailable() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0D1015) : const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.map_outlined, size: 18, color: textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Map preview unavailable',
              style: TextStyle(
                color: textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapBlock({
    required Key? captureKey,
    required String title,
    String? subtitle,
    String? footer,
    required Widget map,
  }) {
    return RepaintBoundary(
      key: captureKey,
      child: ColoredBox(
        color: card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFFFB000),
                        fontSize: 10.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            map,
            if (footer != null && footer.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  footer,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtRelative(
    double? value, {
    required int digits,
    required String unit,
  }) {
    if (value == null || !value.isFinite) return '—';
    return '${value.toStringAsFixed(digits)} $unit';
  }

  String _fmtSignedRelative(double? value) {
    if (value == null || !value.isFinite) return '—';
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(0)} m';
  }

  Widget _batteryCartouche() {
    if (data.batteryPieces.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0E1116) : const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'PD  —  ${data.piecePosition ?? '—'}'.replaceAll('\n', ' • '),
            style: TextStyle(
              color: textPrimary,
              fontSize: 12.2,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          for (final piece in data.batteryPieces) ...[
            const SizedBox(height: 7),
            Text(
              '${piece.label}/PD  —  '
              'D ${_fmtRelative(piece.distanceFromPdM, digits: 0, unit: 'm')}'
              '  •  Az ${_fmtRelative(piece.azimutFromPdMil, digits: 0, unit: 'mil')}'
              '  •  ΔZ ${_fmtSignedRelative(piece.deltaZFromPdM)}',
              style: TextStyle(
                color: textPrimary,
                fontSize: 12.0,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _generalMapSubtitle() {
    final parts = <String>[
      if (data.distance != null) 'D ${data.distance}',
      if (data.azimut != null) 'Az ${data.azimut}',
      if (data.denivelee != null) 'ΔZ ${data.denivelee}',
    ];
    return parts.isEmpty ? null : parts.join(' • ');
  }

  LatLng? _batteryFallbackLatLng(MessageBatteryPieceData piece) {
    final pd = data.pieceLatLng;
    final distanceM = piece.distanceFromPdM;
    final azimutMil = piece.azimutFromPdMil;

    if (pd == null || distanceM == null || azimutMil == null) {
      return piece.latLng;
    }
    if (!distanceM.isFinite || !azimutMil.isFinite) {
      return piece.latLng;
    }

    final azRad = azimutMil * 2.0 * math.pi / 6400.0;
    final northM = distanceM * math.cos(azRad);
    final eastM = distanceM * math.sin(azRad);

    const earthRadiusM = 6378137.0;
    final lat0Rad = pd.latitude * math.pi / 180.0;
    final lat = pd.latitude + (northM / earthRadiusM) * 180.0 / math.pi;
    final cosLat = math.max(0.000001, math.cos(lat0Rad).abs());
    final lon =
        pd.longitude + (eastM / (earthRadiusM * cosLat)) * 180.0 / math.pi;

    return LatLng(lat, lon);
  }

  List<LatLng> _translatePolygon({
    required List<LatLng> polygon,
    required LatLng fromCenter,
    required LatLng toCenter,
  }) {
    if (polygon.isEmpty) return const <LatLng>[];

    const earthRadiusM = 6378137.0;
    final lat0Rad = fromCenter.latitude * math.pi / 180.0;
    final dNorth = (toCenter.latitude - fromCenter.latitude) *
        math.pi /
        180.0 *
        earthRadiusM;
    final dEast = (toCenter.longitude - fromCenter.longitude) *
        math.pi /
        180.0 *
        earthRadiusM *
        math.cos(lat0Rad);

    return [
      for (final p in polygon)
        LatLng(
          p.latitude + dNorth / earthRadiusM * 180.0 / math.pi,
          p.longitude +
              dEast /
                  (earthRadiusM *
                      math.max(
                        0.000001,
                        math.cos(p.latitude * math.pi / 180.0).abs(),
                      )) *
                  180.0 /
                  math.pi,
        ),
    ];
  }

  List<List<LatLng>> _replicatedPolygons({required List<LatLng> polygon}) {
    if (polygon.length < 3) return const <List<LatLng>>[];

    final baseCenter = data.impactLatLng ?? data.objectifLatLng;
    final targets = data.targetGeometry;

    if (baseCenter == null || targets.isEmpty) {
      return <List<LatLng>>[polygon];
    }

    return [
      for (final target in targets)
        _translatePolygon(
          polygon: polygon,
          fromCenter: baseCenter,
          toCenter: target,
        ),
    ];
  }

  List<LatLng> _circleAround({
    required LatLng center,
    required double radiusM,
    int steps = 72,
  }) {
    const earthRadiusM = 6378137.0;
    final lat0Rad = center.latitude * math.pi / 180.0;
    final cosLat = math.max(0.000001, math.cos(lat0Rad).abs());

    return [
      for (var i = 0; i <= steps; i++)
        (() {
          final a = 2.0 * math.pi * i / steps;

          final eastM = radiusM * math.cos(a);
          final northM = radiusM * math.sin(a);

          final lat =
              center.latitude + (northM / earthRadiusM) * 180.0 / math.pi;
          final lon = center.longitude +
              (eastM / (earthRadiusM * cosLat)) * 180.0 / math.pi;

          return LatLng(lat, lon);
        })(),
    ];
  }

  double? _zonalTheoreticalCircleRadiusM({
    bool isIlluminating = false,
    bool isScreening = false,
  }) {
    final radiusM = data.displayEffectRadiusM;
    if (radiusM != null && radiusM.isFinite && radiusM > 0) {
      return radiusM;
    }

    if (isIlluminating) {
      return 600.0; // 600m de rayon (1200m de diamètre d'éclairement)
    }

    if (isScreening) {
      return 150.0; // Emprise/rayon par défaut de l'écran fumigène
    }

    if (!data.targetGeometryClosed || data.targetGeometry.isEmpty) return null;

    return null;
  }

  List<List<LatLng>> _zonalTheoreticalImpactCircles({
    bool isIlluminating = false,
    bool isScreening = false,
  }) {
    final radiusM = _zonalTheoreticalCircleRadiusM(
      isIlluminating: isIlluminating,
      isScreening: isScreening,
    );
    if (radiusM == null) {
      if (!data.targetGeometryClosed || data.targetGeometry.isEmpty) {
        return _replicatedPolygons(polygon: data.impactPolygon);
      }
      return const <List<LatLng>>[];
    }

    final targets = data.targetGeometry.isNotEmpty
        ? data.targetGeometry
        : (data.impactLatLng != null ? [data.impactLatLng!] : <LatLng>[]);

    return [
      for (final target in targets)
        _circleAround(center: target, radiusM: radiusM),
    ];
  }

  List<LatLng> _convexHullLatLng(List<LatLng> points) {
    if (points.length <= 3) return List<LatLng>.from(points);

    const earthRadiusM = 6378137.0;
    final origin = points.first;
    final lat0Rad = origin.latitude * math.pi / 180.0;

    final pts = [
      for (final p in points)
        (
          x: (p.longitude - origin.longitude) *
              math.pi /
              180.0 *
              earthRadiusM *
              math.cos(lat0Rad),
          y: (p.latitude - origin.latitude) * math.pi / 180.0 * earthRadiusM,
          ll: p,
        ),
    ];

    pts.sort((a, b) {
      final cx = a.x.compareTo(b.x);
      return cx != 0 ? cx : a.y.compareTo(b.y);
    });

    double cross(dynamic o, dynamic a, dynamic b) =>
        (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

    final lower = <dynamic>[];
    for (final p in pts) {
      while (lower.length >= 2 &&
          cross(lower[lower.length - 2], lower.last, p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }

    final upper = <dynamic>[];
    for (final p in pts.reversed) {
      while (upper.length >= 2 &&
          cross(upper[upper.length - 2], upper.last, p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }

    lower.removeLast();
    upper.removeLast();

    return [
      for (final p in [...lower, ...upper]) p.ll as LatLng,
    ];
  }

  List<LatLng> _redEnvelope() {
    if (data.targetGeometryClosed) {
      return data.redPolygon;
    }

    final redCopies = _replicatedPolygons(polygon: data.redPolygon);
    if (redCopies.isEmpty) return const <LatLng>[];

    return _convexHullLatLng([for (final poly in redCopies) ...poly]);
  }

  ({double lengthM, double depthM})? _geometryDimensions(List<LatLng> points) {
    if (points.length < 2) return null;

    const earthRadiusM = 6378137.0;
    final origin = points.first;
    final lat0Rad = origin.latitude * math.pi / 180.0;

    final local = <({double x, double y})>[
      for (final p in points)
        (
          x: (p.longitude - origin.longitude) *
              math.pi /
              180.0 *
              earthRadiusM *
              math.cos(lat0Rad),
          y: (p.latitude - origin.latitude) * math.pi / 180.0 * earthRadiusM,
        ),
    ];

    var bestI = 0;
    var bestJ = 1;
    var maxD2 = -1.0;

    for (var i = 0; i < local.length; i++) {
      for (var j = i + 1; j < local.length; j++) {
        final dx = local[j].x - local[i].x;
        final dy = local[j].y - local[i].y;
        final d2 = dx * dx + dy * dy;
        if (d2 > maxD2) {
          maxD2 = d2;
          bestI = i;
          bestJ = j;
        }
      }
    }

    final lengthM = math.sqrt(math.max(0.0, maxD2));
    if (lengthM <= 0.001) {
      return (lengthM: 0.0, depthM: 0.0);
    }

    final ax = local[bestI].x;
    final ay = local[bestI].y;
    final bx = local[bestJ].x;
    final by = local[bestJ].y;
    final vx = bx - ax;
    final vy = by - ay;

    var minPerp = double.infinity;
    var maxPerp = double.negativeInfinity;

    for (final p in local) {
      final perp = ((p.x - ax) * (-vy) + (p.y - ay) * vx) / lengthM;

      minPerp = math.min(minPerp, perp);
      maxPerp = math.max(maxPerp, perp);
    }

    return (lengthM: lengthM, depthM: math.max(0.0, maxPerp - minPerp));
  }

  String? _dimensionsText(String label, List<LatLng> points) {
    final d = _geometryDimensions(points);
    if (d == null) return null;

    if (d.depthM < 1.0) {
      return '$label : L ${d.lengthM.toStringAsFixed(0)} m';
    }

    return '$label : L ${d.lengthM.toStringAsFixed(0)} m • '
        'P ${d.depthM.toStringAsFixed(0)} m';
  }

  List<LatLng> _extendedLinearDisplayGeometry() {
    final targets = data.targetGeometry;
    if (data.targetGeometryClosed || targets.length < 2) {
      return targets;
    }

    final coveredLengthM = _linearCoverageLengthM();
    if (coveredLengthM == null || coveredLengthM <= 0) {
      return targets;
    }

    const earthRadiusM = 6378137.0;
    final first = targets.first;
    final last = targets.last;
    final lat0Rad = ((first.latitude + last.latitude) / 2.0) * math.pi / 180.0;

    final eastM = (last.longitude - first.longitude) *
        math.pi /
        180.0 *
        earthRadiusM *
        math.cos(lat0Rad);
    final northM =
        (last.latitude - first.latitude) * math.pi / 180.0 * earthRadiusM;

    final centerSpanM = math.sqrt(eastM * eastM + northM * northM);
    if (centerSpanM <= 0.001 || coveredLengthM <= centerSpanM) {
      return targets;
    }

    final extensionEachSideM = (coveredLengthM - centerSpanM) / 2.0;
    final uxEast = eastM / centerSpanM;
    final uxNorth = northM / centerSpanM;

    LatLng offset(
      LatLng origin, {
      required double east,
      required double north,
    }) {
      final lat = origin.latitude + north / earthRadiusM * 180.0 / math.pi;
      final cosLat = math.max(
        0.000001,
        math.cos(origin.latitude * math.pi / 180.0).abs(),
      );
      final lon =
          origin.longitude + east / (earthRadiusM * cosLat) * 180.0 / math.pi;
      return LatLng(lat, lon);
    }

    final start = offset(
      first,
      east: -uxEast * extensionEachSideM,
      north: -uxNorth * extensionEachSideM,
    );
    final end = offset(
      last,
      east: uxEast * extensionEachSideM,
      north: uxNorth * extensionEachSideM,
    );

    return <LatLng>[start, ...targets, end];
  }

  double? _linearCoverageLengthM() {
    if (data.targetGeometryClosed || data.targetGeometry.length < 2) {
      return null;
    }

    final centers = _geometryDimensions(data.targetGeometry);
    if (centers == null) return null;

    final footprint = _geometryDimensions(data.impactPolygon);
    final footprintWidth =
        footprint == null ? 0.0 : math.min(footprint.lengthM, footprint.depthM);

    return centers.lengthM + footprintWidth;
  }

  String? _impactFooter({required bool includeRed}) {
    if (!includeRed && !data.targetGeometryClosed) {
      final covered = _linearCoverageLengthM();
      if (covered == null) return null;

      final nominal = covered / 1.10;
      return 'Linear ${nominal.toStringAsFixed(0)} m';
    }

    if (includeRed) {
      final red = _dimensionsText('RED', _redEnvelope());
      return red;
    }

    return _dimensionsText('Emprise centres impacts', data.targetGeometry);
  }

  String? _specialEffectFooter() {
    final effect = data.specialEffect;
    if (effect.isScreening) return effect.footprintStatus;
    if (!effect.isIllumination || !effect.hasFootprint) return null;

    final diameter = effect.effectiveDiameterM;
    final start = effect.startHeightAglM;
    final end = effect.endHeightAglM;
    final durationMin = effect.burnDurationMinS;
    final durationMax = effect.burnDurationMaxS;
    final descent = effect.descentRateMps;
    if (diameter == null ||
        start == null ||
        end == null ||
        durationMax == null) {
      return null;
    }

    final durationText = durationMin != null &&
            (durationMin - durationMax).abs() > 0.001
        ? '${durationMin.toStringAsFixed(0)}–${durationMax.toStringAsFixed(0)} s'
        : '${durationMax.toStringAsFixed(0)} s';
    final descentText =
        descent == null ? '' : ' • ${descent.toStringAsFixed(0)} m/s descent';
    return 'M772 functioning / 1st deployment at calculated point • '
        'footprint Ø ${diameter.toStringAsFixed(0)} m • '
        '$durationText$descentText • '
        '${start.toStringAsFixed(0)} → ${end.toStringAsFixed(0)} m AGL. '
        'The active tables do not publish a separate calculated 2nd deployment/ignition point.';
  }

  Widget _resultCell(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                color: textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '—',
              style: TextStyle(
                color: textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(BuildContext context) {
    if (!data.hasMapData) {
      return _mapUnavailable();
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isPhone = screenWidth < 600.0;

    final globalMapHeight = isPhone ? 285.0 : 360.0;
    final impactMapHeight = isPhone ? 270.0 : 310.0;
    final redMapHeight = isPhone ? 360.0 : 430.0;

    final isSpecialEffect =
        data.specialEffect.isIllumination || data.specialEffect.isScreening;
    // L'écran RP est centré sur le point objectif. Les anciennes cartes
    // pouvaient visualiser la coordonnée D/A calculée à distance du marqueur
    // OBJ lorsque les deux entrées ne concordaient pas.
    final targetCenter = data.specialEffect.isScreening
        ? data.objectifLatLng!
        : (data.impactLatLng ?? data.objectifLatLng!);
    final zonalCircleRadiusM =
        isSpecialEffect ? null : _zonalTheoreticalCircleRadiusM();
    final focusRadius = math
        .max(
          data.impactFocusRadiusM ?? 0,
          data.redFocusRadiusM ?? 0,
        )
        .toDouble();

    final batteryPoints = <MessageBatteryMapPoint>[
      for (final piece in data.batteryPieces)
        if (_batteryFallbackLatLng(piece) case final latLng?)
          MessageBatteryMapPoint(label: piece.label, latLng: latLng),
    ];

    final zonalFrameCircles = !isSpecialEffect && data.targetGeometryClosed
        ? _zonalTheoreticalImpactCircles()
        : const <List<LatLng>>[];
    final impactPolygons = isSpecialEffect || data.targetGeometryClosed
        ? const <List<LatLng>>[]
        : _replicatedPolygons(polygon: data.impactPolygon);
    final specialEffectCenters = data.targetGeometry.isNotEmpty
        ? data.targetGeometry
        : <LatLng>[targetCenter];
    final specialEffectFrame = data.specialEffect.hasFootprint
        ? [
            for (final center in specialEffectCenters)
              ..._circleAround(
                center: center,
                radiusM: data.specialEffect.initialFootprintRadiusM!,
              ),
          ]
        : const <LatLng>[];

    final redCopies = data.targetGeometryClosed
        ? const <List<LatLng>>[]
        : _replicatedPolygons(polygon: data.redPolygon);
    final redFrameEnvelope = data.targetGeometryClosed
        ? data.redPolygon
        : redCopies.isEmpty
            ? _redEnvelope()
            : _convexHullLatLng([for (final poly in redCopies) ...poly]);
    final extendedLinearGeometry = _extendedLinearDisplayGeometry();
    final impactGeometry = <LatLng>[
      targetCenter,
      ...data.targetGeometry,
      ...specialEffectFrame,
      for (final poly in zonalFrameCircles) ...poly,
      for (final poly in impactPolygons) ...poly,
    ];

    final bundle = const MessageMapReportBuilder().build(
      pdLatLng: data.pieceLatLng!,
      objLatLng: data.objectifLatLng!,
      // Le point objectif est fourni à la fois comme impact et géométrie de
      // référence : le constructeur local garde ainsi son propre algorithme
      // de cadrage, sans dépendre d'une extension de signature.
      impactLatLng: targetCenter,
      focusRadiusM: data.specialEffect.hasFootprint
          ? data.specialEffect.initialFootprintRadiusM
          : (focusRadius > 0 ? focusRadius : null),
      batteryPieces: batteryPoints,
      targetGeometry: data.targetGeometry,
      zonalAzimutLargeurMil: data.zonalAzimutLargeurMil,
      zonalAzimutProfondeurMil: data.zonalAzimutProfondeurMil,
      impactGeometry: impactGeometry,
      redGeometry: isSpecialEffect ? const <LatLng>[] : redFrameEnvelope,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bundle.batteryView != null) ...[
          _mapBlock(
            captureKey: reportCapture?.batteryMapKey,
            title: 'Battery emplacement map',
            map: MessageMapReportView(
              config: bundle.batteryView!,
              dark: dark,
              height: 220,
            ),
          ),
          const SizedBox(height: 12),
        ],
        _mapBlock(
          captureKey: reportCapture?.globalMapKey,
          title: 'General map PD → target',
          subtitle: _generalMapSubtitle(),
          map: MessageMapReportView(
            config: bundle.globalView,
            dark: dark,
            impactPolygon: data.impactPolygon,
            redPolygon: data.redPolygon,
            impactPolygons: impactPolygons,
            targetGeometry: data.targetGeometry,
            targetLabels: data.targetLabels,
            targetPieceIds: data.targetPieceIds,
            zonalAzimutLargeurMil: data.zonalAzimutLargeurMil,
            zonalAzimutProfondeurMil: data.zonalAzimutProfondeurMil,
            targetGeometryClosed: data.targetGeometryClosed,
            specialEffect: data.specialEffect,
            height: globalMapHeight,
          ),
        ),
        const SizedBox(height: 12),
        _mapBlock(
          captureKey: reportCapture?.impactMapKey,
          title: data.specialEffect.isIllumination
              ? 'Target / illumination footprint'
              : (data.specialEffect.isScreening
                  ? 'Target / M819 screening envelope'
                  : 'Target / impact'),
          footer: _specialEffectFooter() ?? _impactFooter(includeRed: false),
          map: MessageMapReportView(
            config: bundle.impactView,
            dark: dark,
            impactPolygon: data.impactPolygon,
            impactPolygons: impactPolygons,
            targetGeometry: data.targetGeometry,
            targetLabels: data.targetLabels,
            targetPieceIds: data.targetPieceIds,
            displayLineGeometry: extendedLinearGeometry,
            zonalAzimutLargeurMil: data.zonalAzimutLargeurMil,
            zonalAzimutProfondeurMil: data.zonalAzimutProfondeurMil,
            targetGeometryClosed: data.targetGeometryClosed,
            theoreticalCircleRadiusM: zonalCircleRadiusM,
            specialEffect: data.specialEffect,
            height: impactMapHeight,
          ),
        ),
        if (!isSpecialEffect) ...[
          const SizedBox(height: 12),
          _mapBlock(
            captureKey: reportCapture?.redMapKey,
            title: 'RED / danger zone',
            footer: _impactFooter(includeRed: true),
            map: MessageMapReportView(
              config: bundle.redView,
              dark: dark,
              impactPolygon: data.impactPolygon,
              redPolygon: data.redPolygon,
              impactPolygons: impactPolygons,
              redPolygons: redCopies,
              redEnvelope: redFrameEnvelope,
              targetGeometry: data.targetGeometry,
              targetLabels: data.targetLabels,
              targetPieceIds: data.targetPieceIds,
              theoreticalCircleRadiusM: zonalCircleRadiusM,
              zonalAzimutLargeurMil: data.zonalAzimutLargeurMil,
              zonalAzimutProfondeurMil: data.zonalAzimutProfondeurMil,
              targetGeometryClosed: data.targetGeometryClosed,
              showTargetLabels: false,
              height: redMapHeight,
            ),
          ),
        ],
      ],
    );
  }

  Widget _compactPieceValue(String label, String? value) {
    return Row(
      children: [
        Text(
          '$label ',
          style: TextStyle(
            color: textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Text(
            value ?? '—',
            style: TextStyle(
              color: textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _otherPiecesResults() {
    final others = List<MessagePieceResultData>.from(data.pieceResults);
    final primaryPdIndex = others.indexWhere(
      (piece) => piece.label.trim().toUpperCase() == 'PD',
    );
    if (primaryPdIndex >= 0) {
      others.removeAt(primaryPdIndex);
    } else if (others.isNotEmpty) {
      others.removeAt(0);
    }

    if (others.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Text(
          'OTHER GUNS / OFFSETS',
          style: TextStyle(
            color: textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        for (final p in others)
          Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(9),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 680;

                final pieceHeader = Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      p.label,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (p.offsetM != null)
                      Text(
                        'Offset ${p.offsetM! >= 0 ? '+' : ''}'
                        '${p.offsetM!.toStringAsFixed(0)} m',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                );

                final values = [
                  _compactPieceValue('Firing bearing', p.noire),
                  _compactPieceValue('AQE', p.aqe),
                  _compactPieceValue('Charge', p.charge),
                  _compactPieceValue('TV', p.temps),
                ];

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      pieceHeader,
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(child: values[0]),
                          const SizedBox(width: 10),
                          Expanded(child: values[1]),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(child: values[2]),
                          const SizedBox(width: 10),
                          Expanded(child: values[3]),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    SizedBox(width: 150, child: pieceHeader),
                    const SizedBox(width: 14),
                    Expanded(child: values[0]),
                    const SizedBox(width: 14),
                    Expanded(child: values[1]),
                    const SizedBox(width: 14),
                    Expanded(child: values[2]),
                    const SizedBox(width: 14),
                    Expanded(child: values[3]),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title('LAST CALCULATION CONFIGURATION'),
          _valueRow('System', data.systeme),
          _valueRow('Fire type', data.typeTir),
          _valueRow('Ammunition', data.munition),
          _valueRow('Fuze', data.fusee),
          if (data.chargeOperateur != null)
            _valueRow('Operator charge', data.chargeOperateur),
          if (data.masse != null) _valueRow('Mass', data.masse),
          if (data.tirSimilaire != null)
            _valueRow('Similar fire', data.tirSimilaire),
          if (data.meteo != null) _valueRow('Weather', data.meteo),
          _title('DIRECTING GUN / TARGET'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _positionPanel('Directing gun', data.piecePosition),
              ),
              const SizedBox(width: 10),
              Expanded(child: _positionPanel('Target', data.objectifPosition)),
            ],
          ),
          if (data.batteryPieces.isNotEmpty) ...[
            _title('IMPLANTATION BATTERIE'),
            _batteryCartouche(),
          ],
          _title('MAP AND ZONES'),
          _buildMapSection(context),
          _title('LAST CALCULATION RESULTS'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _resultCell('Firing bearing', data.noire)),
              const SizedBox(width: 18),
              Expanded(child: _resultCell('AQE', data.aqe)),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _resultCell('Charge', data.charge)),
              const SizedBox(width: 18),
              Expanded(child: _resultCell('Time of flight', data.temps)),
            ],
          ),
          _otherPiecesResults(),
        ],
      ),
    );
  }
}
