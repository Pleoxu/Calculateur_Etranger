import 'dart:typed_data';

class M252TableFormatException implements Exception {
  const M252TableFormatException(this.message);

  final String message;

  @override
  String toString() => 'M252 table format error: $message';
}

class M252TableRangeException implements Exception {
  const M252TableRangeException({
    required this.table,
    required this.value,
    required this.minimum,
    required this.maximum,
  });

  final String table;
  final double value;
  final double minimum;
  final double maximum;

  @override
  String toString() =>
      '$table has no value for $value (domain $minimum..$maximum).';
}

class M252WindVector {
  const M252WindVector({required this.wz, required this.wx});

  final double wz;
  final double wx;
}

class M252WindTable {
  const M252WindTable(this._angles, this._vectors);

  final List<double> _angles;
  final List<M252WindVector> _vectors;

  int get length => _angles.length;

  M252WindVector atAngleMil(double angleMil) {
    var normalized = angleMil % 6400.0;
    if (normalized < 0) normalized += 6400.0;
    if (normalized == 6400.0) normalized = 0.0;

    for (var index = 0; index < _angles.length - 1; index++) {
      final left = _angles[index];
      final right = _angles[index + 1];
      if (normalized >= left && normalized <= right) {
        final ratio =
            right == left ? 0.0 : (normalized - left) / (right - left);
        return M252WindVector(
          wz: _lerp(_vectors[index].wz, _vectors[index + 1].wz, ratio),
          wx: _lerp(_vectors[index].wx, _vectors[index + 1].wx, ratio),
        );
      }
    }

    // The supplied table includes the 6400-mil duplicate of the origin. The
    // guard only protects malformed but otherwise decodable payloads.
    return _vectors.first;
  }
}

class M252AirDensityRow {
  const M252AirDensityRow({
    required this.deltaAltitudeM,
    required this.deltaTemperaturePct,
    required this.deltaPressurePct,
  });

  final double deltaAltitudeM;
  final double deltaTemperaturePct;
  final double deltaPressurePct;
}

class M252AirDensityTable {
  const M252AirDensityTable(this.rows);

  final List<M252AirDensityRow> rows;

  M252AirDensityRow atAbsoluteDeltaAltitude(double deltaAltitudeM) {
    final absolute = deltaAltitudeM.abs();
    return _interpolate(
      rows,
      absolute,
      (row) => row.deltaAltitudeM,
      (left, right, ratio) => M252AirDensityRow(
        deltaAltitudeM: absolute,
        deltaTemperaturePct: _lerp(
          left.deltaTemperaturePct,
          right.deltaTemperaturePct,
          ratio,
        ),
        deltaPressurePct: _lerp(
          left.deltaPressurePct,
          right.deltaPressurePct,
          ratio,
        ),
      ),
      table: 'M252 BEBTL air-density table',
    );
  }
}

class M252PowderTemperatureRow {
  const M252PowderTemperatureRow({
    required this.temperatureF,
    required this.deltaVoMs,
  });

  final double temperatureF;
  final double deltaVoMs;
}

class M252PowderTemperatureTable {
  const M252PowderTemperatureTable(this.rows);

  final List<M252PowderTemperatureRow> rows;

  M252PowderTemperatureRow atCelsius(double temperatureC) {
    return atFahrenheit(temperatureC * 9.0 / 5.0 + 32.0);
  }

  M252PowderTemperatureRow atFahrenheit(double temperatureF) {
    return _interpolate(
      rows,
      temperatureF,
      (row) => row.temperatureF,
      (left, right, ratio) => M252PowderTemperatureRow(
        temperatureF: temperatureF,
        deltaVoMs: _lerp(left.deltaVoMs, right.deltaVoMs, ratio),
      ),
      table: 'M252 CEBTL powder-temperature table',
    );
  }
}

