// lib/presentation/fire/widgets/message_map_report_view.dart

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:calculateur_etranger/domain/fire/effects/special_effect_display_profile.dart';

import 'package:calculateur_etranger/presentation/fire/models/message_map_report_models.dart';
import 'package:calculateur_etranger/services/maps/local_map_service.dart';

Color _zonalPieceColor(String rawLabel) {
  final label = rawLabel.trim().toUpperCase();
  switch (label) {
    case 'PS7':
      return const Color(0xFFEC67C4);
    case 'PS6':
      return const Color(0xFF5EC269);
    case 'PS5':
      return const Color(0xFFF2A341);
    case 'PD':
      return const Color(0xFF70E3AB);
    case 'PS1':
      return const Color(0xFFEC5B55);
    case 'PS2':
      return const Color(0xFF4E80EE);
    case 'PS3':
      return const Color(0xFFF8D65B);
    case 'PS4':
      return const Color(0xFF876C42);
    default:
      return const Color(0xFF4DB6FF);
  }
}

class MessageMapReportView extends StatefulWidget {
  const MessageMapReportView({
    super.key,
    required this.config,
    required this.dark,
    this.impactPolygon = const <LatLng>[],
    this.redPolygon = const <LatLng>[],
    this.impactPolygons = const <List<LatLng>>[],
    this.redPolygons = const <List<LatLng>>[],
    this.redEnvelope = const <LatLng>[],
    this.targetGeometry = const <LatLng>[],
    this.targetLabels = const <String>[],
    this.targetPieceIds = const <String>[],
    this.showTargetLabels = true,
    this.displayLineGeometry = const <LatLng>[],
    this.targetGeometryClosed = false,
    this.zonalAzimutLargeurMil,
    this.zonalAzimutProfondeurMil,
    this.theoreticalCircleRadiusM,
    this.specialEffect = const SpecialEffectDisplayProfile.none(),
    this.height = 260,
  });

  final MessageMapViewConfig config;
  final bool dark;
  final List<LatLng> impactPolygon;
  final List<LatLng> redPolygon;
  final List<List<LatLng>> impactPolygons;
  final List<List<LatLng>> redPolygons;
  final List<LatLng> redEnvelope;
  final List<LatLng> targetGeometry;
  final List<String> targetLabels;
  final List<String> targetPieceIds;
  final bool showTargetLabels;
  final List<LatLng> displayLineGeometry;
  final bool targetGeometryClosed;
  final double? zonalAzimutLargeurMil;
  final double? zonalAzimutProfondeurMil;
  final double? theoreticalCircleRadiusM;
  final SpecialEffectDisplayProfile specialEffect;
  final double height;

  @override
  State<MessageMapReportView> createState() => _MessageMapReportViewState();
}

