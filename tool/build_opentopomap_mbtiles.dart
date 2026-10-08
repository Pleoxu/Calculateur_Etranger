import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) async {
  final options = _parseArgs(args);

  final output = options['output'];
  final name = options['name'] ?? 'OpenTopoMap zone';
  final west = double.tryParse(options['west'] ?? '');
  final south = double.tryParse(options['south'] ?? '');
  final east = double.tryParse(options['east'] ?? '');
  final north = double.tryParse(options['north'] ?? '');
  final minZoom = int.tryParse(options['min-zoom'] ?? '');
  final maxZoom = int.tryParse(options['max-zoom'] ?? '');

  if (output == null ||
      west == null ||
      south == null ||
      east == null ||
      north == null ||
      minZoom == null ||
      maxZoom == null) {
    _usage();
    exitCode = 64;
    return;
  }

  if (west >= east || south >= north) {
    stderr.writeln('Emprise invalide.');
    exitCode = 64;
    return;
  }

  if (minZoom < 0 || maxZoom < minZoom || maxZoom > 17) {
    stderr.writeln('Zoom invalide. Utiliser 0 <= min <= max <= 17.');
    exitCode = 64;
    return;
  }

  final jobs = <_TileJob>[];
  for (var z = minZoom; z <= maxZoom; z++) {
    final xMin = _lonToX(west, z);
    final xMax = _lonToX(east, z);
    final yMin = _latToY(north, z);
    final yMax = _latToY(south, z);

    final count = (xMax - xMin + 1) * (yMax - yMin + 1);
    stdout.writeln('Zoom $z : $count tuile(s)');

    for (var x = xMin; x <= xMax; x++) {
      for (var y = yMin; y <= yMax; y++) {
        jobs.add(_TileJob(z: z, x: x, y: y));
      }
    }
  }

  const maxTiles = 2000;
  if (jobs.length > maxTiles) {
    stderr.writeln(
      'Zone trop grande pour cet outil pilote : ${jobs.length} tuiles '
      '(maximum $maxTiles). Réduire l’emprise ou les zooms.',
    );
    exitCode = 64;
    return;
  }

  final file = File(output);
  if (await file.exists()) {
    await file.delete();
  }
  await file.parent.create(recursive: true);

  final db = sqlite3.open(file.path);
  try {
    db.execute('''
      PRAGMA journal_mode = OFF;
      PRAGMA synchronous = OFF;

      CREATE TABLE metadata (
        name TEXT PRIMARY KEY,
        value TEXT
      );

      CREATE TABLE tiles (
        zoom_level INTEGER,
        tile_column INTEGER,
        tile_row INTEGER,
        tile_data BLOB,
        UNIQUE(zoom_level, tile_column, tile_row)
      );

      CREATE UNIQUE INDEX tile_index
      ON tiles (zoom_level, tile_column, tile_row);
    ''');

    final centerLon = (west + east) / 2.0;
    final centerLat = (south + north) / 2.0;
    final centerZoom = math.min(maxZoom, math.max(minZoom, 14));

    final metadata = <String, String>{
      'name': name,
      'type': 'baselayer',
      'version': '1.0',
      'description': 'OpenTopoMap raster tiles - pilot offline zone',
      'format': 'png',
      'bounds': '$west,$south,$east,$north',
      'center': '$centerLon,$centerLat,$centerZoom',
      'minzoom': '$minZoom',
      'maxzoom': '$maxZoom',
      'attribution': 'Kartendaten: © OpenStreetMap-Mitwirkende, SRTM | '
          'Kartendarstellung: © OpenTopoMap (CC-BY-SA)',
    };

    final insertMetadata = db.prepare(
      'INSERT INTO metadata(name, value) VALUES(?, ?)',
    );
    try {
      for (final entry in metadata.entries) {
        insertMetadata.execute([entry.key, entry.value]);
      }
    } finally {
      insertMetadata.dispose();
    }

    final insertTile = db.prepare('''
      INSERT OR REPLACE INTO tiles(
        zoom_level,
        tile_column,
        tile_row,
        tile_data
      ) VALUES (?, ?, ?, ?)
    ''');

    final client = http.Client();

    try {
      var done = 0;
      var bytes = 0;

      db.execute('BEGIN');

      for (final job in jobs) {
        final bytesTile = await _downloadTile(client, job);

        final tmsY = ((1 << job.z) - 1) - job.y;

        insertTile.execute([job.z, job.x, tmsY, bytesTile]);

        done++;
        bytes += bytesTile.length;

        if (done % 25 == 0 || done == jobs.length) {
          final pct = jobs.isEmpty ? 100.0 : done * 100.0 / jobs.length;
          stdout.writeln(
            '${pct.toStringAsFixed(1)} % — $done/${jobs.length} '
            '— ${(bytes / 1024 / 1024).toStringAsFixed(1)} Mo',
          );
        }

        // Reste volontairement lent : cet outil est prévu pour une petite
        // emprise de démonstration, pas pour de l’aspiration massive.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      db.execute('COMMIT');
    } catch (_) {
      try {
        db.execute('ROLLBACK');
      } catch (_) {}
      rethrow;
    } finally {
      client.close();
      insertTile.dispose();
    }
  } finally {
    db.dispose();
  }

  stdout.writeln('');
  stdout.writeln('MBTiles créé : ${file.path}');
  stdout.writeln('Tuiles : ${jobs.length}');
  stdout.writeln(
    'Taille : ${(await file.length() / 1024 / 1024).toStringAsFixed(1)} Mo',
  );
}

Future<List<int>> _downloadTile(http.Client client, _TileJob job) async {
  final hosts = ['a', 'b', 'c'];

  Object? lastError;

  for (var attempt = 0; attempt < 3; attempt++) {
    final host = hosts[(job.x + job.y + attempt) % hosts.length];
    final uri = Uri.parse(
      'https://$host.tile.opentopomap.org/'
      '${job.z}/${job.x}/${job.y}.png',
    );

    try {
      final response = await client.get(
        uri,
        headers: const {
          'User-Agent': 'CalculateurTirOfflineDemo/1.0 '
              '(small offline pilot zone; contact: local-demo)',
          'Accept': 'image/png,image/*;q=0.8,*/*;q=0.5',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 &&
          response.bodyBytes.length >= 8 &&
          response.bodyBytes[0] == 0x89 &&
          response.bodyBytes[1] == 0x50 &&
          response.bodyBytes[2] == 0x4E &&
          response.bodyBytes[3] == 0x47) {
        return response.bodyBytes;
      }

      lastError = HttpException(
        'HTTP ${response.statusCode} pour $uri',
        uri: uri,
      );
    } catch (e) {
      lastError = e;
    }

    await Future<void>.delayed(Duration(milliseconds: 700 * (attempt + 1)));
  }

  throw StateError(
    'Échec téléchargement z=${job.z} x=${job.x} y=${job.y} : $lastError',
  );
}

int _lonToX(double lon, int z) {
  final n = 1 << z;
  return (((lon + 180.0) / 360.0) * n).floor().clamp(0, n - 1).toInt();
}

int _latToY(double lat, int z) {
  final n = 1 << z;
  final clamped = lat.clamp(-85.05112878, 85.05112878).toDouble();
  final rad = clamped * math.pi / 180.0;
  final mercator = math.log(math.tan(math.pi / 4.0 + rad / 2.0));
  return (((1.0 - mercator / math.pi) / 2.0) * n)
      .floor()
      .clamp(0, n - 1)
      .toInt();
}

Map<String, String> _parseArgs(List<String> args) {
  final result = <String, String>{};

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;

    final key = arg.substring(2);
    if (i + 1 >= args.length) continue;

    final value = args[i + 1];
    if (value.startsWith('--')) continue;

    result[key] = value;
    i++;
  }

  return result;
}

void _usage() {
  stdout.writeln('''
Usage:
  dart run tool/build_opentopomap_mbtiles.dart \\
    --output "/chemin/zone.mbtiles" \\
    --name "Nom de zone" \\
    --west 6.407 \\
    --south 43.601 \\
    --east 6.531 \\
    --north 43.692 \\
    --min-zoom 11 \\
    --max-zoom 16
''');
}

class _TileJob {
  const _TileJob({required this.z, required this.x, required this.y});

  final int z;
  final int x;
  final int y;
}
