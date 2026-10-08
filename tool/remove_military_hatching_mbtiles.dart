import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final options = _parseArgs(args);

  final sourcePath = options['source'];
  final outputPath = options['output'];

  if (sourcePath == null || outputPath == null) {
    _usage();
    exitCode = 64;
    return;
  }

  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('MBTiles source introuvable : $sourcePath');
    exitCode = 66;
    return;
  }

  final outputFile = File(outputPath);
  if (outputFile.existsSync()) {
    outputFile.deleteSync();
  }
  outputFile.parent.createSync(recursive: true);

  final src = sqlite3.open(sourceFile.path, mode: OpenMode.readOnly);
  final dst = sqlite3.open(outputFile.path);

  try {
    dst.execute('''
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

    final metadataRows = src.select('SELECT name, value FROM metadata');
    final insertMetadata = dst.prepare(
      'INSERT INTO metadata(name, value) VALUES(?, ?)',
    );

    try {
      for (final row in metadataRows) {
        var value = row['value']?.toString() ?? '';
        final name = row['name']?.toString() ?? '';

        if (name == 'name' && value.trim().isNotEmpty) {
          value = '$value - V2 sans hachures';
        }
        if (name == 'description') {
          value = '$value | post-traitement local : hachures rouges atténuées';
        }

        insertMetadata.execute([name, value]);
      }
    } finally {
      insertMetadata.dispose();
    }

    final total =
        src.select('SELECT COUNT(*) AS n FROM tiles').first['n'] as int;
    stdout.writeln('Tuiles à traiter : $total');

    final rows = src.select('''
      SELECT zoom_level, tile_column, tile_row, tile_data
      FROM tiles
      ORDER BY zoom_level, tile_column, tile_row
    ''');

    final insertTile = dst.prepare('''
      INSERT INTO tiles(
        zoom_level,
        tile_column,
        tile_row,
        tile_data
      ) VALUES (?, ?, ?, ?)
    ''');

    var done = 0;
    var changedTiles = 0;
    var changedPixels = 0;

    dst.execute('BEGIN');

    try {
      for (final row in rows) {
        final bytes = row['tile_data'] as Uint8List;
        final result = _removeDiagonalRedHatching(bytes);

        if (result.changedPixels > 0) {
          changedTiles++;
          changedPixels += result.changedPixels;
        }

        insertTile.execute([
          row['zoom_level'],
          row['tile_column'],
          row['tile_row'],
          result.bytes,
        ]);

        done++;

        if (done % 25 == 0 || done == total) {
          final pct = total == 0 ? 100.0 : done * 100.0 / total;
          stdout.writeln(
            '${pct.toStringAsFixed(1)} % — $done/$total '
            '— tuiles modifiées $changedTiles',
          );
        }
      }

      dst.execute('COMMIT');
    } catch (_) {
      try {
        dst.execute('ROLLBACK');
      } catch (_) {}
      rethrow;
    } finally {
      insertTile.dispose();
    }

    stdout.writeln('');
    stdout.writeln('MBTiles V2 créé : ${outputFile.path}');
    stdout.writeln('Tuiles modifiées : $changedTiles / $total');
    stdout.writeln('Pixels de hachures remplacés : $changedPixels');
    stdout.writeln(
      'Taille : ${(outputFile.lengthSync() / 1024 / 1024).toStringAsFixed(1)} Mo',
    );
  } finally {
    src.dispose();
    dst.dispose();
  }
}

_HatchResult _removeDiagonalRedHatching(Uint8List pngBytes) {
  final image = img.decodePng(pngBytes);
  if (image == null) {
    return _HatchResult(bytes: pngBytes, changedPixels: 0);
  }

  final width = image.width;
  final height = image.height;

  final mask = List<bool>.filled(width * height, false);
  var candidates = 0;

  bool isCandidate(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return false;

    final p = image.getPixel(x, y);
    final r = p.r.toInt();
    final g = p.g.toInt();
    final b = p.b.toInt();

    // Teinte typique des hachures militaires visibles dans OpenTopoMap :
    // rouge/saumon clair, nettement plus rouge que vert/bleu.
    //
    // Le seuil est volontairement étroit pour éviter autant que possible
    // les courbes de niveau brun/orange et les autres éléments cartographiques.
    return r >= 205 &&
        g >= 90 &&
        g <= 205 &&
        b >= 90 &&
        b <= 205 &&
        r - g >= 35 &&
        r - b >= 35 &&
        (g - b).abs() <= 45;
  }

  // Première passe : couleur + continuité diagonale "/".
  //
  // Une hachure doit avoir une continuité diagonale locale sur plusieurs
  // pixels. Cela évite de supprimer tous les éléments rouges de la carte.
  for (var y = 2; y < height - 2; y++) {
    for (var x = 2; x < width - 2; x++) {
      if (!isCandidate(x, y)) continue;

      final diag1 = isCandidate(x - 1, y + 1) || isCandidate(x + 1, y - 1);
      final diag2 = isCandidate(x - 2, y + 2) || isCandidate(x + 2, y - 2);

      if (diag1 && diag2) {
        mask[y * width + x] = true;
        candidates++;
      }
    }
  }

  if (candidates == 0) {
    return _HatchResult(bytes: pngBytes, changedPixels: 0);
  }

  // Élargit légèrement le masque pour prendre toute l'épaisseur du trait.
  final expanded = List<bool>.from(mask);
  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      if (!mask[y * width + x]) continue;

      for (var oy = -1; oy <= 1; oy++) {
        for (var ox = -1; ox <= 1; ox++) {
          final nx = x + ox;
          final ny = y + oy;

          // Ne dilater que sur des pixels encore rouge/saumon.
          if (isCandidate(nx, ny)) {
            expanded[ny * width + nx] = true;
          }
        }
      }
    }
  }

  final original = img.Image.from(image);
  var changed = 0;

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (!expanded[y * width + x]) continue;

      final replacement = _backgroundEstimate(
        original,
        expanded,
        width,
        height,
        x,
        y,
      );

      if (replacement == null) continue;

      image.setPixelRgba(
        x,
        y,
        replacement.$1,
        replacement.$2,
        replacement.$3,
        replacement.$4,
      );
      changed++;
    }
  }

  if (changed == 0) {
    return _HatchResult(bytes: pngBytes, changedPixels: 0);
  }

  final encoded = Uint8List.fromList(img.encodePng(image, level: 6));
  return _HatchResult(bytes: encoded, changedPixels: changed);
}

(int, int, int, int)? _backgroundEstimate(
  img.Image image,
  List<bool> mask,
  int width,
  int height,
  int x,
  int y,
) {
  // Cherche surtout de part et d'autre de la diagonale, donc dans la direction
  // perpendiculaire aux hachures. Les points plus éloignés ont moins de poids.
  const offsets = <(int, int)>[
    (-2, -2),
    (2, 2),
    (-3, -3),
    (3, 3),
    (-4, -4),
    (4, 4),
    (-2, 0),
    (2, 0),
    (0, -2),
    (0, 2),
    (-3, 0),
    (3, 0),
    (0, -3),
    (0, 3),
  ];

  var sr = 0.0;
  var sg = 0.0;
  var sb = 0.0;
  var sa = 0.0;
  var sw = 0.0;

  for (final o in offsets) {
    final nx = x + o.$1;
    final ny = y + o.$2;

    if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
    if (mask[ny * width + nx]) continue;

    final p = image.getPixel(nx, ny);
    final distance = math.sqrt((o.$1 * o.$1 + o.$2 * o.$2).toDouble());
    final w = 1.0 / math.max(1.0, distance);

    sr += p.r.toInt() * w;
    sg += p.g.toInt() * w;
    sb += p.b.toInt() * w;
    sa += p.a.toInt() * w;
    sw += w;
  }

  if (sw <= 0) return null;

  return (
    (sr / sw).round().clamp(0, 255),
    (sg / sw).round().clamp(0, 255),
    (sb / sw).round().clamp(0, 255),
    (sa / sw).round().clamp(0, 255),
  );
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
  dart run tool/remove_military_hatching_mbtiles.dart \\
    --source "/chemin/canjuers_topo.mbtiles" \\
    --output "/chemin/canjuers_topo_v2.mbtiles"
''');
}

class _HatchResult {
  const _HatchResult({required this.bytes, required this.changedPixels});

  final Uint8List bytes;
  final int changedPixels;
}
