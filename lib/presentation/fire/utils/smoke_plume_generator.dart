// lib/presentation/fire/utils/smoke_plume_generator.dart

import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Générateur géométrique pour la modélisation de l'écran de fumée (M819 RP).
class SmokePlumeGenerator {
  /// Calcule l'enveloppe du nuage de fumée le long de sa trajectoire de diffusion.
  ///
  /// - [origin] : Point de dépotement / initiation (LatLng).
  /// - [windBearingDeg] : Direction vers laquelle le vent souffle (0° = Nord, sens horaire).
  /// - [maxDistanceMeters] : Distance totale de propagation du nuage.
  /// - [dispersionAngleDeg] : Angle du cône de diffusion (généralement 15° à 25°).
  /// - [initialRadiusMeters] : Rayon initial au point de dépotement.
  /// - [kDrag] : Coefficient de ralentissement par traînée d'air.
  /// - [steps] : Nombre de segments pour adoucir le polygone.
  static List<LatLng> generateSmokeEnvelope({
    required LatLng origin,
    required double windBearingDeg,
    double maxDistanceMeters = 250.0,
    double dispersionAngleDeg = 20.0,
    double initialRadiusMeters = 15.0,
    double kDrag = 0.004,
    int steps = 12,
  }) {
    const distanceCalc = Distance();
    final halfAngleRad = (dispersionAngleDeg / 2.0) * math.pi / 180.0;

    final leftEdge = <LatLng>[];
    final rightEdge = <LatLng>[];

    final stepSize = maxDistanceMeters / steps;

    for (var i = 0; i <= steps; i++) {
      final s = i * stepSize;

      // Ralentissement de la vitesse : V(s) = V0 * e^(-k * s)
      final velocityFactor = math.exp(-kDrag * s);
      final effectiveDistance = s * velocityFactor;

      // Point central sur la trajectoire entraînée par le vent
      final centerPoint = distanceCalc.offset(
        origin,
        effectiveDistance,
        windBearingDeg,
      );

      // Cône d'élargissement : r(s) = r0 + s * tan(theta / 2)
      final currentRadius = initialRadiusMeters + (s * math.tan(halfAngleRad));

      // Points perpendiculaires à la trajectoire (gauche et droite)
      final leftPoint = distanceCalc.offset(
        centerPoint,
        currentRadius,
        (windBearingDeg - 90.0) % 360.0,
      );
      final rightPoint = distanceCalc.offset(
        centerPoint,
        currentRadius,
        (windBearingDeg + 90.0) % 360.0,
      );

      leftEdge.add(leftPoint);
      rightEdge.add(rightPoint);
    }

    // Polygone fermé : bord gauche (aller) + bord droit (retour)
    return [...leftEdge, ...rightEdge.reversed];
  }
}
