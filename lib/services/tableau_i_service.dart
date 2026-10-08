// lib/services/tableau_i_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/fire/services/ballistic_asset_context.dart';
import 'secure_asset_resolver.dart';

class _IRow {
  final int xM;
  final double dXMass;
  final double dXTemp;

  const _IRow({required this.xM, required this.dXMass, required this.dXTemp});
}

class TableauIService {
  final String typeTir;
  final String charge;
  final bool verbose;

  TableauIService({
    Object? systeme,
    required this.typeTir,
    required this.charge,
    bool tirMontagne = false,
    int snapAzToStepMil = 100,
    this.verbose = false,
  });

  bool _loaded = false;
  final List<_IRow> _rows = <_IRow>[];

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
      throw FormatException('[TableauI] ITBL trop court: ${bytes.length}');
    }

    final reader = ByteData.sublistView(bytes);
    final magic = ascii.decode(bytes.sublist(0, 4));

    if (magic != 'ITBL') {
      throw FormatException('[TableauI] En-tête magique invalide: $magic');
    }

    final version = reader.getUint8(4);
    if (version != 1) {
      throw FormatException('[TableauI] Version non supportée: $version');
    }

    final rowCount = reader.getUint32(5, Endian.little);
    final expectedSize = headerSize + rowCount * rowSize;

    if (bytes.length != expectedSize) {
      throw FormatException(
        '[TableauI] Taille invalide: attendu=$expectedSize actuel=${bytes.length}',
      );
    }

    _rows.clear();
    var offset = headerSize;

    for (var i = 0; i < rowCount; i++) {
      final xM = reader.getUint32(offset, Endian.little);
      offset += 4;

      final dXMassScaled = reader.getInt16(offset, Endian.little);
      offset += 2;

      final dXTempScaled = reader.getInt16(offset, Endian.little);
      offset += 2;

      _rows.add(
        _IRow(xM: xM, dXMass: dXMassScaled / 10.0, dXTemp: dXTempScaled / 10.0),
      );
    }

    _rows.sort((a, b) => a.xM.compareTo(b.xM));
  }

  Future<(double, double)> correctionsAt({required double distanceM}) async {
    await load();
    if (_rows.isEmpty) return (0.0, 0.0);

    if (distanceM <= _rows.first.xM) {
      return (_rows.first.dXMass, _rows.first.dXTemp);
    }
    if (distanceM >= _rows.last.xM) {
      return (_rows.last.dXMass, _rows.last.dXTemp);
    }

    for (var i = 1; i < _rows.length; i++) {
      if (distanceM <= _rows[i].xM) {
        final r0 = _rows[i - 1];
        final r1 = _rows[i];
        final u = (distanceM - r0.xM) / (r1.xM - r0.xM);
        return (
          r0.dXMass + (r1.dXMass - r0.dXMass) * u,
          r0.dXTemp + (r1.dXTemp - r0.dXTemp) * u,
        );
      }
    }

    return (_rows.last.dXMass, _rows.last.dXTemp);
  }

  Future<double?> rotZ({
    required double distance,
    required int azimutMil,
    required double latitudeDeg,
    bool tirMontagne = false,
    bool absolute = false,
  }) async =>
      throw UnsupportedError(
        'TableauIService.rotZ is unavailable in this compatibility build.',
      );
}
