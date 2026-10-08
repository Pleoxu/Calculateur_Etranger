import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';

import 'package:calculateur_etranger/presentation/fire/models/repartition_view_mode.dart';
import 'package:calculateur_etranger/presentation/fire/painters/tir_lineaire_painter.dart';
import 'package:calculateur_etranger/presentation/fire/painters/tir_zonal_painter.dart';
import 'package:calculateur_etranger/presentation/fire/painters/tir_painter_utils.dart';
import 'package:calculateur_etranger/presentation/fire/utils/tir_repartition_data.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/adaptive_info_line.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/tir_repartition_controls.dart';
import 'package:calculateur_etranger/presentation/fire/pages/red_page.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/tir_repartition_legend.dart';

class TirRepartitionPage extends StatefulWidget {
  const TirRepartitionPage({
    super.key,
    required this.output,
    required this.natureType,
    required this.longueurM,
    required this.profondeurM,
    required this.dark,
    this.debordPct,
    this.pointAppLineaire,
    this.azimutLineaireMil,
    this.pointAppZonal,
    this.azimutLargeurMil,
    this.azimutProfondeurMil,
    this.azimutTirMil,
    this.diametreEfficaciteM = 100.0,
    this.utmZone,
    this.fusee,
    this.typeTir,
    this.observateurX,
    this.observateurY,
    this.observateurZ,
    this.showObservateur = false,
  });

  final TirCompletOutput output;
  final NatureTirType natureType;
  final double longueurM;
  final double profondeurM;
  final bool dark;
  final double? debordPct;
  final PointApplicationLineaire? pointAppLineaire;
  final double? azimutLineaireMil;
  final PointZonal? pointAppZonal;
  final double? azimutLargeurMil;
  final double? azimutProfondeurMil;
  final double? azimutTirMil;
  final double diametreEfficaciteM;

  /// Zone UTM de la pièce directrice (ex. "31T", "31N").
  final String? utmZone;

  /// Fusée sélectionnée (FRAPPE, RALEC, FUCHSIA).
  final TypeFusee? fusee;

  /// Type de tir (appui ou eclairant).
  final TypeTir? typeTir;

  /// Coordonnées observateur en UTM, transmises à la page RED.
  final double? observateurX;
  final double? observateurY;
  final double? observateurZ;

  /// Afficher l'observateur sur RED/Zone éclairée.
  final bool showObservateur;

  @override
  State<TirRepartitionPage> createState() => _TirRepartitionPageState();
}

class _TirRepartitionPageState extends State<TirRepartitionPage> {
  int? _selectedSalve;

  RepartitionViewMode _viewMode = RepartitionViewMode.reelle;

