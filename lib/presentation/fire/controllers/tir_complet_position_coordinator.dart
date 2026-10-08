// lib/presentation/fire/controllers/tir_complet_position_coordinator.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:calculateur_etranger/services/position/external_gnss_service.dart';
import 'package:calculateur_etranger/services/position/ops_position_service.dart';
import 'package:calculateur_etranger/services/position/strix_serial_transport.dart';

class TirCompletPositionCoordinator {
  TirCompletPositionCoordinator({
    ExternalGnssService? externalGnssService,
    OpsPositionService? opsPositionService,
    StrixSerialTransport? strixTransport,
  })  : _externalGnssService = externalGnssService ?? ExternalGnssService(),
        _opsPositionService = opsPositionService ?? OpsPositionService(),
        _strixTransport = strixTransport ?? StrixSerialTransport();

  final ExternalGnssService _externalGnssService;
  final OpsPositionService _opsPositionService;
  final StrixSerialTransport _strixTransport;

  StreamSubscription<OpsPositionData>? _gpsSub;
  StreamSubscription<ExternalGnssPositionData>? _externalGpsSub;

  bool get gpsActive => _gpsSub != null;
  bool get externalGpsActive => _externalGpsSub != null;

  Future<OpsPositionData?> getCurrentDevicePosition() {
    return _opsPositionService.getCurrentPosition();
  }

  void startDeviceTracking({
    required void Function(OpsPositionData gps) onData,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    stopDeviceTracking();

    _gpsSub = _opsPositionService
        .watchPosition(distanceFilterMeters: 5)
        .listen(onData, onError: onError);
  }

  void stopDeviceTracking() {
    _gpsSub?.cancel();
    _gpsSub = null;
  }

  void startExternalTracking({
    required FutureOr<void> Function(ExternalGnssPositionData data) onData,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    unawaited(_startExternalTrackingAsync(onData: onData, onError: onError));
  }

  Future<void> _startExternalTrackingAsync({
    required FutureOr<void> Function(ExternalGnssPositionData data) onData,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    // On coupe uniquement l'abonnement logique précédent.
    // Le port série STRIX reste ouvert afin d'éviter de fermer libserialport
    // pendant qu'un worker natif est encore dans sp_wait().
    await stopExternalTracking();

    _externalGpsSub = _externalGnssService.positions.listen(
      onData,
      onError: onError,
    );

    try {
      if (!_strixTransport.isOpen) {
        await _strixTransport.start();
      }

      await _externalGnssService.bindStrix(_strixTransport.bytes);
      debugPrint('[POSITION] STRIX externe actif');
    } catch (e, st) {
      debugPrint('[POSITION] STRIX start failed: $e');
      onError?.call(e, st);
    }
  }

  /// Désactive l'utilisation du GPS externe côté application sans fermer
  /// le port série natif. C'est volontaire : fermer libserialport pendant
  /// qu'un reader est en attente peut provoquer un SIGSEGV sur macOS.
  Future<void> stopExternalTracking({bool reset = true}) async {
    await _externalGpsSub?.cancel();
    _externalGpsSub = null;

    await _externalGnssService.unbind();

    if (reset) {
      _externalGnssService.reset();
    }

    debugPrint('[POSITION] STRIX acquisition disabled — port kept open');
  }

  Future<void> dispose() async {
    stopDeviceTracking();

    // D'abord détacher tout le pipeline Dart.
    await stopExternalTracking();
    await _externalGnssService.dispose();

    // La fermeture physique du port n'a lieu qu'à la destruction du
    // coordinateur, donc une seule fois et hors callback de lecture normal.
    await _strixTransport.dispose();

    debugPrint('[POSITION] coordinator disposed');
  }
}