class M252TrajectoryRow {
  const M252TrajectoryRow({
    required this.distanceM,
    required this.elevationMil,
    required this.driftMil,
    required this.crosswindMilPerKnot,
    required this.elevationChangePer100m,
    required this.v0MinusMPerMs,
    required this.v0PlusMPerMs,
    required this.headwindMPerKnot,
    required this.tailwindMPerKnot,
    required this.temperatureMinusMPerPct,
    required this.temperaturePlusMPerPct,
    required this.pressureMinusMPerPct,
    required this.pressurePlusMPerPct,
    required this.massMinusM,
    required this.massPlusM,
    required this.timeOfFlightS,
    required this.elevationVariationPer100m,
    required this.tirMontagne,
    required this.validMask,
    required this.turnsPer100m,
    required this.weatherLine,
  });

  final double distanceM;
  final double elevationMil;
  final double driftMil;
  final double crosswindMilPerKnot;
  final double elevationChangePer100m;
  final double v0MinusMPerMs;
  final double v0PlusMPerMs;
  final double headwindMPerKnot;
  final double tailwindMPerKnot;
  final double temperatureMinusMPerPct;
  final double temperaturePlusMPerPct;
  final double pressureMinusMPerPct;
  final double pressurePlusMPerPct;
  final double massMinusM;
  final double massPlusM;
  final double timeOfFlightS;
  final double elevationVariationPer100m;
  final bool tirMontagne;
  final int validMask;
  final int turnsPer100m;

  /// Doctrinal `LINE NO.` sourced from M252 Table D (discrete, never interpolated).
  final int weatherLine;
}

class M252TrajectoryTable {
  const M252TrajectoryTable(this.rows);

  final List<M252TrajectoryRow> rows;

  M252TrajectoryRow atDistance(double distanceM) {
    return _interpolate(
      rows,
      distanceM,
      (row) => row.distanceM,
      (left, right, ratio) => M252TrajectoryRow(
        distanceM: distanceM,
        elevationMil: _lerp(left.elevationMil, right.elevationMil, ratio),
        driftMil: _lerp(left.driftMil, right.driftMil, ratio),
        crosswindMilPerKnot: _lerp(
          left.crosswindMilPerKnot,
          right.crosswindMilPerKnot,
          ratio,
        ),
        elevationChangePer100m: _lerp(
          left.elevationChangePer100m,
          right.elevationChangePer100m,
          ratio,
        ),
        v0MinusMPerMs: _lerp(left.v0MinusMPerMs, right.v0MinusMPerMs, ratio),
        v0PlusMPerMs: _lerp(left.v0PlusMPerMs, right.v0PlusMPerMs, ratio),
        headwindMPerKnot: _lerp(
          left.headwindMPerKnot,
          right.headwindMPerKnot,
          ratio,
        ),
        tailwindMPerKnot: _lerp(
          left.tailwindMPerKnot,
          right.tailwindMPerKnot,
          ratio,
        ),
        temperatureMinusMPerPct: _lerp(
          left.temperatureMinusMPerPct,
          right.temperatureMinusMPerPct,
          ratio,
        ),
        temperaturePlusMPerPct: _lerp(
          left.temperaturePlusMPerPct,
          right.temperaturePlusMPerPct,
          ratio,
        ),
        pressureMinusMPerPct: _lerp(
          left.pressureMinusMPerPct,
          right.pressureMinusMPerPct,
          ratio,
        ),
        pressurePlusMPerPct: _lerp(
          left.pressurePlusMPerPct,
          right.pressurePlusMPerPct,
          ratio,
        ),
        massMinusM: _lerp(left.massMinusM, right.massMinusM, ratio),
        massPlusM: _lerp(left.massPlusM, right.massPlusM, ratio),
        timeOfFlightS: _lerp(left.timeOfFlightS, right.timeOfFlightS, ratio),
        elevationVariationPer100m: _lerp(
          left.elevationVariationPer100m,
          right.elevationVariationPer100m,
          ratio,
        ),
        tirMontagne: left.tirMontagne,
        validMask: left.validMask,
        turnsPer100m: left.turnsPer100m,
        weatherLine: ratio < 1.0 ? left.weatherLine : right.weatherLine,
      ),
      table: 'M252 DEBTL trajectory table',
    );
  }
}

