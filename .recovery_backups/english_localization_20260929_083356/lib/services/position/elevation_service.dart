import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Service d'altitude basé sur des tuiles Copernicus GLO-30 préconverties.
///
/// Architecture retenue pour mobile :
/// - l'application reste légère ;
/// - les tuiles ne sont plus forcément embarquées dans assets/dem ;
/// - une tuile est cherchée dans le cache local en fonction de la position ;
/// - si elle est absente et si [downloadBaseUrl] est renseigné dans le manifest,
///   elle est téléchargée puis mise en cache ;
/// - si rien n'est disponible, [elevationAt] renvoie null sans casser l'écran.
///
/// Format attendu des tuiles : float32 little-endian, rangées du nord vers le
/// sud, puis ouest vers est. Pour GLO-30 1 arc-seconde : 3601 x 3601 valeurs.
///
/// Exemple assets/dem/manifest.json :
/// {
///   "version": 2,
///   "downloadBaseUrl": "https://exemple.fr/dem/f32",
///   "maxCacheBytes": 536870912,
///   "tileWidth": 3601,
///   "tileHeight": 3601,
///   "nodata": -32768,
///   "tiles": []
/// }
///
/// Avec "tiles": [] le service calcule automatiquement l'identifiant de tuile
/// à partir de la latitude/longitude : N43E001, N48W002, etc.
class ElevationService {
  ElevationService._();

  static final ElevationService instance = ElevationService._();

  static const String _manifestPath = 'assets/dem/manifest.json';
  static const int _defaultWidth = 3601;
  static const int _defaultHeight = 3601;
  static const double _defaultNoData = -32768;
  static const int _defaultMaxCacheBytes = 512 * 1024 * 1024;

  Future<_DemManifest>? _manifestFuture;
  Future<Directory>? _cacheDirectoryFuture;
  final Map<String, Future<_DemTileData>> _memoryTileCache = {};

  /// Retourne l'altitude en mètres, ou null si la tuile n'est pas disponible.
  Future<double?> elevationAt({
    required double latitude,
    required double longitude,
  }) async {
    if (!latitude.isFinite || !longitude.isFinite) return null;
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    try {
      final manifest = await _loadManifest();
      final tile = manifest.tileFor(latitude, longitude);
      if (tile == null) return null;

      final data = await _loadTileData(tile, manifest);
      return data.sampleBilinear(latitude: latitude, longitude: longitude);
    } catch (e) {
      // L'altitude DEM est une aide, jamais un prérequis de positionnement.
      // Si la tuile manque, si le serveur n'est pas configuré ou si le
      // téléchargement échoue, l'appelant doit pouvoir continuer avec son
      // altitude GPS/manuelle de secours.
      return null;
    }
  }

  Future<_DemTileData> _loadTileData(
    _DemTile tile,
    _DemManifest manifest,
  ) async {
    final existing = _memoryTileCache.remove(tile.id);
    if (existing != null) {
      _memoryTileCache[tile.id] = existing;
      return existing;
    }

    final future = _loadTileWithCache(tile, manifest);
    _memoryTileCache[tile.id] = future;
    _trimMemoryTileCache();
    return future;
  }

  void _trimMemoryTileCache() {
    const maxTilesInRam = 3;
    while (_memoryTileCache.length > maxTilesInRam) {
      _memoryTileCache.remove(_memoryTileCache.keys.first);
    }
  }

