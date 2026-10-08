import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';

import 'package:calculateur_etranger/presentation/fire/models/repartition_view_mode.dart';
import 'package:calculateur_etranger/presentation/fire/painters/tir_painter_utils.dart';
import 'package:calculateur_etranger/presentation/fire/utils/tir_repartition_data.dart';

class ZonalPainter extends CustomPainter {
  ZonalPainter({
    required this.output,
    required this.longueurM,
    required this.profondeurM,
    required this.debordPct,
    required this.dark,
    required this.azimutTirMil,
    required this.azimutLargeurMil,
    required this.azimutProfondeurMil,
    required this.pointAppZonal,
    required this.pieceColors,
    required this.diametreEfficaciteM,
    required this.pieceIndex,
    required this.selectedSalve,
    required this.viewMode,
    required this.showSpatialDistribution,
  });

  final TirCompletOutput output;
  final double longueurM;
  final double profondeurM;
  final double debordPct;
  final bool dark;
  final double azimutTirMil;
  final double azimutLargeurMil;
  final double azimutProfondeurMil;
  final PointZonal? pointAppZonal;
  final Map<String, Color> pieceColors;
  final double diametreEfficaciteM;
  final Map<String, int> pieceIndex;
  final int? selectedSalve;
  final RepartitionViewMode viewMode;
  final bool showSpatialDistribution;

  List<TirLineaireShot> get visibleShots {
    if (selectedSalve == null) {
      return output.shots;
    }

    return output.shots.where((s) => s.numeroSalve == selectedSalve).toList();
  }

  PointZonal get zonalPoint => pointAppZonal ?? PointZonal.centre;

  List<Offset> _innerRectLocal(double l, double p) {
    return [
      Offset(-l / 2.0, -p / 2.0),
      Offset(l / 2.0, -p / 2.0),
      Offset(l / 2.0, p / 2.0),
      Offset(-l / 2.0, p / 2.0),
    ];
  }

  List<Offset> _outerRectLocal(double l, double p, double debordPct) {
    final factor = 1.0 + (debordPct / 100.0);
    final extL = l * factor;
    final extP = p * factor;

    return [
      Offset(-extL / 2.0, -extP / 2.0),
      Offset(extL / 2.0, -extP / 2.0),
      Offset(extL / 2.0, extP / 2.0),
      Offset(-extL / 2.0, extP / 2.0),
    ];
  }

  List<({double l, double p, TirLineaireShot shot})>
      _buildRealProjectedShotsLocal() {
    final prX = output.prX;
    final prY = output.prY;

    final azLRadW = milToRad(azimutLargeurMil);
    final azPRadW = milToRad(azimutProfondeurMil);

    final uLxW = math.sin(azLRadW);
    final uLyW = math.cos(azLRadW);

    final uPxW = math.sin(azPRadW);
    final uPyW = math.cos(azPRadW);

    final out = <({double l, double p, TirLineaireShot shot})>[];

    for (final shot in visibleShots) {
      final dxW = shot.objX - prX;
      final dyW = shot.objY - prY;

      final dL = dxW * uLxW + dyW * uLyW;
      final dP = dxW * uPxW + dyW * uPyW;

      out.add((l: dL, p: dP, shot: shot));
    }

    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (longueurM <= 0 || profondeurM <= 0) {
      return;
    }

    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = dark ? const Color(0xFF0E0F12) : const Color(0xFFF4F5F7),
    );

    final L = longueurM;
    final P = profondeurM;

    final uL = dirFromAzMil(azimutLargeurMil);
    final uP = dirFromAzMil(azimutProfondeurMil);

    final R = (diametreEfficaciteM <= 0 ? 100.0 : diametreEfficaciteM) / 2.0;

    final innerLocal = _innerRectLocal(L, P);
    final extLocal = _outerRectLocal(L, P, debordPct);

    // Source unique des positions : le plan de tir calculé en amont.
    // La vue Théorique ne doit pas reconstruire une grille locale au painter,
    // sinon elle diverge de la doctrine réelle déjà appliquée par le moteur
    // zonal. Elle affiche donc les mêmes points planifiés, sans ellipses.
    final shotsLocal = _buildRealProjectedShotsLocal();

    final extLs = extLocal.map((e) => e.dx).toList();
    final extPs = extLocal.map((e) => e.dy).toList();

    double minL = extLs.reduce(math.min);
    double maxL = extLs.reduce(math.max);
    double minP = extPs.reduce(math.min);
    double maxP = extPs.reduce(math.max);

