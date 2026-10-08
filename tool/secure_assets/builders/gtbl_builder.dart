import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../table_builder.dart';

class GtblBuilder implements TableBuilder {
  static const int version = 2;
  static const int _flagTirMontagne = 1 << 0;

  String get id => 'gtbl';

  @override
  bool supports(File file) {
    final name = file.uri.pathSegments.last;
    return name.startsWith('Tableau_G_') && name.endsWith('.json');
  }

  @override
  Future<Map<String, dynamic>> build(File input, Directory outputRoot) async {
    final fileName = input.uri.pathSegments.last;
    final assetId = _assetIdFromFileName(fileName);

    final outputDir = Directory('${outputRoot.path}/G');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final output = File('${outputDir.path}/$assetId.gtbl.gz');

    final decoded = json.decode(await input.readAsString());

    final List<dynamic> rowsRaw;
    if (decoded is List) {
      rowsRaw = decoded;
    } else if (decoded is Map && decoded['data'] is List) {
      rowsRaw = decoded['data'] as List<dynamic>;
    } else {
      throw FormatException('[GTBL] JSON racine invalide : ${input.path}');
    }

    final rows = rowsRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    rows.sort((a, b) {
      final tmA = _bool(a['tirMontagne']) ? 1 : 0;
      final tmB = _bool(b['tirMontagne']) ? 1 : 0;

      if (tmA != tmB) return tmA.compareTo(tmB);

      return _num(a, 'distance').compareTo(_num(b, 'distance'));
    });

    final bytes = BytesBuilder();

    bytes.add(ascii.encode('GTBL'));
    bytes.addByte(version);
    bytes.add(_u32(rows.length));

    for (final row in rows) {
      final tirMontagne = _bool(row['tirMontagne']);

      bytes.add(_f32(_num(row, 'distance')));
      bytes.add(_f32(_num(row, 'hausse')));

      bytes.add(_f32(_num(row, 'ecartProbablePortee')));
      bytes.add(_f32(_num(row, 'ecartProbableDirection')));
      bytes.add(_f32(_num(row, 'ecartProbableHauteurEclatement')));
      bytes.add(_f32(_num(row, 'ecartProbableDelaiEclatement')));
      bytes.add(_f32(_num(row, 'ecartProbablePorteeEclatement')));

      bytes.add(
        _f32(_numAny(row, const ['angleChute', 'angleChuteMil', 'Aw', 'aw'])),
      );

      bytes.add(
        _f32(
          _numAny(row, const [
            'cotangenteAngleChute',
            'cotAngleChute',
            'CotAw',
            'cotAw',
            'cot_aw',
          ]),
        ),
      );

      bytes.add(
        _f32(
          _numAny(row, const [
            'vitesseRestante',
            'vitesseRestanteMs',
            'Vw',
            'vw',
          ]),
        ),
      );

      bytes.add(_f32(_numAny(row, const ['fleche', 'Ys', 'ys'])));

      bytes.add(_f32(_num(row, 'correctionComplementSiteAnglePlus')));
      bytes.add(_f32(_num(row, 'correctionComplementSiteAngleMoins')));

      var flags = 0;
      if (tirMontagne) flags |= _flagTirMontagne;

      bytes.addByte(flags);
      bytes.add(_u16(0));
    }

    final gzipped = gzip.encode(bytes.toBytes());
    await output.writeAsBytes(gzipped, flush: true);

    return {
      'id': assetId,
      'format': 'GTBL_V2',
      'path': output.path,
      'rows': rows.length,
    };
  }

  String _assetIdFromFileName(String fileName) {
    var name = fileName;

    if (name.endsWith('.json')) {
      name = name.substring(0, name.length - '.json'.length);
    }

    if (name.startsWith('Tableau_G_')) {
      name = name.substring('Tableau_G_'.length);
    }

    return 'G_${name.toUpperCase()}';
  }

  double _num(Map<String, dynamic> row, String key) {
    return _toDouble(row[key]);
  }

  double _numAny(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      if (row.containsKey(key)) {
        return _toDouble(row[key]);
      }
    }
    return 0.0;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.trim().replaceAll(',', '.')) ?? 0.0;
    }
    return 0.0;
  }

  bool _bool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'oui' || s == 'yes';
    }
    return false;
  }

  Uint8List _f32(double value) {
    final data = ByteData(4);
    data.setFloat32(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  Uint8List _u16(int value) {
    final data = ByteData(2);
    data.setUint16(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  Uint8List _u32(int value) {
    final data = ByteData(4);
    data.setUint32(0, value, Endian.little);
    return data.buffer.asUint8List();
  }
}
