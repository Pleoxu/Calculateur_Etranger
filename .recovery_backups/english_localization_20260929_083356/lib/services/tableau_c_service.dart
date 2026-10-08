// lib/services/tableau_c_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:calculateur_etranger/security/native_secure_assets.dart';

class _TableauCRow {
  final int angleMil;
  final double wxAbs;
  final double wzAbs;

  const _TableauCRow({
    required this.angleMil,
    required this.wxAbs,
    required this.wzAbs,
  });
}

class TableauCService {
  final String typeTir;
  final int niveauMeteo;
  final bool verbose;

  /// Chemin AES de la table de décomposition du vent.
  final String encryptedPath;

  TableauCService({
    required this.typeTir,
    required this.niveauMeteo,
    this.verbose = false,
    this.encryptedPath = 'assets/secure_enc/tableaux/C/C_GLOBAL.ctbl.gz.enc',
  });

  static const int _headerSize = 9;
  static const int _rowSize = 6;

  bool _loaded = false;

  final Map<int, _TableauCRow> _rows = <int, _TableauCRow>{};
  late List<int> _angles;

  void _v(String message) {
    if (verbose || kDebugMode) {
      debugPrint(message);
    }
  }

  Future<void> load() async {
    if (_loaded) return;

    final Uint8List compressedBytes;

    try {
      compressedBytes = await NativeSecureAssets.decryptAsset(encryptedPath);
    } catch (e) {
      throw StateError('[SECURE] AES CTBL decrypt failed $encryptedPath : $e');
    }

    final bytes = Uint8List.fromList(gzip.decode(compressedBytes));

    _decode(bytes);

    _angles = _rows.keys.toList()..sort();

    if (_angles.isEmpty || !_rows.containsKey(0) || !_rows.containsKey(6400)) {
      throw StateError('[TableauC] Le CTBL doit contenir les angles 0 et 6400');
    }

    _loaded = true;

    _v('[SECURE] TableauC AES natif OK $encryptedPath');
    _v(
      '[TableauC] OK rows=${_rows.length} '
      'range=${_angles.first}..${_angles.last}',
    );
  }

  void _decode(Uint8List bytes) {
    if (bytes.length < _headerSize) {
      throw FormatException('[TableauC] CTBL trop court: ${bytes.length}');
    }

    final data = ByteData.sublistView(bytes);

    final magic = ascii.decode(bytes.sublist(0, 4));
    if (magic != 'CTBL') {
      throw FormatException('[TableauC] Magic invalide: $magic');
    }

    final version = data.getUint8(4);
    if (version != 1) {
      throw FormatException('[TableauC] Version non supportée: $version');
    }

    final rowCount = data.getUint32(5, Endian.little);
    final expectedSize = _headerSize + rowCount * _rowSize;

    if (bytes.length != expectedSize) {
      throw FormatException(
        '[TableauC] Taille invalide: '
        'expected=$expectedSize actual=${bytes.length}',
      );
    }

    _rows.clear();

    var offset = _headerSize;
    var previousAngle = -1;

    for (var i = 0; i < rowCount; i++) {
      final angle = data.getUint16(offset, Endian.little);
      offset += 2;

      final wzScaled = data.getUint16(offset, Endian.little);
      offset += 2;

      final wxScaled = data.getUint16(offset, Endian.little);
      offset += 2;

      if (angle <= previousAngle) {
        throw FormatException(
          '[TableauC] Angles non strictement croissants: '
          '$previousAngle -> $angle',
        );
      }

      previousAngle = angle;

      _rows[angle] = _TableauCRow(
        angleMil: angle,
        wzAbs: wzScaled / 100.0,
        wxAbs: wxScaled / 100.0,
      );
    }
  }

  Future<double> coefAt({
    required int directionVent,
    required int gisementTir,
    required String composante,
  }) async {
    final comp = await composantesVent(
      directionVent: directionVent,
      gisementTir: gisementTir,
    );

    switch (composante.trim().toLowerCase()) {
      case 'wx':
        return comp['wx'] as double;
      case 'wz':
        return comp['wz'] as double;
      default:
        throw ArgumentError.value(
          composante,
          'composante',
          'Valeur attendue: wx ou wz',
        );
    }
  }

  Future<Map<String, dynamic>> composantesVent({
    required int directionVent,
    required int gisementTir,
  }) async {
    await load();

    final deltaMil = (((directionVent - gisementTir) % 6400) + 6400) % 6400;

    final (a0, a1, u) = _bounds(deltaMil.toDouble());

    final row0 = _rows[a0];
    final row1 = _rows[a1];

    if (row0 == null || row1 == null) {
      throw StateError('[TableauC] Bornes absentes: $a0/$a1');
    }

    final wxAbs = _lerp(row0.wxAbs, row1.wxAbs, u);
    final wzAbs = _lerp(row0.wzAbs, row1.wzAbs, u);

    final wx = wxAbs * _wxSign(deltaMil);
    final wz = wzAbs * _wzSign(deltaMil);

    _v(
      '[TableauC] dir=$directionVent '
      'gis=$gisementTir '
      'delta=$deltaMil '
      'bounds=($a0,$a1,u=$u) '
      'wxAbs=${wxAbs.toStringAsFixed(6)} '
      'wzAbs=${wzAbs.toStringAsFixed(6)} '
      'wx=${wx.toStringAsFixed(6)} '
      'wz=${wz.toStringAsFixed(6)}',
    );

    return <String, dynamic>{
      'wx': wx,
      'wz': wz,
      'deltaMil': deltaMil,
      'a0': a0,
      'a1': a1,
      'u': u,
    };
  }

  (int, int, double) _bounds(double angleMil) {
    if (angleMil <= _angles.first) {
      return (_angles.first, _angles.first, 0.0);
    }

    if (angleMil >= _angles.last) {
      return (_angles.last, _angles.last, 0.0);
    }

    for (var i = 1; i < _angles.length; i++) {
      final a = _angles[i - 1];
      final b = _angles[i];

      if (angleMil <= b) {
        return (a, b, (angleMil - a) / (b - a));
      }
    }

    return (_angles.last, _angles.last, 0.0);
  }

  static double _wxSign(int deltaMil) {
    if (deltaMil == 1600 || deltaMil == 4800) {
      return 0.0;
    }

    return (deltaMil < 1600 || deltaMil > 4800) ? 1.0 : -1.0;
  }

  static double _wzSign(int deltaMil) {
    if (deltaMil == 0 || deltaMil == 3200) {
      return 0.0;
    }

    return deltaMil < 3200 ? 1.0 : -1.0;
  }

  static double _lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }
}
