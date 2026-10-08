import 'package:proj4dart/proj4dart.dart';

class UtmPosition {
  final int zone;
  final String band;

  final double x; // Easting
  final double y; // Northing
  final double z; // Altitude

  const UtmPosition({
    required this.zone,
    required this.band,
    required this.x,
    required this.y,
    required this.z,
  });

  @override
  String toString() {
    return 'UTM(zone: $zone$band, X: $x, Y: $y, Z: $z)';
  }
}

class LatLonPosition {
  final double latitude;
  final double longitude;
  final double altitude;

  const LatLonPosition({
    required this.latitude,
    required this.longitude,
    required this.altitude,
  });

  @override
  String toString() {
    return 'LatLon(lat: $latitude, lon: $longitude, alt: $altitude)';
  }
}

class UtmConverter {
  static UtmPosition fromLatLon({
    required double latitude,
    required double longitude,
    required double altitude,
  }) {
    final zone = ((longitude + 180) / 6).floor() + 1;
    final band = _latitudeBand(latitude);

    final isNorthernHemisphere = latitude >= 0;

    final epsgCode =
        isNorthernHemisphere ? 'EPSG:${32600 + zone}' : 'EPSG:${32700 + zone}';

    final wgs84 = _wgs84Projection();
    final utmProj = _utmProjection(
      epsgCode: epsgCode,
      zone: zone,
      isNorthernHemisphere: isNorthernHemisphere,
    );

    final point = Point(x: longitude, y: latitude);
    final utmPoint = wgs84.transform(utmProj, point);

    return UtmPosition(
      zone: zone,
      band: band,
      x: utmPoint.x,
      y: utmPoint.y,
      z: altitude,
    );
  }

  static UtmPosition fromLatLonInZone({
    required double latitude,
    required double longitude,
    required double altitude,
    required int zone,
    String? band,
  }) {
    if (zone < 1 || zone > 60) {
      return fromLatLon(
        latitude: latitude,
        longitude: longitude,
        altitude: altitude,
      );
    }

    final effectiveBand = (band == null || band.trim().isEmpty)
        ? _latitudeBand(latitude)
        : band.trim().toUpperCase();

    final isNorthernHemisphere =
        effectiveBand.codeUnitAt(0) >= 'N'.codeUnitAt(0);
    final epsgCode =
        isNorthernHemisphere ? 'EPSG:${32600 + zone}' : 'EPSG:${32700 + zone}';

    final wgs84 = _wgs84Projection();
    final utmProj = _utmProjection(
      epsgCode: epsgCode,
      zone: zone,
      isNorthernHemisphere: isNorthernHemisphere,
    );

    final point = Point(x: longitude, y: latitude);
    final utmPoint = wgs84.transform(utmProj, point);

    return UtmPosition(
      zone: zone,
      band: effectiveBand,
      x: utmPoint.x,
      y: utmPoint.y,
      z: altitude,
    );
  }

  static LatLonPosition toLatLon({
    required int zone,
    required String band,
    required double x,
    required double y,
    required double z,
  }) {
    final normalizedBand = band.trim().toUpperCase();

    final isNorthernHemisphere =
        normalizedBand.codeUnitAt(0) >= 'N'.codeUnitAt(0);

    final epsgCode =
        isNorthernHemisphere ? 'EPSG:${32600 + zone}' : 'EPSG:${32700 + zone}';

    final wgs84 = _wgs84Projection();
    final utmProj = _utmProjection(
      epsgCode: epsgCode,
      zone: zone,
      isNorthernHemisphere: isNorthernHemisphere,
    );

    final point = Point(x: x, y: y);
    final latLonPoint = utmProj.transform(wgs84, point);

    return LatLonPosition(
      latitude: latLonPoint.y,
      longitude: latLonPoint.x,
      altitude: z,
    );
  }

  static Projection _wgs84Projection() {
    return Projection.get('EPSG:4326') ??
        Projection.add('EPSG:4326', '+proj=longlat +datum=WGS84 +no_defs');
  }

  static Projection _utmProjection({
    required String epsgCode,
    required int zone,
    required bool isNorthernHemisphere,
  }) {
    return Projection.get(epsgCode) ??
        Projection.add(
          epsgCode,
          '+proj=utm '
          '+zone=$zone '
          '${isNorthernHemisphere ? '+north' : '+south'} '
          '+datum=WGS84 '
          '+units=m '
          '+no_defs',
        );
  }

  static String _latitudeBand(double latitude) {
    const bands = 'CDEFGHJKLMNPQRSTUVWX';
    final index = ((latitude + 80) ~/ 8).clamp(0, bands.length - 1);
    return bands[index];
  }
}
