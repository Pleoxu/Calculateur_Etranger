import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:sqlite3/sqlite3.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _usage();
    return;
  }

  try {
    final a = _parseArgs(args);

    final demPath = _required(a, 'dem');
    final outputPath = _required(a, 'output');
    final name =
        a['name']?.trim().isNotEmpty == true ? a['name']!.trim() : 'Zone DEM';

    final tileWest = double.parse(_required(a, 'tile-west'));
    final tileSouth = double.parse(_required(a, 'tile-south'));
    final tileEast = double.parse(_required(a, 'tile-east'));
    final tileNorth = double.parse(_required(a, 'tile-north'));

    final west = double.parse(_required(a, 'west'));
    final south = double.parse(_required(a, 'south'));
    final east = double.parse(_required(a, 'east'));
    final north = double.parse(_required(a, 'north'));

    final minZoom = int.parse(_required(a, 'min-zoom'));
    final maxZoom = int.parse(_required(a, 'max-zoom'));

    _validateBounds(west, south, east, north);
    _validateBounds(tileWest, tileSouth, tileEast, tileNorth);

    if (west < tileWest ||
        east > tileEast ||
        south < tileSouth ||
        north > tileNorth) {
      throw const FormatException(
        'L’emprise demandée dépasse la tuile DEM fournie.',
      );
    }

    if (minZoom < 0 || maxZoom < minZoom || maxZoom > 22) {
      throw const FormatException('Plage de zoom invalide.');
    }

    final demFile = File(demPath);
    if (!await demFile.exists()) {
      throw FileSystemException('DEM introuvable', demPath);
    }

    const width = 3600;
    const height = 3600;
    const expectedBytes = width * height * 4;

    final raw = await demFile.readAsBytes();
    if (raw.lengthInBytes != expectedBytes) {
      throw StateError(
        'Taille DEM inattendue : ${raw.lengthInBytes} octets. '
        'Attendu : $expectedBytes octets pour 3600x3600 Float32.',
      );
    }

    final elevations = raw.buffer.asFloat32List(
      raw.offsetInBytes,
      width * height,
    );

    final stats = _scanStats(
      elevations,
      width: width,
      height: height,
      tileWest: tileWest,
      tileSouth: tileSouth,
      tileEast: tileEast,
      tileNorth: tileNorth,
      west: west,
      south: south,
      east: east,
      north: north,
    );

    stdout.writeln(
      'Altitude zone : ${stats.min.toStringAsFixed(0)} à '
      '${stats.max.toStringAsFixed(0)} m',
    );

    final output = File(outputPath);
    if (await output.exists()) {
      await output.delete();
    }
    await output.parent.create(recursive: true);

    final db = sqlite3.open(outputPath);

    try {
      _createMbtiles(db);

      final insert = db.prepare(
        'INSERT OR REPLACE INTO tiles '
        '(zoom_level, tile_column, tile_row, tile_data) '
        'VALUES (?, ?, ?, ?)',
      );

      var totalTiles = 0;
      var totalBytes = 0;

      db.execute('BEGIN');

      try {
        for (var z = minZoom; z <= maxZoom; z++) {
          final range = _tileRange(
            west: west,
            south: south,
            east: east,
            north: north,
            zoom: z,
          );

          var countAtZoom = 0;

          for (var x = range.minX; x <= range.maxX; x++) {
            for (var y = range.minY; y <= range.maxY; y++) {
              final png = _renderTile(
                elevations: elevations,
                demWidth: width,
                demHeight: height,
                tileWest: tileWest,
                tileSouth: tileSouth,
                tileEast: tileEast,
                tileNorth: tileNorth,
                z: z,
                x: x,
                y: y,
                minElevation: stats.min,
                maxElevation: stats.max,
                zoneWest: west,
                zoneSouth: south,
                zoneEast: east,
                zoneNorth: north,
              );

              insert.execute(<Object?>[z, x, _xyzToTms(z, y), png]);

              totalTiles++;
              countAtZoom++;
              totalBytes += png.length;
            }
          }

          stdout.writeln('Zoom $z : $countAtZoom tuile(s)');
        }

        _writeMetadata(
          db,
          name: name,
          west: west,
          south: south,
          east: east,
          north: north,
          minZoom: minZoom,
          maxZoom: maxZoom,
        );

        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      } finally {
        insert.dispose();
      }

      db.execute(
        'CREATE UNIQUE INDEX tile_index '
        'ON tiles (zoom_level, tile_column, tile_row)',
      );

      final fileBytes = await output.length();

      stdout.writeln('');
      stdout.writeln('MBTiles créé : $outputPath');
      stdout.writeln('Tuiles : $totalTiles');
      stdout.writeln(
        'PNG cumulés : ${(totalBytes / 1048576).toStringAsFixed(1)} Mo',
      );
      stdout.writeln(
        'Fichier final : ${(fileBytes / 1048576).toStringAsFixed(1)} Mo',
      );
    } finally {
      db.dispose();
    }
  } on FormatException catch (e) {
    stderr.writeln('Erreur : ${e.message}');
    _usage();
    exitCode = 64;
  } catch (e, st) {
    stderr.writeln('Erreur : $e');
    stderr.writeln(st);
    exitCode = 1;
  }
}

