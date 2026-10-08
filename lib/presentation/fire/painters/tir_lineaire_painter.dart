import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';

import 'package:calculateur_etranger/presentation/fire/models/repartition_view_mode.dart';
import 'package:calculateur_etranger/presentation/fire/painters/tir_painter_utils.dart';
import 'package:calculateur_etranger/presentation/fire/utils/tir_repartition_data.dart';

class LineairePainter extends CustomPainter {
  LineairePainter({
    required this.output,
    required this.longueurM,
    required this.debordPct,
    required this.dark,
    required this.azimutLineaireMil,
    required this.azimutTirMil,
    required this.pointAppLineaire,
    required this.pieceColors,
    required this.diametreEfficaciteM,
    required this.pieceIndex,
    required this.selectedSalve,
    required this.viewMode,
    required this.showSpatialDistribution,
  });

  final TirCompletOutput output;
  final double longueurM;
  final double debordPct;
  final bool dark;
  final double azimutLineaireMil;
  final double azimutTirMil;
  final PointApplicationLineaire? pointAppLineaire;
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

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = dark ? const Color(0xFF0E0F12) : const Color(0xFFF4F5F7),
    );

    final L = longueurM <= 0 ? 1.0 : longueurM;

    final deb = (debordPct / 100.0).clamp(0.0, 0.8);

    final Le = L * (1 + deb);

    final u = dirFromAzMil(azimutLineaireMil);
    final v = rot90(u);

    final pa = pointAppLineaire ?? PointApplicationLineaire.centre;

    double sMin;
    double sMax;

    switch (pa) {
      case PointApplicationLineaire.centre:
        sMin = -L / 2;
        sMax = L / 2;
        break;
      default:
        // Compatibility fallback: do not infer a directional endpoint rule.
        sMin = -L / 2;
        sMax = L / 2;
        break;
    }

    final mid = (sMin + sMax) / 2;

    final extMin = mid - Le / 2;
    final extMax = mid + Le / 2;

    final prX = output.prX;
    final prY = output.prY;

    final pts = <({double s, double t, TirLineaireShot shot})>[];

    final sortedShots = visibleShots.toList()
      ..sort((a, b) {
        final sa = a.numeroSalve ?? 999999;
        final sb = b.numeroSalve ?? 999999;

        if (sa != sb) {
          return sa.compareTo(sb);
        }

        final ra = pieceIndex[a.nomPiece] ?? 999999;
        final rb = pieceIndex[b.nomPiece] ?? 999999;

        if (ra != rb) {
          return ra.compareTo(rb);
        }

        return a.nomPiece.compareTo(b.nomPiece);
      });

    double minS = extMin;
    double maxS = extMax;

    double minT = 0;
    double maxT = 0;

    for (int i = 0; i < sortedShots.length; i++) {
      final shot = sortedShots[i];

      late final double s;
      late final double t;

      final dx = shot.objX - prX;
      final dy = shot.objY - prY;

      s = dx * u.dx + (-dy) * u.dy;

      final isEclairant = diametreEfficaciteM >= 600.0;

      if (viewMode == RepartitionViewMode.theorique || isEclairant) {
        // En théorie, on conserve la position doctrinale calculée du coup
        // sur l'axe linéaire. Il ne faut pas redistribuer les coups selon
        // l'ordre des pièces, sinon la vue devient une simple file régulière
        // qui ne correspond plus au plan de tir réel généré.
        t = 0.0;
      } else {
        t = dx * v.dx + (-dy) * v.dy;
      }

      pts.add((s: s, t: t, shot: shot));

      minS = math.min(minS, s);
      maxS = math.max(maxS, s);

      minT = math.min(minT, t);
      maxT = math.max(maxT, t);

      final coverage = shot.coverageEllipse;

      if (coverage != null) {
        // IMPORTANT :
        // même échelle entre Théorique / Réel / Répartition.
        // On conserve donc TOUJOURS l’emprise réelle maximale
        // dans les bornes monde, même si on affiche uniquement
        // le cercle doctrinal.

        // profondeur RTC
        minS = math.min(minS, s - coverage.semiMajorAxis);
        maxS = math.max(maxS, s + coverage.semiMajorAxis);

        // largeur RTC
        minT = math.min(minT, t - coverage.semiMinorAxis);
        maxT = math.max(maxT, t + coverage.semiMinorAxis);
      }
    }

    final R = (diametreEfficaciteM <= 0 ? 100.0 : diametreEfficaciteM) / 2.0;

    if (viewMode == RepartitionViewMode.theorique ||
        diametreEfficaciteM >= 600.0) {
      minS -= R;
      maxS += R;
    }

    minT -= R;
    maxT += R;

    if ((maxT - minT).abs() < 1e-6) {
      minT -= R;
      maxT += R;
    }

    const margin = 120.0;

    final rawW = math.max(1e-6, (maxS - minS).abs());
    final rawH = math.max(1e-6, (maxT - minT).abs());

    final sx = (size.width - 2 * margin) / rawW;
    final sy = (size.height - 2 * margin) / rawH;

    final scale = math.max(0.001, math.min(sx, sy));

    final screenCenter = Offset(size.width / 2, size.height / 2);

    final rawCenter = Offset((minS + maxS) / 2, (minT + maxT) / 2);

    final origin = screenCenter - (u * rawCenter.dx + v * rawCenter.dy) * scale;

    Offset toPx(double s, double t) {
      return origin + (u * s + v * t) * scale;
    }

    final ae = toPx(extMin, 0);
    final be = toPx(extMax, 0);

    canvas.drawLine(
      ae,
      be,
      Paint()
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..color = dark ? Colors.white24 : Colors.black26,
    );

    final a = toPx(sMin, 0);
    final b = toPx(sMax, 0);

    canvas.drawLine(
      a,
      b,
      Paint()
        ..strokeWidth = 4.2
        ..strokeCap = StrokeCap.round
        ..color = dark ? Colors.white70 : Colors.black87,
    );

    final pr = toPx(0, 0);

    final prColor = dark ? const Color(0xFFFFE44D) : Colors.amber.shade800;

    canvas.drawCircle(
      pr,
      16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = prColor,
    );

    final prText = TextPainter(
      text: TextSpan(
        text: 'PR',
        style: TextStyle(
          color: prColor,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    prText.paint(canvas, pr + Offset(18, -prText.height - 6));

    /// =========================
    /// VUE REELLE / DISTRIBUTION
    /// =========================

    if (viewMode.isRealLike) {
      for (final p in pts) {
        final coverage = p.shot.coverageEllipse;

        if (coverage == null) {
          continue;
        }

        final pt = toPx(p.s, p.t);

        final col = pieceColors[p.shot.nomPiece] ?? cPD;

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

    final rPx = R * scale;

    for (final p in pts) {
      final pt = toPx(p.s, p.t);

      final col = pieceColors[p.shot.nomPiece] ?? cPD;

      final String label = (p.shot.numeroSalve != null)
          ? '${p.shot.numeroSalve}'
          : '${(seen[p.shot.nomPiece] = (seen[p.shot.nomPiece] ?? 0) + 1)}';

      final isEclairant = diametreEfficaciteM >= 600.0;

      /// Cercle doctrinal en mode théorique, ou toujours pour l'éclairant
      if (viewMode == RepartitionViewMode.theorique || isEclairant) {
        if (isEclairant) {
          // remplissage zone éclairée
          canvas.drawCircle(
            pt,
            rPx,
            Paint()
              ..style = PaintingStyle.fill
              ..color = Colors.amber.withValues(alpha: dark ? 0.16 : 0.10),
          );

          // contour lumineux
          canvas.drawCircle(
            pt,
            rPx,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.amber.withValues(alpha: dark ? 0.95 : 0.75),
          );

          // petit halo interne
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
      drawCenteredText(canvas, pt, label);
    }

    _drawCompass(canvas, size);
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

    if ((azimutTirMil - azimutLineaireMil).abs() > 10) {
      final dirT = dirFromAzMil(azimutTirMil);

      const tirColor = cPD;

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

    final dirAxe = dirFromAzMil(azimutLineaireMil);

    const axeColor = Colors.amber;

    arrow(
      canvas,
      origin,
      dirAxe,
      38,
      Paint()
        ..strokeWidth = 2.5
        ..color = axeColor
        ..strokeCap = StrokeCap.round,
    );

    label(
      canvas,
      origin + dirAxe * 50,
      azimutLineaireMil.toStringAsFixed(0),
      color: axeColor,
      fontSize: 11,
    );
  }

  @override
  bool shouldRepaint(covariant LineairePainter old) {
    return old.output != output ||
        old.longueurM != longueurM ||
        old.debordPct != debordPct ||
        old.dark != dark ||
        old.azimutLineaireMil != azimutLineaireMil ||
        old.azimutTirMil != azimutTirMil ||
        old.pointAppLineaire != pointAppLineaire ||
        old.diametreEfficaciteM != diametreEfficaciteM ||
        old.pieceColors != pieceColors ||
        old.pieceIndex != pieceIndex ||
        old.selectedSalve != selectedSalve ||
        old.viewMode != viewMode ||
        old.showSpatialDistribution != showSpatialDistribution;
  }
}
