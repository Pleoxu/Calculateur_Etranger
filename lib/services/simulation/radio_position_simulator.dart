// lib/services/simulation/radio_position_simulator.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import 'package:calculateur_etranger/domain/radio/radio_position_message.dart';
import 'package:calculateur_etranger/domain/radio/radio_position_provider.dart';
import 'package:calculateur_etranger/presentation/fire/models/piece_soutien.dart';

class RadioPositionSimulator implements RadioPositionProvider {
  static const String defaultAssetPath =
      'assets/sim_radio/radio_positions_batterie_1.json';

  final String assetPath;

  final StreamController<RadioPositionMessage> _controller =
      StreamController<RadioPositionMessage>.broadcast();

  bool _started = false;

  RadioPositionSimulator({this.assetPath = defaultAssetPath});

  @override
  Stream<RadioPositionMessage> get stream => _controller.stream;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;

    final messages = await loadRadioMessages(assetPath: assetPath);

    for (final msg in messages) {
      if (_controller.isClosed) return;
      _controller.add(msg);
    }
  }

  @override
  Future<void> stop() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  Future<List<RadioPositionMessage>> loadRadioMessages({
    String assetPath = defaultAssetPath,
  }) async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('[RADIO_SIM] Invalid JSON root');
    }

    final rootTimestamp = _asDateTime(decoded['timestamp']);

    final piecesRaw = decoded['pieces'];
    if (piecesRaw is! List) {
      throw const FormatException(
        '[RADIO_SIM] \'pieces\' field missing or invalid',
      );
    }

    final positions = piecesRaw
        .whereType<Map>()
        .map((e) => _RadioPiecePosition.fromJson(e.cast<String, dynamic>()))
        .toList();

    positions.sort(
      (a, b) => _pieceOrder(a.pieceId).compareTo(_pieceOrder(b.pieceId)),
    );

    return positions.map((p) {
      final id = p.pieceId.trim().toUpperCase();

      return RadioPositionMessage(
        id: id,
        type: id == 'PD' ? RadioNodeType.pd : RadioNodeType.ps,
        x: p.x,
        y: p.y,
        z: p.z,
        timestamp: p.timestamp ?? rootTimestamp ?? DateTime.now(),
        accuracy: p.accuracy,
      );
    }).toList(growable: false);
  }

  Future<List<PieceSoutien>> loadPieces({
    String assetPath = defaultAssetPath,
  }) async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('[RADIO_SIM] Invalid JSON root');
    }

    final piecesRaw = decoded['pieces'];
    if (piecesRaw is! List) {
      throw const FormatException(
        '[RADIO_SIM] \'pieces\' field missing or invalid',
      );
    }

    final positions = piecesRaw
        .whereType<Map>()
        .map((e) => _RadioPiecePosition.fromJson(e.cast<String, dynamic>()))
        .toList();

    final pd = positions.firstWhere(
      (p) => p.pieceId.toUpperCase() == 'PD',
      orElse: () => throw const FormatException('[RADIO_SIM] PD absente'),
    );

    final supports =
        positions.where((p) => p.pieceId.toUpperCase() != 'PD').toList()
          ..sort(
            (a, b) => _pieceOrder(a.pieceId).compareTo(_pieceOrder(b.pieceId)),
          );

    return supports.map((p) {
      final daz = _toDazFromPd(pdX: pd.x, pdY: pd.y, psX: p.x, psY: p.y);

      return PieceSoutien(
        nom: p.pieceId,
        distanceM: daz.distanceM,
        azimutMil: daz.azimutMil,
        xPS: p.x,
        yPS: p.y,
        zPS: p.z,
      );
    }).toList(growable: false);
  }

  Future<RadioPositionSimulationResult> loadBattery({
    String assetPath = defaultAssetPath,
  }) async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('[RADIO_SIM] Invalid JSON root');
    }

    final piecesRaw = decoded['pieces'];
    if (piecesRaw is! List) {
      throw const FormatException(
        '[RADIO_SIM] \'pieces\' field missing or invalid',
      );
    }

    final positions = piecesRaw
        .whereType<Map>()
        .map((e) => _RadioPiecePosition.fromJson(e.cast<String, dynamic>()))
        .toList();

    final pd = positions.firstWhere(
      (p) => p.pieceId.toUpperCase() == 'PD',
      orElse: () => throw const FormatException('[RADIO_SIM] PD absente'),
    );

    final pieces = await loadPieces(assetPath: assetPath);
    final observerRaw = decoded['observer'] ?? decoded['observateur'];
    final observer = observerRaw is Map
        ? RadioObserverPosition.fromJson(observerRaw.cast<String, dynamic>())
        : null;

    return RadioPositionSimulationResult(
      batteryId: decoded['batteryId']?.toString(),
      timestamp: decoded['timestamp']?.toString(),
      pdX: pd.x,
      pdY: pd.y,
      pdZ: pd.z,
      pdZone: pd.zone,
      piecesSoutien: pieces,
      observer: observer,
    );
  }

  static _Daz _toDazFromPd({
    required double pdX,
    required double pdY,
    required double psX,
    required double psY,
  }) {
    final dx = psX - pdX;
    final dy = psY - pdY;

    final distanceM = math.sqrt(dx * dx + dy * dy);

    var azimutMil = math.atan2(dx, dy) * 6400.0 / (2.0 * math.pi);
    if (azimutMil < 0) azimutMil += 6400.0;

    return _Daz(distanceM: distanceM, azimutMil: azimutMil);
  }

  static int _pieceOrder(String id) {
    final normalized = id.trim().toUpperCase();
    if (normalized == 'PD') return 0;

    final match = RegExp(r'^PS(\d+)$').firstMatch(normalized);
    if (match == null) return 999;

    return int.tryParse(match.group(1) ?? '') ?? 999;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class RadioPositionSimulationResult {
  final String? batteryId;
  final String? timestamp;

  final double pdX;
  final double pdY;
  final double pdZ;
  final String? pdZone;

  final List<PieceSoutien> piecesSoutien;
  final RadioObserverPosition? observer;

  const RadioPositionSimulationResult({
    required this.batteryId,
    required this.timestamp,
    required this.pdX,
    required this.pdY,
    required this.pdZ,
    required this.pdZone,
    required this.piecesSoutien,
    this.observer,
  });
}

class RadioObserverPosition {
  final String observerId;
  final String? zone;
  final double x;
  final double y;
  final double z;
  final DateTime? timestamp;
  final double? accuracy;

  const RadioObserverPosition({
    required this.observerId,
    required this.zone,
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
    required this.accuracy,
  });

  factory RadioObserverPosition.fromJson(Map<String, dynamic> json) {
    return RadioObserverPosition(
      observerId: _RadioPiecePosition._asString(json['observerId']) ??
          _RadioPiecePosition._asString(json['id']) ??
          'OBS',
      zone: _RadioPiecePosition._asString(json['zone']),
      x: _RadioPiecePosition._asDouble(json['x']) ?? 0.0,
      y: _RadioPiecePosition._asDouble(json['y']) ?? 0.0,
      z: _RadioPiecePosition._asDouble(json['z']) ?? 0.0,
      timestamp: _RadioPiecePosition._asDateTime(json['timestamp']),
      accuracy: _RadioPiecePosition._asDouble(
        json['accuracy'] ?? json['precisionM'],
      ),
    );
  }
}

class _RadioPiecePosition {
  final String pieceId;
  final String? zone;

  final double x;
  final double y;
  final double z;

  final DateTime? timestamp;
  final double? accuracy;

  const _RadioPiecePosition({
    required this.pieceId,
    required this.zone,
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
    required this.accuracy,
  });

  factory _RadioPiecePosition.fromJson(Map<String, dynamic> json) {
    return _RadioPiecePosition(
      pieceId: _asString(json['pieceId']) ?? 'PS',
      zone: _asString(json['zone']),
      x: _asDouble(json['x']) ?? 0.0,
      y: _asDouble(json['y']) ?? 0.0,
      z: _asDouble(json['z']) ?? 0.0,
      timestamp: _asDateTime(json['timestamp']),
      accuracy: _asDouble(json['accuracy']),
    );
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim().replaceAll(',', '.'));
    }
    return null;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class _Daz {
  final double distanceM;
  final double azimutMil;

  const _Daz({required this.distanceM, required this.azimutMil});
}
