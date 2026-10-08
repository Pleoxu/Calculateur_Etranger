import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:sqlite3/sqlite3.dart' as sqlite;

class _Bounds {
  const _Bounds(this.west, this.south, this.east, this.north);

  final double west;
  final double south;
  final double east;
  final double north;
}

class _DetailZone {
  const _DetailZone({
    required this.name,
    required this.bounds,
    required this.minZoom,
    required this.maxZoom,
  });

  final String name;
  final _Bounds bounds;
  final int minZoom;
  final int maxZoom;
}

class _TileCoord {
  const _TileCoord(this.z, this.x, this.y);

  final int z;
  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is _TileCoord && other.z == z && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(z, x, y);
}

class _Cli {
  _Cli(this.values, this.zones, this.flags);

  final Map<String, String> values;
  final List<String> zones;
  final Set<String> flags;
}

_Cli _parseArgs(List<String> args) {
  final values = <String, String>{};
  final zones = <String>[];
  final flags = <String>{};

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;

    final key = arg.substring(2);

    if (key == 'dry-run') {
      flags.add(key);
      continue;
    }

    if (i + 1 >= args.length || args[i + 1].startsWith('--')) {
      flags.add(key);
      continue;
    }

    final value = args[++i];
    if (key == 'zone') {
      zones.add(value);
    } else {
      values[key] = value;
    }
  }

  return _Cli(values, zones, flags);
}

double _d(Map<String, String> a, String key) =>
    double.parse(a[key] ?? (throw ArgumentError('Argument manquant --$key')));

int _i(Map<String, String> a, String key) =>
    int.parse(a[key] ?? (throw ArgumentError('Argument manquant --$key')));

String _s(Map<String, String> a, String key) =>
    a[key] ?? (throw ArgumentError('Argument manquant --$key'));

_DetailZone _parseZone(String raw) {
  // Format :
  // nom,west,south,east,north,minZoom,maxZoom
  final p = raw.split(',').map((e) => e.trim()).toList();
  if (p.length != 7) {
    throw ArgumentError(
      'Zone invalide "$raw". Format attendu : '
      'nom,west,south,east,north,minZoom,maxZoom',
    );
  }

  return _DetailZone(
    name: p[0],
    bounds: _Bounds(
      double.parse(p[1]),
      double.parse(p[2]),
      double.parse(p[3]),
      double.parse(p[4]),
    ),
    minZoom: int.parse(p[5]),
    maxZoom: int.parse(p[6]),
  );
}

int _lonToTileX(double lon, int z) {
  final n = 1 << z;
  return ((((lon + 180.0) / 360.0) * n).floor()).clamp(0, n - 1);
}

int _latToTileY(double lat, int z) {
  final n = 1 << z;
  final latRad = lat * math.pi / 180.0;
  final y =
      (1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
          2.0 *
          n;
  return y.floor().clamp(0, n - 1);
}

Iterable<_TileCoord> _tilesForBounds(
  _Bounds bounds,
  int minZoom,
  int maxZoom,
) sync* {
  for (var z = minZoom; z <= maxZoom; z++) {
    final x0 = _lonToTileX(bounds.west, z);
    final x1 = _lonToTileX(bounds.east, z);
    final y0 = _latToTileY(bounds.north, z);
    final y1 = _latToTileY(bounds.south, z);

    for (var x = math.min(x0, x1); x <= math.max(x0, x1); x++) {
      for (var y = math.min(y0, y1); y <= math.max(y0, y1); y++) {
        yield _TileCoord(z, x, y);
      }
    }
  }
}

Future<Uint8List> _download(http.Client client, _TileCoord tile) async {
  const hosts = <String>['a', 'b', 'c'];
  final host = hosts[(tile.x + tile.y + tile.z) % hosts.length];
  final uri = Uri.parse(
    'https://$host.tile.opentopomap.org/${tile.z}/${tile.x}/${tile.y}.png',
  );

  for (var attempt = 1; attempt <= 4; attempt++) {
    final response = await client.get(
      uri,
      headers: const <String, String>{
        'User-Agent': 'CalculateurTirNG-offline-pilot/3.0',
      },
    );

    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      return response.bodyBytes;
    }

    if (attempt == 4) {
      throw HttpException('HTTP ${response.statusCode} pour $uri', uri: uri);
    }

    await Future<void>.delayed(Duration(milliseconds: 900 * attempt));
  }

  throw StateError('Téléchargement impossible');
}

