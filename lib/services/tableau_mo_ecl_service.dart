// lib/services/tableau_mo_ecl_service.dart

import 'dart:io';
import 'package:calculateur_etranger/security/native_secure_assets.dart';
import 'package:flutter/foundation.dart';

import 'secure_asset_resolver.dart';

class TableauMoEclRow {
  final double porteeM;
  final double hausseMil;
  final double? corrHausse50Mil;
  final double? corrEvent50S;
  final double eventS;
  final bool tirMontagne;

  const TableauMoEclRow({
    required this.porteeM,
    required this.hausseMil,
    required this.corrHausse50Mil,
    required this.corrEvent50S,
    required this.eventS,
    required this.tirMontagne,
  });
}

class TableauMoEclService {
  static const int _headerSize = 9;
  static const int _rowSize = 15;

  static final Map<String, Future<List<TableauMoEclRow>>> _cache = {};

  final String charge;
  final bool tirMontagne;
  final SecureAssetResolver _resolver;

  const TableauMoEclService({
    required this.charge,
    required this.tirMontagne,
    SecureAssetResolver resolver = const SecureAssetResolver(),
  }) : _resolver = resolver;

  String get _relativeEncryptedPath => _resolver.encryptedAsset(
        systeme: SystemeArme.mo,
        famille: 'ECL',
        typeTir: 'OECL',
        charge: charge,
        extension: 'moecltbl',
      );

  String get _encryptedAssetPath => 'assets/secure_enc/$_relativeEncryptedPath';

  Future<void> load() async {
    await _rows();
  }

  Future<TableauMoEclRow> interpoler({
    required double distanceM,
    bool? tirMontagne,
  }) async {
    final branche = tirMontagne ?? this.tirMontagne;

    final rows = (await _rows())
        .where((row) => row.tirMontagne == branche)
        .toList()
      ..sort((a, b) => a.porteeM.compareTo(b.porteeM));

    if (rows.isEmpty) {
      throw StateError(
        '[MO_ECL] no rows for charge=$charge '
        'tirMontagne=$branche',
      );
    }

    if (distanceM < rows.first.porteeM || distanceM > rows.last.porteeM) {
      throw RangeError(
        '[MO_ECL] distance out of range for charge=$charge '
        'tirMontagne=$branche : '
        '${distanceM.toStringAsFixed(1)} m '
        '(domaine ${rows.first.porteeM.toStringAsFixed(0)}'
        '..${rows.last.porteeM.toStringAsFixed(0)} m)',
      );
    }

    for (final row in rows) {
      if ((row.porteeM - distanceM).abs() < 0.0001) {
        return row;
      }
    }

    for (var i = 1; i < rows.length; i++) {
      final upper = rows[i];

      if (distanceM <= upper.porteeM) {
        final lower = rows[i - 1];
        final span = upper.porteeM - lower.porteeM;

        if (span <= 0.0) {
          throw StateError(
            '[MO_ECL] ranges not strictly increasing '
            'charge=$charge tirMontagne=$branche',
          );
        }

        final u = (distanceM - lower.porteeM) / span;

        final result = TableauMoEclRow(
          porteeM: distanceM,
          hausseMil: _lerp(lower.hausseMil, upper.hausseMil, u),
          corrHausse50Mil: _lerpNullable(
            lower.corrHausse50Mil,
            upper.corrHausse50Mil,
            u,
          ),
          corrEvent50S: _lerpNullable(
            lower.corrEvent50S,
            upper.corrEvent50S,
            u,
          ),
          eventS: _lerp(lower.eventS, upper.eventS, u),
          tirMontagne: branche,
        );

        if (kDebugMode) {
          debugPrint(
            '[MO_ECL] charge=$charge TM=$branche '
            'distance=${distanceM.toStringAsFixed(1)} '
            'bounds=${lower.porteeM.toStringAsFixed(0)}'
            '..${upper.porteeM.toStringAsFixed(0)} '
            'u=${u.toStringAsFixed(4)} '
            'elevation=${result.hausseMil.toStringAsFixed(2)} '
            'event=${result.eventS.toStringAsFixed(2)}',
          );
        }

        return result;
      }
    }

    throw StateError(
      '[MO_ECL] interpolation impossible '
      'charge=$charge distance=$distanceM tirMontagne=$branche',
    );
  }

  Future<List<TableauMoEclRow>> _rows() {
    final key = '${charge.toUpperCase()}|$tirMontagne';

    return _cache.putIfAbsent(key, _loadAndDecode);
  }

  Future<List<TableauMoEclRow>> _loadAndDecode() async {
    final encryptedAssetPath = _encryptedAssetPath;

    final compressed = await NativeSecureAssets.decryptAsset(
      encryptedAssetPath,
    );

    final raw = Uint8List.fromList(gzip.decode(compressed));

    if (raw.length < _headerSize) {
      throw FormatException(
        '[MO_ECL] fichier trop court : $encryptedAssetPath',
      );
    }

    final data = ByteData.sublistView(raw);
    final magic = String.fromCharCodes(raw.sublist(0, 4));

    if (magic != 'MOEL') {
      throw FormatException(
        '[MO_ECL] Invalid magic: $magic ($encryptedAssetPath)',
      );
    }

    final version = data.getUint8(4);

    if (version != 1) {
      throw FormatException(
        '[MO_ECL] Invalid version: $version ($encryptedAssetPath)',
      );
    }

    final rowCount = data.getUint32(5, Endian.little);
    final expectedLength = _headerSize + rowCount * _rowSize;

    if (raw.length != expectedLength) {
      throw FormatException(
        '[MO_ECL] Invalid size: '
        '${raw.length}/$expectedLength ($encryptedAssetPath)',
      );
    }

    final rows = <TableauMoEclRow>[];
    var offset = _headerSize;

    for (var i = 0; i < rowCount; i++) {
      final porteeM = data.getUint16(offset, Endian.little).toDouble();
      offset += 2;

      final hausseMil = data.getInt32(offset, Endian.little).toDouble() / 100.0;
      offset += 4;

      final corrHausseRaw = data.getInt16(offset, Endian.little);
      offset += 2;

      final corrEventRaw = data.getInt16(offset, Endian.little);
      offset += 2;

      final eventS = data.getInt16(offset, Endian.little).toDouble() / 100.0;
      offset += 2;

      final flags = data.getUint8(offset);
      offset += 1;

      offset += 2; // réserve

      rows.add(
        TableauMoEclRow(
          porteeM: porteeM,
          hausseMil: hausseMil,
          corrHausse50Mil: (flags & 0x02) != 0 ? null : corrHausseRaw / 100.0,
          corrEvent50S: (flags & 0x04) != 0 ? null : corrEventRaw / 100.0,
          eventS: eventS,
          tirMontagne: (flags & 0x01) != 0,
        ),
      );
    }

    if (kDebugMode) {
      final normalCount = rows.where((row) => !row.tirMontagne).length;
      final montagneCount = rows.where((row) => row.tirMontagne).length;

      debugPrint(
        '[MO_ECL] OK charge=$charge rows=${rows.length} '
        'normal=$normalCount montagne=$montagneCount '
        'asset=$encryptedAssetPath',
      );
    }

    return List.unmodifiable(rows);
  }

  static double _lerp(double a, double b, double u) {
    return a + (b - a) * u;
  }

  static double? _lerpNullable(double? a, double? b, double u) {
    if (a == null || b == null) {
      return null;
    }

    return _lerp(a, b, u);
  }

  static void clearCache() {
    _cache.clear();
  }
}
