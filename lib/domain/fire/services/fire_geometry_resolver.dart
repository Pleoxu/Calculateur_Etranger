import 'dart:math' as math;

import 'package:calculateur_etranger/domain/fire/input/fire_request.dart';

class FireGeometryResult {
  final double latitudeDeg;
  final double distanceTopo;
  final double azimutMil;
  final double objXfinal;
  final double objYfinal;

  /// Coordonnées UTM de la pièce directrice (calculées depuis UTM, LatLon ou DAZ)
  final double pdX;
  final double pdY;

  const FireGeometryResult({
    required this.latitudeDeg,
    required this.distanceTopo,
    required this.azimutMil,
    required this.objXfinal,
    required this.objYfinal,
    required this.pdX,
    required this.pdY,
  });
}

class _UtmZoneParsed {
  final int zoneNumber;
  final bool isNorthHemisphere;

  const _UtmZoneParsed(this.zoneNumber, this.isNorthHemisphere);
}

class _LatLonDeg {
  final double latDeg;
  final double lonDeg;

  const _LatLonDeg(this.latDeg, this.lonDeg);
}

class _UtmPoint {
  final double easting;
  final double northing;
  final int zoneNumber;
  final bool isNorthHemisphere;

  const _UtmPoint({
    required this.easting,
    required this.northing,
    required this.zoneNumber,
    required this.isNorthHemisphere,
  });
}

class FireGeometryResolver {
  const FireGeometryResolver();

  FireGeometryResult resolve(FireRequest request) {
    double xP = request.piece.utmX ?? 0.0;
    double yP = request.piece.utmY ?? 0.0;
    double latitudeDeg = 0.0;
    _UtmZoneParsed? pieceZone;

    final hasPieceUtm =
        request.piece.utmX != null && request.piece.utmY != null;
    final hasPieceLatLon =
        request.piece.latitude != null && request.piece.longitude != null;

    if (hasPieceUtm) {
      pieceZone = _parseUtmZone(request.piece.utmZone);

      final ll = _utmToLatLonWgs84(
        easting: xP,
        northing: yP,
        zoneNumber: pieceZone.zoneNumber,
        isNorthHemisphere: pieceZone.isNorthHemisphere,
      );
      latitudeDeg = ll.latDeg;
    } else if (hasPieceLatLon) {
      latitudeDeg = request.piece.latitude!;

      final utmPiece = _latLonToUtmWgs84(
        latDeg: request.piece.latitude!,
        lonDeg: request.piece.longitude!,
      );
      xP = utmPiece.easting;
      yP = utmPiece.northing;
      pieceZone = _UtmZoneParsed(
        utmPiece.zoneNumber,
        utmPiece.isNorthHemisphere,
      );
    }

    switch (request.target.mode) {
      case FireTargetMode.utm:
        if (request.target.utmX != null && request.target.utmY != null) {
          final dx = request.target.utmX! - xP;
          final dy = request.target.utmY! - yP;
          final dist = math.sqrt(dx * dx + dy * dy);
          var az = math.atan2(dx, dy) * 6400.0 / (2.0 * math.pi);
          if (az < 0) az += 6400.0;

          return FireGeometryResult(
            latitudeDeg: latitudeDeg,
            distanceTopo: dist,
            azimutMil: az,
            objXfinal: request.target.utmX!,
            objYfinal: request.target.utmY!,
            pdX: xP,
            pdY: yP,
          );
        }
        break;

      case FireTargetMode.latLon:
        if (request.target.latitude != null &&
            request.target.longitude != null) {
          final utmObj = _latLonToUtmWgs84(
            latDeg: request.target.latitude!,
            lonDeg: request.target.longitude!,
          );

          final objX = utmObj.easting;
          final objY = utmObj.northing;

          final dx = objX - xP;
          final dy = objY - yP;
          final dist = math.sqrt(dx * dx + dy * dy);
          var az = math.atan2(dx, dy) * 6400.0 / (2.0 * math.pi);
          if (az < 0) az += 6400.0;

          return FireGeometryResult(
            latitudeDeg: latitudeDeg,
            distanceTopo: dist,
            azimutMil: az,
            objXfinal: objX,
            objYfinal: objY,
            pdX: xP,
            pdY: yP,
          );
        }
        break;

      case FireTargetMode.daz:
        final azRad =
            (request.target.azimutMil ?? 0.0) * 2.0 * math.pi / 6400.0;
        final dist = request.target.distanceM ?? 0.0;
        final xO = xP + dist * math.sin(azRad);
        final yO = yP + dist * math.cos(azRad);

        return FireGeometryResult(
          latitudeDeg: latitudeDeg,
          distanceTopo: dist,
          azimutMil: request.target.azimutMil ?? 0.0,
          objXfinal: xO,
          objYfinal: yO,
          pdX: xP,
          pdY: yP,
        );
    }

    return FireGeometryResult(
      latitudeDeg: latitudeDeg,
      distanceTopo: 0.0,
      azimutMil: 0.0,
      objXfinal: xP,
      objYfinal: yP,
      pdX: xP,
      pdY: yP,
    );
  }