class _MessageMapReportViewState extends State<MessageMapReportView> {
  TileProvider? _localTileProvider;
  bool _onlineEnabled = false;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadActiveOfflineMap();
  }

  @override
  void didUpdateWidget(covariant MessageMapReportView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadActiveOfflineMap();
  }

  Future<void> _loadActiveOfflineMap() async {
    try {
      final onlineEnabled = await LocalMapService.instance.isOnlineEnabled();

      if (!mounted) return;

      if (onlineEnabled) {
        _localTileProvider?.dispose();

        setState(() {
          _onlineEnabled = true;
          _localTileProvider = null;
          _loading = false;
          _loadError = null;
        });
        return;
      }

      setState(() {
        _onlineEnabled = false;
        _loading = true;
        _loadError = null;
      });

      final zoneId = await LocalMapService.instance.activeZoneId();

      if (zoneId == null || zoneId.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _loadError = 'No offline map active';
        });
        return;
      }

      final provider = await LocalMapService.instance.providerFor(
        zoneId.trim(),
      );

      if (!mounted) {
        provider?.dispose();
        return;
      }

      setState(() {
        _localTileProvider = provider;
        _loading = false;
        _loadError = provider == null ? 'Offline basemap unavailable' : null;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('[MAP REPORT] MBTiles loading failed: $e');
      setState(() {
        _loading = false;
        _loadError = 'Offline basemap unavailable';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _MessageMapReportBody(
          config: widget.config,
          dark: widget.dark,
          onlineEnabled: _onlineEnabled,
          localTileProvider: _localTileProvider,
          impactPolygon: widget.impactPolygon,
          redPolygon: widget.redPolygon,
          impactPolygons: widget.impactPolygons,
          redPolygons: widget.redPolygons,
          redEnvelope: widget.redEnvelope,
          targetGeometry: widget.targetGeometry,
          targetLabels: widget.targetLabels,
          targetPieceIds: widget.targetPieceIds,
          showTargetLabels: widget.showTargetLabels,
          displayLineGeometry: widget.displayLineGeometry,
          targetGeometryClosed: widget.targetGeometryClosed,
          zonalAzimutLargeurMil: widget.zonalAzimutLargeurMil,
          zonalAzimutProfondeurMil: widget.zonalAzimutProfondeurMil,
          theoreticalCircleRadiusM: widget.theoreticalCircleRadiusM,
          specialEffect: widget.specialEffect,
          height: widget.height,
        ),
        if (_loading)
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          )
        else if (_localTileProvider == null && _loadError != null)
          Positioned(
            left: 12,
            bottom: 12,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _loadError!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MessageMapReportBody extends StatelessWidget {
  const _MessageMapReportBody({
    required this.config,
    required this.dark,
    required this.onlineEnabled,
    required this.localTileProvider,
    this.impactPolygon = const <LatLng>[],
    this.redPolygon = const <LatLng>[],
    this.impactPolygons = const <List<LatLng>>[],
    this.redPolygons = const <List<LatLng>>[],
    this.redEnvelope = const <LatLng>[],
    this.targetGeometry = const <LatLng>[],
    this.targetLabels = const <String>[],
    this.targetPieceIds = const <String>[],
    this.showTargetLabels = true,
    this.displayLineGeometry = const <LatLng>[],
    this.targetGeometryClosed = false,
    this.zonalAzimutLargeurMil,
    this.zonalAzimutProfondeurMil,
    this.theoreticalCircleRadiusM,
    this.specialEffect = const SpecialEffectDisplayProfile.none(),
    this.height = 260,
  });

  final MessageMapViewConfig config;
  final bool dark;
  final bool onlineEnabled;
  final TileProvider? localTileProvider;
  final List<LatLng> impactPolygon;
  final List<LatLng> redPolygon;
  final List<List<LatLng>> impactPolygons;
  final List<List<LatLng>> redPolygons;
  final List<LatLng> redEnvelope;
  final List<LatLng> targetGeometry;
  final List<String> targetLabels;
  final List<String> targetPieceIds;
  final bool showTargetLabels;
  final List<LatLng> displayLineGeometry;
  final bool targetGeometryClosed;
  final double? zonalAzimutLargeurMil;
  final double? zonalAzimutProfondeurMil;
  final double? theoreticalCircleRadiusM;
  final SpecialEffectDisplayProfile specialEffect;
  final double height;

  double _bearingDeg(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180.0;
    final lat2 = to.latitude * math.pi / 180.0;
    final dLon = (to.longitude - from.longitude) * math.pi / 180.0;

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    var deg = math.atan2(y, x) * 180.0 / math.pi;
    if (deg < 0) deg += 360.0;
    return deg;
  }

  bool get _hasExplicitZonalAxes =>
      zonalAzimutLargeurMil != null &&
      zonalAzimutLargeurMil!.isFinite &&
      zonalAzimutProfondeurMil != null &&
      zonalAzimutProfondeurMil!.isFinite;

  double? get _tirBearingDeg {
    if (config.kind == MessageMapViewKind.impactZone && _hasExplicitZonalAxes) {
      return (zonalAzimutProfondeurMil! % 6400.0) * 360.0 / 6400.0;
    }

    final pd = config.pdLatLng;
    final obj = config.objLatLng;
    if (pd == null || obj == null) return null;
    return _bearingDeg(pd, obj);
  }

  double? get _linearBearingDeg {
    if (config.kind == MessageMapViewKind.impactZone && _hasExplicitZonalAxes) {
      return (zonalAzimutLargeurMil! % 6400.0) * 360.0 / 6400.0;
    }

    if (targetGeometryClosed) return null;

    final points =
        displayLineGeometry.length >= 2 ? displayLineGeometry : targetGeometry;
    if (points.length < 2) return null;
    return _bearingDeg(points.first, points.last);
  }

  int _normalizeMil(double mil) {
    var value = mil.round() % 6400;
    if (value < 0) value += 6400;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final background = dark ? const Color(0xFF0E1014) : const Color(0xFFF5F6F8);
    final border = dark ? Colors.white.withValues(alpha: 0.12) : Colors.black12;
    final textSecondary = dark ? Colors.white70 : Colors.black54;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isPhone = screenWidth < 600.0;
    final isImpactMap = config.kind == MessageMapViewKind.impactZone;
    final isRedMap = config.kind == MessageMapViewKind.impactPlusRed;

    final impactCenters = targetGeometry.isNotEmpty
        ? targetGeometry
        : <LatLng>[
            if (config.impactLatLng != null)
              config.impactLatLng!
            else if (config.objLatLng != null)
              config.objLatLng!,
          ];
    final targetMarkerSize = isRedMap
        ? (isPhone ? 7.0 : 9.0)
        : isImpactMap
            ? (isPhone ? 18.0 : 22.0)
            : 34.0;

    final markers = <Marker>[
      if (config.kind == MessageMapViewKind.batteryDeployment)
        for (final piece in config.batteryPoints)
          Marker(
            point: piece.latLng,
            width: 42,
            height: 42,
            child: _BatteryPieceMarker(
              label: piece.label,
              isPd: piece.isPd,
              pieceColor: _zonalPieceColor(piece.label),
            ),
          ),
      if (config.showPd && config.pdLatLng != null)
        Marker(
          point: config.pdLatLng!,
          width: 36,
          height: 36,
          child: const _PointMarker(
            label: 'PD',
            icon: Icons.crop_square_rounded,
          ),
        ),
      if (config.showObj &&
          config.objLatLng != null &&
          ((config.kind != MessageMapViewKind.impactZone &&
                  config.kind != MessageMapViewKind.impactPlusRed) ||
              targetGeometry.length < 2))
        Marker(
          point: config.objLatLng!,
          width: 38,
          height: 38,
          child: const _PointMarker(label: 'OBJ', icon: Icons.adjust_rounded),
        ),
      if (config.showImpact && config.impactLatLng != null)
        Marker(
          point: config.impactLatLng!,
          width: 38,
          height: 38,
          child: const _PointMarker(label: 'Impact', icon: Icons.circle),
        ),
      if (isImpactMap && specialEffect.isScreening && impactCenters.isNotEmpty)
        for (final center in impactCenters)
          Marker(
            point: center,
            width: 56,
            height: 42,
            child: const _PointMarker(
              label: 'M772',
              icon: Icons.cloud_outlined,
            ),
          )
      else if (isImpactMap &&
          specialEffect.isIllumination &&
          impactCenters.isNotEmpty)
        for (final center in impactCenters)
          Marker(
            point: center,
            width: 56,
            height: 42,
            child: const _PointMarker(
              label: 'M772',
              icon: Icons.lightbulb_outline_rounded,
            ),
          )
      else if ((config.kind == MessageMapViewKind.impactZone ||
              config.kind == MessageMapViewKind.impactPlusRed) &&
          targetGeometry.isNotEmpty)
        for (var i = 0; i < targetGeometry.length; i++)
          Marker(
            point: targetGeometry[i],
            width: targetMarkerSize,
            height: targetMarkerSize,
            child: _TargetGeometryMarker(
              label: showTargetLabels &&
                      i < targetLabels.length &&
                      targetLabels[i].trim().isNotEmpty
                  ? targetLabels[i]
                  : '',
              pieceColor: isImpactMap &&
                      i < targetPieceIds.length &&
                      targetPieceIds[i].trim().isNotEmpty
                  ? _zonalPieceColor(targetPieceIds[i])
                  : null,
              impactStyle: isImpactMap,
              compact: isPhone || isRedMap,
            ),
          ),
    ];

    final cr4TirAxis = <LatLng>[];
    if (isRedMap && config.pdLatLng != null && config.objLatLng != null) {
      cr4TirAxis.addAll(<LatLng>[config.pdLatLng!, config.objLatLng!]);
    }

    final lineGeometry =
        displayLineGeometry.length >= 2 ? displayLineGeometry : targetGeometry;

    final polylines = <Polyline>[
      if (cr4TirAxis.length >= 2)
        Polyline(
          points: cr4TirAxis,
          strokeWidth: 2.0,
          color: const Color(0xFFFF4D3D).withValues(alpha: 0.75),
        ),
      if (lineGeometry.length >= 2 && !targetGeometryClosed) ...[
        Polyline(
          points: lineGeometry,
          strokeWidth: 6.0,
          color: const Color(0xCC11141A),
        ),
        Polyline(
          points: lineGeometry,
          strokeWidth: 3.0,
          color: config.kind == MessageMapViewKind.impactZone
              ? const Color(0xFFFFB000)
              : const Color(0xFF4DB6FF),
        ),
      ],
      if (config.showTrajectory &&
          config.pdLatLng != null &&
          config.objLatLng != null) ...[
        Polyline(
          points: <LatLng>[config.pdLatLng!, config.objLatLng!],
          strokeWidth: 6.0,
          color: const Color(0xCC11141A),
        ),
        Polyline(
          points: <LatLng>[config.pdLatLng!, config.objLatLng!],
          strokeWidth: 3.2,
          color: const Color(0xFFFFB000),
        ),
      ],
    ];

    final polygons = <Polygon>[
      if (!isRedMap && targetGeometryClosed && targetGeometry.length >= 3)
        Polygon(
          points: _convexHullLatLng(targetGeometry),
          color: const Color(0xFF4DB6FF).withValues(alpha: 0.12),
          borderColor: const Color(0xFF4DB6FF).withValues(alpha: 0.92),
          borderStrokeWidth: 2.0,
        ),
      if (!specialEffect.isIllumination &&
          !specialEffect.isScreening &&
          impactPolygons.isNotEmpty)
        for (final poly in impactPolygons)
          if (poly.length >= 3)
            Polygon(
              points: poly,
              color: const Color(0xFFECEFF1).withValues(alpha: 0.35),
              borderColor: const Color(0xFFB0BEC5).withValues(alpha: 0.85),
              borderStrokeWidth: 1.8,
            )
          else if (impactPolygon.length >= 3)
            Polygon(
              points: impactPolygon,
              color: const Color(0xFFFFC14D).withValues(alpha: 0.18),
              borderColor: const Color(0xFFFFB000).withValues(alpha: 0.90),
              borderStrokeWidth: 2.0,
            ),
      if (config.showRedZone) ...[
        if (redPolygons.any((poly) => poly.length >= 3)) ...[
          for (final poly in redPolygons)
            if (poly.length >= 3)
              Polygon(
                points: poly,
                color: const Color(0xFFFF4D3D).withValues(alpha: 0.10),
                borderColor: const Color(0xFFFF4D3D).withValues(alpha: 0.82),
                borderStrokeWidth: 1.9,
              ),
        ] else if (redPolygon.length >= 3)
          Polygon(
            points: redPolygon,
            color: const Color(0xFFFF4D3D).withValues(alpha: 0.15),
            borderColor: const Color(0xFFFF4D3D).withValues(alpha: 0.95),
            borderStrokeWidth: 2.4,
          )
        else if (redEnvelope.length >= 3)
          Polygon(
            points: redEnvelope,
            color: const Color(0xFFFF4D3D).withValues(alpha: 0.15),
            borderColor: const Color(0xFFFF4D3D).withValues(alpha: 0.95),
            borderStrokeWidth: 2.4,
          ),
      ],
    ];

    final legendItems = <_LegendItemData>[
      if (specialEffect.isIllumination && specialEffect.hasFootprint)
        const _LegendItemData(
          label: 'Illumination footprint',
          color: Color(0xFFFFCC00),
        ),
      if (specialEffect.isScreening && isImpactMap)
        const _LegendItemData(
          label: 'M772 deployment',
          color: Color(0xFF61D6A5),
        ),
      if (config.kind != MessageMapViewKind.impactZone &&
          targetGeometry.length >= 2)
        const _LegendItemData(label: 'Target', color: Color(0xFF4DB6FF)),
      if (config.showRedZone &&
          (redPolygons.isNotEmpty ||
              redEnvelope.length >= 3 ||
              redPolygon.length >= 3))
        const _LegendItemData(label: 'RED', color: Color(0xFFFF4D3D)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const referenceWidthPx = 720.0;
        final actualWidthPx = constraints.maxWidth.isFinite
            ? math.max(220.0, constraints.maxWidth)
            : referenceWidthPx;

        final safeWidthPx = math.max(180.0, actualWidthPx * 0.80);

        final widthZoomCorrection =
            (math.log(safeWidthPx / referenceWidthPx) / math.ln2)
                .clamp(-3.0, 1.0)
                .toDouble();

        final offlineMinZoom =
            localTileProvider != null ? 11.0 : (config.minZoom ?? 3.0);
        final effectiveZoom = (config.zoom + widthZoomCorrection)
            .clamp(
              math.max(config.minZoom ?? 3.0, offlineMinZoom),
              config.maxZoom ?? 18.0,
            )
            .toDouble();

        final widthBucket = (actualWidthPx / 24.0).round();

        final showDirectionRose =
            config.kind == MessageMapViewKind.impactZone &&
                _hasExplicitZonalAxes &&
                _tirBearingDeg != null &&
                _linearBearingDeg != null;

        return Container(
          height: height,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              FlutterMap(
                key: ValueKey(
                  '${config.kind}-$widthBucket-'
                  '${effectiveZoom.toStringAsFixed(2)}',
                ),
                options: MapOptions(
                  initialCenter: config.center,
                  initialZoom: effectiveZoom,
                  initialRotation: config.rotationDeg,
                  minZoom: math
                      .max(
                        (config.minZoom ?? 3.0).toDouble(),
                        localTileProvider != null ? 11.0 : 3.0,
                      )
                      .toDouble(),
                  maxZoom: config.maxZoom ?? 18,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  if (onlineEnabled)
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.calculateurTirNg',
                    )
                  else if (localTileProvider != null)
                    TileLayer(
                      tileProvider: localTileProvider!,
                      minNativeZoom: 11,
                      maxNativeZoom: 15,
                    )
                  else
                    const SizedBox.shrink(),
                  if (config.showImpactZone &&
                      specialEffect.hasFootprint &&
                      impactCenters.isNotEmpty)
                    CircleLayer(
                      circles: [
                        for (final target in impactCenters)
                          CircleMarker(
                            point: target,
                            radius: specialEffect.initialFootprintRadiusM!,
                            useRadiusInMeter: true,
                            color:
                                const Color(0xFFFFDD00).withValues(alpha: 0.16),
                            borderColor:
                                const Color(0xFFFFCC00).withValues(alpha: 0.96),
                            borderStrokeWidth: 2.4,
                          ),
                      ],
                    ),
                  if (config.showImpactZone &&
                      !specialEffect.hasFootprint &&
                      theoreticalCircleRadiusM != null &&
                      theoreticalCircleRadiusM! > 0 &&
                      impactCenters.isNotEmpty)
                    CircleLayer(
                      circles: [
                        for (final target in impactCenters)
                          CircleMarker(
                            point: target,
                            radius: theoreticalCircleRadiusM!,
                            useRadiusInMeter: true,
                            color: const Color(
                              0xFFFFC14D,
                            ).withValues(alpha: 0.12),
                            borderColor: const Color(
                              0xFFFFB000,
                            ).withValues(alpha: 0.88),
                            borderStrokeWidth: 1.6,
                          ),
                      ],
                    ),
                  if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
                  if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                  if (markers.isNotEmpty) MarkerLayer(markers: markers),
                ],
              ),
              Positioned(
                top: 9,
                right: 9,
                child: showDirectionRose
                    ? _DirectionRose(
                        dark: dark,
                        tirBearingDeg: _tirBearingDeg!,
                        linearBearingDeg: _linearBearingDeg!,
                        mapRotationDeg: config.rotationDeg,
                        tirLabel:
                            'P ${_normalizeMil(zonalAzimutProfondeurMil!)}',
                        linearLabel:
                            'F ${_normalizeMil(zonalAzimutLargeurMil!)}',
                      )
                    : _NorthIndicator(
                        dark: dark,
                        border: border,
                        mapRotationDeg: config.rotationDeg,
                      ),
              ),
              if (config.scaleBarMeters != null)
                Positioned(
                  left: 12,
                  bottom: legendItems.isNotEmpty ? 54 : 12,
                  child: _ScaleIndicator(
                    meters: config.scaleBarMeters!,
                    zoom: effectiveZoom,
                    latitudeDeg: config.center.latitude,
                    dark: dark,
                    border: border,
                  ),
                ),
              if (legendItems.isNotEmpty)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: dark
                          ? Colors.black.withValues(alpha: 0.72)
                          : Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: border),
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        for (final item in legendItems)
                          _LegendItem(item: item, textSecondary: textSecondary),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DirectionRose extends StatelessWidget {
  const _DirectionRose({
    required this.dark,
    required this.tirBearingDeg,
    required this.linearBearingDeg,
    required this.mapRotationDeg,
    this.tirLabel,
    this.tirOppositeLabel,
    this.linearLabel,
    this.linearOppositeLabel,
  });

  final bool dark;
  final double tirBearingDeg;
  final double linearBearingDeg;
  final double mapRotationDeg;
  final String? tirLabel;
  final String? tirOppositeLabel;
  final String? linearLabel;
  final String? linearOppositeLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 146,
      height: 146,
      child: CustomPaint(
        painter: _DirectionRosePainter(
          tirBearingDeg: tirBearingDeg,
          linearBearingDeg: linearBearingDeg,
          mapRotationDeg: mapRotationDeg,
          tirLabel: tirLabel,
          tirOppositeLabel: tirOppositeLabel,
          linearLabel: linearLabel,
          linearOppositeLabel: linearOppositeLabel,
          dark: dark,
        ),
      ),
    );
  }
}

class _DirectionRosePainter extends CustomPainter {
  const _DirectionRosePainter({
    required this.tirBearingDeg,
    required this.linearBearingDeg,
    required this.mapRotationDeg,
    required this.dark,
    this.tirLabel,
    this.tirOppositeLabel,
    this.linearLabel,
    this.linearOppositeLabel,
  });

  final double tirBearingDeg;
  final double linearBearingDeg;
  final double mapRotationDeg;
  final bool dark;
  final String? tirLabel;
  final String? tirOppositeLabel;
  final String? linearLabel;
  final String? linearOppositeLabel;

  int _milFromDeg(double deg) {
    var normalized = deg % 360.0;
    if (normalized < 0) normalized += 360.0;
    var mil = (normalized * 6400.0 / 360.0).round();
    if (mil >= 6400) mil = 0;
    return mil;
  }

  Offset _point(Offset center, double radius, double bearingDeg) {
    final angle = (bearingDeg - 90.0) * math.pi / 180.0;
    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
  }

  void _drawArrow(
    Canvas canvas,
    Offset center,
    double bearingDeg,
    Color color,
    String label,
    double radius,
  ) {
    final end = _point(center, radius, bearingDeg);

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(center, end, paint);

    final angle = (bearingDeg - 90.0) * math.pi / 180.0;
    const head = 7.0;
    final p1 = Offset(
      end.dx - head * math.cos(angle - 0.55),
      end.dy - head * math.sin(angle - 0.55),
    );
    final p2 = Offset(
      end.dx - head * math.cos(angle + 0.55),
      end.dy - head * math.sin(angle + 0.55),
    );

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      ui.Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close(),
      fill,
    );

    final labelPos = _point(center, radius + 11.0, bearingDeg);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset(labelPos.dx - tp.width / 2, labelPos.dy - tp.height / 2),
    );
  }

  void _drawOppositeArrow(
    Canvas canvas,
    Offset center,
    double bearingDeg,
    Color color,
    String label,
    double radius,
  ) {
    _drawArrow(
      canvas,
      center,
      (bearingDeg + 180.0) % 360.0,
      color,
      label,
      radius,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 2);
    final circleRadius = math.min(size.width, size.height) * 0.29;

    final circlePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.62)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, circleRadius, circlePaint);

    final screenNorthDeg = -mapRotationDeg;
    final screenTirDeg = tirBearingDeg - mapRotationDeg;
    final screenAxisDeg = linearBearingDeg - mapRotationDeg;

    _drawArrow(
      canvas,
      center,
      screenNorthDeg,
      Colors.black,
      'N',
      circleRadius + 3,
    );

    _drawArrow(
      canvas,
      center,
      screenTirDeg,
      const Color(0xFF48E0B5),
      tirLabel ?? '${_milFromDeg(tirBearingDeg)}',
      circleRadius + 1,
    );
    if (tirOppositeLabel != null) {
      _drawOppositeArrow(
        canvas,
        center,
        screenTirDeg,
        const Color(0xFF48E0B5),
        tirOppositeLabel!,
        circleRadius + 1,
      );
    }

    _drawArrow(
      canvas,
      center,
      screenAxisDeg,
      const Color(0xFFFFB000),
      linearLabel ?? '${_milFromDeg(linearBearingDeg)}',
      circleRadius + 1,
    );
    if (linearOppositeLabel != null) {
      _drawOppositeArrow(
        canvas,
        center,
        screenAxisDeg,
        const Color(0xFFFFB000),
        linearOppositeLabel!,
        circleRadius + 1,
      );
    }

    canvas.drawCircle(
      center,
      2.4,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _DirectionRosePainter oldDelegate) {
    return oldDelegate.tirBearingDeg != tirBearingDeg ||
        oldDelegate.linearBearingDeg != linearBearingDeg ||
        oldDelegate.mapRotationDeg != mapRotationDeg ||
        oldDelegate.tirLabel != tirLabel ||
        oldDelegate.tirOppositeLabel != tirOppositeLabel ||
        oldDelegate.linearLabel != linearLabel ||
        oldDelegate.linearOppositeLabel != linearOppositeLabel ||
        oldDelegate.dark != dark;
  }
}

class _NorthIndicator extends StatelessWidget {
  const _NorthIndicator({
    required this.dark,
    required this.border,
    required this.mapRotationDeg,
  });

  final bool dark;
  final Color border;
  final double mapRotationDeg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 48,
      decoration: BoxDecoration(
        color: dark
            ? Colors.black.withValues(alpha: 0.76)
            : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'N',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFFB000),
            ),
          ),
          const SizedBox(height: 1),
          Transform.rotate(
            angle: -mapRotationDeg * math.pi / 180.0,
            child: const Icon(
              Icons.navigation_rounded,
              size: 20,
              color: Color(0xFFFFB000),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaleIndicator extends StatelessWidget {
  const _ScaleIndicator({
    required this.meters,
    required this.zoom,
    required this.latitudeDeg,
    required this.dark,
    required this.border,
  });

  final double meters;
  final double zoom;
  final double latitudeDeg;
  final bool dark;
  final Color border;

  @override
  Widget build(BuildContext context) {
    const webMercatorMetersPerPixelAtZoom0 = 156543.03392;
    final latitudeRad = latitudeDeg * math.pi / 180.0;

    final metersPerPixel = webMercatorMetersPerPixelAtZoom0 *
        math.max(0.01, math.cos(latitudeRad).abs()) /
        math.pow(2.0, zoom);

    final widthPx = (meters / math.max(0.0001, metersPerPixel)).clamp(
      44.0,
      160.0,
    );

    final fg = dark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 5),
      decoration: BoxDecoration(
        color: dark
            ? Colors.black.withValues(alpha: 0.76)
            : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: widthPx,
            height: 7,
            child: CustomPaint(painter: _ScaleBarPainter(color: fg)),
          ),
          const SizedBox(height: 2),
          Text(
            '${meters.toStringAsFixed(0)} m',
            style: TextStyle(
              color: fg,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaleBarPainter extends CustomPainter {
  const _ScaleBarPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final y = size.height - 1.0;

    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    canvas.drawLine(Offset(0, 0), Offset(0, size.height), paint);
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScaleBarPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _BatteryPieceMarker extends StatelessWidget {
  const _BatteryPieceMarker({
    required this.label,
    required this.isPd,
    required this.pieceColor,
  });

  final String label;
  final bool isPd;
  final Color pieceColor;

  @override
  Widget build(BuildContext context) {
    final accent = pieceColor;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: isPd ? 27 : 23,
          height: isPd ? 27 : 23,
          decoration: BoxDecoration(
            color: const Color(0xEE11141A),
            shape: BoxShape.circle,
            border: Border.all(color: accent, width: isPd ? 2.2 : 1.6),
          ),
          child: Icon(
            isPd ? Icons.crop_square_rounded : Icons.circle_outlined,
            size: isPd ? 15 : 12,
            color: accent,
          ),
        ),
        Positioned(
          top: 28,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xE611141A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: accent.withValues(alpha: 0.65),
                width: 0.8,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isPd ? const Color(0xFFFFC14D) : Colors.white,
                fontSize: 8.8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TargetGeometryMarker extends StatelessWidget {
  const _TargetGeometryMarker({
    required this.label,
    this.pieceColor,
    this.impactStyle = false,
    this.compact = false,
  });

  final String label;
  final Color? pieceColor;
  final bool impactStyle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = impactStyle
        ? (pieceColor ?? const Color(0xFFFFB000))
        : const Color(0xFF4DB6FF);
    final fillColor = impactStyle ? accent : const Color(0xEE11141A);

    return Container(
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: impactStyle ? const Color(0xCC11141A) : accent,
          width: compact ? 1.1 : 1.6,
        ),
      ),
      alignment: Alignment.center,
      child: label.trim().isEmpty
          ? Center(
              child: Container(
                width: compact ? 4.5 : 7.0,
                height: compact ? 4.5 : 7.0,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    color: impactStyle ? Colors.black : Colors.white,
                    fontSize: compact ? 8.0 : 10.0,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
    );
  }
}

class _PointMarker extends StatelessWidget {
  const _PointMarker({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF11141A).withValues(alpha: 0.90),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white70, width: 1.2),
          ),
          child: Icon(icon, size: 12, color: Colors.white),
        ),
        Positioned(
          top: 26,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xDD11141A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8.8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

List<LatLng> _convexHullLatLng(List<LatLng> points) {
  if (points.length <= 3) return List<LatLng>.from(points);

  final pts = List<LatLng>.from(points)
    ..sort((a, b) {
      final lon = a.longitude.compareTo(b.longitude);
      if (lon != 0) return lon;
      return a.latitude.compareTo(b.latitude);
    });

  double cross(LatLng o, LatLng a, LatLng b) {
    return (a.longitude - o.longitude) * (b.latitude - o.latitude) -
        (a.latitude - o.latitude) * (b.longitude - o.longitude);
  }

  final lower = <LatLng>[];
  for (final p in pts) {
    while (lower.length >= 2 &&
        cross(lower[lower.length - 2], lower.last, p) <= 0) {
      lower.removeLast();
    }
    lower.add(p);
  }

  final upper = <LatLng>[];
  for (final p in pts.reversed) {
    while (upper.length >= 2 &&
        cross(upper[upper.length - 2], upper.last, p) <= 0) {
      upper.removeLast();
    }
    upper.add(p);
  }

  if (lower.isNotEmpty) lower.removeLast();
  if (upper.isNotEmpty) upper.removeLast();

  final hull = <LatLng>[...lower, ...upper];
  return hull.length >= 3 ? hull : List<LatLng>.from(points);
}

class _LegendItemData {
  const _LegendItemData({required this.label, required this.color});

  final String label;
  final Color color;
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.item, required this.textSecondary});

  final _LegendItemData item;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          item.label,
          style: TextStyle(
            color: textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
