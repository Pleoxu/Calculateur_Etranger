// lib/services/tableau_f_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/fire/services/ballistic_asset_context.dart';
import 'secure_asset_resolver.dart';

class _TableauFRow {
  final int elevationMil;
  final double dXDerivM;
  final double dZDerivM;

  const _TableauFRow({
    required this.elevationMil,
    required this.dXDerivM,
    required this.dZDerivM,
  });
}

/// Compatibility-only shape retained for legacy callers.
/// No operational coefficients are reconstructed here.
class FLongCoeffs {
  final double kVentMoins;
  final double kVentPlus;
  final double kTempMoins;
  final double kTempPlus;
  final double kPressionMoins;
  final double kPressionPlus;
  final double kV0Moins;
  final double kV0Plus;
  final double kMasseMoins;
  final double kMassePlus;

  const FLongCoeffs({
    required this.kVentMoins,
    required this.kVentPlus,
    required this.kTempMoins,
    required this.kTempPlus,
    required this.kPressionMoins,
    required this.kPressionPlus,
    required this.kV0Moins,
    required this.kV0Plus,
    required this.kMasseMoins,
    required this.kMassePlus,
  });
}

class TableauFService {
  final String typeTir;
  final String charge;
  final bool verbose;

  TableauFService({
    Object? systeme,
    required this.typeTir,
    required this.charge,
    bool tirMontagne = false,
    this.verbose = false,
  });

  bool _loaded = false;
  final List<_TableauFRow> _rows = <_TableauFRow>[];

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
      throw FormatException('[TableauF] FTBL trop court: ${bytes.length}');
    }

    final data = ByteData.sublistView(bytes);
    final magic = ascii.decode(bytes.sublist(0, 4));

    if (magic != 'FTBL') {
      throw FormatException('[Table F] Invalid magic: $magic');
    }

    final version = data.getUint8(4);
    if (version != 1) {
      throw FormatException('[Table F] Unsupported version: $version');
    }

    final rowCount = data.getUint32(5, Endian.little);
    final expectedSize = headerSize + rowCount * rowSize;

    if (bytes.length != expectedSize) {
      throw FormatException(
        '[Table F] Invalid size: expected=$expectedSize actual=${bytes.length}',
      );
    }

    _rows.clear();
    var offset = headerSize;

    for (var i = 0; i < rowCount; i++) {
      final elevation = data.getUint16(offset, Endian.little);
      offset += 2;

      final dXScaled = data.getInt16(offset, Endian.little);
      offset += 2;

      final dZScaled = data.getInt16(offset, Endian.little);
      offset += 2;

      _rows.add(
        _TableauFRow(
          elevationMil: elevation,
          dXDerivM: dXScaled / 10.0,
          dZDerivM: dZScaled / 10.0,
        ),
      );
    }

    _rows.sort((a, b) => a.elevationMil.compareTo(b.elevationMil));
  }

  Future<_TableauFRow?> getRowAt(int elevationMil) async {
    await load();
    if (_rows.isEmpty) return null;

    if (elevationMil <= _rows.first.elevationMil) return _rows.first;
    if (elevationMil >= _rows.last.elevationMil) return _rows.last;

    for (var i = 1; i < _rows.length; i++) {
      if (elevationMil <= _rows[i].elevationMil) {
        final r0 = _rows[i - 1];
        final r1 = _rows[i];
        final u = (elevationMil - r0.elevationMil) /
            (r1.elevationMil - r0.elevationMil);

        return _TableauFRow(
          elevationMil: elevationMil,
          dXDerivM: r0.dXDerivM + (r1.dXDerivM - r0.dXDerivM) * u,
          dZDerivM: r0.dZDerivM + (r1.dZDerivM - r0.dZDerivM) * u,
        );
      }
    }
    return _rows.last;
  }

  Never _unsupported(String member) => throw UnsupportedError(
        'TableauFService.$member is unavailable in this compatibility build.',
      );

  Future<double?> bondPorteeParMil({
    required double distance,
    bool tirMontagne = false,
  }) async =>
      _unsupported('bondPorteeParMil');

  Future<double?> hausseMil({
    required double distance,
    bool tirMontagne = false,
  }) async =>
      _unsupported('hausseMil');

  Future<double?> correctionWz({
    required double distance,
    bool tirMontagne = false,
  }) async =>
      _unsupported('correctionWz');

  Future<double?> deriveMil({
    required double distance,
    bool tirMontagne = false,
  }) async =>
      _unsupported('deriveMil');

  Future<FLongCoeffs?> correctionsLongitudinales({
    required double distance,
    bool tirMontagne = false,
  }) async =>
      _unsupported('correctionsLongitudinales');

  Future<double> tempageSeconds({
    required double distance,
    bool tirMontagne = false,
  }) async =>
      _unsupported('tempageSeconds');
}
