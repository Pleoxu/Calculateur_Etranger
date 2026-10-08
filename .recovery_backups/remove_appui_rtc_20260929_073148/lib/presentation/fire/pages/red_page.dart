import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/presentation/fire/painters/tir_painter_utils.dart';
import 'package:calculateur_etranger/services/effects/red_service.dart';
import 'package:calculateur_etranger/presentation/fire/pages/tir_repartition_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Conversion UTM → WGS84 (intégrée directement pour éviter les conflits)
// ─────────────────────────────────────────────────────────────────────────────

class _LatLon {
  const _LatLon(this.lat, this.lon);
  final double lat;
  final double lon;
}

_LatLon _utmToLatLon(double easting, double northing, String? zone) {
  final z = (zone ?? '').trim().toUpperCase();
  int zoneNum = 31;
  bool isNorth = true;

  if (z.isNotEmpty) {
    final m = RegExp(r'^(\d{1,2})([A-Z])?$').firstMatch(z);
    if (m != null) {
      zoneNum = int.tryParse(m.group(1)!) ?? 31;
      final letter = m.group(2);
      if (letter != null) isNorth = letter.compareTo('N') >= 0;
    } else {
      zoneNum = int.tryParse(z.replaceAll(RegExp(r'[^0-9]'), '')) ?? 31;
    }
  }

  const a = 6378137.0;
  const f = 1 / 298.257223563;
  const k0 = 0.9996;
  const b = a * (1 - f);
  final e2 = (a * a - b * b) / (a * a);
  final lon0Rad = ((zoneNum - 1) * 6 - 180 + 3) * (math.pi / 180.0);

  final x = easting - 500000.0;
  final y = isNorth ? northing : northing - 10000000.0;

  final M = y / k0;
  final mu = M / (a * (1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256));

  final e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2));
  final fp = mu +
      (3 * e1 / 2 - 27 * e1 * e1 * e1 / 32) * math.sin(2 * mu) +
      (21 * e1 * e1 / 16 - 55 * e1 * e1 * e1 * e1 / 32) * math.sin(4 * mu) +
      (151 * e1 * e1 * e1 / 96) * math.sin(6 * mu) +
      (1097 * e1 * e1 * e1 * e1 / 512) * math.sin(8 * mu);

  final C1 = e2 * math.pow(math.cos(fp), 2) / (1 - e2);
  final T1 = math.pow(math.tan(fp), 2);
  final N1 = a / math.sqrt(1 - e2 * math.pow(math.sin(fp), 2));
  final R1 = a * (1 - e2) / math.pow(1 - e2 * math.pow(math.sin(fp), 2), 1.5);
  final D = x / (N1 * k0);

  final latRad = fp -
      (N1 * math.tan(fp) / R1) *
          (D * D / 2 -
              (5 + 3 * T1 + 10 * C1 - 4 * C1 * C1 - 9 * e2) *
                  D *
                  D *
                  D *
                  D /
                  24 +
              (61 +
                      90 * T1 +
                      298 * C1 +
                      45 * T1 * T1 -
                      252 * e2 -
                      3 * C1 * C1) *
                  D *
                  D *
                  D *
                  D *
                  D *
                  D /
                  720);

  final lonRad = lon0Rad +
      (D -
              (1 + 2 * T1 + C1) * D * D * D / 6 +
              (5 - 2 * C1 + 28 * T1 - 3 * C1 * C1 + 8 * e2 + 24 * T1 * T1) *
                  D *
                  D *
                  D *
                  D *
                  D /
                  120) /
          math.cos(fp);

  return _LatLon(latRad * 180.0 / math.pi, lonRad * 180.0 / math.pi);
}

_LatLon? _safeUtmToLatLon(double? easting, double? northing, String? zone) {
  if (easting == null || northing == null) return null;
  if (!easting.isFinite || !northing.isFinite) return null;

  // Bornes UTM plausibles : évite d'envoyer des valeurs brutes invalides à flutter_map.
  if (easting < 100000 || easting > 900000) return null;
  if (northing < 1000000 || northing > 10000000) return null;

  final ll = _utmToLatLon(easting, northing, zone);

  if (!ll.lat.isFinite || !ll.lon.isFinite) return null;
  if (ll.lat < -90.0 || ll.lat > 90.0) return null;
  if (ll.lon < -180.0 || ll.lon > 180.0) return null;

  return ll;
}

// ─────────────────────────────────────────────────────────────────────────────
// Page RED
// ─────────────────────────────────────────────────────────────────────────────

class RedPage extends StatefulWidget {
  const RedPage({
    super.key,
    required this.output,
    required this.dark,
    required this.azimutTirMil,
    required this.utmZone,
    this.fusee,
    this.typeTir,
    this.natureType = NatureTirType.ponctuel,
    this.longueurM = 0.0,
    this.profondeurM = 0.0,
    this.debordPct,
    this.pointAppLineaire,
    this.pointAppZonal,
    this.diametreEfficaciteM = 100.0,
    this.azimutLineaireMil,
    this.azimutLargeurMil,
    this.azimutProfondeurMil,
    this.observateurX,
    this.observateurY,
    this.observateurZ,
    this.showObservateur = false,
  });

  final TirCompletOutput output;
  final bool dark;
  final double azimutTirMil;
  final String utmZone;

  /// Fusée sélectionnée — détermine le type d'obus par défaut (RALEC si RTC).
  final TypeFusee? fusee;

  /// Type de tir — détermine l'affichage (RED ou zone éclairante).
  final TypeTir? typeTir;

