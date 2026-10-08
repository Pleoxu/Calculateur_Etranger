import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:calculateur_etranger/models/effects/coverage_ellipse.dart';
import 'package:calculateur_etranger/services/effects/red_service.dart';

double milToRad(double mil) => (2 * math.pi) * (mil / 6400.0);

class UnitVector {
  const UnitVector(this.ux, this.uy);

  final double ux;
  final double uy;
}

UnitVector unitFromAzMil(double azMil) {
  final t = milToRad(azMil);
  return UnitVector(math.sin(t), math.cos(t));
}

Offset dirFromAzMil(double azMil) {
  final t = milToRad(azMil);
  return Offset(math.sin(t), -math.cos(t));
}

Offset rot90(Offset v) => Offset(-v.dy, v.dx);

void drawCenteredText(Canvas canvas, Offset center, String text) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        shadows: [
          Shadow(blurRadius: 2.0, color: Colors.black, offset: Offset(1, 1)),
        ],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

void arrow(Canvas canvas, Offset start, Offset dir, double len, Paint paint) {
  final end = start + dir * len;
  canvas.drawLine(start, end, paint);

  final left = Offset(-dir.dy, dir.dx);

  canvas.drawLine(end, end - dir * 10 + left * 6, paint);
  canvas.drawLine(end, end - dir * 10 - left * 6, paint);
}

