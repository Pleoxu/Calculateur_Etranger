import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class OpsPositionData {
  final double latitude;
  final double longitude;
  final double altitude;
  final double accuracy;

  /// Indique si l'altitude provient d'une API d'élévation (true)
  /// ou du capteur GPS (false / non disponible).
  final bool altitudeFromApi;

  const OpsPositionData({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.accuracy,
    this.altitudeFromApi = false,
  });

  @override
  String toString() {
    return 'OpsPositionData('
        'lat: $latitude, '
        'lon: $longitude, '
        'alt: $altitude, '
        'accuracy: $accuracy, '
        'altitudeFromApi: $altitudeFromApi'
        ')';
  }
}

class OpsPositionService {
  /// URL de l'API Open-Meteo Elevation (gratuite, sans clé).
  static const _elevationBaseUrl = 'https://api.open-meteo.com/v1/elevation';

  /// Vérifie les services de localisation et demande la permission si besoin.
  ///
  /// Sur simulateur iOS, [isLocationServiceEnabled] peut retourner false même
  /// quand une position simulée est configurée dans Xcode. On contourne ce
  /// comportement en ne bloquant pas sur ce seul critère : si la permission
  /// est accordée, on tente quand même l'acquisition.
  ///
  /// Retourne `true` si l'application peut accéder à la position.
  Future<bool> _ensureLocationReady() async {
    // Sur simulateur iOS, le service peut signaler "disabled" alors qu'une
    // position simulée est bien disponible. On vérifie d'abord la permission
    // avant de bloquer sur l'état du service.
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('[OPS GPS] Permission refusée : $permission');
      return false;
    }

    // La permission est accordée. On vérifie le service mais on ne bloque
    // pas sur simulateur iOS (kDebugMode + Platform.isIOS).
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      final isSimulator = kDebugMode && Platform.isIOS;
      if (!isSimulator) {
        debugPrint('[OPS GPS] Service de localisation désactivé');
        return false;
      }
      debugPrint(
        '[OPS GPS] Service signalé désactivé sur simulateur iOS — '
        'on tente quand même l\'acquisition (position simulée Xcode)',
      );
    }

    return true;
  }

  /// Acquisition ponctuelle de la position OPS.
  ///
  /// Utilisée pour le premier remplissage immédiat des coordonnées.
  /// Sur simulateur iOS, on utilise [LocationAccuracy.reduced] en fallback
  /// si [LocationAccuracy.best] échoue, pour accepter la position simulée.
  Future<OpsPositionData?> getCurrentPosition() async {
    try {
      final ready = await _ensureLocationReady();
      if (!ready) return null;

      Position? pos;

      // Premier essai avec la précision maximale.
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (e) {
        debugPrint('[OPS GPS] Échec précision best : $e');
        // Fallback : précision réduite (acceptée par le simulateur Xcode).
        try {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.reduced,
              timeLimit: Duration(seconds: 10),
            ),
          );
        } catch (e2) {
          debugPrint('[OPS GPS] Échec précision reduced : $e2');
          return null;
        }
      }

      debugPrint(
        '[OPS GPS] Position obtenue : '
        'lat=${pos.latitude} lon=${pos.longitude} '
        'alt=${pos.altitude} acc=${pos.accuracy}',
      );

      return await _toOpsPositionData(pos);
    } catch (e, st) {
      debugPrint('[OPS GPS] Erreur inattendue : $e\n$st');
      return null;
    }
  }

  /// Suivi continu de la position OPS.
  ///
  /// Utilisé quand la source PD est OPS/GPS.
  /// [distanceFilterMeters] limite les updates aux déplacements significatifs.
  Stream<OpsPositionData> watchPosition({int distanceFilterMeters = 5}) async* {
    final ready = await _ensureLocationReady();
    if (!ready) return;

    // Sur simulateur, on abaisse le filtre de distance à 0 pour recevoir
    // les mises à jour de la position simulée Xcode même sans déplacement.
    final isSimulator = kDebugMode && Platform.isIOS;
    final effectiveFilter = isSimulator ? 0 : distanceFilterMeters;

    final settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: effectiveFilter,
    );

    await for (final pos in Geolocator.getPositionStream(
      locationSettings: settings,
    )) {
      debugPrint(
        '[OPS GPS STREAM] lat=${pos.latitude} lon=${pos.longitude} '
        'alt=${pos.altitude} acc=${pos.accuracy}',
      );
      final data = await _toOpsPositionData(pos);
      yield data;
    }
  }

  /// Convertit une position Geolocator en donnée métier OPS.
  ///
  /// On tente d'abord de récupérer l'altitude terrain via Open-Meteo.
  /// En cas d'échec réseau ou timeout, on garde l'altitude GPS.
  Future<OpsPositionData> _toOpsPositionData(Position pos) async {
    final lat = pos.latitude;
    final lon = pos.longitude;
    final gpsAlt = pos.altitude;

    final apiAlt = await _fetchElevation(lat, lon);

    return OpsPositionData(
      latitude: lat,
      longitude: lon,
      altitude: apiAlt ?? gpsAlt,
      accuracy: pos.accuracy,
      altitudeFromApi: apiAlt != null,
    );
  }

  /// Interroge l'API Open-Meteo Elevation pour obtenir l'altitude terrain
  /// au point [lat]/[lon].
  ///
  /// Retourne l'altitude en mètres ou `null` en cas d'échec.
  Future<double?> _fetchElevation(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        '$_elevationBaseUrl'
        '?latitude=${lat.toStringAsFixed(6)}'
        '&longitude=${lon.toStringAsFixed(6)}',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final elevations = json['elevation'];

      if (elevations is List && elevations.isNotEmpty) {
        final value = elevations.first;
        if (value is num) return value.toDouble();
      }

      return null;
    } catch (_) {
      // Pas de réseau ou timeout → on retombe sur l'altitude GPS.
      return null;
    }
  }
}
