// lib/services/tableau_h_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/fire/services/ballistic_asset_context.dart';
import 'secure_asset_resolver.dart';

class _HRow {
  final int elevationMil;
  final double dXm;
  final double dZm;

  const _HRow({
    required this.elevationMil,
    required this.dXm,
    required this.dZm,
  });
}

class TableauHService {
  final String typeTir;
  final String charge;
  final bool verbose;

  TableauHService({
    Object? systeme,
    required this.typeTir,
    required this.charge,
    bool debug = false,
    this.verbose = false,
  });

  bool _loaded = false;
  final List<_HRow> _rows = <_HRow>[];

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
    const rowSize = 6;

    if (bytes.length < headerSize) {
      throw FormatException('[TableauH] HTBL trop court: ${bytes.length}');
    }

    final reader = ByteData.sublistView(bytes);
    final magic = ascii.decode(bytes.sublist(0, 4));

    if (magic != 'HTBL') {
      throw FormatException('[TableauH] En-tête magique invalide: $magic');
    }

    final version = reader.getUint8(4);
    if (version != 1) {
      throw FormatException('[TableauH] Version non supportée: $version');
    }

    final rowCount = reader.getUint32(5, Endian.little);
    final expectedSize = headerSize + rowCount * rowSize;

    if (bytes.length != expectedSize) {
      throw FormatException(
        '[TableauH] Taille invalide: attendu=$expectedSize actuel=${bytes.length}',
      );
    }

    _rows.clear();
    var offset = headerSize;

    for (var i = 0; i < rowCount; i++) {
      final elevation = reader.getUint16(offset, Endian.little);
      offset += 2;

      final dXScaled = reader.getInt16(offset, Endian.little);
      offset += 2;

      final dZScaled = reader.getInt16(offset, Endian.little);
      offset += 2;

      _rows.add(
        _HRow(
          elevationMil: elevation,
          dXm: dXScaled / 10.0,
          dZm: dZScaled / 10.0,
        ),
      );
    }

    _rows.sort((a, b) => a.elevationMil.compareTo(b.elevationMil));
  }

  Future<(double, double)> correctionsAt({required int elevationMil}) async {
    await load();
    if (_rows.isEmpty) return (0.0, 0.0);

    if (elevationMil <= _rows.first.elevationMil) {
      return (_rows.first.dXm, _rows.first.dZm);
    }
    if (elevationMil >= _rows.last.elevationMil) {
      return (_rows.last.dXm, _rows.last.dZm);
    }

    for (var i = 1; i < _rows.length; i++) {
      if (elevationMil <= _rows[i].elevationMil) {
        final r0 = _rows[i - 1];
        final r1 = _rows[i];
        final u = (elevationMil - r0.elevationMil) /
            (r1.elevationMil - r0.elevationMil);
        return (r0.dXm + (r1.dXm - r0.dXm) * u, r0.dZm + (r1.dZm - r0.dZm) * u);
      }
    }

    return (_rows.last.dXm, _rows.last.dZm);
  }

  Future<double> rotxM({
    required double distance,
    required int gisementMil,
    required double latitudeDeg,
    bool tirMontagne = false,
  }) async =>
      throw UnsupportedError(
        'TableauHService.rotxM is unavailable in this compatibility build.',
      );
}
