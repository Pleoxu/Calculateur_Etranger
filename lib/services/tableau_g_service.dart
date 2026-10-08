// lib/services/tableau_g_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/fire/services/ballistic_asset_context.dart';
import 'secure_asset_resolver.dart';

class _GRow {
  final int elevationMil;
  final double dXm;
  final double dZm;

  const _GRow({
    required this.elevationMil,
    required this.dXm,
    required this.dZm,
  });
}

/// Compatibility-only terminal row shape for legacy call sites.
class TableauGInterpolatedRow {
  final double distance;
  final double angleChute;
  final double cotangenteAngleChute;
  final double ecartProbablePortee;
  final double ecartProbableDirection;
  final double vitesseRestante;

  const TableauGInterpolatedRow({
    required this.distance,
    required this.angleChute,
    required this.cotangenteAngleChute,
    required this.ecartProbablePortee,
    required this.ecartProbableDirection,
    required this.vitesseRestante,
  });
}

class TableauGService {
  final String typeTir;
  final String charge;
  final bool verbose;

  TableauGService({
    required this.typeTir,
    required this.charge,
    bool tirMontagne = false,
    this.verbose = false,
  });

  bool _loaded = false;
  final List<_GRow> _rows = <_GRow>[];

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
      throw FormatException('[TableauG] GTBL trop court: ${bytes.length}');
    }

    final reader = ByteData.sublistView(bytes);
    final magic = ascii.decode(bytes.sublist(0, 4));

    if (magic != 'GTBL') {
      throw FormatException('[TableauG] En-tête magique invalide: $magic');
    }

    final version = reader.getUint8(4);
    if (version != 1) {
      throw FormatException('[TableauG] Version non supportée: $version');
    }

    final rowCount = reader.getUint32(5, Endian.little);
    final expectedSize = headerSize + rowCount * rowSize;

    if (bytes.length != expectedSize) {
      throw FormatException(
        '[TableauG] Taille invalide: attendu=$expectedSize actuel=${bytes.length}',
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
        _GRow(
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

  Never _unsupported(String member) => throw UnsupportedError(
        'TableauGService.$member is unavailable in this compatibility build.',
      );

  Future<double> kAcs({
    required double distanceM,
    required double asMil,
  }) async =>
      _unsupported('kAcs');

  Future<TableauGInterpolatedRow> rowInterpolated({
    required double distanceM,
    bool tirMontagne = false,
  }) async =>
      _unsupported('rowInterpolated');
}