  @override
  Widget build(BuildContext context) {
    final output = widget.output;

    if (output.shots.isEmpty) {
      return const Scaffold(body: Center(child: Text('No rounds to display.')));
    }

    final dark = widget.dark;
    final textColor = dark ? Colors.white : Colors.black87;
    final bg = dark ? const Color(0xFF0E0F12) : const Color(0xFFF4F5F7);

    final isPonctuelView = widget.natureType == NatureTirType.ponctuel ||
        (widget.longueurM.abs() <= 0.001 && widget.profondeurM.abs() <= 0.001);

    final salveOptions =
        isPonctuelView ? const <int>[] : buildSalveOptions(output);
    final showSalveFilter = salveOptions.length > 1;

    if (_selectedSalve != null && !salveOptions.contains(_selectedSalve)) {
      _selectedSalve = null;
    }

    final selectedSalve = showSalveFilter ? _selectedSalve : null;
    final rawVisibleShots = filterShotsBySalve(output.shots, selectedSalve);
    final pdShot = _pdShot(output.shots);
    final visibleShots =
        isPonctuelView ? <TirLineaireShot>[pdShot] : rawVisibleShots;

    final debordPct = (widget.debordPct ?? output.debordPct).clamp(0.0, 80.0);
    final azimutTirMil = widget.azimutTirMil ?? output.firePlan.azimutMilOut;

    final isZonal = !isPonctuelView &&
        widget.natureType == NatureTirType.zonal &&
        widget.profondeurM > 0.0;

    // Détection du tir éclairant
    final isEclairant = widget.typeTir == TypeTir.eclairant ||
        (output.shots.isNotEmpty &&
            output.shots.first.resultat.typeAssets.toUpperCase().contains(
                  'OECL',
                ));

    final title = isEclairant
        ? 'Illuminating'
        : isPonctuelView
            ? 'Point Distribution'
            : (isZonal ? 'Zonal Distribution' : 'Linear Distribution');

    final pieceColors = isPonctuelView
        ? <String, Color>{'PD': const Color(0xFF2EE6A6)}
        : buildPieceColors(output.shots);

    final painterData = buildPainterData(
      output: output,
      pieceColors: pieceColors,
      isZonal: isZonal,
      azimutLargeurMil: widget.azimutLargeurMil,
      azimutLineaireMil: widget.azimutLineaireMil,
      azimutTirMil: azimutTirMil,
    );

    final orderedLegendIds =
        isPonctuelView ? <String>['PD'] : painterData.orderedIds;

    final effectivePieceIndex =
        isPonctuelView ? <String, int>{'PD': 0} : painterData.pieceIndex;

    final painter = isPonctuelView
        ? _PonctuelPainter(
            output: output,
            shot: pdShot,
            dark: dark,
            azimutTirMil: azimutTirMil,
            diametreEfficaciteM: widget.diametreEfficaciteM,
            color: pieceColors['PD'] ?? const Color(0xFF2EE6A6),
            viewMode: _viewMode,
            showSpatialDistribution: _viewMode.showsSpatialDistribution,
          )
        : isZonal
            ? ZonalPainter(
                output: output,
                longueurM: widget.longueurM,
                profondeurM: widget.profondeurM,
                debordPct: debordPct,
                dark: dark,
                azimutTirMil: azimutTirMil,
                azimutLargeurMil: widget.azimutLargeurMil ??
                    ((azimutTirMil + 1600.0) % 6400.0),
                azimutProfondeurMil: widget.azimutProfondeurMil ?? azimutTirMil,
                pointAppZonal: widget.pointAppZonal,
                pieceColors: pieceColors,
                diametreEfficaciteM: widget.diametreEfficaciteM,
                pieceIndex: effectivePieceIndex,
                selectedSalve: selectedSalve,
                viewMode: _viewMode,
                showSpatialDistribution: _viewMode.showsSpatialDistribution,
              )
            : LineairePainter(
                output: output,
                longueurM: widget.longueurM,
                debordPct: debordPct,
                dark: dark,
                azimutLineaireMil:
                    widget.azimutLineaireMil ?? output.firePlan.azimutMilOut,
                azimutTirMil: azimutTirMil,
                pointAppLineaire: widget.pointAppLineaire,
                pieceColors: pieceColors,
                diametreEfficaciteM: widget.diametreEfficaciteM,
                pieceIndex: effectivePieceIndex,
                selectedSalve: selectedSalve,
                viewMode: _viewMode,
                showSpatialDistribution: _viewMode.showsSpatialDistribution,
              );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: textColor,
        elevation: 0,
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RedPage(
                      output: output,
                      dark: dark,
                      azimutTirMil: azimutTirMil,
                      utmZone: widget.utmZone ?? '31T',
                      fusee: widget.fusee,
                      typeTir: widget.typeTir,
                      azimutLineaireMil:
                          isPonctuelView ? null : widget.azimutLineaireMil,
                      azimutLargeurMil:
                          isPonctuelView ? null : widget.azimutLargeurMil,
                      azimutProfondeurMil:
                          isPonctuelView ? null : widget.azimutProfondeurMil,
                      observateurX: widget.observateurX,
                      observateurY: widget.observateurY,
                      observateurZ: widget.observateurZ,
                      showObservateur: widget.showObservateur ||
                          (widget.observateurX != null &&
                              widget.observateurY != null),
                    ),
                  ),
                );
              },
              icon: Icon(
                isEclairant
                    ? Icons.wb_incandescent_outlined
                    : Icons.warning_amber_rounded,
                size: 18,
                color: isEclairant
                    ? const Color(0xFFDDAA00)
                    : const Color(0xFFFF4422),
              ),
              label: Text(
                isEclairant ? 'Illuminated area' : 'RED',
                style: TextStyle(
                  color: isEclairant
                      ? const Color(0xFFDDAA00)
                      : const Color(0xFFFF4422),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: isPonctuelView
                  ? _buildPonctuelInfoLine(
                      textColor: textColor,
                      output: output,
                      visibleShots: visibleShots,
                    )
                  : isZonal
                      ? _buildZonalInfoLine(
                          textColor: textColor,
                          output: output,
                          visibleShots: visibleShots,
                          visibleCount: visibleShots.length,
                          debordPct: debordPct,
                          selectedSalve: selectedSalve,
                          azimutTirMil: azimutTirMil,
                        )
                      : _buildLineaireInfoLine(
                          textColor: textColor,
                          output: output,
                          visibleShots: visibleShots,
                          visibleCount: visibleShots.length,
                          debordPct: debordPct,
                          selectedSalve: selectedSalve,
                        ),
            ),
            TirRepartitionLegend(
              orderedIds: orderedLegendIds,
              pieceColors: pieceColors,
              textColor: textColor,
            ),
            // En mode éclairant, masquer les chips Théorique/Réel/Distribution
            // et afficher un message invitant à ouvrir la zone éclairée.
            if (isEclairant)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Center(
                  child: Text(
                    'Tap \'Illuminated zone\' to view the illuminated area on the map.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFDDAA00).withValues(alpha: 0.80),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: RepartitionControlsRow(
                  viewMode: _viewMode,
                  salves: showSalveFilter ? salveOptions : const <int>[],
                  selectedSalve: selectedSalve,
                  dark: dark,
                  onViewModeChanged: (mode) => setState(() => _viewMode = mode),
                  onSalveChanged: (value) =>
                      setState(() => _selectedSalve = value),
                ),
              ),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;

                  if (size.width <= 0 || size.height <= 0) {
                    return const Center(child: Text("Invalid display area."));
                  }

                  return InteractiveViewer(
                    minScale: 0.2,
                    maxScale: 8,
                    boundaryMargin: const EdgeInsets.all(250),
                    child: CustomPaint(
                      size: size,
                      painter: painter,
                      child: const SizedBox.expand(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  TirLineaireShot _pdShot(List<TirLineaireShot> shots) {
    for (final shot in shots) {
      if (shot.nomPiece.trim().toUpperCase() == 'PD') {
        return shot;
      }
    }

    return shots.first;
  }

  Widget _buildPonctuelInfoLine({
    required Color textColor,
    required TirCompletOutput output,
    required List<TirLineaireShot> visibleShots,
  }) {
    final result = _firstResult(visibleShots);

    final ballisticLine = '${_tirLabel(output, visibleShots)}'
        '${_distancePart(result)}'
        '${_chargePart(result)}'
        '${_vitessePart(result)}'
        '${_angleChutePart(visibleShots)}';

    const missionLine = 'Point • PD • Rounds: 1';

    return AdaptiveInfoLine(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ballisticLine,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            missionLine,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildZonalInfoLine({
    required Color textColor,
    required TirCompletOutput output,
    required List<TirLineaireShot> visibleShots,
    required int visibleCount,
    required double debordPct,
    required int? selectedSalve,
    required double azimutTirMil,
  }) {
    final azP = widget.azimutProfondeurMil ?? azimutTirMil;
    final azL = widget.azimutLargeurMil ?? ((azP + 1600.0) % 6400.0);
    final result = _firstResult(visibleShots);

    final specialLabel = specialZonalLabel(
      longueurM: widget.longueurM,
      profondeurM: widget.profondeurM,
      salves: salveCount(output),
    );

    final ballisticLine = '${_tirLabel(output, visibleShots)}'
        '${_distancePart(result)}'
        '${_chargePart(result)}'
        '${_vitessePart(result)}'
        '${_angleChutePart(visibleShots)}'
        ' • L:${azL.toStringAsFixed(0)}'
        ' • P:${azP.toStringAsFixed(0)}'
        ' • FIRE:${azimutTirMil.toStringAsFixed(0)}';

    final missionPrefix =
        specialLabel == null ? 'Zonal' : 'Zonal • $specialLabel';

    final missionLine = '$missionPrefix: '
        '${widget.longueurM.toStringAsFixed(0)}×${widget.profondeurM.toStringAsFixed(0)} m'
        ' • Overrun: ${debordPct.toStringAsFixed(0)}%'
        ' • Rounds: $visibleCount'
        ' • ${salveLabel(selectedSalve)}';

    return AdaptiveInfoLine(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ballisticLine,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            missionLine,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLineaireInfoLine({
    required Color textColor,
    required TirCompletOutput output,
    required List<TirLineaireShot> visibleShots,
    required int visibleCount,
    required double debordPct,
    required int? selectedSalve,
  }) {
    final azLin =
        widget.azimutLineaireMil ?? widget.output.firePlan.azimutMilOut;
    final result = _firstResult(visibleShots);

    final ballisticLine = '${_tirLabel(output, visibleShots)}'
        '${_distancePart(result)}'
        '${_chargePart(result)}'
        '${_vitessePart(result)}'
        '${_angleChutePart(visibleShots)}'
        ' • AZ:${azLin.toStringAsFixed(0)}';

    final missionLine = 'Linear: ${widget.longueurM.toStringAsFixed(0)} m'
        ' • PA: ${paLineaireLabel(widget.pointAppLineaire)}'
        ' • Overrun: ${debordPct.toStringAsFixed(0)}%'
        ' • Rounds: $visibleCount'
        ' • ${salveLabel(selectedSalve)}';

    return AdaptiveInfoLine(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ballisticLine,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            missionLine,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  CalculResult? _firstResult(List<TirLineaireShot> visibleShots) {
    return widget.output.resultatPrincipal ??
        widget.output.resultatPd ??
        (visibleShots.isNotEmpty
            ? visibleShots.first.resultat
            : (widget.output.shots.isNotEmpty
                ? widget.output.shots.first.resultat
                : null));
  }

  String _tirLabel(
    TirCompletOutput output,
    List<TirLineaireShot> visibleShots,
  ) {
    final result = _firstResult(visibleShots);
    final raw = result?.typeAssets.trim() ?? '';

    if (raw.toLowerCase().contains('ecl') ||
        raw.toLowerCase().contains('écl')) {
      return 'Illuminating';
    }

    return 'Appui';
  }

  String _distancePart(CalculResult? result) {
    if (result == null) {
      return '';
    }

    final distanceVisee = result.distanceTopoM + result.totalLongM;

    if (distanceVisee <= 0.0) {
      return '';
    }

    return ' • D:${distanceVisee.round()} m';
  }

  String _chargePart(CalculResult? result) {
    if (result == null) {
      return '';
    }

    final charge = result.charge.trim();

    if (charge.isEmpty) {
      return '';
    }

    final normalized = charge.toUpperCase().startsWith('CH')
        ? charge.toUpperCase()
        : 'CH${charge.toUpperCase()}';

    return ' • $normalized';
  }

  String _vitessePart(CalculResult? result) {
    final v = result?.vitesseRestanteMps;

    if (v == null || v <= 0.0) {
      return '';
    }

    return ' • Vw:${v.round()} m/s';
  }

  String _angleChutePart(List<TirLineaireShot> visibleShots) {
    final angleDeg = _firstNumber([
      () => visibleShots.isNotEmpty
          ? visibleShots.first.coverageEllipse?.angleChuteDeg
          : null,
      () => widget.output.shots.first.coverageEllipse?.angleChuteDeg,
    ]);

    if (angleDeg <= 0.0) {
      return '';
    }

    final angleMil = angleDeg * 6400.0 / 360.0;

    return ' • θ:${angleMil.round()} mil';
  }

  double _firstNumber(List<Object? Function()> readers) {
    for (final reader in readers) {
      final value = _safeRead(reader);

      if (value is num) {
        return value.toDouble();
      }

      if (value is String) {
        final parsed = double.tryParse(value.replaceAll(',', '.'));
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return 0.0;
  }

  Object? _safeRead(Object? Function() reader) {
    try {
      return reader();
    } catch (_) {
      return null;
    }
  }
}

class _PonctuelPainter extends CustomPainter {
  const _PonctuelPainter({
    required this.output,
    required this.shot,
    required this.dark,
    required this.azimutTirMil,
    required this.diametreEfficaciteM,
    required this.color,
    required this.viewMode,
    required this.showSpatialDistribution,
  });

  final TirCompletOutput output;
  final TirLineaireShot shot;
  final bool dark;
  final double azimutTirMil;
  final double diametreEfficaciteM;
  final Color color;
  final RepartitionViewMode viewMode;
  final bool showSpatialDistribution;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = dark ? const Color(0xFF0E0F12) : const Color(0xFFF4F5F7),
    );

    final center = Offset(size.width / 2.0, size.height / 2.0);

    final localShot = _localPoint(shot.objX, shot.objY);
    final scale = _scaleFor(size, localShot);

    Offset toCanvas(Offset p) =>
        Offset(center.dx + p.dx * scale, center.dy - p.dy * scale);

    final pr = toCanvas(Offset.zero);
    final point = toCanvas(localShot);

    final linePaint = Paint()
      ..color = dark ? Colors.white60 : Colors.black54
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(pr, point, linePaint);

    final radiusPx = (diametreEfficaciteM / 2.0 * scale).clamp(28.0, 120.0);

    if (viewMode.isRealLike && shot.coverageEllipse != null) {
      drawCoverageEllipse(
        canvas,
        coverage: shot.coverageEllipse!,
        centerPx: point,
        scale: scale,
        color: color,
        dark: dark,
        showSpatialDistribution: showSpatialDistribution,
      );
    } else if (viewMode == RepartitionViewMode.theorique) {
      canvas.drawCircle(
        point,
        radiusPx,
        Paint()
          ..color = color.withValues(alpha: dark ? 0.35 : 0.30)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
    } else {
      canvas.drawCircle(
        point,
        radiusPx,
        Paint()
          ..color = color.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        point,
        radiusPx,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke,
      );
    }

    final markerFill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final markerStroke = Paint()
      ..color = Colors.black.withValues(alpha: 0.75)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(point, 15, markerFill);
    canvas.drawCircle(point, 15, markerStroke);

    _drawCenteredText(
      canvas,
      text: '1',
      center: point,
      color: Colors.white,
      fontSize: 17,
      fontWeight: FontWeight.w900,
    );

    _drawCenteredText(
      canvas,
      text: 'PR',
      center: pr + const Offset(42, -18),
      color: const Color(0xFFFFE34D),
      fontSize: 24,
      fontWeight: FontWeight.w900,
    );

    _drawCenteredText(
      canvas,
      text: 'PD',
      center: point + const Offset(42, -32),
      color: color,
      fontSize: 20,
      fontWeight: FontWeight.w900,
    );
  }

  Offset _localPoint(double x, double y) {
    final azRad = azimutTirMil * 2.0 * math.pi / 6400.0;
    final ux = math.sin(azRad);
    final uy = math.cos(azRad);

    final dx = x - output.prX;
    final dy = y - output.prY;

    return Offset(dx * ux + dy * uy, dx * uy - dy * ux);
  }

  double _scaleFor(Size size, Offset p) {
    final extent = math.max(
      200.0,
      math.max(p.dx.abs(), p.dy.abs()) + diametreEfficaciteM,
    );

    final available = math.min(size.width, size.height) * 0.42;
    return available / extent;
  }

  void _drawCenteredText(
    Canvas canvas, {
    required String text,
    required Offset center,
    required Color color,
    required double fontSize,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          shadows: const [
            Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, center - Offset(tp.width / 2.0, tp.height / 2.0));
  }

  @override
  bool shouldRepaint(covariant _PonctuelPainter oldDelegate) {
    return oldDelegate.output != output ||
        oldDelegate.shot != shot ||
        oldDelegate.dark != dark ||
        oldDelegate.azimutTirMil != azimutTirMil ||
        oldDelegate.diametreEfficaciteM != diametreEfficaciteM ||
        oldDelegate.color != color ||
        oldDelegate.viewMode != viewMode ||
        oldDelegate.showSpatialDistribution != showSpatialDistribution;
  }
}
