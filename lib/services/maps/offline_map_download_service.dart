import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mbtiles/mbtiles.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:calculateur_etranger/services/maps/local_map_service.dart';

/// Source XYZ autorisée pour la préparation d'une zone hors ligne.
///
/// IMPORTANT : ne pas brancher ici un serveur qui interdit le préchargement
/// ou les téléchargements hors ligne. Le service ne choisit volontairement
/// aucune source par défaut.
class OfflineMapTileSource {
  const OfflineMapTileSource({
    required this.id,
    required this.name,
    required this.urlTemplate,
    required this.format,
    required this.attribution,
    this.headers = const <String, String>{},
  });

  final String id;
  final String name;

  /// Modèle XYZ, par exemple :
  /// https://example.com/tiles/{z}/{x}/{y}.png
  final String urlTemplate;

  /// png, jpg ou webp.
  final String format;

  final String attribution;
  final Map<String, String> headers;

  Uri uriFor({required int z, required int x, required int y}) {
    final raw = urlTemplate
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');
    return Uri.parse(raw);
  }
}

class OfflineMapBounds {
  const OfflineMapBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  final double west;
  final double south;
  final double east;
  final double north;

  OfflineMapBounds normalized() {
    final w = west.clamp(-180.0, 180.0).toDouble();
    final e = east.clamp(-180.0, 180.0).toDouble();
    final s = south.clamp(-85.05112878, 85.05112878).toDouble();
    final n = north.clamp(-85.05112878, 85.05112878).toDouble();

    return OfflineMapBounds(
      west: math.min(w, e),
      east: math.max(w, e),
      south: math.min(s, n),
      north: math.max(s, n),
    );
  }

  double get centerLatitude => (south + north) / 2.0;
  double get centerLongitude => (west + east) / 2.0;
}

class OfflineMapDownloadRequest {
  const OfflineMapDownloadRequest({
    required this.name,
    required this.bounds,
    required this.minZoom,
    required this.maxZoom,
    required this.source,
  });

  final String name;
  final OfflineMapBounds bounds;
  final int minZoom;
  final int maxZoom;
  final OfflineMapTileSource source;
}

class OfflineMapDownloadProgress {
  const OfflineMapDownloadProgress({
    required this.completedTiles,
    required this.totalTiles,
    required this.downloadedBytes,
    required this.currentZoom,
  });

  final int completedTiles;
  final int totalTiles;
  final int downloadedBytes;
  final int currentZoom;

  double get fraction => totalTiles <= 0 ? 0 : completedTiles / totalTiles;
}

class OfflineMapDownloadEstimate {
  const OfflineMapDownloadEstimate({
    required this.tileCount,
    required this.approximateBytes,
  });

  final int tileCount;

  /// Estimation grossière basée sur 30 kio par tuile raster.
  final int approximateBytes;

  double get approximateMegabytes => approximateBytes / (1024 * 1024);
}

class OfflineMapDownloadCancelled implements Exception {
  const OfflineMapDownloadCancelled();

  @override
  String toString() => 'Map download canceled';
}

/// Télécharge une emprise XYZ puis l'écrit dans un MBTiles raster.
///
/// Le service :
/// - refuse toute requête si le mode cartographique "En ligne" n'a pas été
///   explicitement activé ;
/// - ne possède aucune URL de fournisseur en dur ;
/// - limite la taille afin d'éviter un téléchargement accidentel gigantesque ;
/// - installe le MBTiles terminé via LocalMapService puis l'active.
class OfflineMapDownloadService {
  OfflineMapDownloadService._();

  static final OfflineMapDownloadService instance =
      OfflineMapDownloadService._();

  static const int maxTilesPerDownload = 30000;
  static const int _estimatedBytesPerRasterTile = 30 * 1024;

  bool _cancelRequested = false;

  void cancel() {
    _cancelRequested = true;
  }

  OfflineMapDownloadEstimate estimate(OfflineMapDownloadRequest request) {
    _validateRequest(request);

    final bounds = request.bounds.normalized();
    var count = 0;

    for (var z = request.minZoom; z <= request.maxZoom; z++) {
      final range = _tileRange(bounds, z);
      count += (range.maxX - range.minX + 1) * (range.maxY - range.minY + 1);
    }

    return OfflineMapDownloadEstimate(
      tileCount: count,
      approximateBytes: count * _estimatedBytesPerRasterTile,
    );
  }

