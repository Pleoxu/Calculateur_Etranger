import 'dart:typed_data';

import 'package:calculateur_etranger/services/m252/m252_table_codec.dart';

class M819TableFormatException implements Exception {
  const M819TableFormatException(this.message);

  final String message;

  @override
  String toString() => 'M819 table format error: $message';
}

class M819TrajectoryRow {
  const M819TrajectoryRow({
    required this.distanceM,
    required this.elevationMil,
    required this.fuzeSetting,
    required this.probableBurstHeightErrorM,
    required this.probableBurstTimeErrorS,
    required this.probableBurstRangeErrorM,
    required this.timeOfFlightS,
    required this.weatherLine,
    required this.azimuthCorrectionMilPerKnot,
    required this.v0DecreaseMPerMs,
    required this.v0IncreaseMPerMs,
    required this.headwindMPerKnot,
    required this.tailwindMPerKnot,
    required this.airTemperatureDecreaseMPerPct,
    required this.airTemperatureIncreaseMPerPct,
    required this.airDensityDecreaseMPerPct,
    required this.airDensityIncreaseMPerPct,
  });

  final double distanceM;
  final double elevationMil;

  /// Table D column 3, M772 setting. It is a setting, never a time in seconds.
  final double fuzeSetting;
  final double probableBurstHeightErrorM;
  final double probableBurstTimeErrorS;
  final double probableBurstRangeErrorM;
  final double timeOfFlightS;
  final int weatherLine;

  /// Table D column 11 (CW of 1 knot). The source may leave it blank.
  final double? azimuthCorrectionMilPerKnot;

  /// Table D columns 12–19. These range corrections are in metres for the
  /// named unit change; their signs are preserved from the published table.
  final double? v0DecreaseMPerMs;
  final double? v0IncreaseMPerMs;
  final double? headwindMPerKnot;
  final double? tailwindMPerKnot;
  final double? airTemperatureDecreaseMPerPct;
  final double? airTemperatureIncreaseMPerPct;
  final double? airDensityDecreaseMPerPct;
  final double? airDensityIncreaseMPerPct;
}

class M819TrajectoryTable {
  const M819TrajectoryTable(this.rows);

  final List<M819TrajectoryRow> rows;

  M819TrajectoryRow atDistance(double distanceM) => _interpolate(
        rows,
        distanceM,
        (row) => row.distanceM,
        (left, right, ratio) => M819TrajectoryRow(
          distanceM: distanceM,
          elevationMil: _lerp(left.elevationMil, right.elevationMil, ratio),
          fuzeSetting: _lerp(left.fuzeSetting, right.fuzeSetting, ratio),
          probableBurstHeightErrorM: _lerp(
            left.probableBurstHeightErrorM,
            right.probableBurstHeightErrorM,
            ratio,
          ),
          probableBurstTimeErrorS: _lerp(
            left.probableBurstTimeErrorS,
            right.probableBurstTimeErrorS,
            ratio,
          ),
          probableBurstRangeErrorM: _lerp(
            left.probableBurstRangeErrorM,
            right.probableBurstRangeErrorM,
            ratio,
          ),
          timeOfFlightS: _lerp(left.timeOfFlightS, right.timeOfFlightS, ratio),
          weatherLine: ratio < 1.0 ? left.weatherLine : right.weatherLine,
          azimuthCorrectionMilPerKnot: _nullableLerp(
            left.azimuthCorrectionMilPerKnot,
            right.azimuthCorrectionMilPerKnot,
            ratio,
          ),
          v0DecreaseMPerMs: _nullableLerp(
            left.v0DecreaseMPerMs,
            right.v0DecreaseMPerMs,
            ratio,
          ),
          v0IncreaseMPerMs: _nullableLerp(
            left.v0IncreaseMPerMs,
            right.v0IncreaseMPerMs,
            ratio,
          ),
          headwindMPerKnot: _nullableLerp(
            left.headwindMPerKnot,
            right.headwindMPerKnot,
            ratio,
          ),
          tailwindMPerKnot: _nullableLerp(
            left.tailwindMPerKnot,
            right.tailwindMPerKnot,
            ratio,
          ),
          airTemperatureDecreaseMPerPct: _nullableLerp(
            left.airTemperatureDecreaseMPerPct,
            right.airTemperatureDecreaseMPerPct,
            ratio,
          ),
          airTemperatureIncreaseMPerPct: _nullableLerp(
            left.airTemperatureIncreaseMPerPct,
            right.airTemperatureIncreaseMPerPct,
            ratio,
          ),
          airDensityDecreaseMPerPct: _nullableLerp(
            left.airDensityDecreaseMPerPct,
            right.airDensityDecreaseMPerPct,
            ratio,
          ),
          airDensityIncreaseMPerPct: _nullableLerp(
            left.airDensityIncreaseMPerPct,
            right.airDensityIncreaseMPerPct,
            ratio,
          ),
        ),
        table: 'M819 M772 Table D',
      );
}