  /// Précharge les tuiles couvrant un carré autour d'une position.
  /// Utile pour un bouton "Télécharger autour de moi".
  Future<void> prefetchAround({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    final manifest = await _loadManifest();
    final latDelta = radiusKm / 111.32;
    final cosLat = math.max(0.15, math.cos(latitude * math.pi / 180).abs());
    final lonDelta = radiusKm / (111.32 * cosLat);

    final minLat = (latitude - latDelta).floor();
    final maxLat = (latitude + latDelta).floor();
    final minLon = (longitude - lonDelta).floor();
    final maxLon = (longitude + lonDelta).floor();

    for (var lat = minLat; lat <= maxLat; lat++) {
      for (var lon = minLon; lon <= maxLon; lon++) {
        final tile = manifest.tileFor(lat + 0.5, lon + 0.5);
        if (tile != null) {
          try {
            await _ensureTileAvailable(tile, manifest);
          } catch (_) {
            // Préchargement opportuniste : on ignore les tuiles indisponibles.
          }
        }
      }
    }
    await _pruneCacheIfNeeded(manifest.maxCacheBytes);
  }

  /// Taille actuelle du cache DEM, en octets.
  Future<int> cacheSizeBytes() async {
    final dir = await _cacheDirectory();
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  /// Vide le cache DEM local.
  Future<void> clearCache() async {
    final dir = await _cacheDirectory();
    if (await dir.exists()) await dir.delete(recursive: true);
    _memoryTileCache.clear();
  }

  Future<_DemManifest> _loadManifest() {
    return _manifestFuture ??= _readManifest();
  }

  Future<_DemManifest> _readManifest() async {
    try {
      final raw = await rootBundle.loadString(_manifestPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return _DemManifest.fromJson(json);
    } catch (_) {
      return const _DemManifest();
    }
  }

  Future<_DemTileData> _loadTileWithCache(
    _DemTile tile,
    _DemManifest manifest,
  ) async {
    final bytes = await _ensureTileAvailable(tile, manifest);
    return _DemTileData(tile: tile, bytes: bytes.buffer.asByteData());
  }

  Future<Uint8List> _ensureTileAvailable(
    _DemTile tile,
    _DemManifest manifest,
  ) async {
    final cached = await _cachedTileFile(tile);
    if (await cached.exists()) {
      await cached.setLastModified(DateTime.now());
      return cached.readAsBytes();
    }

    if (tile.assetPath != null && tile.assetPath!.isNotEmpty) {
      try {
        final data = await rootBundle.load(tile.assetPath!);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await cached.create(recursive: true);
        await cached.writeAsBytes(bytes, flush: true);
        return bytes;
      } catch (_) {
        // On tente ensuite le téléchargement éventuel.
      }
    }

    if (manifest.downloadBaseUrl == null || manifest.downloadBaseUrl!.isEmpty) {
      throw StateError(
        'Tuile DEM absente et aucun serveur DEM configuré: ${tile.id}',
      );
    }

    final uri = manifest.downloadUriFor(tile.fileName);
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Téléchargement DEM impossible (${response.statusCode})',
        uri: uri,
      );
    }

    final bytes = response.bodyBytes;
    final expectedBytes = tile.width * tile.height * 4;
    if (bytes.lengthInBytes != expectedBytes) {
      throw FormatException(
        'Taille inattendue pour ${tile.id}: ${bytes.lengthInBytes} octets, attendu $expectedBytes',
      );
    }

    await cached.create(recursive: true);
    await cached.writeAsBytes(bytes, flush: true);
    await _pruneCacheIfNeeded(manifest.maxCacheBytes);
    return bytes;
  }

  Future<File> _cachedTileFile(_DemTile tile) async {
    final dir = await _cacheDirectory();
    return File(p.join(dir.path, tile.fileName));
  }

  Future<Directory> _cacheDirectory() async {
    return _cacheDirectoryFuture ??= () async {
      final base = await getApplicationSupportDirectory();
      final dir = Directory(p.join(base.path, 'dem_cache'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }();
  }

  Future<void> _pruneCacheIfNeeded(int maxCacheBytes) async {
    if (maxCacheBytes <= 0) return;
    final dir = await _cacheDirectory();
    if (!await dir.exists()) return;

    final files = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.f32')) {
        files.add(entity);
      }
    }

    var total = 0;
    final entries = <_CacheEntry>[];
    for (final file in files) {
      final stat = await file.stat();
      total += stat.size;
      entries.add(
        _CacheEntry(file: file, size: stat.size, touched: stat.modified),
      );
    }

    if (total <= maxCacheBytes) return;
    entries.sort((a, b) => a.touched.compareTo(b.touched));

    for (final entry in entries) {
      if (total <= maxCacheBytes) break;
      try {
        await entry.file.delete();
        total -= entry.size;
      } catch (_) {
        // Suppression best-effort.
      }
    }
  }
}

class _DemManifest {
  const _DemManifest({
    this.tiles = const [],
    this.downloadBaseUrl,
    this.width = ElevationService._defaultWidth,
    this.height = ElevationService._defaultHeight,
    this.nodata = ElevationService._defaultNoData,
    this.maxCacheBytes = ElevationService._defaultMaxCacheBytes,
  });

  final List<_DemTile> tiles;
  final String? downloadBaseUrl;
  final int width;
  final int height;
  final double nodata;
  final int maxCacheBytes;

  factory _DemManifest.fromJson(Map<String, dynamic> json) {
    final width = ((json['tileWidth'] ??
            json['width'] ??
            ElevationService._defaultWidth) as num)
        .toInt();
    final height = ((json['tileHeight'] ??
            json['height'] ??
            ElevationService._defaultHeight) as num)
        .toInt();
    final nodata =
        ((json['nodata'] ?? ElevationService._defaultNoData) as num).toDouble();
    final maxCacheBytes = ((json['maxCacheBytes'] ??
            ElevationService._defaultMaxCacheBytes) as num)
        .toInt();
    final downloadBaseUrl = json['downloadBaseUrl']?.toString();

    final tilesRaw = (json['tiles'] as List<dynamic>? ?? const []);
    final tiles = tilesRaw
        .whereType<Map<String, dynamic>>()
        .map(
          (t) => _DemTile.fromJson(
            t,
            defaultWidth: width,
            defaultHeight: height,
            defaultNoData: nodata,
          ),
        )
        .where((t) => t.isValid)
        .toList(growable: false);

    return _DemManifest(
      tiles: tiles,
      downloadBaseUrl: downloadBaseUrl,
      width: width,
      height: height,
      nodata: nodata,
      maxCacheBytes: maxCacheBytes,
    );
  }

