// lib/services/position/external_gnss_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:calculateur_etranger/services/position/nmea0183_parser.dart';
import 'package:calculateur_etranger/services/position/strix_telemetry_parser.dart';
import 'package:calculateur_etranger/services/position/utm_converter.dart';

enum ExternalGnssProtocol { nmea0183, strixV8 }

class ExternalGnssQuality {
  final int? satellitesUsed;
  final double? hdop;
  final double? pdop;
  final int? carrierSolution;

  const ExternalGnssQuality({
    this.satellitesUsed,
    this.hdop,
    this.pdop,
    this.carrierSolution,
  });
}

class ExternalGnssPositionData {
  final ExternalGnssProtocol protocol;
  final double latitude;
  final double longitude;
  final double altitude;
  final UtmPosition utm;
  final ExternalGnssQuality quality;

  const ExternalGnssPositionData({
    required this.protocol,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.utm,
    required this.quality,
  });
}

class ExternalGnssService {
  ExternalGnssService({
    Nmea0183Parser? parser,
    StrixTelemetryParser? strixParser,
  })  : _parser = parser ?? Nmea0183Parser(),
        _strixParser = strixParser ?? StrixTelemetryParser();

  final Nmea0183Parser _parser;
  final StrixTelemetryParser _strixParser;

  final StreamController<ExternalGnssPositionData> _positionController =
      StreamController<ExternalGnssPositionData>.broadcast();

  StreamSubscription<String>? _nmeaSubscription;
  StreamSubscription<List<int>>? _strixSubscription;
  ExternalGnssPositionData? _lastPosition;

  Stream<ExternalGnssPositionData> get positions => _positionController.stream;
  ExternalGnssPositionData? get lastPosition => _lastPosition;
  NmeaGnssFix get currentFix => _parser.currentFix;

  Future<void> bind(Stream<String> nmeaLines) async {
    await unbind();
    _nmeaSubscription = nmeaLines.listen(
      addNmeaLine,
      onError: (Object e, StackTrace st) =>
          debugPrint('[GNSS EXT] Erreur transport NMEA : $e'),
      cancelOnError: false,
    );
  }

  Future<void> bindStrix(Stream<List<int>> byteStream) async {
    await unbind();
    _strixSubscription = byteStream.listen(
      addStrixBytes,
      onError: (Object e, StackTrace st) =>
          debugPrint('[GNSS STRIX] Erreur transport : $e'),
      cancelOnError: false,
    );
  }

  void addNmeaLine(String line) {
    final sentenceType = _sentenceType(line);
    final fix = _parser.parseLine(line);
    if (fix == null) return;

    final emitsPosition =
        sentenceType == 'GGA' || sentenceType == 'GNS' || sentenceType == 'RMC';
    if (!emitsPosition || !fix.hasValidPosition) return;
    if (sentenceType == 'RMC' && !fix.rmcActive) return;
    if (sentenceType == 'GGA' && fix.fixQuality == 0) return;

    _publish(
      protocol: ExternalGnssProtocol.nmea0183,
      latitude: fix.latitude!,
      longitude: fix.longitude!,
      altitude: fix.altitudeMslMeters ?? 0.0,
      quality: ExternalGnssQuality(
        satellitesUsed: fix.satellitesUsed,
        hdop: fix.hdop,
        pdop: fix.pdop,
      ),
    );
  }

  void addStrixBytes(List<int> bytes) {
    for (final rover in _strixParser.addBytes(bytes)) {
      _publish(
        protocol: ExternalGnssProtocol.strixV8,
        latitude: rover.latitude,
        longitude: rover.longitude,
        altitude: rover.altitudeMslMeters,
        quality: ExternalGnssQuality(
          satellitesUsed: rover.satellitesUsed,
          pdop: rover.pdop,
          carrierSolution: rover.carrierSolution,
        ),
      );

      debugPrint(
        '[GNSS STRIX ROVER] '
        'lat=${rover.latitude.toStringAsFixed(8)} '
        'lon=${rover.longitude.toStringAsFixed(8)} '
        'alt=${rover.altitudeMslMeters.toStringAsFixed(2)} '
        'fix=${rover.fixType} '
        'sat=${rover.satellitesUsed} '
        'carr=${rover.carrierSolution} '
        'pdop=${rover.pdop.toStringAsFixed(2)}',
      );
    }
  }

  void _publish({
    required ExternalGnssProtocol protocol,
    required double latitude,
    required double longitude,
    required double altitude,
    required ExternalGnssQuality quality,
  }) {
    final utm = UtmConverter.fromLatLon(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
    );

    final data = ExternalGnssPositionData(
      protocol: protocol,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      utm: utm,
      quality: quality,
    );

    _lastPosition = data;
    if (!_positionController.isClosed) _positionController.add(data);
  }

  String? _sentenceType(String line) {
    final raw = line.trim();
    if (!raw.startsWith(r'$')) return null;
    final comma = raw.indexOf(',');
    final star = raw.indexOf('*');
    final end = comma >= 0 ? comma : (star >= 0 ? star : raw.length);
    if (end <= 1) return null;
    final id = raw.substring(1, end).toUpperCase();
    if (id.length < 5) return null;
    return id.substring(id.length - 3);
  }

  void addNmeaLines(Iterable<String> lines) {
    for (final line in lines) {
      addNmeaLine(line);
    }
  }

  Future<void> unbind() async {
    await _nmeaSubscription?.cancel();
    await _strixSubscription?.cancel();
    _nmeaSubscription = null;
    _strixSubscription = null;
  }

  void reset() {
    _parser.reset();
    _strixParser.reset();
    _lastPosition = null;
  }

  Future<void> dispose() async {
    await unbind();
    await _positionController.close();
  }
}