class M819EffectsRow {
  const M819EffectsRow({
    required this.distanceM,
    required this.elevationMil,
    required this.elevationForBurstHeight50mTurns,
    required this.elevationForBurstHeight50mMil,
    required this.fuzeVariationFor50m,
    required this.elevationForBurstRange100mTurns,
    required this.elevationForBurstRange100mMil,
    required this.fuzeVariationFor100m,
    required this.trajectoryHeightM,
    required this.impactDistanceM,
  });

  final double distanceM;
  final double? elevationMil;
  final double? elevationForBurstHeight50mTurns;
  final double? elevationForBurstHeight50mMil;
  final double? fuzeVariationFor50m;
  final double? elevationForBurstRange100mTurns;
  final double? elevationForBurstRange100mMil;
  final double? fuzeVariationFor100m;
  final double? trajectoryHeightM;
  final double? impactDistanceM;
}

class M819EffectsTable {
  const M819EffectsTable(this.rows);

  final List<M819EffectsRow> rows;

  M819EffectsRow atDistance(double distanceM) => _interpolate(
        rows,
        distanceM,
        (row) => row.distanceM,
        (left, right, ratio) => M819EffectsRow(
          distanceM: distanceM,
          elevationMil:
              _nullableLerp(left.elevationMil, right.elevationMil, ratio),
          elevationForBurstHeight50mTurns: _nullableLerp(
            left.elevationForBurstHeight50mTurns,
            right.elevationForBurstHeight50mTurns,
            ratio,
          ),
          elevationForBurstHeight50mMil: _nullableLerp(
            left.elevationForBurstHeight50mMil,
            right.elevationForBurstHeight50mMil,
            ratio,
          ),
          fuzeVariationFor50m: _nullableLerp(
            left.fuzeVariationFor50m,
            right.fuzeVariationFor50m,
            ratio,
          ),
          elevationForBurstRange100mTurns: _nullableLerp(
            left.elevationForBurstRange100mTurns,
            right.elevationForBurstRange100mTurns,
            ratio,
          ),
          elevationForBurstRange100mMil: _nullableLerp(
            left.elevationForBurstRange100mMil,
            right.elevationForBurstRange100mMil,
            ratio,
          ),
          fuzeVariationFor100m: _nullableLerp(
            left.fuzeVariationFor100m,
            right.fuzeVariationFor100m,
            ratio,
          ),
          trajectoryHeightM: _nullableLerp(
            left.trajectoryHeightM,
            right.trajectoryHeightM,
            ratio,
          ),
          impactDistanceM: _nullableLerp(
            left.impactDistanceM,
            right.impactDistanceM,
            ratio,
          ),
        ),
        table: 'M819 M772 Table E',
      );
}

class M819FuzeFactorsRow {
  const M819FuzeFactorsRow({
    required this.fuzeSetting,
    required this.v0Dec,
    required this.v0Inc,
    required this.headwind,
    required this.tailwind,
    required this.airTemperatureDec,
    required this.airTemperatureInc,
    required this.airDensityDec,
    required this.airDensityInc,
  });

  final double fuzeSetting;
  final double v0Dec;
  final double v0Inc;
  final double headwind;
  final double tailwind;
  final double airTemperatureDec;
  final double airTemperatureInc;
  final double airDensityDec;
  final double airDensityInc;
}

class M819FuzeFactorsTable {
  const M819FuzeFactorsTable(this.rows);

  final List<M819FuzeFactorsRow> rows;