void label(
  Canvas canvas,
  Offset pos,
  String text, {
  required Color color,
  double fontSize = 12,
  FontWeight fontWeight = FontWeight.w800,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        shadows: const [
          Shadow(
            blurRadius: 1.5,
            color: Colors.black54,
            offset: Offset(0.5, 0.5),
          ),
        ],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
}

void badge(Canvas canvas, Offset pos, String text, {required bool dark}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: dark ? Colors.white : Colors.black87,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final rect = Rect.fromLTWH(pos.dx, pos.dy, tp.width + 18, tp.height + 10);
  final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

  canvas.drawRRect(
    rrect,
    Paint()
      ..color = dark
          ? Colors.black.withValues(alpha: 0.35)
          : Colors.white.withValues(alpha: 0.75),
  );

  canvas.drawRRect(
    rrect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = dark ? Colors.white24 : Colors.black12,
  );

  tp.paint(canvas, pos + const Offset(9, 5));
}

void drawCoverageEllipse(
  Canvas canvas, {
  required CoverageEllipse coverage,
  required Offset centerPx,
  required double scale,
  required Color color,
  required bool dark,
  bool showSpatialDistribution = false,
}) {
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..color = color.withValues(alpha: dark ? 0.72 : 0.58);

  final fill = Paint()
    ..style = PaintingStyle.fill
    ..color = color.withValues(alpha: dark ? 0.12 : 0.08);

  canvas.save();
  canvas.translate(centerPx.dx, centerPx.dy);

  final dir = dirFromAzMil(coverage.azimutMil);
  canvas.rotate(math.atan2(dir.dy, dir.dx));

  // Mode Réel : utiliser directement l'ellipse calculée par
  // FragmentationService. Les axes sont déjà des demi-axes en mètres.
  if (!showSpatialDistribution) {
    final majorPx = math.max(3.0, coverage.semiMajorAxis * scale);
    final minorPx = math.max(3.0, coverage.semiMinorAxis * scale);

    final ellipseRect = Rect.fromCenter(
      center: Offset.zero,
      width: majorPx * 2.0,
      height: minorPx * 2.0,
    );

    canvas.drawOval(ellipseRect, fill);
    canvas.drawOval(ellipseRect, stroke);

    canvas.drawLine(
      Offset(0.0, -minorPx * 0.18),
      Offset(0.0, minorPx * 0.18),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = color.withValues(alpha: dark ? 0.38 : 0.28),
    );

    canvas.restore();
    return;
  }

  // Mode Distribution : conserver la représentation dissymétrique et son
  // gradient d'effet. Cette vue reste illustrative et distincte de l'ellipse
  // physique du mode Réel.
  final baseRadiusM = math.max(
    1.0,
    coverage.lethalRadius > 0.0
        ? coverage.lethalRadius
        : coverage.visualSemiMinorAxis,
  );

  final angleRad = coverage.angleChuteDeg * math.pi / 180.0;
  final safeSin = math.sin(angleRad).abs().clamp(0.20, 1.0).toDouble();

  final frontAxisM = math.max(
    baseRadiusM * 0.85,
    coverage.visualSemiMajorAxis * 0.85,
  );
  final rearAxisM = math.max(
    coverage.visualSemiMajorAxis,
    baseRadiusM / safeSin,
  );
  final lateralAxisM = math.max(baseRadiusM, coverage.visualSemiMinorAxis);

  final frontPx = math.max(3.0, frontAxisM * scale);
  final rearPx = math.max(3.0, rearAxisM * scale);
  final lateralPx = math.max(3.0, lateralAxisM * scale);

  final effectPath = _buildAsymmetricEffectPath(
    frontPx: frontPx,
    rearPx: rearPx,
    lateralPx: lateralPx,
  );

  final bounds = Rect.fromLTRB(-rearPx, -lateralPx, frontPx, lateralPx);

  canvas.save();
  canvas.clipPath(effectPath);

  final rearColor = dark ? Colors.cyanAccent : Colors.blueAccent;
  final centerColor = dark ? Colors.yellowAccent : Colors.amber;
  final frontColor = dark ? Colors.redAccent : Colors.deepOrange;

  final longitudinalPaint = Paint()
    ..style = PaintingStyle.fill
    ..shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        rearColor.withValues(alpha: dark ? 0.18 : 0.14),
        centerColor.withValues(alpha: dark ? 0.48 : 0.38),
        frontColor.withValues(alpha: dark ? 0.42 : 0.34),
      ],
      stops: const [0.0, 0.58, 1.0],
    ).createShader(bounds);
  canvas.drawRect(bounds, longitudinalPaint);

  final corePaint = Paint()
    ..style = PaintingStyle.fill
    ..shader = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        centerColor.withValues(alpha: dark ? 0.62 : 0.50),
        centerColor.withValues(alpha: dark ? 0.28 : 0.22),
        centerColor.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.42, 1.0],
    ).createShader(Rect.fromLTRB(-lateralPx, -lateralPx, lateralPx, lateralPx));
  canvas.drawCircle(Offset.zero, lateralPx, corePaint);

  final rearDiffusePaint = Paint()
    ..style = PaintingStyle.fill
    ..shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        rearColor.withValues(alpha: dark ? 0.10 : 0.08),
        Colors.transparent,
      ],
      stops: const [0.0, 1.0],
    ).createShader(Rect.fromLTRB(-rearPx, -lateralPx, 0.0, lateralPx));
  canvas.drawRect(
    Rect.fromLTRB(-rearPx, -lateralPx, 0.0, lateralPx),
    rearDiffusePaint,
  );

  final frontCompactPaint = Paint()
    ..style = PaintingStyle.fill
    ..shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        frontColor.withValues(alpha: dark ? 0.16 : 0.12),
        frontColor.withValues(alpha: dark ? 0.28 : 0.22),
        frontColor.withValues(alpha: dark ? 0.06 : 0.05),
      ],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Rect.fromLTRB(0.0, -lateralPx, frontPx, lateralPx));
  canvas.drawRect(
    Rect.fromLTRB(0.0, -lateralPx, frontPx, lateralPx),
    frontCompactPaint,
  );

  canvas.restore();
  canvas.drawPath(effectPath, stroke);

  canvas.drawLine(
    Offset(-rearPx, 0.0),
    Offset(frontPx, 0.0),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = color.withValues(alpha: dark ? 0.22 : 0.16),
  );

  canvas.restore();
}

// ─────────────────────────────────────────────────────────────────────────────
// Visuel RED : zones dangereuses par éclats métalliques
// ─────────────────────────────────────────────────────────────────────────────

/// Cache statique du résultat RED par type d'obus.
final Map<ObusTirType, RedResult> _redCache = {};

/// Retourne (ou calcule et met en cache) le résultat RED.
/// Fonction publique pour être accessible depuis les painters.
RedResult getRedResult(ObusTirType type) {
  return _redCache.putIfAbsent(type, () => RedService(type: type).computeRed());
}