  /// Nature et géométrie de la mission à restituer dans la page Répartition.
  ///
  /// Ces informations ne doivent jamais être remplacées par un mode ponctuel
  /// lors d'un aller-retour entre RED et Répartition.
  final NatureTirType natureType;
  final double longueurM;
  final double profondeurM;
  final double? debordPct;
  final PointApplicationLineaire? pointAppLineaire;
  final PointZonal? pointAppZonal;
  final double diametreEfficaciteM;

  final double? azimutLineaireMil;
  final double? azimutLargeurMil;
  final double? azimutProfondeurMil;

  /// Coordonnées observateur en UTM.
  ///
  /// Elles sont optionnelles pour ne pas casser les anciens appels à RedPage.
  /// Si [showObservateur] est false ou si X/Y sont invalides, aucun marqueur
  /// observateur n'est affiché.
  final double? observateurX;
  final double? observateurY;
  final double? observateurZ;
  final bool showObservateur;

  @override
  State<RedPage> createState() => _RedPageState();
}

class _RedPageState extends State<RedPage> {
  late ObusTirType _obusType;
  bool _showMap = true;
  bool _showDistribution = false;
  bool _showRedLabels = false;
  late final MapController _mapController;
  double? _currentMapZoom;
  double? _currentMapLatitude;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Sélection automatique du type d'obus :
    // - AppuiRTC ou fusée RALEC → RALEC (hexolite HT)
    // - Sinon → FRAPPE (XF 13333)
    final isRtc = widget.typeTir == TypeTir.appuiRtc ||
        widget.fusee == TypeFusee.ralec ||
        (widget.output.shots.isNotEmpty &&
            widget.output.shots.first.resultat.typeAssets
                .toUpperCase()
                .contains('RTC'));