class M252DispersionRow {
  const M252DispersionRow({
    required this.distanceM,
    required this.elevationMil,
    required this.probableRangeErrorM,
    required this.probableDirectionErrorM,
    required this.impactAngleMil,
    required this.impactCotangent,
    required this.remainingVelocityMs,
    required this.trajectoryHeightM,
    required this.tirMontagne,
  });

  final double distanceM;
  final double elevationMil;
  final double probableRangeErrorM;
  final double probableDirectionErrorM;
  final double impactAngleMil;
  final double impactCotangent;
  final double remainingVelocityMs;
  final double trajectoryHeightM;
  final bool tirMontagne;
}

class M252DispersionTable {
  const M252DispersionTable(this.rows);

  final List<M252DispersionRow> rows;

  M252DispersionRow atDistance(double distanceM) {
    return _interpolate(
      rows,
      distanceM,
      (row) => row.distanceM,
      (left, right, ratio) => M252DispersionRow(
        distanceM: distanceM,
        elevationMil: _lerp(left.elevationMil, right.elevationMil, ratio),
        probableRangeErrorM: _lerp(
          left.probableRangeErrorM,
          right.probableRangeErrorM,
          ratio,
        ),
        probableDirectionErrorM: _lerp(
          left.probableDirectionErrorM,
          right.probableDirectionErrorM,
          ratio,
        ),
        impactAngleMil: _lerp(left.impactAngleMil, right.impactAngleMil, ratio),
        impactCotangent: _lerp(
          left.impactCotangent,
          right.impactCotangent,
          ratio,
        ),
        remainingVelocityMs: _lerp(
          left.remainingVelocityMs,
          right.remainingVelocityMs,
          ratio,
        ),
        trajectoryHeightM: _lerp(
          left.trajectoryHeightM,
          right.trajectoryHeightM,
          ratio,
        ),
        tirMontagne: left.tirMontagne,
      ),
      table: 'M252 EEBTL dispersion table',
    );
  }
}

class M252ReferenceTables {
  const M252ReferenceTables({
    required this.wind,
    required this.airDensity,
    required this.powderTemperature,
    required this.trajectory,
    required this.dispersion,
  });

  final M252WindTable wind;
  final M252AirDensityTable airDensity;
  final M252PowderTemperatureTable powderTemperature;
  final M252TrajectoryTable trajectory;
  final M252DispersionTable dispersion;
}

class M252TableCodec {
  const M252TableCodec._();

  static M252WindTable decodeWind(Uint8List bytes) {
    final header = _header(bytes, expectedMagic: 'AEBT', rowSize: 6);
    final data = ByteData.sublistView(bytes);
    final angles = <double>[];
    final vectors = <M252WindVector>[];
    var offset = 9;
    for (var index = 0; index < header.rowCount; index++) {
      final angle = data.getUint16(offset, Endian.little);
      final wz = data.getUint16(offset + 2, Endian.little) / 100.0;
      final wx = data.getUint16(offset + 4, Endian.little) / 100.0;
      if (angle > 6400 || angle % 100 != 0 || wz > 1 || wx > 1) {
        throw M252TableFormatException('Invalid AEBTL row $index.');
      }
      if (angles.isNotEmpty && angle <= angles.last) {
        throw M252TableFormatException(
          'AEBTL angles are not strictly ascending.',
        );
      }
      angles.add(angle.toDouble());
      vectors.add(M252WindVector(wz: wz, wx: wx));
      offset += 6;
    }
    if (angles.first != 0 || angles.last != 6400) {
      throw const M252TableFormatException('AEBTL must cover 0..6400 mil.');
    }
    return M252WindTable(angles, vectors);
  }