    for (final e in shotsLocal) {
      minL = math.min(minL, e.l - R);
      maxL = math.max(maxL, e.l + R);

      minP = math.min(minP, e.p - R);
      maxP = math.max(maxP, e.p + R);

      // Étendre l'emprise selon les ellipses en mode réel
      if (viewMode.isRealLike) {
        final coverage = e.shot.coverageEllipse;

        if (coverage != null) {
          // Axe longitudinal : profondeur de la forme d'effet.
          minL = math.min(minL, e.l - coverage.semiMajorAxis);
          maxL = math.max(maxL, e.l + coverage.semiMajorAxis);

          // Axe latéral : largeur réelle de la forme d'effet.
          // Ne pas utiliser semiMajorAxis ici, sinon l'échelle zonale est faussée.
          minP = math.min(minP, e.p - coverage.semiMinorAxis);
          maxP = math.max(maxP, e.p + coverage.semiMinorAxis);
        }
      }
    }

    final allL = <double>[
      ...innerLocal.map((e) => e.dx),
      ...extLocal.map((e) => e.dx),
      minL,
      maxL,
    ];

    final allP = <double>[
      ...innerLocal.map((e) => e.dy),
      ...extLocal.map((e) => e.dy),
      minP,
      maxP,
    ];

    const margin = 120.0;

    final rawW = math.max(1e-6, allL.reduce(math.max) - allL.reduce(math.min));

    final rawH = math.max(1e-6, allP.reduce(math.max) - allP.reduce(math.min));

    final sx = (size.width - 2 * margin) / rawW;
    final sy = (size.height - 2 * margin) / rawH;

    final scale = math.max(0.001, math.min(sx, sy));

    final rawCenter = Offset(
      (allL.reduce(math.min) + allL.reduce(math.max)) / 2.0,
      (allP.reduce(math.min) + allP.reduce(math.max)) / 2.0,
    );

    final screenCenter = Offset(size.width / 2.0, size.height / 2.0);

    final origin =
        screenCenter - (uL * rawCenter.dx + uP * rawCenter.dy) * scale;

    Offset toPxLP(double lM, double pM) {
      return origin + uL * (lM * scale) + uP * (pM * scale);
    }

    final innerPx = innerLocal.map((e) => toPxLP(e.dx, e.dy)).toList();
    final extPx = extLocal.map((e) => toPxLP(e.dx, e.dy)).toList();

    final prPx = toPxLP(0.0, 0.0);
    final rPx = R * scale;

    _strokeQuad(
      canvas,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = dark ? Colors.white24 : Colors.black26,
      extPx[0],
      extPx[1],
      extPx[2],
      extPx[3],
    );

    _strokeQuad(
      canvas,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = dark ? Colors.white70 : Colors.black87,
      innerPx[0],
      innerPx[1],
      innerPx[2],
      innerPx[3],
    );

    _drawCross(canvas, prPx);
    _drawCompass(canvas, size);
    _drawSideLabels(canvas, innerPx[0], innerPx[1], innerPx[2], innerPx[3]);
    _drawPr(canvas, prPx);

    final shotsSorted = shotsLocal.toList()
      ..sort((a, b) {
        final sa = a.shot.numeroSalve ?? 999999;
        final sb = b.shot.numeroSalve ?? 999999;

        if (sa != sb) {
          return sa.compareTo(sb);
        }

        final ra = pieceIndex[a.shot.nomPiece] ?? 999999;
        final rb = pieceIndex[b.shot.nomPiece] ?? 999999;

        if (ra != rb) {
          return ra.compareTo(rb);
        }

        return a.shot.nomPiece.compareTo(b.shot.nomPiece);
      });

    /// =========================
    /// VUE REELLE / DISTRIBUTION
    /// =========================

    if (viewMode.isRealLike) {
      for (final e in shotsSorted) {
        final coverage = e.shot.coverageEllipse;

        if (coverage == null) {
          continue;
        }

        final pt = toPxLP(e.l, e.p);
        final col = pieceColors[e.shot.nomPiece] ?? cPD;

        drawCoverageEllipse(
          canvas,
          coverage: coverage,
          centerPx: pt,
          scale: scale,
          color: col,
          dark: dark,
          showSpatialDistribution: showSpatialDistribution,
        );
      }
    }

    /// =========================
    /// POINTS / PASTILLES
    /// =========================

    final seen = <String, int>{};