  /// Table F publishes discrete M772 settings while Table D gives a setting
  /// to one decimal. Use the closest *published* Table-F line; this is a
  /// lookup, not an extrapolation of factors beyond the printed table.
  M819FuzeFactorsRow atNearestPublishedFuzeSetting(double setting) {
    if (rows.isEmpty) {
      throw const M819TableFormatException('M819 Table F has no rows.');
    }
    return rows.reduce((best, candidate) {
      final candidateGap = (candidate.fuzeSetting - setting).abs();
      final bestGap = (best.fuzeSetting - setting).abs();
      if (candidateGap < bestGap) return candidate;
      if (candidateGap == bestGap && candidate.fuzeSetting < best.fuzeSetting) {
        return candidate;
      }
      return best;
    });
  }

  M819FuzeFactorsRow atFuzeSetting(double setting) => _interpolate(
        rows,
        setting,
        (row) => row.fuzeSetting,
        (left, right, ratio) => M819FuzeFactorsRow(
          fuzeSetting: setting,
          v0Dec: _lerp(left.v0Dec, right.v0Dec, ratio),
          v0Inc: _lerp(left.v0Inc, right.v0Inc, ratio),
          headwind: _lerp(left.headwind, right.headwind, ratio),
          tailwind: _lerp(left.tailwind, right.tailwind, ratio),
          airTemperatureDec: _lerp(
            left.airTemperatureDec,
            right.airTemperatureDec,
            ratio,
          ),
          airTemperatureInc: _lerp(
            left.airTemperatureInc,
            right.airTemperatureInc,
            ratio,
          ),
          airDensityDec: _lerp(left.airDensityDec, right.airDensityDec, ratio),
          airDensityInc: _lerp(left.airDensityInc, right.airDensityInc, ratio),
        ),
        table: 'M819 M772 Table F',
      );
}

class M819ReferenceTables {
  const M819ReferenceTables({
    required this.wind,
    required this.airDensity,
    required this.powderTemperature,
    required this.trajectory,
    required this.effects,
    required this.fuzeFactors,
  });

  final M252WindTable wind;
  final M252AirDensityTable airDensity;
  final M252PowderTemperatureTable powderTemperature;
  final M819TrajectoryTable trajectory;
  final M819EffectsTable effects;
  final M819FuzeFactorsTable fuzeFactors;
}

abstract final class M819TableCodec {
  static M819TrajectoryTable decodeTrajectory(Uint8List bytes) {
    final header = _header(bytes, magic: 'M8D2', rowSize: 68);
    final data = ByteData.sublistView(bytes);
    final rows = <M819TrajectoryRow>[];
    var offset = 9;
    for (var index = 0; index < header.rowCount; index++) {
      double value(int field) =>
          data.getFloat32(offset + field * 4, Endian.little);
      final validMask = data.getUint16(offset + 65, Endian.little);
      if ((validMask & ~0x01ff) != 0 || data.getUint8(offset + 67) != 0) {
        throw M819TableFormatException('Invalid M8D2 flags at row $index.');
      }
      double? optional(int bit, int field) =>
          (validMask & (1 << bit)) == 0 ? null : value(field);
      final distance = value(0);
      if (!distance.isFinite ||
          (rows.isNotEmpty && distance <= rows.last.distanceM)) {
        throw M819TableFormatException('Invalid M8D2 distance at row $index.');
      }
      final weatherLine = data.getUint8(offset + 64);
      if (weatherLine > 15) {
        throw M819TableFormatException('Invalid M8D2 LINE NO. at row $index.');
      }
      rows.add(M819TrajectoryRow(
        distanceM: distance,
        elevationMil: value(1),
        fuzeSetting: value(2),
        probableBurstHeightErrorM: value(3),
        probableBurstTimeErrorS: value(4),
        probableBurstRangeErrorM: value(5),
        timeOfFlightS: value(6),
        azimuthCorrectionMilPerKnot: optional(0, 7),
        v0DecreaseMPerMs: optional(1, 8),
        v0IncreaseMPerMs: optional(2, 9),
        headwindMPerKnot: optional(3, 10),
        tailwindMPerKnot: optional(4, 11),
        airTemperatureDecreaseMPerPct: optional(5, 12),
        airTemperatureIncreaseMPerPct: optional(6, 13),
        airDensityDecreaseMPerPct: optional(7, 14),
        airDensityIncreaseMPerPct: optional(8, 15),
        weatherLine: weatherLine,
      ));
      offset += 68;
    }
    return M819TrajectoryTable(rows);
  }