  _UtmZoneParsed _parseUtmZone(String? zone) {
    final z = (zone ?? '').trim().toUpperCase();
    if (z.isEmpty) {
      return const _UtmZoneParsed(31, true);
    }

    final m = RegExp(r'^(\d{1,2})([A-Z])?$').firstMatch(z);
    if (m == null) {
      final num = int.tryParse(z.replaceAll(RegExp(r'[^0-9]'), '')) ?? 31;
      return _UtmZoneParsed(num, true);
    }

    final num = int.tryParse(m.group(1)!) ?? 31;
    final letter = m.group(2);

    if (letter == null) {
      return _UtmZoneParsed(num, true);
    }

    return _UtmZoneParsed(num, letter.compareTo('N') >= 0);
  }

  _LatLonDeg _utmToLatLonWgs84({
    required double easting,
    required double northing,
    required int zoneNumber,
    required bool isNorthHemisphere,
  }) {
    const a = 6378137.0;
    const f = 1 / 298.257223563;
    const k0 = 0.9996;

    const b = a * (1 - f);
    final double e2 = (a * a - b * b) / (a * a);
    final lon0Rad = ((zoneNumber - 1) * 6 - 180 + 3) * (math.pi / 180.0);

    final x = easting - 500000.0;
    final y = isNorthHemisphere ? northing : northing - 10000000.0;

    final M = y / k0;
    final mu =
        M / (a * (1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256));

    final e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2));
    final j1 = (3 * e1 / 2 - 27 * e1 * e1 * e1 / 32);
    final j2 = (21 * e1 * e1 / 16 - 55 * e1 * e1 * e1 * e1 / 32);
    final j3 = (151 * e1 * e1 * e1 / 96);
    final j4 = (1097 * e1 * e1 * e1 * e1 / 512);

    final fp = mu +
        j1 * math.sin(2 * mu) +
        j2 * math.sin(4 * mu) +
        j3 * math.sin(6 * mu) +
        j4 * math.sin(8 * mu);

    final C1 = e2 * math.pow(math.cos(fp), 2) / (1 - e2);
    final T1 = math.pow(math.tan(fp), 2);
    final N1 = a / math.sqrt(1 - e2 * math.pow(math.sin(fp), 2));
    final R1 = a * (1 - e2) / math.pow(1 - e2 * math.pow(math.sin(fp), 2), 1.5);
    final D = x / (N1 * k0);

    final latRad = fp -
        (N1 * math.tan(fp) / R1) *
            (D * D / 2 -
                (5 + 3 * T1 + 10 * C1 - 4 * C1 * C1 - 9 * e2) *
                    D *
                    D *
                    D *
                    D /
                    24 +
                (61 +
                        90 * T1 +
                        298 * C1 +
                        45 * T1 * T1 -
                        252 * e2 -
                        3 * C1 * C1) *
                    D *
                    D *
                    D *
                    D *
                    D *
                    D /
                    720);

    final lonRad = lon0Rad +
        (D -
                (1 + 2 * T1 + C1) * D * D * D / 6 +
                (5 - 2 * C1 + 28 * T1 - 3 * C1 * C1 + 8 * e2 + 24 * T1 * T1) *
                    D *
                    D *
                    D *
                    D *
                    D /
                    120) /
            math.cos(fp);

    return _LatLonDeg(latRad * 180.0 / math.pi, lonRad * 180.0 / math.pi);
  }

  _UtmPoint _latLonToUtmWgs84({
    required double latDeg,
    required double lonDeg,
  }) {
    const a = 6378137.0;
    const f = 1 / 298.257223563;
    const k0 = 0.9996;

    final latRad = latDeg * math.pi / 180.0;
    final lonRad = lonDeg * math.pi / 180.0;

    final zoneNumber = ((lonDeg + 180) / 6).floor() + 1;
    final lon0Deg = (zoneNumber - 1) * 6 - 180 + 3;
    final lon0Rad = lon0Deg * math.pi / 180.0;

    final e2 = f * (2 - f);
    final ep2 = e2 / (1 - e2);

    final N = a / math.sqrt(1 - e2 * math.sin(latRad) * math.sin(latRad));
    final T = math.tan(latRad) * math.tan(latRad);
    final C = ep2 * math.cos(latRad) * math.cos(latRad);
    final A = math.cos(latRad) * (lonRad - lon0Rad);

    final M = a *
        ((1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256) * latRad -
            (3 * e2 / 8 + 3 * e2 * e2 / 32 + 45 * e2 * e2 * e2 / 1024) *
                math.sin(2 * latRad) +
            (15 * e2 * e2 / 256 + 45 * e2 * e2 * e2 / 1024) *
                math.sin(4 * latRad) -
            (35 * e2 * e2 * e2 / 3072) * math.sin(6 * latRad));

    final easting = k0 *
            N *
            (A +
                (1 - T + C) * math.pow(A, 3) / 6 +
                (5 - 18 * T + T * T + 72 * C - 58 * ep2) *
                    math.pow(A, 5) /
                    120) +
        500000.0;

    var northing = k0 *
        (M +
            N *
                math.tan(latRad) *
                (A * A / 2 +
                    (5 - T + 9 * C + 4 * C * C) * math.pow(A, 4) / 24 +
                    (61 - 58 * T + T * T + 600 * C - 330 * ep2) *
                        math.pow(A, 6) /
                        720));

    final isNorth = latDeg >= 0;
    if (!isNorth) {
      northing += 10000000.0;
    }

    return _UtmPoint(
      easting: easting,
      northing: northing,
      zoneNumber: zoneNumber,
      isNorthHemisphere: isNorth,
    );
  }
}
