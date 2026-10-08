import 'dart:io';
import 'dart:math' as math;

import 'package:sqlite3/sqlite3.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _usage();
    return;
  }

  try {
    final values = _parseArgs(args);

    final sourcePath = _required(values, 'source');
    final outputPath = _required(values, 'output');
    final name = values['name']?.trim().isNotEmpty == true
        ? values['name']!.trim()
        : 'Zone extraite';

    final west = double.parse(_required(values, 'west'));
    final south = double.parse(_required(values, 'south'));
    final east = double.parse(_required(values, 'east'));
    final north = double.parse(_required(values, 'north'));

    final requestedMinZoom = int.parse(_required(values, 'min-zoom'));
    final requestedMaxZoom = int.parse(_required(values, 'max-zoom'));

    _validateBounds(west, south, east, north);
    if (requestedMinZoom < 0 || requestedMaxZoom < requestedMinZoom) {
      throw const FormatException('Plage de zoom invalide.');
    }

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('MBTiles source introuvable', sourcePath);
    }

    final outputFile = File(outputPath);
    if (await outputFile.exists()) {
      await outputFile.delete();
    }
    await outputFile.parent.create(recursive: true);

    final source = sqlite3.open(sourcePath, mode: OpenMode.readOnly);
    Database? destination;

    try {
      _requireStandardTilesTable(source);

      final sourceMetadata = _readMetadata(source);
      final sourceMinZoom = int.tryParse(sourceMetadata['minzoom'] ?? '');
      final sourceMaxZoom = int.tryParse(sourceMetadata['maxzoom'] ?? '');

      final minZoom = sourceMinZoom == null
          ? requestedMinZoom
          : math.max(requestedMinZoom, sourceMinZoom);
      final maxZoom = sourceMaxZoom == null
          ? requestedMaxZoom
          : math.min(requestedMaxZoom, sourceMaxZoom);

      if (minZoom > maxZoom) {
        throw StateError('Aucun zoom commun entre la demande et la source.');
      }

      destination = sqlite3.open(outputPath);
      _createDestination(destination);

      final insertTile = destination.prepare(
        'INSERT OR REPLACE INTO tiles '
        '(zoom_level, tile_column, tile_row, tile_data) '
        'VALUES (?, ?, ?, ?)',
      );

      var copiedTiles = 0;
      var copiedBytes = 0;

      destination.execute('BEGIN');
      try {
        for (var z = minZoom; z <= maxZoom; z++) {
          final range = _tileRange(
            west: west,
            south: south,
            east: east,
            north: north,
            zoom: z,
          );

          final minTmsRow = _xyzToTms(z, range.maxY);
          final maxTmsRow = _xyzToTms(z, range.minY);

          final rows = source.select(
            'SELECT zoom_level, tile_column, tile_row, tile_data '
            'FROM tiles '
            'WHERE zoom_level = ? '
            'AND tile_column BETWEEN ? AND ? '
            'AND tile_row BETWEEN ? AND ?',
            <Object?>[z, range.minX, range.maxX, minTmsRow, maxTmsRow],
          );

          for (final row in rows) {
            final data = row['tile_data'] as List<int>;
            insertTile.execute(<Object?>[
              row['zoom_level'],
              row['tile_column'],
              row['tile_row'],
              data,
            ]);
            copiedTiles++;
            copiedBytes += data.length;
          }

          stdout.writeln('Zoom $z : ${rows.length} tuile(s) copiée(s)');
        }

        _writeMetadata(
          destination,
          sourceMetadata: sourceMetadata,
          name: name,
          west: west,
          south: south,
          east: east,
          north: north,
          minZoom: minZoom,
          maxZoom: maxZoom,
        );

        destination.execute('COMMIT');
      } catch (_) {
        destination.execute('ROLLBACK');
        rethrow;
      } finally {
        insertTile.dispose();
      }

      destination.execute(
        'CREATE UNIQUE INDEX tile_index '
        'ON tiles (zoom_level, tile_column, tile_row)',
      );

      final size = await outputFile.length();
      stdout.writeln('');
      stdout.writeln('Extraction terminée.');
      stdout.writeln('Fichier : $outputPath');
      stdout.writeln('Tuiles : $copiedTiles');
      stdout.writeln(
        'Données copiées : ${(copiedBytes / 1048576).toStringAsFixed(1)} Mo',
      );
      stdout.writeln(
        'Taille MBTiles : ${(size / 1048576).toStringAsFixed(1)} Mo',
      );

      if (copiedTiles == 0) {
        stderr.writeln(
          'ATTENTION : aucune tuile trouvée dans cette emprise/plage de zoom.',
        );
        exitCode = 2;
      }
    } finally {
      destination?.dispose();
      source.dispose();
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

void _requireStandardTilesTable(Database db) {
  final rows = db.select(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='tiles'",
  );
  if (rows.isEmpty) {
    throw StateError(
      'La source ne contient pas de table MBTiles standard "tiles".',
    );
  }
}

Map<String, String> _readMetadata(Database db) {
  final result = <String, String>{};
  final hasMetadata = db.select(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='metadata'",
  );
  if (hasMetadata.isEmpty) return result;

  for (final row in db.select('SELECT name, value FROM metadata')) {
    result[row['name'].toString()] = row['value'].toString();
  }
  return result;
}

void _createDestination(Database db) {
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
  required Map<String, String> sourceMetadata,
  required String name,
  required double west,
  required double south,
  required double east,
  required double north,
  required int minZoom,
  required int maxZoom,
}) {
  final metadata = Map<String, String>.from(sourceMetadata);
  metadata['name'] = name;
  metadata['type'] = metadata['type'] ?? 'baselayer';
  metadata['version'] = metadata['version'] ?? '1.3';
  metadata['bounds'] = '$west,$south,$east,$north';
  metadata['center'] = '${(west + east) / 2},${(south + north) / 2},$minZoom';
  metadata['minzoom'] = '$minZoom';
  metadata['maxzoom'] = '$maxZoom';

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

int _lonToX(double longitude, int zoom) {
  final n = 1 << zoom;
  return (((longitude + 180.0) / 360.0) * n).floor();
}

int _latToY(double latitude, int zoom) {
  final clamped = latitude.clamp(-85.05112878, 85.05112878).toDouble();
  final latRad = clamped * math.pi / 180.0;
  final n = 1 << zoom;
  final tanLat = math.tan(latRad);
  final asinhTanLat = math.log(tanLat + math.sqrt(tanLat * tanLat + 1.0));
  return ((1.0 - asinhTanLat / math.pi) / 2.0 * n).floor();
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
  final values = <String, String>{};
  var index = 0;

  while (index < args.length) {
    final token = args[index];
    if (!token.startsWith('--')) {
      throw FormatException('Argument inattendu : $token');
    }
    if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
      throw FormatException('Valeur manquante pour $token');
    }
    values[token.substring(2)] = args[index + 1];
    index += 2;
  }

  return values;
}

String _required(Map<String, String> values, String key) {
  final value = values[key]?.trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Argument obligatoire manquant : --$key');
  }
  return value;
}

void _usage() {
  stdout.writeln(r'''
Usage :
  dart run tool/extract_mbtiles_zone.dart \
    --source "/chemin/source.mbtiles" \
    --output "$HOME/Desktop/canjuers.mbtiles" \
    --name "Canjuers - pilote" \
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
