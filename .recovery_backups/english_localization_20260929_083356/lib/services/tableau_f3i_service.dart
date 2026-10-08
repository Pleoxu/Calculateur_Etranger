// lib/services/tableau_f3i_service.dart

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:calculateur_etranger/security/native_secure_assets.dart';
import '../domain/fire/services/ballistic_asset_context.dart';

class TableauF3iService {
  final String typeTir;
  final String charge;
  final bool tirMontagne;
  final String? assetPath;
  final bool verbose;

  TableauF3iService({
    required this.typeTir,
    required this.charge,
    required this.tirMontagne,
    this.assetPath,
    this.verbose = false,
  });

  bool _loaded = false;

  final List<int> _temperatures = <int>[];
  final List<_F3Row> _rows = <_F3Row>[];

  String _canonType(String s) => BallisticAssetContext.canonicalizeVariant(s);

  String _canonAssetType(String s) {
    final raw = s
        .trim()
        .toUpperCase()
        .replaceAll('É', 'E')
        .replaceAll(' ', '')
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'_+'), '_');

    final canonical = _canonType(raw).toUpperCase();

    switch (canonical) {
      case 'OECL':
      case 'OECL_ALL':
        return 'OECL_ART392';

      default:
        return canonical;
    }
  }

  Future<void> load() async {
    if (_loaded) return;

    final t = _canonAssetType(typeTir);
    final ch = charge.trim().toUpperCase();

    final candidates = <String>[
      if (assetPath != null && assetPath!.trim().isNotEmpty) assetPath!,

      // Convention actuelle : la variante complète est conservée.
      'assets/secure/tableaux/F3/F3I_${t}_$ch.f3tbl.gz',

      // Compatibilité historique uniquement, essayée après la variante complète.
      if (t.endsWith('_ALL'))
        'assets/secure/tableaux/F3/'
            'F3I_${t.substring(0, t.length - '_ALL'.length)}_$ch.f3tbl.gz',
    ];

    _log(
      '[F3i:LOAD] '
      'typeTir=$typeTir canonical=$t charge=$ch candidates=$candidates',
    );

    Object? lastError;

    for (final path in candidates) {
      try {
        if (!path.endsWith('.f3tbl.gz')) {
          continue;
        }

        final encryptedPath = 'assets/secure_enc/'
            '${path.replaceFirst('assets/secure/', '')}.enc';

        final compressed = await NativeSecureAssets.decryptAsset(encryptedPath);
        final raw = Uint8List.fromList(gzip.decode(compressed));

        _decodeF3tbl(raw, path);

        _loaded = true;

        _log(
          '[F3i] OK rows=${_rows.length} temps=$_temperatures via $encryptedPath',
        );

        return;
      } catch (e) {
        lastError = e;
      }
    }

    throw StateError(
      '[F3i] impossible de charger AES $typeTir/$charge : $lastError',
    );
  }

  void _decodeF3tbl(Uint8List bytes, String path) {
    _rows.clear();
    _temperatures.clear();

    if (bytes.length < 10) {
      throw FormatException('F3TB trop court : ${bytes.length} bytes');
    }

    final data = ByteData.sublistView(bytes);
    var offset = 0;

    void requireBytes(int count) {
      if (offset + count > bytes.length) {
        throw FormatException('F3TB tronqué à offset=$offset dans $path');
      }
    }

    requireBytes(4);
    final magic = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    offset += 4;

    if (magic != 'F3TB') {
      throw FormatException('Magic F3TB invalide dans $path : $magic');
    }

    requireBytes(1);
    final version = data.getUint8(offset);
    offset += 1;

    if (version != 1) {
      throw FormatException('Version F3TB non supportée dans $path : $version');
    }

    requireBytes(4);
    final rowCount = data.getUint32(offset, Endian.little);
    offset += 4;

    requireBytes(1);
    final tempCount = data.getUint8(offset);
    offset += 1;

    for (var i = 0; i < tempCount; i++) {
      requireBytes(2);
      _temperatures.add(data.getInt16(offset, Endian.little));
      offset += 2;
    }

    final rowSize = 4 + 1 + tempCount * 4;
    final expectedSize = 10 + tempCount * 2 + rowCount * rowSize;

    if (bytes.length != expectedSize) {
      throw FormatException(
        'F3TB taille invalide dans $path : ${bytes.length}, attendu $expectedSize',
      );
    }

    for (var rowIndex = 0; rowIndex < rowCount; rowIndex++) {
      requireBytes(rowSize);

      final distance = data.getFloat32(offset, Endian.little);
      offset += 4;

      final flags = data.getUint8(offset);
      offset += 1;

      final tm = (flags & 0x01) != 0;
      final values = <int, double>{};

      for (final temp in _temperatures) {
        final value = data.getFloat32(offset, Endian.little);
        offset += 4;
        values[temp] = value;
      }

      _rows.add(_F3Row(distance: distance, tirMontagne: tm, values: values));
    }

    _rows.sort((a, b) => a.distance.compareTo(b.distance));
  }

  Future<double> interp({
    required double distance,
    required double tempC,
  }) async {
    _log(
      '[F3i:INPUT] '
      'typeTir=$typeTir '
      'charge=$charge '
      'tirMontagne=$tirMontagne '
      'distance=$distance '
      'tempC=$tempC',
    );

    await load();

    final rows = _rows
        .where((r) => r.tirMontagne == tirMontagne)
        .toList(growable: false);

    final usableRows = rows.isEmpty ? _rows : rows;

    if (usableRows.isEmpty || _temperatures.isEmpty) return 0.0;

    final sortedRows = usableRows.toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));

    if (distance <= sortedRows.first.distance) {
      return _interpTemp(sortedRows.first, tempC);
    }

    if (distance >= sortedRows.last.distance) {
      return _interpTemp(sortedRows.last, tempC);
    }

    _F3Row lo = sortedRows.first;
    _F3Row hi = sortedRows.last;

    for (var i = 1; i < sortedRows.length; i++) {
      if (distance <= sortedRows[i].distance) {
        lo = sortedRows[i - 1];
        hi = sortedRows[i];
        break;
      }
    }

    final d0 = lo.distance;
    final d1 = hi.distance;
    final uD = d1 == d0 ? 0.0 : (distance - d0) / (d1 - d0);
    final v0 = _interpTemp(lo, tempC);
    final v1 = _interpTemp(hi, tempC);
    final out = v0 + (v1 - v0) * uD;

    _log(
      '[F3i] distance=$distance temp=$tempC TM=$tirMontagne '
      'd=(${d0.toStringAsFixed(0)},${d1.toStringAsFixed(0)}) '
      'v=(${v0.toStringAsFixed(3)},${v1.toStringAsFixed(3)}) => rtc=$out',
    );

    return out;
  }

  double _interpTemp(_F3Row row, double tempC) {
    final temps = row.values.keys.toList()..sort();

    if (temps.isEmpty) return 0.0;
    if (tempC <= temps.first) return row.values[temps.first] ?? 0.0;
    if (tempC >= temps.last) return row.values[temps.last] ?? 0.0;

    int t0 = temps.first;
    int t1 = temps.last;

    for (var i = 1; i < temps.length; i++) {
      if (tempC <= temps[i]) {
        t0 = temps[i - 1];
        t1 = temps[i];
        break;
      }
    }

    final v0 = row.values[t0] ?? 0.0;
    final v1 = row.values[t1] ?? v0;
    final u = t1 == t0 ? 0.0 : (tempC - t0) / (t1 - t0);

    return v0 + (v1 - v0) * u;
  }

  void _log(String msg) {
    if (verbose || kDebugMode) debugPrint(msg);
  }
}

class _F3Row {
  final double distance;
  final bool tirMontagne;
  final Map<int, double> values;

  const _F3Row({
    required this.distance,
    required this.tirMontagne,
    required this.values,
  });
}