  _DemTile? tileFor(double latitude, double longitude) {
    for (final tile in tiles) {
      if (tile.contains(latitude, longitude)) return tile;
    }

    // Mode intelligent : si le manifest ne liste pas explicitement les tuiles,
    // on calcule l'id de la tuile 1° x 1° correspondant à la position.
    final south = latitude.floorToDouble();
    final west = longitude.floorToDouble();
    if (south < -90 || south >= 90 || west < -180 || west >= 180) return null;

    final id = _tileIdForSouthWest(south.toInt(), west.toInt());
    return _DemTile(
      id: id,
      assetPath: 'assets/dem/$id.f32',
      fileName: '$id.f32',
      minLat: south,
      maxLat: south + 1,
      minLon: west,
      maxLon: west + 1,
      width: width,
      height: height,
      nodata: nodata,
    );
  }

  Uri downloadUriFor(String fileName) {
    final base = downloadBaseUrl!;
    final normalized = base.endsWith('/') ? base : '$base/';
    return Uri.parse(normalized).resolve(fileName);
  }
}

class _DemTile {
  const _DemTile({
    required this.id,
    required this.assetPath,
    required this.fileName,
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
    required this.width,
    required this.height,
    required this.nodata,
  });

  final String id;
  final String? assetPath;
  final String fileName;
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;
  final int width;
  final int height;
  final double nodata;

  bool get isValid =>
      id.isNotEmpty &&
      fileName.isNotEmpty &&
      width > 1 &&
      height > 1 &&
      maxLat > minLat &&
      maxLon > minLon;

  bool contains(double lat, double lon) =>
      lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;

  factory _DemTile.fromJson(
    Map<String, dynamic> json, {
    required int defaultWidth,
    required int defaultHeight,
    required double defaultNoData,
  }) {
    double d(String k) => (json[k] as num).toDouble();
    int i(String k, int fallback) => ((json[k] ?? fallback) as num).toInt();
    final id = (json['id'] ?? '').toString();
    final path = (json['path'] ?? json['assetPath'])?.toString();
    final fileName =
        (json['file'] ?? json['fileName'] ?? p.basename(path ?? '$id.f32'))
            .toString();

    return _DemTile(
      id: id,
      assetPath: path,
      fileName: fileName,
      minLat: d('minLat'),
      maxLat: d('maxLat'),
      minLon: d('minLon'),
      maxLon: d('maxLon'),
      width: i('width', defaultWidth),
      height: i('height', defaultHeight),
      nodata: ((json['nodata'] ?? defaultNoData) as num).toDouble(),
    );
  }
}

class _DemTileData {
  const _DemTileData({required this.tile, required this.bytes});

  final _DemTile tile;
  final ByteData bytes;

  double? sampleBilinear({
    required double latitude,
    required double longitude,
  }) {
    if (!tile.contains(latitude, longitude)) return null;

    final x = (longitude - tile.minLon) /
        (tile.maxLon - tile.minLon) *
        (tile.width - 1);
    final y = (tile.maxLat - latitude) /
        (tile.maxLat - tile.minLat) *
        (tile.height - 1);

    final x0 = x.floor().clamp(0, tile.width - 1);
    final y0 = y.floor().clamp(0, tile.height - 1);
    final x1 = math.min(x0 + 1, tile.width - 1);
    final y1 = math.min(y0 + 1, tile.height - 1);

    final q11 = _valueAt(x0, y0);
    final q21 = _valueAt(x1, y0);
    final q12 = _valueAt(x0, y1);
    final q22 = _valueAt(x1, y1);

    final vals = [q11, q21, q12, q22].whereType<double>().toList();
    if (vals.isEmpty) return null;
    if (vals.length < 4) {
      return vals.reduce((a, b) => a + b) / vals.length;
    }

    final tx = x - x0;
    final ty = y - y0;
    final top = q11! * (1 - tx) + q21! * tx;
    final bottom = q12! * (1 - tx) + q22! * tx;
    return top * (1 - ty) + bottom * ty;
  }

  double? _valueAt(int x, int y) {
    final index = y * tile.width + x;
    final offset = index * 4;
    if (offset < 0 || offset + 4 > bytes.lengthInBytes) return null;
    final v = bytes.getFloat32(offset, Endian.little);
    if (!v.isFinite) return null;
    if ((v - tile.nodata).abs() < 0.001) return null;
    return v;
  }
}

class _CacheEntry {
  const _CacheEntry({
    required this.file,
    required this.size,
    required this.touched,
  });

  final File file;
  final int size;
  final DateTime touched;
}

String _tileIdForSouthWest(int south, int west) {
  final ns = south >= 0 ? 'N' : 'S';
  final ew = west >= 0 ? 'E' : 'W';
  final lat = south.abs().toString().padLeft(2, '0');
  final lon = west.abs().toString().padLeft(3, '0');
  return '$ns$lat$ew$lon';
}