/// Invalide le cache RED.
void invalidateRedCache() {
  _redCache.clear();
}

// ─────────────────────────────────────────────────────────────────────────────
// Zone RED globale : union de tous les disques d'impact
// ─────────────────────────────────────────────────────────────────────────────

/// Dessine la zone RED globale couvrant l'ensemble des points d'impact.
///
/// Construit l'union géométrique des disques de danger et RED pour tous
/// les coups, puis remplit chaque zone d'un seul tenant :
///   - Zone de danger (P ≥ 50%) : remplissage rouge vif + contour plein
///   - Zone RED (P ≤ 10⁻³)     : remplissage orange translucide + contour tirets
///
/// [centersPx] : liste des centres des impacts en pixels.
/// [scale]     : pixels par mètre.
/// [obusType]  : type d'obus (RALEC ou FRAPPE).
void drawRedZoneGlobal(
  Canvas canvas, {
  required List<Offset> centersPx,
  required double scale,
  required bool dark,
  ObusTirType obusType = ObusTirType.frappe,
}) {
  if (centersPx.isEmpty) return;

  final red = getRedResult(obusType);

  final redRadiusPx = red.redM * scale;
  final dangerRadiusPx = red.dangerRadiusM * scale;

  if (redRadiusPx < 1.0) return;

  // ── Construction des paths union ─────────────────────────────────────────
  // Flutter Path utilise le fill rule EvenOdd ou NonZero.
  // Pour l'union, on additionne tous les cercles dans un même Path
  // avec fillType = nonZero : chaque disque ajouté s'unit aux précédents.

  final pathRed = Path();
  final pathDanger = Path();

  for (final c in centersPx) {
    pathRed.addOval(Rect.fromCircle(center: c, radius: redRadiusPx));
    if (dangerRadiusPx > 1.0) {
      pathDanger.addOval(Rect.fromCircle(center: c, radius: dangerRadiusPx));
    }
  }

  pathRed.fillType = PathFillType.nonZero;
  pathDanger.fillType = PathFillType.nonZero;

  // ── Calcul de la bounding box pour le gradient ───────────────────────────
  final boundsRed = pathRed.getBounds();

  // ── Dessin zone RED (P ≤ 10⁻³) ──────────────────────────────────────────
  // Remplissage : orange-rouge très translucide
  canvas.drawPath(
    pathRed,
    Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFF4400).withValues(alpha: dark ? 0.13 : 0.09),
  );

  // Contour extérieur RED plein
  canvas.drawPath(
    pathRed,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = dark ? 2.0 : 1.5
      ..color = const Color(0xFFFF3300).withValues(alpha: dark ? 0.75 : 0.60),
  );

  // Contour tirets RED
  _drawDashedPath(
    canvas,
    path: pathRed,
    bounds: boundsRed,
    color: const Color(0xFFFF6644).withValues(alpha: dark ? 0.55 : 0.45),
    strokeWidth: 1.5,
    dashLength: 14.0,
    gapLength: 9.0,
  );

  // ── Dessin zone de danger (P ≥ 50%) ─────────────────────────────────────
  if (dangerRadiusPx > 1.0) {
    // Remplissage rouge vif
    canvas.drawPath(
      pathDanger,
      Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFF0000).withValues(alpha: dark ? 0.30 : 0.22),
    );

    // Contour danger plein
    canvas.drawPath(
      pathDanger,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = dark ? 2.5 : 2.0
        ..color = const Color(0xFFFF0000).withValues(alpha: dark ? 0.88 : 0.72),
    );
  }

  // ── Label unique (centroïde de la zone RED) ───────────────────────────────
  final centroid = _pathCentroid(centersPx);

  if (redRadiusPx > 15.0) {
    // Label RED : positionné au-dessus du bord supérieur de la zone
    final topY = boundsRed.top;
    _drawRedLabelAt(
      canvas,
      pos: Offset(centroid.dx, topY - 6),
      text: 'RED ${red.redM.round()} m  (${obusType.label})',
      color: const Color(0xFFFF4422),
      dark: dark,
      alignBottom: true,
    );
  }

  if (dangerRadiusPx > 15.0) {
    final boundsDanger = pathDanger.getBounds();
    _drawRedLabelAt(
      canvas,
      pos: Offset(centroid.dx, boundsDanger.top - 4),
      text: 'Danger  ${red.dangerRadiusM.round()} m',
      color: const Color(0xFFFF0000),
      dark: dark,
      alignBottom: true,
    );
  }
}