Uint8List _renderTile({
  required Float32List elevations,
  required int demWidth,
  required int demHeight,
  required double tileWest,
  required double tileSouth,
  required double tileEast,
  required double tileNorth,
  required int z,
  required int x,
  required int y,
  required double minElevation,
  required double maxElevation,
  required double zoneWest,
  required double zoneSouth,
  required double zoneEast,
  required double zoneNorth,
}) {
  const size = 256;
  final image = img.Image(width: size, height: size);

  final tileBounds = _xyzBounds(z, x, y);
  final span = math.max(1.0, maxElevation - minElevation);

  for (var py = 0; py < size; py++) {
    final fy = (py + 0.5) / size;
    final lat = tileBounds.north + (tileBounds.south - tileBounds.north) * fy;

    for (var px = 0; px < size; px++) {
      final fx = (px + 0.5) / size;
      final lon = tileBounds.west + (tileBounds.east - tileBounds.west) * fx;

      // Ne jamais étirer les bords du DEM sur les parties d'une tuile XYZ
      // qui se trouvent hors de la zone préparée. C'était la cause des
      // grandes bandes horizontales/verticales visibles aux faibles zooms.
      if (lon < zoneWest ||
          lon > zoneEast ||
          lat < zoneSouth ||
          lat > zoneNorth ||
          lon < tileWest ||
          lon > tileEast ||
          lat < tileSouth ||
          lat > tileNorth) {
        image.setPixelRgba(px, py, 228, 228, 228, 255);
        continue;
      }

      final e = _sampleDem(
        elevations,
        demWidth,
        demHeight,
        tileWest,
        tileSouth,
        tileEast,
        tileNorth,
        lon,
        lat,
      );

      final normalized = ((e - minElevation) / span).clamp(0.0, 1.0);

      // Relief plus lisible : hypsométrie grise douce + ombrage simple
      // calculé à partir de deux échantillons voisins dans le DEM.
      const deltaDeg = 1.0 / 3600.0;
      final eEast = _sampleDem(
        elevations,
        demWidth,
        demHeight,
        tileWest,
        tileSouth,
        tileEast,
        tileNorth,
        math.min(tileEast, lon + deltaDeg),
        lat,
      );
      final eSouth = _sampleDem(
        elevations,
        demWidth,
        demHeight,
        tileWest,
        tileSouth,
        tileEast,
        tileNorth,
        lon,
        math.max(tileSouth, lat - deltaDeg),
      );

      final dzdx = eEast - e;
      final dzdy = eSouth - e;
      final shade = ((-dzdx * 0.9) + (dzdy * 0.7)).clamp(-18.0, 18.0);

      var gray = (82 + normalized * 128 + shade).round().clamp(45, 225);

      // Courbes maîtresses 100 m plus nettes, intermédiaires 50 m discrètes.
      final contour50 = (e / 50.0).round() * 50.0;
      final contour100 = (e / 100.0).round() * 100.0;
      if ((e - contour100).abs() < 1.25) {
        gray = math.max(28, gray - 48);
      } else if ((e - contour50).abs() < 0.8) {
        gray = math.max(38, gray - 28);
      }

      image.setPixelRgba(px, py, gray, gray, gray, 255);
    }
  }

  return Uint8List.fromList(img.encodePng(image, level: 6));
}

