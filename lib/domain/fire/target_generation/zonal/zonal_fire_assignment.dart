// lib/domain/fire/utils/zonal_fire_assignment.dart

import 'dart:math' as math;

class ZonalPoint {
  final int col;
  final int row;

  /// coord largeur locale (m)
  final double xW;

  /// coord profondeur locale (m)
  final double yP;

  const ZonalPoint({
    required this.col,
    required this.row,
    required this.xW,
    required this.yP,
  });
}

double _milToRad(double mil) => mil * 2.0 * math.pi / 6400.0;

Map<String, double> toUtm({
  required double prX,
  required double prY,
  required double xW,
  required double yP,
  required double azLargeurMil,
  required double azProfondeurMil,
}) {
  final azLRad = _milToRad(azLargeurMil);
  final azPRad = _milToRad(azProfondeurMil);

  final uLx = math.sin(azLRad);
  final uLy = math.cos(azLRad);

  final uPx = math.sin(azPRad);
  final uPy = math.cos(azPRad);

  final x = prX + xW * uLx + yP * uPx;
  final y = prY + xW * uLy + yP * uPy;

  return {'x': x, 'y': y};
}

List<ZonalPoint> buildZonalGrid({
  required double largeurM,
  required double profondeurM,
  required double diametreEfficaciteM,
  required double recouvPct,
  required double debordPct,
  required int pointIdx,
}) {
  if (largeurM <= 0 || profondeurM <= 0) {
    return const [];
  }

  final rec = (recouvPct / 100.0).clamp(0.0, 0.8);
  final step = diametreEfficaciteM * (1.0 - rec);

  // Appliquer le débord pour le calcul du nombre de points
  // (cohérent avec _suggestNbCoups qui applique le débord sur les deux dimensions)
  final deb = (debordPct / 100.0).clamp(0.0, 0.5);
  final largeurEff = largeurM * (1.0 + deb);
  final profondeurEff = profondeurM * (1.0 + deb);

  final nL = math.max(1, (largeurEff / step).ceil());
  final nP = math.max(1, (profondeurEff / step).ceil());

  // Le pas réel est calculé sur la dimension sans débord
  // (les points sont répartis sur largeurM × profondeurM)
  final stepL = largeurM / nL;
  final stepP = profondeurM / nP;

  double baseX;
  double baseY;

  switch (pointIdx) {
    // PR au centre
    case 2:
      baseX = -largeurM / 2.0;
      baseY = -profondeurM / 2.0;
      break;

    // PR milieu du côté inférieur
    case 1:
      baseX = -largeurM / 2.0;
      baseY = 0.0;
      break;

    // PR coin inférieur gauche
    case 0:
      baseX = 0.0;
      baseY = 0.0;
      break;

    default:
      baseX = -largeurM / 2.0;
      baseY = -profondeurM / 2.0;
  }

  final pts = <ZonalPoint>[];

  for (int r = 0; r < nP; r++) {
    for (int c = 0; c < nL; c++) {
      final x = baseX + (c + 0.5) * stepL;
      final y = baseY + (r + 0.5) * stepP;

      pts.add(ZonalPoint(col: c, row: r, xW: x, yP: y));
    }
  }

  return pts;
}