  static M252AirDensityTable decodeAirDensity(Uint8List bytes) {
    final header = _header(bytes, expectedMagic: 'BEBT', rowSize: 6);
    final data = ByteData.sublistView(bytes);
    final rows = <M252AirDensityRow>[];
    var offset = 9;
    for (var index = 0; index < header.rowCount; index++) {
      final altitude = data.getInt16(offset, Endian.little).toDouble();
      final temp = data.getInt16(offset + 2, Endian.little) / 10.0;
      final pressure = data.getInt16(offset + 4, Endian.little) / 10.0;
      if (altitude < 0 ||
          (rows.isNotEmpty && altitude <= rows.last.deltaAltitudeM)) {
        throw M252TableFormatException('Invalid BEBTL altitude row $index.');
      }
      rows.add(
        M252AirDensityRow(
          deltaAltitudeM: altitude,
          deltaTemperaturePct: temp,
          deltaPressurePct: pressure,
        ),
      );
      offset += 6;
    }
    return M252AirDensityTable(rows);
  }

  static M252PowderTemperatureTable decodePowderTemperature(Uint8List bytes) {
    final header = _header(bytes, expectedMagic: 'CEBT', rowSize: 4);
    final data = ByteData.sublistView(bytes);
    final rows = <M252PowderTemperatureRow>[];
    var offset = 9;
    for (var index = 0; index < header.rowCount; index++) {
      final temperatureF = data.getInt16(offset, Endian.little).toDouble();
      final deltaVo = data.getInt16(offset + 2, Endian.little) / 10.0;
      if (temperatureF % 5 != 0 ||
          (rows.isNotEmpty && temperatureF <= rows.last.temperatureF)) {
        throw M252TableFormatException('Invalid CEBTL temperature row $index.');
      }
      rows.add(
        M252PowderTemperatureRow(
          temperatureF: temperatureF,
          deltaVoMs: deltaVo,
        ),
      );
      offset += 4;
    }
    return M252PowderTemperatureTable(rows);
  }

  static M252TrajectoryTable decodeTrajectory(Uint8List bytes) {
    final header = _header(
      bytes,
      expectedMagic: 'DEBT',
      rowSize: 75,
      expectedVersion: 2,
    );
    final data = ByteData.sublistView(bytes);
    final rows = <M252TrajectoryRow>[];
    var offset = 9;
    for (var index = 0; index < header.rowCount; index++) {
      double value(int field) =>
          data.getFloat32(offset + field * 4, Endian.little);
      final flags = data.getUint8(offset + 68);
      final validMask = data.getUint32(offset + 69, Endian.little);
      final turns = data.getUint16(offset + 73, Endian.little);
      // bit 0: mountain-fire flag; bits 4..7: Table D LINE NO.; bits 1..3 reserved.
      if ((flags & 0x0e) != 0 || turns == 0) {
        throw M252TableFormatException('Invalid DEBTL flags at row $index.');
      }
      final weatherLine = flags >> 4;
      final distance = value(0);
      if (!distance.isFinite ||
          (rows.isNotEmpty && distance <= rows.last.distanceM)) {
        throw M252TableFormatException('Invalid DEBTL distance at row $index.');
      }
      rows.add(
        M252TrajectoryRow(
          distanceM: distance,
          elevationMil: value(1),
          driftMil: value(2),
          crosswindMilPerKnot: value(3),
          elevationChangePer100m: value(4),
          v0MinusMPerMs: value(5),
          v0PlusMPerMs: value(6),
          headwindMPerKnot: value(7),
          tailwindMPerKnot: value(8),
          temperatureMinusMPerPct: value(9),
          temperaturePlusMPerPct: value(10),
          pressureMinusMPerPct: value(11),
          pressurePlusMPerPct: value(12),
          massMinusM: value(13),
          massPlusM: value(14),
          timeOfFlightS: value(15),
          elevationVariationPer100m: value(16),
          tirMontagne: (flags & 0x01) != 0,
          validMask: validMask,
          turnsPer100m: turns,
          weatherLine: weatherLine,
        ),
      );
      offset += 75;
    }
    return M252TrajectoryTable(rows);
  }