/// Centroïde simple d'une liste de points.
Offset _pathCentroid(List<Offset> pts) {
  if (pts.isEmpty) return Offset.zero;
  double sx = 0, sy = 0;
  for (final p in pts) {
    sx += p.dx;
    sy += p.dy;
  }
  return Offset(sx / pts.length, sy / pts.length);
}

/// Dessine un contour en tirets le long d'un Path.
/// Approximation : on parcourt le contour du bounding box avec des arcs
/// pour chaque disque constitutif (les paths Flutter ne permettent pas
/// nativement de mesurer/subdiviser un Path arbitraire).
/// Ici on utilise une approche simple : on redessine le contour du path
/// en stroke avec un PathEffect émulé via des segments.
void _drawDashedPath(
  Canvas canvas, {
  required Path path,
  required Rect bounds,
  required Color color,
  required double strokeWidth,
  required double dashLength,
  required double gapLength,
}) {
  // Flutter ne supporte pas PathEffect nativement sur Canvas.
  // On utilise une technique de clipping : on dessine le path en stroke
  // normal, puis on le recouvre par segments blancs pour simuler les tirets.
  // Alternative plus simple : dessiner le contour plein avec opacité réduite
  // (déjà fait dans drawRedZoneGlobal), et ajouter ici un second trait
  // légèrement plus épais en tirets via une approximation par arcs.
  //
  // Pour une vraie implémentation de tirets sur path arbitraire,
  // il faudrait PathMetrics (disponible en Flutter).
  final metrics = path.computeMetrics();
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..color = color
    ..strokeCap = StrokeCap.round;

  for (final metric in metrics) {
    double distance = 0.0;
    bool draw = true;
    while (distance < metric.length) {
      final next = distance + (draw ? dashLength : gapLength);
      if (draw) {
        final segment = metric.extractPath(
          distance,
          math.min(next, metric.length),
        );
        canvas.drawPath(segment, paint);
      }
      distance = next;
      draw = !draw;
    }
  }
}

/// Dessine un label à une position donnée.
void _drawRedLabelAt(
  Canvas canvas, {
  required Offset pos,
  required String text,
  required Color color,
  required bool dark,
  bool alignBottom = false,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        shadows: [
          Shadow(
            blurRadius: 3.0,
            color: dark ? Colors.black : Colors.white,
            offset: const Offset(0, 0),
          ),
        ],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final drawPos = alignBottom
      ? Offset(pos.dx - tp.width / 2, pos.dy - tp.height)
      : Offset(pos.dx - tp.width / 2, pos.dy);

  final bgRect = Rect.fromLTWH(
    drawPos.dx - 4,
    drawPos.dy - 2,
    tp.width + 8,
    tp.height + 4,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
    Paint()
      ..color = dark
          ? Colors.black.withValues(alpha: 0.60)
          : Colors.white.withValues(alpha: 0.80),
  );

  tp.paint(canvas, drawPos);
}

Path _buildAsymmetricEffectPath({
  required double frontPx,
  required double rearPx,
  required double lateralPx,
}) {
  const int steps = 40;
  final path = Path();

  Offset pointFor(double x) {
    final axis = x >= 0.0 ? frontPx : rearPx;
    final t = (x.abs() / axis).clamp(0.0, 1.0).toDouble();
    final y = lateralPx * math.sqrt(math.max(0.0, 1.0 - t * t));
    return Offset(x, y);
  }

  for (var i = 0; i <= steps; i++) {
    final x = -rearPx + (rearPx + frontPx) * (i / steps);
    final p = pointFor(x);
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }

  for (var i = steps; i >= 0; i--) {
    final x = -rearPx + (rearPx + frontPx) * (i / steps);
    final p = pointFor(x);
    path.lineTo(p.dx, -p.dy);
  }

  path.close();
  return path;
}
