import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:calculateur_etranger/services/position/elevation_service.dart';
import 'package:calculateur_etranger/services/position/utm_converter.dart';
import 'package:calculateur_etranger/services/maps/local_map_service.dart';

class PickedMapPoint {
  const PickedMapPoint({
    required this.latitude,
    required this.longitude,
    required this.utm,
    this.distanceFromPieceM,
    this.azimutFromPieceMil,
  });

  final double latitude;
  final double longitude;
  final UtmPosition utm;
  final double? distanceFromPieceM;
  final double? azimutFromPieceMil;
}

enum CartePickMode {
  pieceDirectrice,
  objectif,
  observateur,
  objectifObservateur,
}

/// État balistique affiché dans la fiche d’objectif de la carte.
enum CarteTirEtat { ok, limite, impossible }

/// Aperçu de portée produit par l’écran de tir, sans lancer le calcul complet.
class CarteTirApercu {
  const CarteTirApercu({
    required this.etat,
    required this.titre,
    required this.detail,
    this.charge,
  });

  final CarteTirEtat etat;
  final String titre;
  final String detail;
  final String? charge;
}

typedef CarteTirApercuBuilder = Future<CarteTirApercu> Function(
    double distanceM);

class CartePositionPickerPage extends StatefulWidget {
  const CartePositionPickerPage({
    super.key,
    required this.mode,
    required this.dark,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAltitude,
    this.pieceLatitude,
    this.pieceLongitude,
    this.pieceX,
    this.pieceY,
    this.pieceAltitude,
    this.observerLatitude,
    this.observerLongitude,
    this.observerAltitude,
    this.utmZoneLabel,
    this.localMapZoneId,
    this.tirApercuBuilder,
  });

  final CartePickMode mode;
  final bool dark;

  final double? initialLatitude;
  final double? initialLongitude;
  final double? initialAltitude;

  final double? pieceLatitude;
  final double? pieceLongitude;
  final double? pieceX;
  final double? pieceY;
  final double? pieceAltitude;
  final double? observerLatitude;
  final double? observerLongitude;
  final double? observerAltitude;
  final String? utmZoneLabel;
  final String? localMapZoneId;

  /// Évalue la charge et la faisabilité pendant la désignation d’un objectif.
  /// Le callback reste absent des modes PD et observateur.
  final CarteTirApercuBuilder? tirApercuBuilder;

  @override
  State<CartePositionPickerPage> createState() =>
      _CartePositionPickerPageState();
}

class _CartePositionPickerPageState extends State<CartePositionPickerPage> {
  late final MapController _mapController;
  late double _currentZoom;
  late ll.LatLng _currentCenter;

  ll.LatLng? _picked;
  double? _pickedAltitude;
  bool _altitudeLoading = false;
  bool _altitudeFromMnt = false;
  CarteTirApercu? _tirApercu;
  bool _tirApercuLoading = false;
  int _tirApercuRequest = 0;

  TileProvider? _localTileProvider;
  bool _localMapLoading = false;
  bool _onlineEnabled = false;