void _createSchema(sqlite.Database db) {
  db.execute('''
CREATE TABLE IF NOT EXISTS metadata (
  name TEXT,
  value TEXT
)
''');

  db.execute('''
CREATE TABLE IF NOT EXISTS tiles (
  zoom_level INTEGER,
  tile_column INTEGER,
  tile_row INTEGER,
  tile_data BLOB
)
''');

  db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS tile_index
ON tiles (zoom_level, tile_column, tile_row)
''');
}

void _putMetadata(sqlite.Database db, String name, String value) {
  db.execute('INSERT INTO metadata(name, value) VALUES (?, ?)', <Object?>[
    name,
    value,
  ]);
}

Future<void> main(List<String> argv) async {
  final cli = _parseArgs(argv);
  final a = cli.values;

  final output = _s(a, 'output');
  final name = a['name'] ?? 'Canjuers topo multizones';

  final base = _Bounds(
    _d(a, 'west'),
    _d(a, 'south'),
    _d(a, 'east'),
    _d(a, 'north'),
  );

  final baseMin = _i(a, 'min-zoom');
  final baseMax = _i(a, 'max-zoom');

  final details = cli.zones.map(_parseZone).toList();

  final tiles = <_TileCoord>{}..addAll(_tilesForBounds(base, baseMin, baseMax));

  for (final zone in details) {
    tiles.addAll(_tilesForBounds(zone.bounds, zone.minZoom, zone.maxZoom));
  }

  final ordered = tiles.toList()
    ..sort((a, b) {
      final z = a.z.compareTo(b.z);
      if (z != 0) return z;
      final x = a.x.compareTo(b.x);
      return x != 0 ? x : a.y.compareTo(b.y);
    });

  final allMinZooms = <int>[baseMin, ...details.map((e) => e.minZoom)];
  final allMaxZooms = <int>[baseMax, ...details.map((e) => e.maxZoom)];
  final minZ = allMinZooms.reduce(math.min);
  final maxZ = allMaxZooms.reduce(math.max);

  stdout.writeln('=== PLAN DE COUVERTURE ===');
  stdout.writeln('Base : z$baseMin -> z$baseMax');
  for (final zone in details) {
    stdout.writeln(
      '${zone.name} : z${zone.minZoom} -> z${zone.maxZoom} '
      '[${zone.bounds.west}, ${zone.bounds.south}, '
      '${zone.bounds.east}, ${zone.bounds.north}]',
    );
  }

  stdout.writeln('');
  stdout.writeln('Tuiles uniques : ${ordered.length}');
  for (var z = minZ; z <= maxZ; z++) {
    final count = ordered.where((t) => t.z == z).length;
    if (count > 0) stdout.writeln('z$z : $count');
  }

  if (cli.flags.contains('dry-run')) {
    stdout.writeln('');
    stdout.writeln('DRY-RUN : aucun téléchargement effectué.');
    return;
  }

  final file = File(output);
  if (await file.exists()) await file.delete();
  await file.parent.create(recursive: true);

  final db = sqlite.sqlite3.open(output);
  _createSchema(db);

  _putMetadata(db, 'name', name);
  _putMetadata(db, 'type', 'baselayer');
  _putMetadata(db, 'version', '1');
  _putMetadata(db, 'format', 'png');
  _putMetadata(db, 'minzoom', '$minZ');
  _putMetadata(db, 'maxzoom', '$maxZ');
  _putMetadata(
    db,
    'bounds',
    '${base.west},${base.south},${base.east},${base.north}',
  );
  _putMetadata(
    db,
    'attribution',
    'Kartendaten: © OpenStreetMap-Mitwirkende, SRTM | '
        'Kartendarstellung: © OpenTopoMap (CC-BY-SA)',
  );

  final client = http.Client();
  var done = 0;
  var bytes = 0;

  try {
    for (final tile in ordered) {
      final data = await _download(client, tile);
      bytes += data.length;

      // MBTiles utilise TMS : Y inversé par rapport à XYZ.
      final tmsY = ((1 << tile.z) - 1) - tile.y;

      db.execute(
        'INSERT OR REPLACE INTO tiles '
        '(zoom_level, tile_column, tile_row, tile_data) '
        'VALUES (?, ?, ?, ?)',
        <Object?>[tile.z, tile.x, tmsY, data],
      );

      done++;
      if (done % 50 == 0 || done == ordered.length) {
        stdout.writeln(
          '$done/${ordered.length} • '
          '${(bytes / 1024 / 1024).toStringAsFixed(1)} Mo téléchargés',
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
  } finally {
    client.close();
    db.dispose();
  }

  final size = await file.length();
  stdout.writeln('');
  stdout.writeln('Terminé : $output');
  stdout.writeln(
    'Taille MBTiles : ${(size / 1024 / 1024).toStringAsFixed(1)} Mo',
  );
}