double _sampleDem(
  Float32List data,
  int width,
  int height,
  double west,
  double south,
  double east,
  double north,
  double lon,
  double lat,
) {
  final u = ((lon - west) / (east - west)).clamp(0.0, 1.0);
  final v = ((north - lat) / (north - south)).clamp(0.0, 1.0);

  final x = u * (width - 1);
  final y = v * (height - 1);

  final x0 = x.floor();
  final y0 = y.floor();
  final x1 = math.min(width - 1, x0 + 1);
  final y1 = math.min(height - 1, y0 + 1);

  final tx = x - x0;
  final ty = y - y0;

  double valid(double value) {
    if (!value.isFinite || value <= -32000) return 0;
    return value;
  }

  final a = valid(data[y0 * width + x0]);
  final b = valid(data[y0 * width + x1]);
  final c = valid(data[y1 * width + x0]);
  final d = valid(data[y1 * width + x1]);

  final top = a + (b - a) * tx;
  final bottom = c + (d - c) * tx;
  return top + (bottom - top) * ty;
}

_Stats _scanStats(
  Float32List data, {
  required int width,
  required int height,
  required double tileWest,
  required double tileSouth,
  required double tileEast,
  required double tileNorth,
  required double west,
  required double south,
  required double east,
  required double north,
}) {
  var minE = double.infinity;
  var maxE = double.negativeInfinity;

  const samples = 220;

  for (var iy = 0; iy <= samples; iy++) {
    final lat = north + (south - north) * (iy / samples);

    for (var ix = 0; ix <= samples; ix++) {
      final lon = west + (east - west) * (ix / samples);

      final value = _sampleDem(
        data,
        width,
        height,
        tileWest,
        tileSouth,
        tileEast,
        tileNorth,
        lon,
        lat,
      );

      if (value > -32000 && value.isFinite) {
        minE = math.min(minE, value);
        maxE = math.max(maxE, value);
      }
    }
  }

  if (!minE.isFinite || !maxE.isFinite) {
    return const _Stats(0, 1000);
  }

  return _Stats(minE, maxE);
}

void _createMbtiles(Database db) {
  db.execute('''
CREATE TABLE metadata (
  name TEXT NOT NULL,
  value TEXT NOT NULL,
  UNIQUE(name)
)
''');

  db.execute('''
CREATE TABLE tiles (
  zoom_level INTEGER NOT NULL,
  tile_column INTEGER NOT NULL,
  tile_row INTEGER NOT NULL,
  tile_data BLOB NOT NULL
)
''');
}

void _writeMetadata(
  Database db, {
  required String name,
  required double west,
  required double south,
  required double east,
  required double north,
  required int minZoom,
  required int maxZoom,
}) {
  final metadata = <String, String>{
    'name': name,
    'type': 'baselayer',
    'version': '1.3',
    'description': 'Fond de relief généré localement depuis DEM Float32.',
    'format': 'png',
    'bounds': '$west,$south,$east,$north',
    'center': '${(west + east) / 2},${(south + north) / 2},'
        '${math.min(maxZoom, math.max(minZoom, 12))}',
    'minzoom': '$minZoom',
    'maxzoom': '$maxZoom',
  };

  final statement = db.prepare(
    'INSERT OR REPLACE INTO metadata (name, value) VALUES (?, ?)',
  );

  try {
    for (final entry in metadata.entries) {
      statement.execute(<Object?>[entry.key, entry.value]);
    }
  } finally {
    statement.dispose();
  }
}