  static const double _minZoom = 3.0;
  static const double _maxZoom = 19.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentZoom = _initialZoom;
    _currentCenter = _initialCenter;

    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _picked = ll.LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _pickedAltitude = widget.initialAltitude;
      _altitudeFromMnt = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLocalMap();
      if (_isObjectif && _picked != null) {
        unawaited(_refreshTirApercu());
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalMap() async {
    if (_localMapLoading || _localTileProvider != null) return;

    _localMapLoading = true;

    try {
      final wasOnline = _onlineEnabled;
      final onlineEnabled = await LocalMapService.instance.isOnlineEnabled();

      if (!mounted) return;

      if (onlineEnabled) {
        _localTileProvider?.dispose();
        setState(() {
          _onlineEnabled = true;
          _localTileProvider = null;
        });
        return;
      }

      setState(() {
        _onlineEnabled = false;
      });

      final requestedZoneId = widget.localMapZoneId?.trim();

      // En mode hors ligne, la zone choisie comme ACTIVE dans le
      // gestionnaire cartographique est prioritaire.
      LocalMapZone? zone = await LocalMapService.instance.activeZone();

      // Compatibilité : si aucune zone active n'est définie,
      // essayer l'identifiant éventuellement fourni par l'écran appelant.
      if (zone == null &&
          requestedZoneId != null &&
          requestedZoneId.isNotEmpty) {
        final zones = await LocalMapService.instance.installedZones();

        for (final candidate in zones) {
          if (candidate.id == requestedZoneId) {
            zone = candidate;
            break;
          }
        }
      }

      if (zone == null) {
        if (mounted) {
          setState(() {
            _localTileProvider = null;
          });
        }
        return;
      }

      final provider = await LocalMapService.instance.providerFor(zone.id);
      final viewport = _readMbTilesViewport(zone.filePath);

      if (!mounted) {
        provider?.dispose();
        return;
      }

      setState(() {
        _localTileProvider = provider;
      });

      // Si la mission possède déjà une position pertinente (PD, OBS ou point
      // initial), on la conserve. Sinon, on cadre automatiquement la zone
      // MBTiles active d'après ses métadonnées `center` / `bounds`.
      final hasMissionAnchor = (_isObjectifDepuisObservateur &&
              widget.observerLatitude != null &&
              widget.observerLongitude != null) ||
          (_isObjectif &&
              widget.pieceLatitude != null &&
              widget.pieceLongitude != null) ||
          (widget.initialLatitude != null && widget.initialLongitude != null) ||
          (widget.pieceLatitude != null && widget.pieceLongitude != null);

      // Au premier affichage, conserver un point de mission existant.
      // En revanche, après un passage EN LIGNE -> HORS LIGNE, le centre
      // OpenStreetMap peut se trouver hors de l'emprise de la MBTiles.
      // On recadre alors automatiquement sur la zone hors ligne active.
      if (viewport != null && (wasOnline || !hasMissionAnchor)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _currentCenter = viewport.center;
          _currentZoom = viewport.zoom;
          _mapController.move(viewport.center, viewport.zoom);
        });
      }
    } catch (e) {
      debugPrint('[MAP] Impossible de charger la zone MBTiles active : $e');
    } finally {
      _localMapLoading = false;
    }
  }

  _MbTilesViewport? _readMbTilesViewport(String filePath) {
    sqlite.Database? db;

    try {
      db = sqlite.sqlite3.open(filePath, mode: sqlite.OpenMode.readOnly);

      final rows = db.select(
        "SELECT name, value FROM metadata "
        "WHERE name IN ('center', 'bounds', 'minzoom', 'maxzoom')",
      );

      final metadata = <String, String>{};
      for (final row in rows) {
        final name = row['name']?.toString().trim().toLowerCase() ?? '';
        final value = row['value']?.toString().trim() ?? '';
        if (name.isNotEmpty && value.isNotEmpty) {
          metadata[name] = value;
        }
      }

      final centerParts = metadata['center']
          ?.split(',')
          .map((e) => e.trim())
          .toList(growable: false);

      if (centerParts != null && centerParts.length >= 2) {
        final lon = double.tryParse(centerParts[0]);
        final lat = double.tryParse(centerParts[1]);
        final zoom =
            centerParts.length >= 3 ? double.tryParse(centerParts[2]) : null;

        if (lat != null && lon != null) {
          final fallbackZoom =
              double.tryParse(metadata['minzoom'] ?? '') ?? 12.0;
          return _MbTilesViewport(
            center: ll.LatLng(lat, lon),
            zoom: (zoom ?? fallbackZoom).clamp(_minZoom, _maxZoom).toDouble(),
          );
        }
      }

      final boundsParts = metadata['bounds']
          ?.split(',')
          .map((e) => e.trim())
          .toList(growable: false);

      if (boundsParts != null && boundsParts.length >= 4) {
        final west = double.tryParse(boundsParts[0]);
        final south = double.tryParse(boundsParts[1]);
        final east = double.tryParse(boundsParts[2]);
        final north = double.tryParse(boundsParts[3]);

        if (west != null && south != null && east != null && north != null) {
          final minZoom = double.tryParse(metadata['minzoom'] ?? '') ?? 8.0;
          return _MbTilesViewport(
            center: ll.LatLng(
              (south + north) / 2.0,
              (west + east) / 2.0,
            ),
            zoom: minZoom.clamp(_minZoom, _maxZoom).toDouble(),
          );
        }
      }
    } catch (e) {
      debugPrint('[MAP] Métadonnées MBTiles illisibles : $e');
    } finally {
      db?.dispose();
    }

    return null;
  }

  bool get _isObjectif =>
      widget.mode == CartePickMode.objectif ||
      widget.mode == CartePickMode.objectifObservateur;

  bool get _isObjectifDepuisObservateur =>
      widget.mode == CartePickMode.objectifObservateur;

  bool get _isObservateur => widget.mode == CartePickMode.observateur;

  // Les anciennes coordonnées de camps ne sont plus utilisées.
  // La carte s'ouvre sur la mission courante ou, à défaut, sur le centre France.
  ll.LatLng? get _localMapDefaultCenter => null;

  double get _localMapDefaultZoom => 13.0;

  int get _localMapMinNativeZoom => 0;
  int get _localMapMaxNativeZoom => 22;

  ll.LatLng get _initialCenter {
    if (_isObjectifDepuisObservateur &&
        widget.observerLatitude != null &&
        widget.observerLongitude != null) {
      return ll.LatLng(widget.observerLatitude!, widget.observerLongitude!);
    }
    if (_isObjectif &&
        widget.pieceLatitude != null &&
        widget.pieceLongitude != null) {
      return ll.LatLng(widget.pieceLatitude!, widget.pieceLongitude!);
    }
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      return ll.LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
    if (widget.pieceLatitude != null && widget.pieceLongitude != null) {
      return ll.LatLng(widget.pieceLatitude!, widget.pieceLongitude!);
    }
    final localCenter = _localMapDefaultCenter;
    if (localCenter != null) return localCenter;

    return const ll.LatLng(46.603354, 1.888334); // Centre France par défaut.
  }

  double get _initialZoom {
    if (_isObjectifDepuisObservateur &&
        widget.observerLatitude != null &&
        widget.observerLongitude != null) {
      return 13.0;
    }
    if (_isObjectif &&
        widget.pieceLatitude != null &&
        widget.pieceLongitude != null) {
      return 13.0;
    }
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      return 14.0;
    }
    if (_localMapDefaultCenter != null) {
      return _localMapDefaultZoom;
    }
    return 6.0;
  }

  ({int zone, String? band})? _parseZoneLabel(String? raw) {
    final txt = (raw ?? '').trim().toUpperCase();
    if (txt.isEmpty) return null;
    final match = RegExp(r'^(\d{1,2})([C-HJ-NP-X])?$').firstMatch(txt);
    if (match == null) return null;
    final zone = int.tryParse(match.group(1)!);
    if (zone == null || zone < 1 || zone > 60) return null;
    return (zone: zone, band: match.group(2));
  }

  double _distanceM(ll.LatLng a, ll.LatLng b) {
    const earthRadiusM = 6371008.8;
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final dLat = lat2 - lat1;
    final dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * earthRadiusM * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
  }

  double _azimutMil(ll.LatLng from, ll.LatLng to) {
    final lat1 = from.latitude * math.pi / 180.0;
    final lat2 = to.latitude * math.pi / 180.0;
    final dLon = (to.longitude - from.longitude) * math.pi / 180.0;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    var bearing = math.atan2(y, x);
    if (bearing < 0) bearing += 2 * math.pi;
    return bearing * 3200.0 / math.pi;
  }

  PickedMapPoint? _buildPickedResult() {
    final p = _picked;
    if (p == null) return null;

    final altitude = _pickedAltitude ??
        widget.initialAltitude ??
        (_isObjectif
            ? 0.0
            : (_isObservateur
                ? (widget.observerAltitude ?? widget.pieceAltitude ?? 0.0)
                : (widget.pieceAltitude ?? 0.0)));

    final preferredZone = _parseZoneLabel(widget.utmZoneLabel);
    final utm = preferredZone == null
        ? UtmConverter.fromLatLon(
            latitude: p.latitude,
            longitude: p.longitude,
            altitude: altitude,
          )
        : UtmConverter.fromLatLonInZone(
            latitude: p.latitude,
            longitude: p.longitude,
            altitude: altitude,
            zone: preferredZone.zone,
            band: preferredZone.band,
          );

    double? distance;
    double? azimut;
    if (_isObjectifDepuisObservateur &&
        widget.observerLatitude != null &&
        widget.observerLongitude != null) {
      final obs = ll.LatLng(
        widget.observerLatitude!,
        widget.observerLongitude!,
      );
      distance = _distanceM(obs, p);
      azimut = _azimutMil(obs, p);
    } else if (_isObjectif &&
        widget.pieceLatitude != null &&
        widget.pieceLongitude != null) {
      final pd = ll.LatLng(widget.pieceLatitude!, widget.pieceLongitude!);
      distance = _distanceM(pd, p);
      azimut = _azimutMil(pd, p);
    }

    return PickedMapPoint(
      latitude: p.latitude,
      longitude: p.longitude,
      utm: utm,
      distanceFromPieceM: distance,
      azimutFromPieceMil: azimut,
    );
  }

  double? get _fallbackAltitude {
    if (widget.initialAltitude != null) return widget.initialAltitude;
    if (_isObjectif) return 0.0;
    if (_isObservateur) {
      return widget.observerAltitude ?? widget.pieceAltitude ?? 0.0;
    }
    return widget.pieceAltitude ?? 0.0;
  }

  Future<void> _refreshTirApercu() async {
    final builder = widget.tirApercuBuilder;
    final pickedResult = _buildPickedResult();
    final distanceM = pickedResult?.distanceFromPieceM;
    final request = ++_tirApercuRequest;

    if (!_isObjectif || builder == null || distanceM == null) {
      if (mounted) {
        setState(() {
          _tirApercu = null;
          _tirApercuLoading = false;
        });
      }
      return;
    }

    setState(() {
      _tirApercu = null;
      _tirApercuLoading = true;
    });

    try {
      final apercu = await builder(distanceM);
      if (!mounted || request != _tirApercuRequest) return;
      setState(() {
        _tirApercu = apercu;
        _tirApercuLoading = false;
      });
    } catch (error) {
      if (!mounted || request != _tirApercuRequest) return;
      setState(() {
        _tirApercu = const CarteTirApercu(
          etat: CarteTirEtat.impossible,
          titre: 'Tir non évaluable',
          detail: 'Vérifiez le système, la munition et les tables disponibles.',
        );
        _tirApercuLoading = false;
      });
      debugPrint('[CARTE] Aperçu balistique indisponible : $error');
    }
  }

  Future<void> _pickPoint(ll.LatLng point) async {
    setState(() {
      _picked = point;
      _pickedAltitude = _fallbackAltitude;
      _altitudeFromMnt = false;
      _altitudeLoading = true;
    });

    // La distance PD–objectif ne dépend pas de l’altitude MNT : l’aperçu
    // apparaît dès le clic, tandis que l’altitude est chargée en parallèle.
    unawaited(_refreshTirApercu());

    final altitude = await ElevationService.instance.elevationAt(
      latitude: point.latitude,
      longitude: point.longitude,
    );

    if (!mounted || _picked != point) return;

    setState(() {
      if (altitude != null) {
        _pickedAltitude = altitude;
        _altitudeFromMnt = true;
      }
      _altitudeLoading = false;
    });
  }

  void _confirm() {
    final result = _buildPickedResult();
    if (result == null) return;
    Navigator.of(context).pop(result);
  }

  ll.LatLng _focusPoint() {
    if (_picked != null) {
      return _picked!;
    }

    if (_isObjectifDepuisObservateur &&
        widget.observerLatitude != null &&
        widget.observerLongitude != null) {
      return ll.LatLng(widget.observerLatitude!, widget.observerLongitude!);
    }

    if (_isObjectif &&
        widget.pieceLatitude != null &&
        widget.pieceLongitude != null) {
      return ll.LatLng(widget.pieceLatitude!, widget.pieceLongitude!);
    }

    if (_isObservateur &&
        widget.observerLatitude != null &&
        widget.observerLongitude != null) {
      return ll.LatLng(widget.observerLatitude!, widget.observerLongitude!);
    }

    return _currentCenter;
  }

  ll.LatLng? _referencePoint() {
    if (_isObjectifDepuisObservateur &&
        widget.observerLatitude != null &&
        widget.observerLongitude != null) {
      return ll.LatLng(widget.observerLatitude!, widget.observerLongitude!);
    }

    if (_isObjectif &&
        widget.pieceLatitude != null &&
        widget.pieceLongitude != null) {
      return ll.LatLng(widget.pieceLatitude!, widget.pieceLongitude!);
    }

    return null;
  }

  List<ll.LatLng> _missionPoints() {
    final reference = _referencePoint();
    final picked = _picked;

    if (reference == null || picked == null) {
      return const <ll.LatLng>[];
    }

    return <ll.LatLng>[reference, picked];
  }

  void _recenterOnFocus() {
    final focus = _focusPoint();

    _currentCenter = focus;
    _mapController.move(focus, _currentZoom);

    setState(() {});
  }

  void _fitMission(BuildContext context) {
    final points = _missionPoints();
    if (points.length < 2) return;

    final latMin = points.map((p) => p.latitude).reduce(math.min);
    final latMax = points.map((p) => p.latitude).reduce(math.max);
    final lonMin = points.map((p) => p.longitude).reduce(math.min);
    final lonMax = points.map((p) => p.longitude).reduce(math.max);

    final center = ll.LatLng((latMin + latMax) / 2.0, (lonMin + lonMax) / 2.0);

    final diagonalM = _distanceM(
      ll.LatLng(latMin, lonMin),
      ll.LatLng(latMax, lonMax),
    ).clamp(1.0, double.infinity);

    final size = MediaQuery.sizeOf(context);
    final usefulPixels = math.max(
      120.0,
      math.min(size.width, size.height) * 0.55,
    );

    final metersPerPixel = diagonalM / usefulPixels;
    final cosLat =
        math.cos(center.latitude * math.pi / 180.0).abs().clamp(0.01, 1.0);

    final targetZoom =
        (math.log(156543.03392 * cosLat / metersPerPixel) / math.ln2).clamp(
      _minZoom,
      _maxZoom,
    );

    _currentCenter = center;
    _currentZoom = targetZoom.toDouble();

    _mapController.move(center, _currentZoom);
    setState(() {});
  }

  void _zoomBy(double delta) {
    final nextZoom = (_currentZoom + delta).clamp(_minZoom, _maxZoom);
    final focus = _focusPoint();

    _currentZoom = nextZoom;
    _currentCenter = focus;

    _mapController.move(focus, nextZoom);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final bg = dark ? const Color(0xFF0E0F12) : const Color(0xFFF4F5F7);
    final card = dark ? const Color(0xFF12141A) : Colors.white;
    final border = dark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.10);
    final textPrimary =
        dark ? Colors.white.withValues(alpha: 0.92) : Colors.black87;
    final textSecondary =
        dark ? Colors.white.withValues(alpha: 0.68) : Colors.black54;
    final center = _initialCenter;
    final pdPoint =
        widget.pieceLatitude != null && widget.pieceLongitude != null
            ? ll.LatLng(widget.pieceLatitude!, widget.pieceLongitude!)
            : null;
    final obsPoint =
        widget.observerLatitude != null && widget.observerLongitude != null
            ? ll.LatLng(widget.observerLatitude!, widget.observerLongitude!)
            : null;
    final referencePoint = _isObjectifDepuisObservateur ? obsPoint : pdPoint;
    final picked = _picked;
    final pickedResult = _buildPickedResult();
    final canFitMission = _missionPoints().length >= 2;
    final missionLabel =
        _isObjectifDepuisObservateur ? 'OBS → OBJ' : 'PD → OBJ';
    final missionReferenceAltitude = _isObjectifDepuisObservateur
        ? widget.observerAltitude
        : (_isObjectif ? widget.pieceAltitude : null);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
        title: Text(
          _isObjectif
              ? (_isObjectifDepuisObservateur
                  ? 'Objectif vu par observateur'
                  : 'Choisir objectif sur carte')
              : (_isObservateur
                  ? 'Choisir observateur'
                  : 'Choisir pièce directrice'),
        ),
        actions: [
          TextButton.icon(
            onPressed: picked == null ? null : _confirm,
            icon: const Icon(Icons.check),
            label: const Text('Valider'),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: _initialZoom,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onPositionChanged: (position, hasGesture) {
                  final nextCenter = position.center;
                  final nextZoom = position.zoom;
                  if (!mounted) return;
                  setState(() {
                    _currentCenter = nextCenter;
                    _currentZoom = nextZoom;
                  });
                },
                onTap: (tapPosition, point) {
                  _pickPoint(point);
                },
              ),
              children: [
                // En ligne : fond cartographique réseau.
                // Hors ligne : zone MBTiles active.
                if (_onlineEnabled)
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.calculateurTirNg',
                  )
                else if (_localTileProvider != null)
                  TileLayer(
                    tileProvider: _localTileProvider!,
                    minNativeZoom: _localMapMinNativeZoom,
                    maxNativeZoom: _localMapMaxNativeZoom,
                  ),
                if (_isObjectif && referencePoint != null && picked != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [referencePoint, picked],
                        color: const Color(0xFF2EE6A6),
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (pdPoint != null)
                      Marker(
                        point: pdPoint,
                        width: 60,
                        height: 70,
                        alignment: Alignment.topCenter,
                        child: _MapBadgeMarker(
                          label: 'PD',
                          color: const Color(0xFF2EE6A6),
                          dark: dark,
                        ),
                      ),
                    if (obsPoint != null)
                      Marker(
                        point: obsPoint,
                        width: 60,
                        height: 70,
                        alignment: Alignment.topCenter,
                        child: _MapBadgeMarker(
                          label: 'OBS',
                          color: const Color(0xFF80D8FF),
                          dark: dark,
                        ),
                      ),
                    if (picked != null)
                      Marker(
                        point: picked,
                        width: 60,
                        height: 70,
                        alignment: Alignment.topCenter,
                        child: _MapBadgeMarker(
                          label: _isObjectif
                              ? 'OBJ'
                              : (_isObservateur ? 'OBS' : 'PD'),
                          color: _isObjectif
                              ? const Color(0xFFFFB020)
                              : (_isObservateur
                                  ? const Color(0xFF80D8FF)
                                  : const Color(0xFF2EE6A6)),
                          dark: dark,
                        ),
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
              left: 12,
              top: 12,
              child: _ScaleBadge(
                dark: dark,
                zoom: _currentZoom,
                latitude: _currentCenter.latitude,
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: _ZoomControls(
                dark: dark,
                onZoomIn: () => _zoomBy(1),
                onZoomOut: () => _zoomBy(-1),
                onRecenter: _recenterOnFocus,
                onFitMission: canFitMission ? () => _fitMission(context) : null,
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _InfoPanel(
                dark: dark,
                card: card,
                border: border,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                picked: pickedResult,
                altitudeLoading: _altitudeLoading,
                altitudeFromMnt: _altitudeFromMnt,
                isObjectif: _isObjectif,
                isObjectifDepuisObservateur: _isObjectifDepuisObservateur,
                isObservateur: _isObservateur,
                zoneLabel: widget.utmZoneLabel,
                missionLabel: missionLabel,
                missionReferenceAltitude: missionReferenceAltitude,
                tirApercu: _tirApercu,
                tirApercuLoading: _tirApercuLoading,
                onValidate: picked == null ? null : _confirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapBadgeMarker extends StatelessWidget {
  const _MapBadgeMarker({
    required this.label,
    required this.color,
    required this.dark,
  });

  final String label;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 70,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF101216) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: 1.5),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            child: Icon(Icons.location_on, color: color, size: 36),
          ),
        ],
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.dark,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
    required this.onFitMission,
  });

  final bool dark;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRecenter;
  final VoidCallback? onFitMission;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ZoomButton(dark: dark, icon: Icons.add, onTap: onZoomIn),
        const SizedBox(height: 8),
        _ZoomButton(dark: dark, icon: Icons.remove, onTap: onZoomOut),
        const SizedBox(height: 8),
        _ZoomButton(
          dark: dark,
          icon: Icons.center_focus_strong,
          onTap: onRecenter,
        ),
        const SizedBox(height: 8),
        _ZoomButton(dark: dark, icon: Icons.fit_screen, onTap: onFitMission),
      ],
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.dark,
    required this.icon,
    required this.onTap,
  });

  final bool dark;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: onTap == null ? 0.42 : 1.0,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: dark
                  ? Colors.black.withValues(alpha: 0.68)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: dark ? Colors.white24 : Colors.black12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.28 : 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 21,
              color: dark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScaleBadge extends StatelessWidget {
  const _ScaleBadge({
    required this.dark,
    required this.zoom,
    required this.latitude,
  });

  final bool dark;
  final double zoom;
  final double latitude;

  static const double _barWidthPx = 86;

  double get _metersPerPixel {
    final cosLat = math.cos(latitude * math.pi / 180.0).abs().clamp(0.01, 1.0);
    return 156543.03392 * cosLat / math.pow(2.0, zoom);
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
      200000,
      500000,
    ];

    var best = candidates.first;
    for (final c in candidates) {
      if (c <= rawMeters) {
        best = c;
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
    final rawMeters = _metersPerPixel * _barWidthPx;
    final distanceMeters = _niceDistance(rawMeters);
    final width = (distanceMeters / _metersPerPixel).clamp(36.0, _barWidthPx);
    final label = _formatDistance(distanceMeters);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: dark
            ? Colors.black.withValues(alpha: 0.68)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dark ? Colors.white24 : Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.28 : 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: width,
            height: 4,
            decoration: BoxDecoration(
              color: dark ? Colors.white : Colors.black87,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: dark ? Colors.white70 : Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MbTilesViewport {
  const _MbTilesViewport({
    required this.center,
    required this.zoom,
  });

  final ll.LatLng center;
  final double zoom;
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.dark,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.picked,
    required this.altitudeLoading,
    required this.altitudeFromMnt,
    required this.isObjectif,
    required this.zoneLabel,
    required this.isObjectifDepuisObservateur,
    required this.isObservateur,
    required this.missionLabel,
    required this.missionReferenceAltitude,
    required this.tirApercu,
    required this.tirApercuLoading,
    required this.onValidate,
  });

  final bool dark;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final PickedMapPoint? picked;
  final bool altitudeLoading;
  final bool altitudeFromMnt;
  final bool isObjectif;
  final String? zoneLabel;
  final bool isObjectifDepuisObservateur;
  final bool isObservateur;
  final String missionLabel;
  final double? missionReferenceAltitude;
  final CarteTirApercu? tirApercu;
  final bool tirApercuLoading;
  final VoidCallback? onValidate;

  @override
  Widget build(BuildContext context) {
    final p = picked;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: card.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            p == null
                ? 'Touchez la carte pour choisir un point.'
                : (isObjectif
                    ? 'Objectif sélectionné'
                    : (isObservateur
                        ? 'Observateur sélectionné'
                        : 'Pièce sélectionnée')),
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (p != null) ...[
            if (isObjectif &&
                p.distanceFromPieceM != null &&
                p.azimutFromPieceMil != null) ...[
              _MissionSummary(
                dark: dark,
                label: missionLabel,
                distanceM: p.distanceFromPieceM!,
                azimutMil: p.azimutFromPieceMil!,
                deltaZ: missionReferenceAltitude == null
                    ? null
                    : p.utm.z - missionReferenceAltitude!,
                tirApercu: tirApercu,
                tirApercuLoading: tirApercuLoading,
              ),
              const SizedBox(height: 10),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  label: 'Lat',
                  value: p.latitude.toStringAsFixed(6),
                  dark: dark,
                ),
                _InfoChip(
                  label: 'Lon',
                  value: p.longitude.toStringAsFixed(6),
                  dark: dark,
                ),
                _InfoChip(
                  label: 'Zone',
                  value: '${p.utm.zone}${p.utm.band}',
                  dark: dark,
                ),
                _InfoChip(
                  label: 'X',
                  value: p.utm.x.toStringAsFixed(0),
                  dark: dark,
                ),
                _InfoChip(
                  label: 'Y',
                  value: p.utm.y.toStringAsFixed(0),
                  dark: dark,
                ),
                _InfoChip(
                  label: altitudeFromMnt ? 'Z MNT' : 'Z',
                  value: altitudeLoading
                      ? '...'
                      : '${p.utm.z.toStringAsFixed(0)} m',
                  dark: dark,
                ),
                if (isObjectif && p.distanceFromPieceM != null)
                  _InfoChip(
                    label: isObjectifDepuisObservateur
                        ? 'Distance OBS'
                        : 'Distance PD',
                    value: '${p.distanceFromPieceM!.toStringAsFixed(0)} m',
                    dark: dark,
                  ),
                if (isObjectif && p.azimutFromPieceMil != null)
                  _InfoChip(
                    label: isObjectifDepuisObservateur
                        ? 'Azimut OBS'
                        : 'Azimut PD',
                    value: '${p.azimutFromPieceMil!.toStringAsFixed(1)} mil',
                    dark: dark,
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  isObjectifDepuisObservateur
                      ? 'Le point objectif remplira X/Y/Z et mettra à jour distance/azimut depuis l’observateur.'
                      : (isObjectif
                          ? 'Le point objectif remplira X/Y/Z et mettra à jour distance/azimut depuis la PD.'
                          : (isObservateur
                              ? 'Le point observateur remplira X/Y/Z. Si un MNT local couvre la zone, Z vient automatiquement du MNT.'
                              : 'La carte est centrée sur la zone de la pièce si elle est déjà renseignée.')),
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(onPressed: onValidate, child: const Text('Valider')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MissionSummary extends StatelessWidget {
  const _MissionSummary({
    required this.dark,
    required this.label,
    required this.distanceM,
    required this.azimutMil,
    required this.deltaZ,
    required this.tirApercu,
    required this.tirApercuLoading,
  });

  final bool dark;
  final String label;
  final double distanceM;
  final double azimutMil;
  final double? deltaZ;
  final CarteTirApercu? tirApercu;
  final bool tirApercuLoading;

  String _fmtDeltaZ(double? value) {
    if (value == null) return 'N/D';
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(0)} m';
  }

  @override
  Widget build(BuildContext context) {
    final bg = dark
        ? const Color(0xFF101216).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.96);
    final bd = dark
        ? const Color(0xFF2EE6A6).withValues(alpha: 0.35)
        : const Color(0xFF2EE6A6).withValues(alpha: 0.45);
    final titleColor = dark ? const Color(0xFF2EE6A6) : const Color(0xFF246B55);
    final subColor = dark ? Colors.white70 : Colors.black54;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: titleColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MissionValue(
                dark: dark,
                label: 'Distance',
                value: '${distanceM.toStringAsFixed(0)} m',
              ),
              _MissionValue(
                dark: dark,
                label: 'Azimut',
                value: '${azimutMil.toStringAsFixed(1)} mil',
              ),
              _MissionValue(dark: dark, label: 'ΔZ', value: _fmtDeltaZ(deltaZ)),
            ],
          ),
          const SizedBox(height: 8),
          _CarteTirApercuBadge(
            dark: dark,
            apercu: tirApercu,
            loading: tirApercuLoading,
          ),
          if (deltaZ == null) ...[
            const SizedBox(height: 6),
            Text(
              'Altitude de référence indisponible pour le ΔZ.',
              style: TextStyle(color: subColor, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _CarteTirApercuBadge extends StatelessWidget {
  const _CarteTirApercuBadge({
    required this.dark,
    required this.apercu,
    required this.loading,
  });

  final bool dark;
  final CarteTirApercu? apercu;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final state = apercu?.etat;
    final color = switch (state) {
      CarteTirEtat.ok => const Color(0xFF27C98B),
      CarteTirEtat.limite => const Color(0xFFFFA726),
      CarteTirEtat.impossible => const Color(0xFFE05252),
      null => dark ? Colors.white54 : Colors.black45,
    };
    final icon = switch (state) {
      CarteTirEtat.ok => Icons.check_circle_outline,
      CarteTirEtat.limite => Icons.warning_amber_rounded,
      CarteTirEtat.impossible => Icons.cancel_outlined,
      null => Icons.hourglass_top_rounded,
    };
    final title = loading
        ? 'Évaluation de portée…'
        : (apercu?.titre ?? 'Évaluation indisponible');
    final detail = loading
        ? 'Lecture des charges disponibles.'
        : (apercu?.detail ?? 'Touchez la carte pour calculer la charge.');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: dark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    color: dark ? Colors.white70 : Colors.black54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionValue extends StatelessWidget {
  const _MissionValue({
    required this.dark,
    required this.label,
    required this.value,
  });

  final bool dark;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final labelColor = dark ? Colors.white60 : Colors.black54;
    final valueColor = dark ? Colors.white : Colors.black87;

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 12, color: labelColor),
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
    required this.dark,
  });

  final String label;
  final String value;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dark ? Colors.white12 : Colors.black12),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: dark ? Colors.white70 : Colors.black54,
            fontSize: 11,
          ),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: dark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
