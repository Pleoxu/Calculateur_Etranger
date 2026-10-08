// lib/services/tableau_ecl_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/fire/services/ballistic_asset_context.dart';
import 'secure_asset_resolver.dart';

class _EclRow {
  final int xM;
  final int altEclM;
  final double dDerMil;

  const _EclRow({
    required this.xM,
    required this.altEclM,
    required this.dDerMil,
  });
}

class TableauEclService {
  final String typeTir;
  final String charge;
  final bool verbose;

  TableauEclService({
    required this.typeTir,
    required this.charge,
    bool tirMontagne = false,
    this.verbose = false,
  });

  bool _loaded = false;
  final List<_EclRow> _rows = <_EclRow>[];

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
      throw FormatException('[TableauECL] Asset trop court: ${bytes.length}');
    }

    final reader = ByteData.sublistView(bytes);
    final magic = ascii.decode(bytes.sublist(0, 4));

    if (magic != 'ECLT') {
      throw FormatException('[TableauECL] En-tête magique invalide: $magic');
    }

    final version = reader.getUint8(4);
    if (version != 1) {
      throw FormatException('[TableauECL] Version non supportée: $version');
    }

    final rowCount = reader.getUint32(5, Endian.little);
    final expectedSize = headerSize + rowCount * rowSize;

    if (bytes.length != expectedSize) {
      throw FormatException(
        '[TableauECL] Taille invalide: attendu=$expectedSize actuel=${bytes.length}',
      );
    }

    _rows.clear();
    var offset = headerSize;

    for (var i = 0; i < rowCount; i++) {
      final xM = reader.getUint32(offset, Endian.little);
      offset += 4;

      final altEclM = reader.getInt16(offset, Endian.little);
      offset += 2;

      final dDerScaled = reader.getInt16(offset, Endian.little);
      offset += 2;

      _rows.add(_EclRow(xM: xM, altEclM: altEclM, dDerMil: dDerScaled / 100.0));
    }

    _rows.sort((a, b) => a.xM.compareTo(b.xM));
  }

  Future<double> dDerAt({required double distanceM}) async {
    await load();
    if (_rows.isEmpty) return 0.0;

    if (distanceM <= _rows.first.xM) return _rows.first.dDerMil;
    if (distanceM >= _rows.last.xM) return _rows.last.dDerMil;

    for (var i = 1; i < _rows.length; i++) {
      if (distanceM <= _rows[i].xM) {
        final r0 = _rows[i - 1];
        final r1 = _rows[i];
        final u = (distanceM - r0.xM) / (r1.xM - r0.xM);
        return r0.dDerMil + (r1.dDerMil - r0.dDerMil) * u;
      }
    }

    return _rows.last.dDerMil;
  }

  Future<double> corrHaussePar50mMil({required double distanceM}) async =>
      throw UnsupportedError(
        'TableauEclService.corrHaussePar50mMil is unavailable in this compatibility build.',
      );
}