_TileRange _tileRange({
  required double west,
  required double south,
  required double east,
  required double north,
  required int zoom,
}) {
  final n = 1 << zoom;

  final minX = _lonToX(west, zoom).clamp(0, n - 1);
  final maxX = _lonToX(east, zoom).clamp(0, n - 1);
  final minY = _latToY(north, zoom).clamp(0, n - 1);
  final maxY = _latToY(south, zoom).clamp(0, n - 1);

  return _TileRange(
    minX: math.min(minX, maxX),
    maxX: math.max(minX, maxX),
    minY: math.min(minY, maxY),
    maxY: math.max(minY, maxY),
  );
}

_GeoBounds _xyzBounds(int z, int x, int y) {
  return _GeoBounds(
    west: _xToLon(x, z),
    east: _xToLon(x + 1, z),
    north: _yToLat(y, z),
    south: _yToLat(y + 1, z),
  );
}

int _lonToX(double longitude, int zoom) {
  final n = 1 << zoom;
  return (((longitude + 180.0) / 360.0) * n).floor();
}

int _latToY(double latitude, int zoom) {
  final lat = latitude.clamp(-85.05112878, 85.05112878).toDouble();
  final radians = lat * math.pi / 180.0;
  final n = 1 << zoom;
  final tanLat = math.tan(radians);
  final asinhTanLat = math.log(tanLat + math.sqrt(tanLat * tanLat + 1.0));

  return ((1.0 - asinhTanLat / math.pi) / 2.0 * n).floor();
}

double _xToLon(int x, int z) {
  final n = 1 << z;
  return x / n * 360.0 - 180.0;
}

double _yToLat(int y, int z) {
  final n = 1 << z;
  final value = math.pi * (1.0 - 2.0 * y / n);
  return 180.0 /
      math.pi *
      math.atan(0.5 * (math.exp(value) - math.exp(-value)));
}

int _xyzToTms(int zoom, int xyzY) {
  return (1 << zoom) - 1 - xyzY;
}

void _validateBounds(double west, double south, double east, double north) {
  if (!west.isFinite ||
      !south.isFinite ||
      !east.isFinite ||
      !north.isFinite ||
      west < -180 ||
      east > 180 ||
      south < -85.05112878 ||
      north > 85.05112878 ||
      west >= east ||
      south >= north) {
    throw const FormatException('Emprise géographique invalide.');
  }
}

Map<String, String> _parseArgs(List<String> args) {
  final result = <String, String>{};

  var i = 0;
  while (i < args.length) {
    final token = args[i];

    if (!token.startsWith('--')) {
      throw FormatException('Argument inattendu : $token');
    }
    if (i + 1 >= args.length || args[i + 1].startsWith('--')) {
      throw FormatException('Valeur manquante pour $token');
    }

    result[token.substring(2)] = args[i + 1];
    i += 2;
  }

  return result;
}

String _required(Map<String, String> args, String key) {
  final value = args[key]?.trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Argument obligatoire manquant : --$key');
  }
  return value;
}

void _usage() {
  stdout.writeln(r'''
Création d'un MBTiles de relief entièrement hors ligne depuis un DEM .f32.

Exemple Canjuers :

  dart run tool/build_dem_mbtiles.dart \
    --dem assets/dem/N43E006.f32 \
    --output "$HOME/Desktop/canjuers.mbtiles" \
    --name "Canjuers - pilote" \
    --tile-west 6 \
    --tile-south 43 \
    --tile-east 7 \
    --tile-north 44 \
    --west 6.407 \
    --south 43.601 \
    --east 6.531 \
    --north 43.692 \
    --min-zoom 8 \
    --max-zoom 15
''');
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

class _GeoBounds {
  const _GeoBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  final double west;
  final double south;
  final double east;
  final double north;
}

class _Stats {
  const _Stats(this.min, this.max);

  final double min;
  final double max;
}
