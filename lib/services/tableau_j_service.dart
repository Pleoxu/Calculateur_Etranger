// lib/services/tableau_j_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/fire/services/ballistic_asset_context.dart';
import 'secure_asset_resolver.dart';

class _JRow {
  final int xM;
  final double dX;
  final double dZ;

  const _JRow({required this.xM, required this.dX, required this.dZ});
}

class TableauJService {
  final String typeTir;
  final String charge;
  final bool isJBis;
  final bool verbose;

  TableauJService({
    required this.typeTir,
    required this.charge,
    this.isJBis = false,
    this.verbose = false,
  });

  bool _loaded = false;
  final List<_JRow> _rows = <_JRow>[];

  void _v(String message) {
    if (verbose || kDebugMode) {
      debugPrint(message);
    }
  }

  Future<void> load() async {
    throw UnsupportedError(
      'Legacy ballistic asset loading is unavailable in this compatibility build.',
    );
  }

  void _decode(Uint8List bytes) {
    const headerSize = 9;
    const rowSize = 8;

    if (bytes.length < headerSize) {
      throw FormatException('[TableauJ] JTBL trop court: ${bytes.length}');
    }

    final reader = ByteData.sublistView(bytes);
    final magic = ascii.decode(bytes.sublist(0, 4));

    if (magic != 'JTBL' && magic != 'JBIS') {
      throw FormatException('[TableauJ] En-tête magique invalide: $magic');
    }

    final version = reader.getUint8(4);
    if (version != 1) {
      throw FormatException('[TableauJ] Version non supportée: $version');
    }

    final rowCount = reader.getUint32(5, Endian.little);
    final expectedSize = headerSize + rowCount * rowSize;

    if (bytes.length != expectedSize) {
      throw FormatException(
        '[TableauJ] Taille invalide: attendu=$expectedSize actuel=${bytes.length}',
      );
    }

    _rows.clear();
    var offset = headerSize;

    for (var i = 0; i < rowCount; i++) {
      final xM = reader.getUint32(offset, Endian.little);
      offset += 4;

      final dXScaled = reader.getInt16(offset, Endian.little);
      offset += 2;

      final dZScaled = reader.getInt16(offset, Endian.little);
      offset += 2;

      _rows.add(_JRow(xM: xM, dX: dXScaled / 10.0, dZ: dZScaled / 10.0));
    }

    _rows.sort((a, b) => a.xM.compareTo(b.xM));
  }

  Future<(double, double)> correctionsAt({required double distanceM}) async {
    await load();
    if (_rows.isEmpty) return (0.0, 0.0);

    if (distanceM <= _rows.first.xM) return (_rows.first.dX, _rows.first.dZ);
    if (distanceM >= _rows.last.xM) return (_rows.last.dX, _rows.last.dZ);

    for (var i = 1; i < _rows.length; i++) {
      if (distanceM <= _rows[i].xM) {
        final r0 = _rows[i - 1];
        final r1 = _rows[i];
        final u = (distanceM - r0.xM) / (r1.xM - r0.xM);
        return (r0.dX + (r1.dX - r0.dX) * u, r0.dZ + (r1.dZ - r0.dZ) * u);
      }
    }

    return (_rows.last.dX, _rows.last.dZ);
  }
}
