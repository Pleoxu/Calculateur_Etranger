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
              'Aperçu cartographique indisponible',
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

  String _fmtRelative(double? value,
      {required int digits, required String unit}) {
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

    // Pour la carte d'implantation, D/PD + Az/PD sont la référence d'affichage.
    // On ne dépend donc pas des coordonnées issues du FirePlan / des sorties PS,
    // qui peuvent ne concerner que les pièces effectivement affectées à un shot.
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

  List<List<LatLng>> _replicatedPolygons({
    required List<LatLng> polygon,
  }) {
    if (polygon.length < 3) return const <List<LatLng>>[];

    final baseCenter = data.impactLatLng;
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

  double? _zonalTheoreticalCircleRadiusM() {
    if (!data.targetGeometryClosed || data.targetGeometry.isEmpty) return null;

    final footprint = _geometryDimensions(data.impactPolygon);
    if (footprint != null) {
      return (math.min(footprint.lengthM, footprint.depthM) / 2.0)
          .clamp(5.0, 1000.0)
          .toDouble();
    }

    if (data.impactFocusRadiusM != null && data.impactFocusRadiusM! > 0) {
      return data.impactFocusRadiusM!;
    }

    return 50.0;
  }

  List<List<LatLng>> _zonalTheoreticalImpactCircles() {
    if (!data.targetGeometryClosed || data.targetGeometry.isEmpty) {
      return _replicatedPolygons(polygon: data.impactPolygon);
    }

    // Le CR zonal doit représenter le cercle théorique d'efficacité,
    // pas l'ellipse balistique. On récupère le diamètre transversal de
    // l'empreinte existante : c'est la dimension la plus petite de l'ellipse,
    // donc le diamètre théorique déjà porté par le dernier calcul.
    final footprint = _geometryDimensions(data.impactPolygon);

    final fallbackRadius =
        (data.impactFocusRadiusM != null && data.impactFocusRadiusM! > 0)
            ? data.impactFocusRadiusM!
            : 50.0;

    final radiusM = footprint == null
        ? fallbackRadius
        : (math.min(footprint.lengthM, footprint.depthM) / 2.0)
            .clamp(5.0, 1000.0)
            .toDouble();

    return [
      for (final target in data.targetGeometry)
        _circleAround(
          center: target,
          radiusM: radiusM,
        ),
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
    // En zonal, le collector fournit déjà UNE enveloppe RED globale
    // dans data.redPolygon. Ne surtout pas la répliquer autour des impacts.
    if (data.targetGeometryClosed) {
      return data.redPolygon;
    }

    final redCopies = _replicatedPolygons(polygon: data.redPolygon);
    if (redCopies.isEmpty) return const <LatLng>[];

    return _convexHullLatLng([
      for (final poly in redCopies) ...poly,
    ]);
  }

  ({double lengthM, double depthM})? _geometryDimensions(
    List<LatLng> points,
  ) {
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

    return (
      lengthM: lengthM,
      depthM: math.max(0.0, maxPerp - minPerp),
    );
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

    // Les centres sont volontairement rentrés d'un demi-diamètre à chaque
    // extrémité. La longueur réellement couverte est donc le span des centres
    // + la largeur utile de l'empreinte (ici ~100 m), ce qui redonne 330 m
    // pour un linéaire nominal de 300 m avec 10 % de débordement.
    final footprint = _geometryDimensions(data.impactPolygon);
    final footprintWidth =
        footprint == null ? 0.0 : math.min(footprint.lengthM, footprint.depthM);

    return centers.lengthM + footprintWidth;
  }

  String? _impactFooter({required bool includeRed}) {
    if (!includeRed && !data.targetGeometryClosed) {
      final covered = _linearCoverageLengthM();
      if (covered == null) return null;

      // Le cartouche affiche la longueur nominale demandée.
      // Avec la convention standard du linéaire (débord 10 %), 330 m couverts
      // correspondent à 300 m nominaux.
      final nominal = covered / 1.10;
      return 'Linéaire ${nominal.toStringAsFixed(0)} m';
    }

    if (includeRed) {
      final red = _dimensionsText('RED', _redEnvelope());
      return red;
    }

    // En zonal, targetGeometry contient les CENTRES des impacts calculés.
    // Leur enveloppe n'est pas la dimension nominale de la zone demandée.
    // On l'affiche donc explicitement comme emprise des centres afin d'éviter
    // un CR trompeur du type « Zone objectif : 170 × 169 m » pour un zonal
    // nominal 200 × 200 m.
    return _dimensionsText('Emprise centres impacts', data.targetGeometry);
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

    // Plus de hauteur pour lire la couverture et la RED, sans modifier le zoom
    // géographique ni la géométrie. Sur téléphone on reste plus compact.
    // La carte générale PD -> objectif a besoin de davantage de hauteur
    // sur téléphone lorsque l'axe de tir est très vertical à l'écran.
    // On augmente uniquement ce cartouche, sans toucher aux zooms ni aux
    // cartes impact / RED / batterie.
    final globalMapHeight = isPhone ? 285.0 : 360.0;
    final impactMapHeight = isPhone ? 270.0 : 310.0;
    final redMapHeight = isPhone ? 360.0 : 430.0;

    final focusRadius = math
        .max(
          data.impactFocusRadiusM ?? 0,
          data.redFocusRadiusM ?? 0,
        )
        .toDouble();

    final batteryPoints = <MessageBatteryMapPoint>[
      for (final piece in data.batteryPieces)
        if (_batteryFallbackLatLng(piece) case final latLng?)
          MessageBatteryMapPoint(
            label: piece.label,
            latLng: latLng,
          ),
    ];

    final zonalCircleRadiusM = _zonalTheoreticalCircleRadiusM();

    // Les cercles théoriques zonaux sont dessinés par CircleMarker dans la vue,
    // mais le builder a quand même besoin de leur emprise géographique pour
    // calculer un zoom avec une marge suffisante autour de toute la couverture.
    final zonalFrameCircles = data.targetGeometryClosed
        ? _zonalTheoreticalImpactCircles()
        : const <List<LatLng>>[];

    final impactPolygons = data.targetGeometryClosed
        ? const <List<LatLng>>[]
        : _replicatedPolygons(polygon: data.impactPolygon);

    // En zonal, data.redPolygon est déjà l'enveloppe RED globale calculée
    // par le collector. Elle ne doit jamais être répliquée autour des impacts.
    final redCopies = data.targetGeometryClosed
        ? const <List<LatLng>>[]
        : _replicatedPolygons(polygon: data.redPolygon);

    // En zonal : utiliser directement l'enveloppe globale existante.
    // Hors zonal : conserver le comportement historique.
    final redFrameEnvelope = data.targetGeometryClosed
        ? data.redPolygon
        : redCopies.isEmpty
            ? _redEnvelope()
            : _convexHullLatLng([
                for (final poly in redCopies) ...poly,
              ]);

    final extendedLinearGeometry = _extendedLinearDisplayGeometry();

    final bundle = const MessageMapReportBuilder().build(
      pdLatLng: data.pieceLatLng!,
      objLatLng: data.objectifLatLng!,
      impactLatLng: data.impactLatLng ?? data.objectifLatLng,
      focusRadiusM: focusRadius > 0 ? focusRadius : null,
      batteryPieces: batteryPoints,
      targetGeometry: data.targetGeometry,
      zonalAzimutLargeurMil: data.zonalAzimutLargeurMil,
      zonalAzimutProfondeurMil: data.zonalAzimutProfondeurMil,
      impactGeometry: [
        // En zonal : cadrer sur le bord extérieur des cercles théoriques.
        for (final poly in zonalFrameCircles) ...poly,
        // En linéaire / autres modes : conserver l'emprise existante.
        for (final poly in impactPolygons) ...poly,
      ],
      redGeometry: redFrameEnvelope,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bundle.batteryView != null) ...[
          _mapBlock(
            captureKey: reportCapture?.batteryMapKey,
            title: 'Carte implantation batterie',
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
          title: 'Carte générale PD → objectif',
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
            height: globalMapHeight,
          ),
        ),
        const SizedBox(height: 12),
        _mapBlock(
          captureKey: reportCapture?.impactMapKey,
          title: 'Objectif / impact',
          footer: _impactFooter(includeRed: false),
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
            height: impactMapHeight,
          ),
        ),
        const SizedBox(height: 12),
        _mapBlock(
          captureKey: reportCapture?.redMapKey,
          title: 'Zone RED / danger',
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
    final others = data.pieceResults
        .where((p) => p.label.trim().toUpperCase() != 'PD')
        .toList();

    if (others.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Text(
          'AUTRES PIÈCES',
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

                final pieceHeader = Row(
                  children: [
                    Text(
                      p.label,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (p.offsetM != null) ...[
                      const SizedBox(width: 8),
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
                  ],
                );

                final values = [
                  _compactPieceValue('Noire', p.noire),
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
          _title('CONFIGURATION DU DERNIER CALCUL'),
          _valueRow('Système', data.systeme),
          _valueRow('Type de tir', data.typeTir),
          _valueRow('Munition', data.munition),
          _valueRow('Fuze', data.fusee),
          if (data.chargeOperateur != null)
            _valueRow('Operator charge', data.chargeOperateur),
          if (data.masse != null) _valueRow('Masse', data.masse),
          if (data.tirSimilaire != null)
            _valueRow('Similar fire', data.tirSimilaire),
          if (data.meteo != null) _valueRow('Weather', data.meteo),
          _title('PIÈCE DIRECTRICE / OBJECTIF'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _positionPanel('Pièce directrice', data.piecePosition),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _positionPanel('Objectif', data.objectifPosition),
              ),
            ],
          ),
          if (data.batteryPieces.isNotEmpty) ...[
            _title('IMPLANTATION BATTERIE'),
            _batteryCartouche(),
          ],
          _title('CARTE ET ZONES'),
          _buildMapSection(context),
          _title('RÉSULTATS DU DERNIER CALCUL'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _resultCell('Noire', data.noire)),
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
