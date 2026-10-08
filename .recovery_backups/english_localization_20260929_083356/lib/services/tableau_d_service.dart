// lib/services/tableau_d_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:calculateur_etranger/security/native_secure_assets.dart';

class TableauDService {
  final String typeTir;
  final bool verbose;

  /// Chemin AES de la table de correction d'altitude météo.
  final String encryptedPath;

  TableauDService({
    required this.typeTir,
    this.verbose = false,
    this.encryptedPath = 'assets/secure_enc/tableaux/D/D_GLOBAL.dtbl.gz.enc',
  });

  bool _loaded = false;
  final List<_DRow> _rows = <_DRow>[];

  Future<void> load() async {
    if (_loaded) return;

    Uint8List compressedBytes;

    try {
      compressedBytes = await NativeSecureAssets.decryptAsset(encryptedPath);

      if (verbose || kDebugMode) {
        debugPrint('[SECURE] TableauD AES natif OK $encryptedPath');
      }
    } catch (e) {
      throw StateError(
        '[SECURE] AES GTBL decrypt failed '
        '$encryptedPath : $e',
      );
    }

    final bytes = Uint8List.fromList(gzip.decode(compressedBytes));
    _decode(bytes);

    _loaded = true;

    if (verbose || kDebugMode) {
      debugPrint('[TableauD] OK ${_rows.length} rows');
    }
  }

  void _decode(Uint8List bytes) {
    const headerSize = 9;
    const rowSize = 6;

    if (bytes.length < headerSize) {
      throw FormatException('[TableauD] DTBL trop court: ${bytes.length}');
    }

    final reader = ByteData.sublistView(bytes);
    final magic = ascii.decode(bytes.sublist(0, 4));

    if (magic != 'DTBL') {
      throw FormatException('[TableauD] Magic invalide: $magic');
    }

    final version = reader.getUint8(4);
    if (version != 1) {
      throw FormatException('[TableauD] Version non supportée: $version');
    }

    final rowCount = reader.getUint32(5, Endian.little);
    final expectedSize = headerSize + rowCount * rowSize;

    if (bytes.length != expectedSize) {
      throw FormatException(
        '[TableauD] Taille invalide: expected=$expectedSize actual=${bytes.length}',
      );
    }

    _rows.clear();

    var offset = headerSize;

    for (var i = 0; i < rowCount; i++) {
      final deltaAltM = reader.getInt16(offset, Endian.little);
      offset += 2;

      final dcTbPct = reader.getInt16(offset, Endian.little);
      offset += 2;

      final dcPbPct = reader.getInt16(offset, Endian.little);
      offset += 2;

      _rows.add(
        _DRow(
          deltaAltM: deltaAltM.toDouble(),
          dcTbPct: dcTbPct / 10.0,
          dcPbPct: dcPbPct / 10.0,
        ),
      );
    }

    _rows.sort((a, b) => a.deltaAltM.compareTo(b.deltaAltM));

    if (_rows.isEmpty) {
      throw StateError('[TableauD] Aucune ligne exploitable');
    }
  }

  Future<double> valueTbPctAtAbsDelta({required double deltaAltM}) async {
    await load();
    return _interp(absDeltaM: deltaAltM.abs(), selector: (r) => r.dcTbPct);
  }

  Future<double> valuePbPctAtAbsDelta({required double deltaAltM}) async {
    await load();
    return _interp(absDeltaM: deltaAltM.abs(), selector: (r) => r.dcPbPct);
  }

  Future<(double, double)> pbPercentCorrige({
    required double pbHpa,
    required double deltaAltM,
  }) async {
    await load();

    final rawPct = pbHpa / 1013.25 * 100.0;
    final dVal = await valuePbPctAtAbsDelta(deltaAltM: deltaAltM);
    final applied = deltaAltM < 0 ? -dVal : dVal;

    final pbPctCorrige = double.parse((rawPct + applied).toStringAsFixed(2));

    final deltaPbPctSigned = double.parse(
      (pbPctCorrige - 100.0).toStringAsFixed(2),
    );

    return (pbPctCorrige, deltaPbPctSigned);
  }

  double _interp({
    required double absDeltaM,
    required double Function(_DRow row) selector,
  }) {
    if (_rows.isEmpty) return 0.0;

    if (absDeltaM <= _rows.first.deltaAltM) {
      return selector(_rows.first);
    }

    if (absDeltaM >= _rows.last.deltaAltM) {
      return selector(_rows.last);
    }

    _DRow lo = _rows.first;
    _DRow hi = _rows.last;

    for (var i = 1; i < _rows.length; i++) {
      if (absDeltaM <= _rows[i].deltaAltM) {
        lo = _rows[i - 1];
        hi = _rows[i];
        break;
      }
    }

    final d0 = lo.deltaAltM;
    final d1 = hi.deltaAltM;
    final u = d1 == d0 ? 0.0 : (absDeltaM - d0) / (d1 - d0);

    return selector(lo) + (selector(hi) - selector(lo)) * u;
  }
}

class _DRow {
  final double deltaAltM;
  final double dcTbPct;
  final double dcPbPct;

  const _DRow({
    required this.deltaAltM,
    required this.dcTbPct,
    required this.dcPbPct,
  });
}
