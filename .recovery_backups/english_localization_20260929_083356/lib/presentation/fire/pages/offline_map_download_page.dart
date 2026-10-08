import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:calculateur_etranger/services/maps/local_map_service.dart';
import 'package:calculateur_etranger/services/maps/offline_map_download_service.dart';
import 'package:calculateur_etranger/services/maps/offline_map_source_config.dart';

class OfflineMapDownloadPage extends StatefulWidget {
  const OfflineMapDownloadPage({
    super.key,
    required this.dark,
    this.initialCenter,
  });

  final bool dark;
  final LatLng? initialCenter;

  @override
  State<OfflineMapDownloadPage> createState() => _OfflineMapDownloadPageState();
}

class _OfflineMapDownloadPageState extends State<OfflineMapDownloadPage> {
  final MapController _mapController = MapController();
  final TextEditingController _nameCtrl =
      TextEditingController(text: 'Zone hors ligne');

  LatLng? _cornerA;
  LatLng? _cornerB;

  double _minZoom = 8;
  double _maxZoom = 15;

  bool _downloading = false;
  OfflineMapDownloadProgress? _progress;
  String? _error;

  OfflineMapTileSource? get _source => OfflineMapSourceConfig.source;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  OfflineMapBounds? get _selectedBounds {
    final a = _cornerA;
    final b = _cornerB;
    if (a == null || b == null) return null;

    return OfflineMapBounds(
      west: a.longitude < b.longitude ? a.longitude : b.longitude,
      east: a.longitude > b.longitude ? a.longitude : b.longitude,
      south: a.latitude < b.latitude ? a.latitude : b.latitude,
      north: a.latitude > b.latitude ? a.latitude : b.latitude,
    );
  }

  OfflineMapDownloadRequest? get _request {
    final source = _source;
    final bounds = _selectedBounds;
    if (source == null || bounds == null) return null;

    return OfflineMapDownloadRequest(
      name: _nameCtrl.text.trim().isEmpty
          ? 'Zone hors ligne'
          : _nameCtrl.text.trim(),
      bounds: bounds,
      minZoom: _minZoom.round(),
      maxZoom: _maxZoom.round(),
      source: source,
    );
  }

  OfflineMapDownloadEstimate? get _estimate {
    final request = _request;
    if (request == null) return null;

    try {
      return OfflineMapDownloadService.instance.estimate(request);
    } catch (_) {
      return null;
    }
  }

  void _selectCorner(LatLng point) {
    if (_downloading) return;

    setState(() {
      _error = null;

      if (_cornerA == null || _cornerB != null) {
        _cornerA = point;
        _cornerB = null;
      } else {
        _cornerB = point;
      }
    });
  }

  void _clearSelection() {
    if (_downloading) return;
    setState(() {
      _cornerA = null;
      _cornerB = null;
      _progress = null;
      _error = null;
    });
  }

  List<LatLng> _rectanglePoints(OfflineMapBounds bounds) {
    return <LatLng>[
      LatLng(bounds.north, bounds.west),
      LatLng(bounds.north, bounds.east),
      LatLng(bounds.south, bounds.east),
      LatLng(bounds.south, bounds.west),
    ];
  }

  String _formatMegabytes(double value) {
    if (value < 1) return '${(value * 1024).round()} ko';
    if (value < 10) return '${value.toStringAsFixed(1)} Mo';
    return '${value.round()} Mo';
  }

