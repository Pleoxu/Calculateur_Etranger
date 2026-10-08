// lib/services/tableau_e_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/fire/services/ballistic_asset_context.dart';
import 'secure_asset_resolver.dart';

class _TableauERow {
  final double xM;
  final double zM;
  final double dDerMil;
  final double dZRelM;

  const _TableauERow({
    required this.xM,
    required this.zM,
    required this.dDerMil,
    required this.dZRelM,
  });
}

class TableauEService {
  final String typeTir;
  final String charge;
  final bool verbose;

  TableauEService({
    Object? systeme,
    required this.typeTir,
    required this.charge,
    this.verbose = false,
  });

  bool _loaded = false;
  final List<_TableauERow> _rows = <_TableauERow>[];

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
    const rowSize = 16;

    if (bytes.length < headerSize) {
      throw FormatException('[TableauE] ETBL trop court: ${bytes.length}');
    }

    final data = ByteData.sublistView(bytes);
    final magic = ascii.decode(bytes.sublist(0, 4));

    if (magic != 'ETBL') {
      throw FormatException('[Table E] Invalid magic: $magic');
    }

    final version = data.getUint8(4);
    if (version != 1) {
      throw FormatException('[Table E] Unsupported version: $version');
    }

    final rowCount = data.getUint32(5, Endian.little);
    final expectedSize = headerSize + rowCount * rowSize;

    if (bytes.length != expectedSize) {
      throw FormatException(
        '[Table E] Invalid size: expected=$expectedSize actual=${bytes.length}',
      );
    }

    _rows.clear();
    var offset = headerSize;

    for (var i = 0; i < rowCount; i++) {
      final xM = data.getUint32(offset, Endian.little).toDouble();
      offset += 4;

      final zM = data.getInt32(offset, Endian.little).toDouble();
      offset += 4;

      final dDerScaled = data.getInt32(offset, Endian.little);
      offset += 4;

      final dZRelScaled = data.getInt32(offset, Endian.little);
      offset += 4;

      _rows.add(
        _TableauERow(
          xM: xM,
          zM: zM,
          dDerMil: dDerScaled / 1000.0,
          dZRelM: dZRelScaled / 1000.0,
        ),
      );
    }

    _rows.sort((a, b) => a.xM.compareTo(b.xM));
  }

  Future<_TableauERow?> getRowAt(double distanceM) async {
    await load();
    if (_rows.isEmpty) return null;

    if (distanceM <= _rows.first.xM) return _rows.first;
    if (distanceM >= _rows.last.xM) return _rows.last;

    for (var i = 1; i < _rows.length; i++) {
      if (distanceM <= _rows[i].xM) {
        final r0 = _rows[i - 1];
        final r1 = _rows[i];
        final u = (distanceM - r0.xM) / (r1.xM - r0.xM);

        return _TableauERow(
          xM: distanceM,
          zM: r0.zM + (r1.zM - r0.zM) * u,
          dDerMil: r0.dDerMil + (r1.dDerMil - r0.dDerMil) * u,
          dZRelM: r0.dZRelM + (r1.dZRelM - r0.dZRelM) * u,
        );
      }
    }
    return _rows.last;
  }

  Future<double?> deltaVoTemp({required double tempPoudreC}) async =>
      throw UnsupportedError(
        'TableauEService.deltaVoTemp is unavailable in this compatibility build.',
      );

  Future<double?> deltaVoParCarreaux({
    required String charge,
    required double deltaCarreaux,
  }) async =>
      throw UnsupportedError(
        'TableauEService.deltaVoParCarreaux is unavailable in this compatibility build.',
      );
}