    for (final e in shotsSorted) {
      final pt = toPxLP(e.l, e.p);
      final col = pieceColors[e.shot.nomPiece] ?? cPD;

      final String labelText = e.shot.numeroSalve != null
          ? '${e.shot.numeroSalve}'
          : '${(seen[e.shot.nomPiece] = (seen[e.shot.nomPiece] ?? 0) + 1)}';

      final isEclairant = diametreEfficaciteM >= 600.0;

      /// Cercle doctrinal en mode théorique, ou toujours pour l'éclairant.
      if (viewMode == RepartitionViewMode.theorique || isEclairant) {
        if (isEclairant) {
          canvas.drawCircle(
            pt,
            rPx,
            Paint()
              ..style = PaintingStyle.fill
              ..color = Colors.amber.withValues(alpha: dark ? 0.16 : 0.10),
          );

          canvas.drawCircle(
            pt,
            rPx,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.amber.withValues(alpha: dark ? 0.95 : 0.75),
          );

          canvas.drawCircle(
            pt,
            rPx * 0.55,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = Colors.amber.withValues(alpha: dark ? 0.35 : 0.25),
          );
        } else {
          canvas.drawCircle(
            pt,
            rPx,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = col.withValues(alpha: dark ? 0.35 : 0.30),
          );
        }
      }

      canvas.drawCircle(pt, 12.0, Paint()..color = const Color(0x66000000));
      canvas.drawCircle(pt, 9.5, Paint()..color = col);
      drawCenteredText(canvas, pt, labelText);
    }
  }

  void _strokeQuad(
    Canvas canvas,
    Paint p,
    Offset a,
    Offset b,
    Offset c,
    Offset d,
  ) {
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy)
        ..lineTo(d.dx, d.dy)
        ..close(),
      p,
    );
  }

  void _drawCross(Canvas canvas, Offset center) {
    final p = Paint()
      ..strokeWidth = 2
      ..color = dark ? Colors.white38 : Colors.black38;

    canvas.drawLine(
      center + const Offset(-10, 0),
      center + const Offset(10, 0),
      p,
    );

    canvas.drawLine(
      center + const Offset(0, -10),
      center + const Offset(0, 10),
      p,
    );
  }

  void _drawPr(Canvas canvas, Offset pr) {
    final prColor = dark ? const Color(0xFFF8D34A) : Colors.amber.shade800;

    canvas.drawCircle(pr, 10, Paint()..color = prColor);

    label(
      canvas,
      pr + const Offset(26, 0),
      'PR',
      color: prColor,
      fontSize: 14,
      fontWeight: FontWeight.w900,
    );
  }

  void _drawSideLabels(Canvas canvas, Offset a, Offset b, Offset c, Offset d) {
    final midAB = (a + b) * 0.5;
    final midAD = (a + d) * 0.5;

    badge(
      canvas,
      midAB + const Offset(-35, -40),
      'L ${azimutLargeurMil.toStringAsFixed(0)}',
      dark: dark,
    );

    badge(
      canvas,
      midAD + const Offset(-85, -18),
      'P ${azimutProfondeurMil.toStringAsFixed(0)}',
      dark: dark,
    );
  }

  void _drawCompass(Canvas canvas, Size size) {
    const double pad = 16;

    final origin = Offset(size.width - pad - 70, pad + 70);

    final textColor = dark ? Colors.white70 : Colors.black87;

    canvas.drawCircle(
      origin,
      32,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = dark ? Colors.white30 : Colors.black26,
    );

    const dirNord = Offset(0, -1);

    arrow(
      canvas,
      origin,
      dirNord,
      44,
      Paint()
        ..strokeWidth = 2
        ..color = textColor,
    );

    label(
      canvas,
      origin + dirNord * 62,
      'N',
      color: textColor,
      fontSize: 15,
      fontWeight: FontWeight.w900,
    );

    final dirT = dirFromAzMil(azimutTirMil);
    final tirColor = dark ? cPD : const Color(0xFF0B7D4F);

    arrow(
      canvas,
      origin,
      dirT,
      44,
      Paint()
        ..strokeWidth = 2.5
        ..color = tirColor,
    );

    label(
      canvas,
      origin + dirT * 58,
      azimutTirMil.toStringAsFixed(0),
      color: tirColor,
      fontSize: 11,
    );
  }

  @override
  bool shouldRepaint(covariant ZonalPainter old) {
    return old.output != output ||
        old.longueurM != longueurM ||
        old.profondeurM != profondeurM ||
        old.debordPct != debordPct ||
        old.dark != dark ||
        old.azimutTirMil != azimutTirMil ||
        old.azimutLargeurMil != azimutLargeurMil ||
        old.azimutProfondeurMil != azimutProfondeurMil ||
        old.pointAppZonal != pointAppZonal ||
        old.diametreEfficaciteM != diametreEfficaciteM ||
        old.pieceColors != pieceColors ||
        old.pieceIndex != pieceIndex ||
        old.selectedSalve != selectedSalve ||
        old.viewMode != viewMode;
  }
}