  Future<void> _download() async {
    final request = _request;
    if (request == null || _downloading) return;

    final estimate = _estimate;
    if (estimate == null) return;

    if (estimate.tileCount > OfflineMapDownloadService.maxTilesPerDownload) {
      setState(() {
        _error =
            'Zone trop grande : ${estimate.tileCount} tuiles. Réduire la zone '
            'ou le zoom maximal.';
      });
      return;
    }

    setState(() {
      _downloading = true;
      _progress = null;
      _error = null;
    });

    try {
      final LocalMapZone zone =
          await OfflineMapDownloadService.instance.downloadAndInstall(
        request: request,
        onProgress: (value) {
          if (!mounted) return;
          setState(() => _progress = value);
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop(zone.id);
    } on OfflineMapDownloadCancelled {
      if (!mounted) return;
      setState(() => _error = 'Téléchargement annulé.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Téléchargement impossible : $e');
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final bg = dark ? const Color(0xFF0E0F12) : const Color(0xFFF4F5F7);
    final card = dark ? const Color(0xFF12141A) : Colors.white;
    final border =
        dark ? Colors.white.withValues(alpha: 0.10) : const Color(0x1A000000);
    final textPrimary =
        dark ? Colors.white.withValues(alpha: 0.92) : Colors.black87;
    final textSecondary =
        dark ? Colors.white.withValues(alpha: 0.68) : Colors.black54;
    const onlineGreen = Color(0xFF5E9F7A);

    final source = _source;
    final bounds = _selectedBounds;
    final estimate = _estimate;
    final progress = _progress;

    final center = widget.initialCenter ?? const LatLng(46.65, 2.45);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
        title: const Text('Préparer une zone hors ligne'),
        actions: [
          if (_downloading)
            TextButton(
              onPressed: OfflineMapDownloadService.instance.cancel,
              child: const Text('Annuler'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 6.0,
                      onTap: (_, point) => _selectCorner(point),
                    ),
                    children: [
                      if (source != null)
                        TileLayer(
                          urlTemplate: source.urlTemplate,
                          userAgentPackageName: 'calculateur_tir_ng',
                        ),
                      if (bounds != null)
                        PolygonLayer(
                          polygons: [
                            Polygon(
                              points: _rectanglePoints(bounds),
                              color: onlineGreen.withValues(alpha: 0.12),
                              borderColor: onlineGreen,
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          if (_cornerA != null)
                            Marker(
                              point: _cornerA!,
                              width: 34,
                              height: 34,
                              child: const Icon(
                                Icons.radio_button_checked,
                                color: onlineGreen,
                                size: 26,
                              ),
                            ),
                          if (_cornerB != null)
                            Marker(
                              point: _cornerB!,
                              width: 34,
                              height: 34,
                              child: const Icon(
                                Icons.radio_button_checked,
                                color: onlineGreen,
                                size: 26,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (source == null)
                    Positioned.fill(
                      child: ColoredBox(
                        color: bg.withValues(alpha: 0.94),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Text(
                              'Aucune source XYZ autorisée n’est configurée.\n\n'
                              'La page de cadrage est prête, mais une source '
                              'cartographique compatible avec le téléchargement '
                              'hors ligne doit être fournie à l’application.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: card.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border),
                        ),
                        child: Text(
                          _cornerA == null
                              ? 'Touchez la carte pour poser le premier coin.'
                              : (_cornerB == null
                                  ? 'Touchez un second point pour fermer la zone.'
                                  : 'Zone sélectionnée. Ajustez les zooms puis téléchargez.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: card,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtrl,
                          enabled: !_downloading,
                          decoration: const InputDecoration(
                            labelText: 'Nom de la zone',
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: (_cornerA == null && _cornerB == null) ||
                                _downloading
                            ? null
                            : _clearSelection,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Reprendre'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Niveaux de zoom : ${_minZoom.round()} → ${_maxZoom.round()}',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  RangeSlider(
                    min: 4,
                    max: 18,
                    divisions: 14,
                    values: RangeValues(_minZoom, _maxZoom),
                    labels: RangeLabels(
                      '${_minZoom.round()}',
                      '${_maxZoom.round()}',
                    ),
                    onChanged: _downloading
                        ? null
                        : (values) {
                            setState(() {
                              _minZoom = values.start;
                              _maxZoom = values.end;
                              _error = null;
                            });
                          },
                  ),
                  if (estimate != null)
                    Text(
                      '${estimate.tileCount} tuiles • '
                      '≈ ${_formatMegabytes(estimate.approximateMegabytes)}',
                      style: TextStyle(
                        color: estimate.tileCount >
                                OfflineMapDownloadService.maxTilesPerDownload
                            ? Colors.orange
                            : textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (progress != null) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress.fraction),
                    const SizedBox(height: 5),
                    Text(
                      '${progress.completedTiles}/${progress.totalTiles} '
                      '• zoom ${progress.currentZoom}',
                      style: TextStyle(color: textSecondary, fontSize: 11),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: source == null ||
                            bounds == null ||
                            _downloading ||
                            (estimate?.tileCount ?? 0) == 0
                        ? null
                        : _download,
                    icon: const Icon(Icons.download_for_offline_outlined),
                    label: Text(
                      _downloading ? 'Téléchargement…' : 'Télécharger la zone',
                    ),
                  ),
                  if (source != null &&
                      source.attribution.trim().isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      source.attribution,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondary, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