    _obusType = isRtc ? ObusTirType.ralec : ObusTirType.frappe;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _openRepartition() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TirRepartitionPage(
          output: widget.output,
          natureType: widget.natureType,
          longueurM: widget.longueurM,
          profondeurM: widget.profondeurM,
          debordPct: widget.debordPct,
          pointAppLineaire: widget.pointAppLineaire,
          pointAppZonal: widget.pointAppZonal,
          diametreEfficaciteM: widget.diametreEfficaciteM,
          dark: widget.dark,
          azimutTirMil: widget.azimutTirMil,
          utmZone: widget.utmZone,
          fusee: widget.fusee,
          typeTir: widget.typeTir,
          azimutLineaireMil: widget.azimutLineaireMil,
          azimutLargeurMil: widget.azimutLargeurMil,
          azimutProfondeurMil: widget.azimutProfondeurMil,
          observateurX: widget.observateurX,
          observateurY: widget.observateurY,
          observateurZ: widget.observateurZ,
          showObservateur: widget.showObservateur,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final bg = dark ? const Color(0xFF0E0F12) : const Color(0xFFF4F5F7);
    final textColor = dark ? Colors.white : Colors.black87;

    final firstShot =
        widget.output.shots.isNotEmpty ? widget.output.shots.first : null;
    final angleChuteDeg = firstShot?.coverageEllipse?.angleChuteDeg;
    final vitesseRestante = firstShot?.resultat.vitesseRestanteMps;
    final distanceM = firstShot != null
        ? (firstShot.resultat.distanceTopoM + firstShot.resultat.totalLongM)
        : null;
    final charge = firstShot?.resultat.charge.trim() ?? '';

    // Détection du mode éclairant
    final isEclairant = widget.typeTir == TypeTir.eclairant ||
        (firstShot?.resultat.typeAssets.toUpperCase().contains('OECL') ??
            false);

    final redResult = isEclairant
        ? null
        : RedService(type: _obusType).computeRed(
            residualVelocityMps: vitesseRestante,
            angleChuteDeg: angleChuteDeg,
          );

    // Conversion UTM → WGS84
    final prLL = _utmToLatLon(
      widget.output.prX,
      widget.output.prY,
      widget.utmZone,
    );

    // Pièce directrice (PD) : coordonnées séparées du PR
    final pdLL = _utmToLatLon(
      widget.output.pdX,
      widget.output.pdY,
      widget.utmZone,
    );

    // Observateur : affiché uniquement quand le panneau observateur est ouvert
    // et que les coordonnées UTM sont valides.
    final obsLL = widget.showObservateur
        ? _safeUtmToLatLon(
            widget.observateurX,
            widget.observateurY,
            widget.utmZone,
          )
        : null;

    // Pièces de soutien depuis le plan de tir
    final psLLs = widget.output.firePlan.pieces
        .where((p) => !p.isPd)
        .map((p) => _LatLonNamed(_utmToLatLon(p.x, p.y, widget.utmZone), p.id))
        .toList();

    final shotLLs = widget.output.shots
        .map((s) => _utmToLatLon(s.objX, s.objY, widget.utmZone))
        .toList();

    final centerLat = shotLLs.isEmpty
        ? prLL.lat
        : shotLLs.map((p) => p.lat).reduce((a, b) => a + b) / shotLLs.length;
    final centerLon = shotLLs.isEmpty
        ? prLL.lon
        : shotLLs.map((p) => p.lon).reduce((a, b) => a + b) / shotLLs.length;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: textColor,
        elevation: 0,
        title: Text(isEclairant ? 'Zone éclairée' : 'Zone RED'),
        actions: [
          IconButton(
            icon: Icon(
              _showMap ? Icons.map_outlined : Icons.schema_outlined,
              color: _showMap
                  ? const Color(0xFF2EE6A6)
                  : (dark ? Colors.white54 : Colors.black45),
            ),
            tooltip: _showMap ? 'Vue schématique' : 'Vue carte',
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          // Sélecteur FRAPPE/RALEC uniquement pour les tirs non éclairants
          if (!isEclairant)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _ObusSwitcher(
                selected: _obusType,
                dark: dark,
                onChanged: (t) => setState(() => _obusType = t),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isEclairant)
              _EclairantParamsTable(
                dark: dark,
                textColor: textColor,
                distanceM: distanceM,
                charge: charge,
                azimutTirMil: widget.azimutTirMil,
              )
            else
              _ParamsTable(
                dark: dark,
                textColor: textColor,
                redResult: redResult!,
                angleChuteDeg: angleChuteDeg,
                vitesseRestanteMps: vitesseRestante,
                distanceM: distanceM,
                charge: charge,
                azimutTirMil: widget.azimutTirMil,
              ),
            Expanded(
              child: _showMap
                  ? _buildMapView(
                      dark: dark,
                      redResult: redResult,
                      isEclairant: isEclairant,
                      prLL: prLL,
                      pdLL: pdLL,
                      psLLs: psLLs,
                      shotLLs: shotLLs,
                      observateurLL: obsLL,
                      centerLat: centerLat,
                      centerLon: centerLon,
                    )
                  : _buildSchematicView(
                      dark: dark,
                      redResult: redResult,
                      isEclairant: isEclairant,
                      observateurX:
                          widget.showObservateur ? widget.observateurX : null,
                      observateurY:
                          widget.showObservateur ? widget.observateurY : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Vue carte ──────────────────────────────────────────────────────────────

  // Constantes éclairant (doctrine 155 mm OTAN)
  static const double _eclairantRadiusM = 300.0; // rayon zone illuminée (28 ha)

  Widget _buildMapView({
    required bool dark,
    required RedResult? redResult,
    required bool isEclairant,
    required _LatLon prLL,
    required _LatLon pdLL,
    required List<_LatLonNamed> psLLs,
    required List<_LatLon> shotLLs,
    required _LatLon? observateurLL,
    required double centerLat,
    required double centerLon,
  }) {
    final refRadiusM =
        isEclairant ? _eclairantRadiusM : (redResult?.redSemiLongM ?? 400.0);
    final zoom = refRadiusM > 1000
        ? 12.0
        : refRadiusM > 500
            ? 13.0
            : 14.0;

    // Polygones elliptiques pour chaque impact
    final centers = shotLLs.isEmpty ? [_LatLon(centerLat, centerLon)] : shotLLs;

    // Construction des polygones selon le mode
    final List<Polygon> polygons;
    final List<Marker> redLabels;
    final List<Polyline> redAxes;

    if (isEclairant) {
      redLabels = [];
      redAxes = [];
      // Zone illuminée : cercle de 300 m (28 ha, éclairement > 3,4 lux)
      polygons = centers
          .map(
            (c) => Polygon(
              points: _circlePoints(
                centerLat: c.lat,
                centerLon: c.lon,
                radiusM: _eclairantRadiusM,
              ),
              color: const Color(0xFFFFDD00).withValues(alpha: 0.18),
              borderColor: const Color(0xFFFFCC00).withValues(alpha: 0.90),
              borderStrokeWidth: 2.5,
            ),
          )
          .toList();
    } else {
      // Zones RED elliptiques
      final polygonsRed = centers
          .map(
            (c) => Polygon(
              points: _ellipsePoints(
                centerLat: c.lat,
                centerLon: c.lon,
                frontM: redResult!.redFrontM,
                rearM: redResult.redRearM,
                semiLatM: redResult.redSemiLatM,
                azimutTirMil: widget.azimutTirMil,
              ),
              color: const Color(0xFFFF4400).withValues(alpha: 0.10),
              borderColor: const Color(0xFFFF3300).withValues(alpha: 0.75),
              borderStrokeWidth: 2.0,
            ),
          )
          .toList();

      // ── Annotations RED et axes de cotes ─────────────────────────────────
      redLabels = [];
      redAxes = [];
      if (_showRedLabels) {
        for (final c in centers) {
          final az = widget.azimutTirMil * 2 * math.pi / 6400.0;

          ll.LatLng offset(double distM, double azimuthRad) {
            const r = 6371000.0;
            final dNorth = distM * math.cos(azimuthRad);
            final dEast = distM * math.sin(azimuthRad);
            final dLat = dNorth / r * (180 / math.pi);
            final dLon =
                dEast / (r * math.cos(c.lat * math.pi / 180)) * (180 / math.pi);
            return ll.LatLng(c.lat + dLat, c.lon + dLon);
          }

          redAxes.add(
            Polyline(
              points: [
                offset(redResult!.redRearM, az + math.pi),
                offset(redResult.redFrontM, az),
              ],
              strokeWidth: 2.0,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          );

          redAxes.add(
            Polyline(
              points: [
                offset(redResult.redSemiLatM, az - math.pi / 2),
                offset(redResult.redSemiLatM, az + math.pi / 2),
              ],
              strokeWidth: 1.6,
              color: Colors.white.withValues(alpha: 0.52),
            ),
          );

          redLabels.add(
            Marker(
              point: offset(redResult.redFrontM + 40, az),
              width: 120,
              height: 40,
              child: _RedLabel('RED av.\n${redResult.redFrontM.round()} m'),
            ),
          );

          redLabels.add(
            Marker(
              point: offset(redResult.redRearM + 40, az + math.pi),
              width: 120,
              height: 40,
              child: _RedLabel('RED ar.\n${redResult.redRearM.round()} m'),
            ),
          );

          redLabels.add(
            Marker(
              point: offset(redResult.redSemiLatM + 30, az - math.pi / 2),
              width: 120,
              height: 40,
              child: _RedLabel('RED lat.\n${redResult.redSemiLatM.round()} m'),
            ),
          );

          redLabels.add(
            Marker(
              point: offset(redResult.redSemiLatM + 30, az + math.pi / 2),
              width: 120,
              height: 40,
              child: _RedLabel('RED lat.\n${redResult.redSemiLatM.round()} m'),
            ),
          );
        }
      }

      final polygonsDanger = centers
          .map(
            (c) => Polygon(
              points: _ellipsePoints(
                centerLat: c.lat,
                centerLon: c.lon,
                frontM: redResult!.dangerFrontM,
                rearM: redResult.dangerRearM,
                semiLatM: redResult.dangerSemiLatM,
                azimutTirMil: widget.azimutTirMil,
              ),
              color: const Color(0xFFFF0000).withValues(alpha: 0.22),
              borderColor: const Color(0xFFFF0000).withValues(alpha: 0.88),
              borderStrokeWidth: 2.5,
            ),
          )
          .toList();

      final polygonsDistribution = _showDistribution
          ? centers.expand((c) {
              final layers = [
                (k: 0.95, color: const Color(0xFFFF2200), alpha: 0.10),
                (k: 0.75, color: const Color(0xFFFF5500), alpha: 0.13),
                (k: 0.55, color: const Color(0xFFFF8800), alpha: 0.17),
                (k: 0.35, color: const Color(0xFFFFBB00), alpha: 0.24),
                (k: 0.18, color: const Color(0xFFFFFF00), alpha: 0.34),
              ];

              return layers.map((layer) {
                return Polygon(
                  points: _ellipsePoints(
                    centerLat: c.lat,
                    centerLon: c.lon,
                    frontM: redResult!.redFrontM * (layer.k * 1.10),
                    rearM: redResult.redRearM * (layer.k * 0.55),
                    semiLatM: redResult.redSemiLatM * (layer.k * 0.80),
                    azimutTirMil: widget.azimutTirMil,
                  ),
                  color: layer.color.withValues(alpha: layer.alpha),
                  borderColor: Colors.transparent,
                  borderStrokeWidth: 0,
                );
              });
            }).toList()
          : <Polygon>[];

      polygons = [...polygonsRed, ...polygonsDistribution, ...polygonsDanger];
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: ll.LatLng(centerLat, centerLon),
            initialZoom: zoom,
            onPositionChanged: (camera, hasGesture) {
              final nextZoom = camera.zoom;
              final nextLatitude = camera.center.latitude;

              if (_currentMapZoom == nextZoom &&
                  _currentMapLatitude == nextLatitude) {
                return;
              }

              setState(() {
                _currentMapZoom = nextZoom;
                _currentMapLatitude = nextLatitude;
              });
            },
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'calculateur_tir_ng',
              tileBuilder: dark ? _darkTileBuilder : null,
            ),
            PolygonLayer(polygons: polygons),
            if (redAxes.isNotEmpty) PolylineLayer(polylines: redAxes),
            if (redLabels.isNotEmpty) MarkerLayer(markers: redLabels),
            MarkerLayer(
              markers: [
                // PR
                Marker(
                  point: ll.LatLng(prLL.lat, prLL.lon),
                  width: 36,
                  height: 36,
                  child: _PrMarker(),
                ),
                // Observateur
                if (observateurLL != null)
                  Marker(
                    point: ll.LatLng(observateurLL.lat, observateurLL.lon),
                    width: 82,
                    height: 44,
                    child: _ObservateurMarker(),
                  ),
                // PD (Pièce Directrice)
                Marker(
                  point: ll.LatLng(pdLL.lat, pdLL.lon),
                  width: 32,
                  height: 32,
                  child: _PdMarker(),
                ),
                // Pièces de soutien
                for (final ps in psLLs)
                  Marker(
                    point: ll.LatLng(ps.ll.lat, ps.ll.lon),
                    width: 28,
                    height: 28,
                    child: _PsMarker(label: ps.name),
                  ),
                // Impacts
                for (final p in shotLLs)
                  Marker(
                    point: ll.LatLng(p.lat, p.lon),
                    width: 14,
                    height: 14,
                    child: _ImpactMarker(),
                  ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        Positioned(
          right: 12,
          top: 12,
          child: Column(
            children: [
              _MapButton(
                icon: Icons.add,
                onTap: () {
                  final camera = _mapController.camera;
                  _mapController.move(camera.center, camera.zoom + 1);
                },
              ),
              const SizedBox(height: 8),
              _MapButton(
                icon: Icons.remove,
                onTap: () {
                  final camera = _mapController.camera;
                  _mapController.move(camera.center, camera.zoom - 1);
                },
              ),
              const SizedBox(height: 8),
              _MapButton(
                icon: Icons.my_location,
                onTap: () {
                  _mapController.move(ll.LatLng(centerLat, centerLon), zoom);
                },
              ),
              const SizedBox(height: 8),
              _MapButton(
                icon: Icons.fit_screen,
                onTap: () {
                  _mapController.move(ll.LatLng(centerLat, centerLon), zoom);
                },
              ),
            ],
          ),
        ),
        Positioned(
          left: 12,
          bottom: 28,
          child: _ScaleBar(
            dark: dark,
            zoom: _currentMapZoom ?? zoom,
            latitude: _currentMapLatitude ?? centerLat,
          ),
        ),
        if (!isEclairant)
          Positioned(
            left: 12,
            top: 12,
            child: Row(
              children: [
                _RepartitionButton(onTap: _openRepartition),
                const SizedBox(width: 8),
                _DistributionToggle(
                  enabled: _showDistribution,
                  onTap: () =>
                      setState(() => _showDistribution = !_showDistribution),
                ),
                const SizedBox(width: 8),
                _CotesRedToggle(
                  enabled: _showRedLabels,
                  onTap: () => setState(() => _showRedLabels = !_showRedLabels),
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<ll.LatLng> _ellipsePoints({
    required double centerLat,
    required double centerLon,
    required double frontM,
    required double rearM,
    required double semiLatM,
    required double azimutTirMil,
    int steps = 72,
  }) {
    final azTirRad = azimutTirMil * 2 * math.pi / 6400.0;
    final points = <ll.LatLng>[];
    for (int i = 0; i <= steps; i++) {
      final angle = (i / steps) * 2 * math.pi;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      final rLong = cosA >= 0 ? frontM : rearM;
      final dForward = rLong * cosA;
      final dLateral = semiLatM * sinA;
      final dNorth =
          dForward * math.cos(azTirRad) - dLateral * math.sin(azTirRad);
      final dEast =
          dForward * math.sin(azTirRad) + dLateral * math.cos(azTirRad);
      const earthR = 6371000.0;
      final dLat = dNorth / earthR * (180.0 / math.pi);
      final dLon = dEast /
          (earthR * math.cos(centerLat * math.pi / 180.0)) *
          (180.0 / math.pi);
      points.add(ll.LatLng(centerLat + dLat, centerLon + dLon));
    }
    return points;
  }

  /// Cercle géodésique de rayon [radiusM] mètres autour d'un point.
  List<ll.LatLng> _circlePoints({
    required double centerLat,
    required double centerLon,
    required double radiusM,
    int steps = 72,
  }) {
    const earthR = 6371000.0;
    final points = <ll.LatLng>[];
    for (int i = 0; i <= steps; i++) {
      final angle = (i / steps) * 2 * math.pi;
      final dNorth = radiusM * math.cos(angle);
      final dEast = radiusM * math.sin(angle);
      final dLat = dNorth / earthR * (180.0 / math.pi);
      final dLon = dEast /
          (earthR * math.cos(centerLat * math.pi / 180.0)) *
          (180.0 / math.pi);
      points.add(ll.LatLng(centerLat + dLat, centerLon + dLon));
    }
    return points;
  }

  Widget _darkTileBuilder(
    BuildContext context,
    Widget tileWidget,
    TileImage tile,
  ) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -0.9,
        0,
        0,
        0,
        255,
        0,
        -0.9,
        0,
        0,
        255,
        0,
        0,
        -0.9,
        0,
        255,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: tileWidget,
    );
  }

  // ── Vue schématique ────────────────────────────────────────────────────────

  Widget _buildSchematicView({
    required bool dark,
    required RedResult? redResult,
    required bool isEclairant,
    required double? observateurX,
    required double? observateurY,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size.width <= 0 || size.height <= 0) {
          return const Center(child: Text('Zone invalide.'));
        }
        return InteractiveViewer(
          minScale: 0.1,
          maxScale: 10,
          boundaryMargin: const EdgeInsets.all(400),
          child: CustomPaint(
            size: size,
            painter: _RedSchemaPainter(
              output: widget.output,
              redResult: redResult,
              isEclairant: isEclairant,
              eclairantRadiusM: _eclairantRadiusM,
              azimutTirMil: widget.azimutTirMil,
              dark: dark,
              observateurX: observateurX,
              observateurY: observateurY,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter schématique — utilise dart:ui.Path explicitement
// ─────────────────────────────────────────────────────────────────────────────

class _RedSchemaPainter extends CustomPainter {
  const _RedSchemaPainter({
    required this.output,
    required this.redResult,
    required this.isEclairant,
    required this.eclairantRadiusM,
    required this.azimutTirMil,
    required this.dark,
    required this.observateurX,
    required this.observateurY,
  });

  final TirCompletOutput output;
  final RedResult? redResult;
  final bool isEclairant;
  final double eclairantRadiusM;
  final double azimutTirMil;
  final bool dark;
  final double? observateurX;
  final double? observateurY;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = dark ? const Color(0xFF0E0F12) : const Color(0xFFF4F5F7),
    );

    if (output.shots.isEmpty) return;

    final uT = dirFromAzMil(azimutTirMil);
    final uL = rot90(uT);
    final prX = output.prX;
    final prY = output.prY;

    final shotPositions = output.shots.map((s) {
      final dx = s.objX - prX;
      final dy = s.objY - prY;
      return Offset(dx * uT.dx + (-dy) * uT.dy, dx * uL.dx + (-dy) * uL.dy);
    }).toList();

    Offset? observateurLocal;
    if (observateurX != null &&
        observateurY != null &&
        observateurX!.isFinite &&
        observateurY!.isFinite) {
      final dx = observateurX! - prX;
      final dy = observateurY! - prY;
      observateurLocal = Offset(
        dx * uT.dx + (-dy) * uT.dy,
        dx * uL.dx + (-dy) * uL.dy,
      );
    }

    // Rayon de référence pour le calcul des bornes
    final refR =
        isEclairant ? eclairantRadiusM : (redResult?.redSemiLongM ?? 400.0);

    double minFwd = double.infinity, maxFwd = double.negativeInfinity;
    double minLat = double.infinity, maxLat = double.negativeInfinity;
    for (final p in shotPositions) {
      minFwd = math.min(minFwd, p.dx - refR);
      maxFwd = math.max(maxFwd, p.dx + refR);
      minLat = math.min(minLat, p.dy - refR);
      maxLat = math.max(maxLat, p.dy + refR);
    }

    if (observateurLocal != null) {
      minFwd = math.min(minFwd, observateurLocal.dx - 80);
      maxFwd = math.max(maxFwd, observateurLocal.dx + 80);
      minLat = math.min(minLat, observateurLocal.dy - 80);
      maxLat = math.max(maxLat, observateurLocal.dy + 80);
    }

    const margin = 80.0;
    final sx = (size.width - 2 * margin) / math.max(1e-6, maxFwd - minFwd);
    final sy = (size.height - 2 * margin) / math.max(1e-6, maxLat - minLat);
    final scale = math.max(0.001, math.min(sx, sy));

    final rawCenter = Offset((minFwd + maxFwd) / 2, (minLat + maxLat) / 2);
    final screenCenter = Offset(size.width / 2, size.height / 2);

    Offset toPx(double fwd, double lat) {
      return screenCenter +
          Offset(
            (fwd - rawCenter.dx) * scale * uT.dx +
                (lat - rawCenter.dy) * scale * uL.dx,
            (fwd - rawCenter.dx) * scale * uT.dy +
                (lat - rawCenter.dy) * scale * uL.dy,
          );
    }

    for (final sp in shotPositions) {
      final center = toPx(sp.dx, sp.dy);

      if (isEclairant) {
        // Zone illuminée : cercle jaune
        final rPx = eclairantRadiusM * scale;
        canvas.drawCircle(
          center,
          rPx,
          Paint()
            ..style = PaintingStyle.fill
            ..color = const Color(
              0xFFFFDD00,
            ).withValues(alpha: dark ? 0.20 : 0.15),
        );
        canvas.drawCircle(
          center,
          rPx,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = const Color(0xFFFFCC00).withValues(alpha: 0.90),
        );
      } else {
        _drawEllipse(
          canvas,
          center,
          redResult!.redFrontM * scale,
          redResult!.redRearM * scale,
          redResult!.redSemiLatM * scale,
          const Color(0xFFFF4400).withValues(alpha: dark ? 0.12 : 0.08),
          const Color(0xFFFF3300).withValues(alpha: dark ? 0.75 : 0.60),
          2.0,
          dashed: true,
        );
        _drawEllipse(
          canvas,
          center,
          redResult!.dangerFrontM * scale,
          redResult!.dangerRearM * scale,
          redResult!.dangerSemiLatM * scale,
          const Color(0xFFFF0000).withValues(alpha: dark ? 0.28 : 0.20),
          const Color(0xFFFF0000).withValues(alpha: dark ? 0.88 : 0.72),
          2.5,
          dashed: false,
        );
      }

      canvas.drawCircle(center, 5.0, Paint()..color = const Color(0x99000000));
      canvas.drawCircle(center, 3.5, Paint()..color = const Color(0xFF2EE6A6));
    }

    if (observateurLocal != null) {
      _drawObserver(canvas, toPx(observateurLocal.dx, observateurLocal.dy));
    }

    _drawCompass(canvas, size);
  }

  void _drawObserver(Canvas canvas, Offset center) {
    final fill = dark ? const Color(0xFF00E676) : const Color(0xFF00C853);

    // Anneau extérieur
    canvas.drawCircle(
      center,
      16,
      Paint()
        ..color = fill.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );

    // Contour
    canvas.drawCircle(
      center,
      16,
      Paint()
        ..color = fill
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Centre
    canvas.drawCircle(center, 7, Paint()..color = fill);

    // Label OBS
    final tp = TextPainter(
      text: TextSpan(
        text: 'OBS',
        style: TextStyle(
          color: fill,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(center.dx + 22, center.dy - 10));
  }

  void _drawEllipse(
    Canvas canvas,
    Offset center,
    double frontPx,
    double rearPx,
    double latPx,
    Color fillColor,
    Color strokeColor,
    double strokeWidth, {
    required bool dashed,
  }) {
    if (frontPx < 1 && rearPx < 1) return;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.atan2(uT.dy, uT.dx));

    // ui.Path explicite pour éviter le conflit avec latlong2.Path
    final path = _buildEllipsePath(frontPx, rearPx, latPx);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = fillColor,
    );

    if (dashed) {
      final metrics = path.computeMetrics();
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = strokeColor
        ..strokeCap = StrokeCap.round;
      for (final metric in metrics) {
        double d = 0.0;
        bool draw = true;
        while (d < metric.length) {
          final next = d + (draw ? 14.0 : 9.0);
          if (draw) {
            canvas.drawPath(
              metric.extractPath(d, math.min(next, metric.length)),
              p,
            );
          }
          d = next;
          draw = !draw;
        }
      }
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = strokeColor,
      );
    }
    canvas.restore();
  }

  // Retourne un dart:ui.Path (pas latlong2.Path)
  ui.Path _buildEllipsePath(double frontPx, double rearPx, double latPx) {
    const int steps = 60;
    final path = ui.Path();
    for (int i = 0; i <= steps * 2; i++) {
      final a = (i / (steps * 2)) * 2 * math.pi - math.pi / 2;
      final cosA = math.cos(a);
      final sinA = math.sin(a);
      final rx = cosA >= 0 ? frontPx : rearPx;
      final x = rx * cosA;
      final y = latPx * sinA;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  void _drawCompass(Canvas canvas, Size size) {
    const double pad = 16;
    final origin = Offset(size.width - pad - 60, pad + 60);
    final textColor = dark ? Colors.white70 : Colors.black87;
    final tirColor = dark ? const Color(0xFF2EE6A6) : const Color(0xFF0B7D4F);

    canvas.drawCircle(
      origin,
      28,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = dark ? Colors.white24 : Colors.black12,
    );
    arrow(
      canvas,
      origin,
      const Offset(0, -1),
      38,
      Paint()
        ..strokeWidth = 1.8
        ..color = textColor,
    );
    label(
      canvas,
      origin + const Offset(0, -54),
      'N',
      color: textColor,
      fontSize: 13,
      fontWeight: FontWeight.w900,
    );

    final dirT = dirFromAzMil(azimutTirMil);
    arrow(
      canvas,
      origin,
      dirT,
      38,
      Paint()
        ..strokeWidth = 2.2
        ..color = tirColor,
    );
    label(
      canvas,
      origin + dirT * 52,
      '${azimutTirMil.toStringAsFixed(0)} mil',
      color: tirColor,
      fontSize: 10,
    );
  }

  Offset get uT => dirFromAzMil(azimutTirMil);
  Offset get uL => rot90(uT);

  @override
  bool shouldRepaint(covariant _RedSchemaPainter old) =>
      old.redResult != redResult ||
      old.isEclairant != isEclairant ||
      old.azimutTirMil != azimutTirMil ||
      old.dark != dark ||
      old.observateurX != observateurX ||
      old.observateurY != observateurY;
}

// ─────────────────────────────────────────────────────────────────────────────
// Modèles internes
// ─────────────────────────────────────────────────────────────────────────────

/// Coordonnées WGS84 avec nom (pour les pièces de soutien).
class _LatLonNamed {
  const _LatLonNamed(this.ll, this.name);
  final _LatLon ll;
  final String name;
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets UI
// ─────────────────────────────────────────────────────────────────────────────

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xDD1A1C22),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _DistributionToggle extends StatelessWidget {
  const _DistributionToggle({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? const Color(0xFF2EE6A6).withValues(alpha: 0.2)
          : const Color(0xDD1A1C22),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: enabled ? const Color(0xFF2EE6A6) : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            'Distribution',
            style: TextStyle(
              color: enabled ? const Color(0xFF2EE6A6) : Colors.white70,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _CotesRedToggle extends StatelessWidget {
  const _CotesRedToggle({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? const Color(0xFFFF5533).withValues(alpha: 0.2)
          : const Color(0xDD1A1C22),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: enabled ? const Color(0xFFFF5533) : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            'Cotes RED',
            style: TextStyle(
              color: enabled ? const Color(0xFFFF5533) : Colors.white70,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _RepartitionButton extends StatelessWidget {
  const _RepartitionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xDD1A1C22),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            'Répartition',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScaleBar extends StatelessWidget {
  const _ScaleBar({
    required this.dark,
    required this.zoom,
    required this.latitude,
  });

  final bool dark;
  final double zoom;
  final double latitude;

  static const double _earthCircumferenceM = 40075016.686;
  static const double _tileSizePx = 256.0;
  static const double _targetWidthPx = 90.0;

  double get _metersPerPixel {
    final latRad = latitude * math.pi / 180.0;
    final cosLat = math.cos(latRad).abs().clamp(0.01, 1.0);
    return cosLat * _earthCircumferenceM / (_tileSizePx * math.pow(2.0, zoom));
  }

  double _niceDistance(double rawMeters) {
    const candidates = <double>[
      1,
      2,
      5,
      10,
      20,
      50,
      100,
      200,
      500,
      1000,
      2000,
      5000,
      10000,
      20000,
      50000,
      100000,
    ];

    var best = candidates.first;
    for (final candidate in candidates) {
      if (candidate <= rawMeters) {
        best = candidate;
      } else {
        break;
      }
    }
    return best;
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000.0;
      if (km >= 10 || km == km.roundToDouble()) {
        return '${km.toStringAsFixed(0)} km';
      }
      return '${km.toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  @override
  Widget build(BuildContext context) {
    final metersPerPixel = _metersPerPixel;
    final rawMeters = metersPerPixel * _targetWidthPx;
    final distanceMeters = _niceDistance(rawMeters);
    final widthPx =
        (distanceMeters / metersPerPixel).clamp(32.0, _targetWidthPx);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? const Color(0xDD1A1C22) : const Color(0xDDFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dark ? Colors.white24 : Colors.black26),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: widthPx,
            height: 3,
            color: dark ? Colors.white : Colors.black87,
          ),
          const SizedBox(width: 8),
          Text(
            _formatDistance(distanceMeters),
            style: TextStyle(
              color: dark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ObservateurMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const obsGreen = Color(0xFF00E676);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: obsGreen.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: obsGreen, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 5,
                offset: Offset(1, 1),
              ),
            ],
          ),
        ),
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: obsGreen,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white70, width: 1),
          ),
        ),
        const Positioned(
          right: -31,
          child: Text(
            'OBS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: obsGreen,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ),
      ],
    );
  }
}

class _PrMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFE44D),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black54, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(1, 1)),
        ],
      ),
      child: const Center(
        child: Text(
          'PR',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

/// Marqueur Pièce Directrice (PD) — carré vert avec label.
class _PdMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2EE6A6),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black54, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(1, 1)),
        ],
      ),
      child: const Center(
        child: Text(
          'PD',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

/// Marqueur Pièce de Soutien (PS) — cercle gris avec label.
class _PsMarker extends StatelessWidget {
  const _PsMarker({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF8888AA),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black45, width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ImpactMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2EE6A6),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black45, width: 1),
      ),
    );
  }
}

class _ParamsTable extends StatelessWidget {
  const _ParamsTable({
    required this.dark,
    required this.textColor,
    required this.redResult,
    required this.azimutTirMil,
    this.angleChuteDeg,
    this.vitesseRestanteMps,
    this.distanceM,
    this.charge,
  });

  final bool dark;
  final Color textColor;
  final RedResult redResult;
  final double azimutTirMil;
  final double? angleChuteDeg;
  final double? vitesseRestanteMps;
  final double? distanceM;
  final String? charge;

  @override
  Widget build(BuildContext context) {
    final cardBg =
        dark ? const Color(0xFF1A1C22) : Colors.white.withValues(alpha: 0.85);
    final borderColor = dark ? Colors.white12 : Colors.black12;
    final angleMil = angleChuteDeg != null
        ? (angleChuteDeg! * 6400.0 / 360.0).round()
        : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          if (distanceM != null)
            _Param('Distance', '${distanceM!.round()} m', textColor),
          if (charge != null && charge!.isNotEmpty)
            _Param('Charge', charge!.toUpperCase(), textColor),
          if (vitesseRestanteMps != null)
            _Param('Vr', '${vitesseRestanteMps!.round()} m/s', textColor),
          if (angleMil != null) _Param('θ chute', '$angleMil mil', textColor),
          _Param('Obus', redResult.type.label, textColor),
          _Param(
            'Vf éclats',
            '${redResult.fragmentVelocityMps.round()} m/s',
            textColor,
          ),
          const SizedBox(width: 8),
          _Param(
            'Éclats av.',
            '${redResult.dangerFrontM.round()} m',
            const Color(0xFFE06030),
          ),
          _Param(
            'Éclats ar.',
            '${redResult.dangerRearM.round()} m',
            const Color(0xFFE06030),
          ),
          _Param(
            'Éclats lat.',
            '${redResult.dangerSemiLatM.round()} m',
            const Color(0xFFE06030),
          ),
          const SizedBox(width: 8),
          _Param(
            'RED av.',
            '${redResult.redFrontM.round()} m',
            const Color(0xFFCC4422),
          ),
          _Param(
            'RED ar.',
            '${redResult.redRearM.round()} m',
            const Color(0xFFCC4422),
          ),
          _Param(
            'RED lat.',
            '${redResult.redSemiLatM.round()} m',
            const Color(0xFFCC4422),
          ),
        ],
      ),
    );
  }
}

class _Param extends StatelessWidget {
  const _Param(this.label, this.value, this.valueColor);
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: valueColor.withValues(alpha: 0.65),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: valueColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Tableau de paramètres pour le tir éclairant.
class _EclairantParamsTable extends StatelessWidget {
  const _EclairantParamsTable({
    required this.dark,
    required this.textColor,
    required this.azimutTirMil,
    this.distanceM,
    this.charge,
  });

  final bool dark;
  final Color textColor;
  final double azimutTirMil;
  final double? distanceM;
  final String? charge;

  // Constantes doctrine éclairant 155 mm OTAN
  static const double _radiusM = 300.0;
  static const double _surfaceHa = 28.0;
  static const double _durationS = 65.0;
  static const double _altM = 700.0;
  static const int _intensiteCd = 130000; // 13.10⁵ cd

  @override
  Widget build(BuildContext context) {
    final cardBg =
        dark ? const Color(0xFF1A1C22) : Colors.white.withValues(alpha: 0.85);
    final borderColor = dark ? Colors.white12 : Colors.black12;
    const jaune = Color(0xFFDDAA00);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          if (distanceM != null)
            _Param('Distance', '${distanceM!.round()} m', textColor),
          if (charge != null && charge!.isNotEmpty)
            _Param('Charge', charge!.toUpperCase(), textColor),
          const SizedBox(width: 8),
          _Param('Zone illuminée', 'Ø ${(_radiusM * 2).round()} m', jaune),
          _Param('Surface', '${_surfaceHa.toStringAsFixed(0)} ha', jaune),
          _Param('Durée', '${_durationS.toStringAsFixed(0)} s', jaune),
          _Param('Altitude', '${_altM.toStringAsFixed(0)} m', jaune),
          _Param(
            'Intensité',
            '${(_intensiteCd / 1000).toStringAsFixed(0)}k cd',
            jaune,
          ),
        ],
      ),
    );
  }
}

class _ObusSwitcher extends StatelessWidget {
  const _ObusSwitcher({
    required this.selected,
    required this.dark,
    required this.onChanged,
  });

  final ObusTirType selected;
  final bool dark;
  final ValueChanged<ObusTirType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in ObusTirType.values)
          GestureDetector(
            onTap: () => onChanged(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: selected == t
                    ? const Color(0xFF7A1010)
                    : (dark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.07)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected == t
                      ? const Color(0xFFFF6B6B)
                      : Colors.transparent,
                ),
              ),
              child: Text(
                t == ObusTirType.frappe ? 'FRAPPE' : 'RALEC',
                style: TextStyle(
                  color: selected == t
                      ? Colors.white
                      : (dark ? Colors.white60 : Colors.black54),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Annotation RED
// ─────────────────────────────────────────────────────────────────────────────

class _RedLabel extends StatelessWidget {
  const _RedLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFFF5533),
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}