  static M252DispersionTable decodeDispersion(Uint8List bytes) {
    final header = _header(
      bytes,
      expectedMagic: 'EEBT',
      rowSize: 55,
      acceptedVersions: const <int>{1, 2},
    );
    final data = ByteData.sublistView(bytes);
    final rows = <M252DispersionRow>[];
    var offset = 9;
    for (var index = 0; index < header.rowCount; index++) {
      double value(int field) =>
          data.getFloat32(offset + field * 4, Endian.little);
      final flags = data.getUint8(offset + 52);
      final reserved = data.getUint16(offset + 53, Endian.little);
      final allowedFlags = header.version == 2 ? 0x03 : 0x01;
      if ((flags & ~allowedFlags) != 0 || reserved != 0) {
        throw M252TableFormatException('Invalid EEBTL flags at row $index.');
      }
      final distance = value(0);
      if (!distance.isFinite ||
          (rows.isNotEmpty && distance <= rows.last.distanceM)) {
        throw M252TableFormatException('Invalid EEBTL distance at row $index.');
      }
      rows.add(
        M252DispersionRow(
          distanceM: distance,
          elevationMil: value(1),
          // EEBTL_V2 bit 1 means that the source did not publish EPP at this
          // range. CalculResult keeps a non-null legacy field, so unavailable
          // values remain 0.0 and are identified by the binary flag.
          probableRangeErrorM: (flags & 0x02) == 0 ? value(2) : 0.0,
          probableDirectionErrorM: value(3),
          impactAngleMil: value(7),
          impactCotangent: value(8),
          remainingVelocityMs: value(9),
          trajectoryHeightM: value(10),
          tirMontagne: (flags & 0x01) != 0,
        ),
      );
      offset += 55;
    }
    return M252DispersionTable(rows);
  }

  static _TableHeader _header(
    Uint8List bytes, {
    required String expectedMagic,
    required int rowSize,
    int expectedVersion = 1,
    Set<int>? acceptedVersions,
  }) {
    if (bytes.length < 9) {
      throw M252TableFormatException('$expectedMagic header is incomplete.');
    }
    final magic = String.fromCharCodes(bytes.sublist(0, 4));
    if (magic != expectedMagic) {
      throw M252TableFormatException(
        'Expected $expectedMagic magic, received $magic.',
      );
    }
    final data = ByteData.sublistView(bytes);
    final version = data.getUint8(4);
    final accepted = acceptedVersions ?? <int>{expectedVersion};
    if (!accepted.contains(version)) {
      throw M252TableFormatException(
        '$expectedMagic version ${accepted.join(' or ')} is required.',
      );
    }
    final rowCount = data.getUint32(5, Endian.little);
    final expectedSize = 9 + rowCount * rowSize;
    if (bytes.length != expectedSize) {
      throw M252TableFormatException(
        '$expectedMagic has ${bytes.length} bytes; expected $expectedSize.',
      );
    }
    if (rowCount == 0) {
      throw M252TableFormatException('$expectedMagic has no rows.');
    }
    return _TableHeader(rowCount, version);
  }
}

class _TableHeader {
  const _TableHeader(this.rowCount, this.version);

  final int rowCount;
  final int version;
}

T _interpolate<T>(
  List<T> rows,
  double target,
  double Function(T row) value,
  T Function(T left, T right, double ratio) create, {
  required String table,
}) {
  final minimum = value(rows.first);
  final maximum = value(rows.last);
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
    final leftValue = value(left);
    final rightValue = value(right);
    if (target >= leftValue && target <= rightValue) {
      final ratio = rightValue == leftValue
          ? 0.0
          : (target - leftValue) / (rightValue - leftValue);
      return create(left, right, ratio);
    }
  }
  return rows.last;
}

double _lerp(double left, double right, double ratio) =>
    left + (right - left) * ratio;