  static M819EffectsTable decodeEffects(Uint8List bytes) {
    final header = _header(bytes, magic: 'M8E1', rowSize: 44);
    final data = ByteData.sublistView(bytes);
    final rows = <M819EffectsRow>[];
    var offset = 9;
    for (var index = 0; index < header.rowCount; index++) {
      double value(int field) =>
          data.getFloat32(offset + field * 4, Endian.little);
      final validMask = data.getUint16(offset + 40, Endian.little);
      if ((validMask & ~0x01ff) != 0 ||
          data.getUint16(offset + 42, Endian.little) != 0) {
        throw M819TableFormatException('Invalid M8E1 flags at row $index.');
      }
      double? optional(int field) =>
          (validMask & (1 << field)) == 0 ? null : value(field + 1);
      final distance = value(0);
      if (!distance.isFinite ||
          (rows.isNotEmpty && distance <= rows.last.distanceM)) {
        throw M819TableFormatException('Invalid M8E1 distance at row $index.');
      }
      rows.add(M819EffectsRow(
        distanceM: distance,
        elevationMil: optional(0),
        elevationForBurstHeight50mTurns: optional(1),
        elevationForBurstHeight50mMil: optional(2),
        fuzeVariationFor50m: optional(3),
        elevationForBurstRange100mTurns: optional(4),
        elevationForBurstRange100mMil: optional(5),
        fuzeVariationFor100m: optional(6),
        trajectoryHeightM: optional(7),
        impactDistanceM: optional(8),
      ));
      offset += 44;
    }
    return M819EffectsTable(rows);
  }

  static M819FuzeFactorsTable decodeFuzeFactors(Uint8List bytes) {
    final header = _header(bytes, magic: 'M8F1', rowSize: 36);
    final data = ByteData.sublistView(bytes);
    final rows = <M819FuzeFactorsRow>[];
    var offset = 9;
    for (var index = 0; index < header.rowCount; index++) {
      double value(int field) =>
          data.getFloat32(offset + field * 4, Endian.little);
      final setting = value(0);
      if (!setting.isFinite ||
          (rows.isNotEmpty && setting <= rows.last.fuzeSetting)) {
        throw M819TableFormatException('Invalid M8F1 setting at row $index.');
      }
      rows.add(M819FuzeFactorsRow(
        fuzeSetting: setting,
        v0Dec: value(1),
        v0Inc: value(2),
        headwind: value(3),
        tailwind: value(4),
        airTemperatureDec: value(5),
        airTemperatureInc: value(6),
        airDensityDec: value(7),
        airDensityInc: value(8),
      ));
      offset += 36;
    }
    return M819FuzeFactorsTable(rows);
  }

  static _Header _header(
    Uint8List bytes, {
    required String magic,
    required int rowSize,
  }) {
    if (bytes.length < 9 ||
        String.fromCharCodes(bytes.sublist(0, 4)) != magic) {
      throw M819TableFormatException('Invalid $magic header.');
    }
    final data = ByteData.sublistView(bytes);
    if (data.getUint8(4) != 1) {
      throw M819TableFormatException('$magic version 1 is required.');
    }
    final rows = data.getUint32(5, Endian.little);
    if (rows == 0 || bytes.length != 9 + rows * rowSize) {
      throw M819TableFormatException('Invalid $magic payload length.');
    }
    return _Header(rows);
  }
}

class _Header {
  const _Header(this.rowCount);
  final int rowCount;
}

T _interpolate<T>(
  List<T> rows,
  double target,
  double Function(T row) abscissa,
  T Function(T left, T right, double ratio) make, {
  required String table,
}) {
  final minimum = abscissa(rows.first);
  final maximum = abscissa(rows.last);
  if (target < minimum || target > maximum) {
    throw M252TableRangeException(
      table: table,
      value: target,
      minimum: minimum,
      maximum: maximum,
    );
  }
  for (var index = 0; index < rows.length - 1; index++) {
    final left = rows[index];
    final right = rows[index + 1];
    final leftValue = abscissa(left);
    final rightValue = abscissa(right);
    if (target >= leftValue && target <= rightValue) {
      final ratio = rightValue == leftValue
          ? 0.0
          : (target - leftValue) / (rightValue - leftValue);
      return make(left, right, ratio);
    }
  }
  return rows.last;
}

double _lerp(double left, double right, double ratio) =>
    left + (right - left) * ratio;

double? _nullableLerp(double? left, double? right, double ratio) {
  if (left == null || right == null) return null;
  return _lerp(left, right, ratio);
}