  Future<LocalMapZone> downloadAndInstall({
    required OfflineMapDownloadRequest request,
    ValueChanged<OfflineMapDownloadProgress>? onProgress,
  }) async {
    _validateRequest(request);

    final onlineEnabled = await LocalMapService.instance.isOnlineEnabled();
    if (!onlineEnabled) {
      throw StateError(
        'Offline mode active. Explicitly switch to Online mode before '
        'to prepare a new zone.',
      );
    }

    final estimateValue = estimate(request);
    if (estimateValue.tileCount > maxTilesPerDownload) {
      throw StateError(
        'Zone too large: ${estimateValue.tileCount} tiles '
        '(limit $maxTilesPerDownload). Reduce the extent or the maximum zoom.',
      );
    }

    _cancelRequested = false;

    final tempDir = await getTemporaryDirectory();
    final safeBase = _safeFileBase(request.name);
    final tempPath = p.join(
      tempDir.path,
      '${safeBase}_${DateTime.now().millisecondsSinceEpoch}.mbtiles',
    );

    final tempFile = File(tempPath);
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    final bounds = request.bounds.normalized();

    final metadata = MbTilesMetadata(
      name: request.name.trim().isEmpty ? 'Offline area' : request.name.trim(),
      format: request.source.format,
      minZoom: request.minZoom.toDouble(),
      maxZoom: request.maxZoom.toDouble(),
      attributionHtml: request.source.attribution,
      description:
          'Offline zone prepared by Fire Calculator from ${request.source.name}.',
    );

    final mbtiles = MbTiles.create(mbtilesPath: tempPath, metadata: metadata);

    final client = http.Client();
    var completed = 0;
    var bytes = 0;

    try {
      for (var z = request.minZoom; z <= request.maxZoom; z++) {
        final range = _tileRange(bounds, z);

        for (var x = range.minX; x <= range.maxX; x++) {
          for (var y = range.minY; y <= range.maxY; y++) {
            if (_cancelRequested) {
              throw const OfflineMapDownloadCancelled();
            }

            final uri = request.source.uriFor(z: z, x: x, y: y);
            final response = await client
                .get(uri, headers: request.source.headers)
                .timeout(const Duration(seconds: 20));

            if (response.statusCode == HttpStatus.ok) {
              final data = Uint8List.fromList(response.bodyBytes);
              if (data.isNotEmpty) {
                mbtiles.putTile(z: z, x: x, y: y, bytes: data);
                bytes += data.length;
              }
            } else if (response.statusCode != HttpStatus.notFound &&
                response.statusCode != HttpStatus.noContent) {
              throw HttpException(
                'Tuile $z/$x/$y : HTTP ${response.statusCode}',
                uri: uri,
              );
            }

            completed++;
            onProgress?.call(
              OfflineMapDownloadProgress(
                completedTiles: completed,
                totalTiles: estimateValue.tileCount,
                downloadedBytes: bytes,
                currentZoom: z,
              ),
            );
          }
        }
      }
    } catch (_) {
      rethrow;
    } finally {
      client.close();
      mbtiles.dispose();
    }

    if (_cancelRequested) {
      if (await tempFile.exists()) await tempFile.delete();
      throw const OfflineMapDownloadCancelled();
    }

    try {
      final installed = await LocalMapService.instance.importMbTiles(
        sourcePath: tempPath,
        displayName: request.name,
      );

      debugPrint(
        '[MAP DOWNLOAD] zone=${installed.name} '
        'tiles=$completed bytes=$bytes source=${request.source.id}',
      );

      return installed;
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  void _validateRequest(OfflineMapDownloadRequest request) {
    if (request.source.urlTemplate.trim().isEmpty) {
      throw ArgumentError('No tile source configured.');
    }
    if (!request.source.urlTemplate.contains('{z}') ||
        !request.source.urlTemplate.contains('{x}') ||
        !request.source.urlTemplate.contains('{y}')) {
      throw ArgumentError(
        'The source must be an XYZ template containing {z}, {x} and {y}.',
      );
    }

    final format = request.source.format.toLowerCase().trim();
    if (format != 'png' && format != 'jpg' && format != 'webp') {
      throw ArgumentError('Unsupported raster format: $format');
    }

    if (request.minZoom < 0 ||
        request.maxZoom < request.minZoom ||
        request.maxZoom > 22) {
      throw ArgumentError(
        'Invalid zoom range: ${request.minZoom}–${request.maxZoom}.',
      );
    }

    final b = request.bounds.normalized();
    if ((b.east - b.west).abs() < 1e-9 || (b.north - b.south).abs() < 1e-9) {
      throw ArgumentError('Emprise cartographique vide.');
    }
  }

  _TileRange _tileRange(OfflineMapBounds bounds, int zoom) {
    final minX = _longitudeToTileX(bounds.west, zoom);
    final maxX = _longitudeToTileX(bounds.east, zoom);

    // En XYZ, Y augmente du nord vers le sud.
    final minY = _latitudeToTileY(bounds.north, zoom);
    final maxY = _latitudeToTileY(bounds.south, zoom);

    return _TileRange(
      minX: math.min(minX, maxX),
      maxX: math.max(minX, maxX),
      minY: math.min(minY, maxY),
      maxY: math.max(minY, maxY),
    );
  }

  int _longitudeToTileX(double longitude, int zoom) {
    final n = 1 << zoom;
    final x = (((longitude + 180.0) / 360.0) * n).floor();
    return x.clamp(0, n - 1);
  }

  int _latitudeToTileY(double latitude, int zoom) {
    final n = 1 << zoom;
    final lat = latitude.clamp(-85.05112878, 85.05112878).toDouble();
    final latRad = lat * math.pi / 180.0;

    final tanLat = math.tan(latRad);
    final asinhTanLat = math.log(tanLat + math.sqrt(tanLat * tanLat + 1.0));

    final value = (1.0 - asinhTanLat / math.pi) / 2.0 * n;
    return value.floor().clamp(0, n - 1);
  }

  String _safeFileBase(String raw) {
    final value = raw.trim().toLowerCase();
    final normalized = value
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return normalized.isEmpty ? 'zone' : normalized;
  }
}

class _TileRange {
  const _TileRange({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  final int minX;
  final int maxX;
  final int minY;
  final int maxY;
}
