import 'dart:math' as math;

import 'package:calculateur_etranger/domain/fire/effects/terminal_effect_factory.dart';
import 'package:calculateur_etranger/domain/fire/effects/terminal_effect_input.dart';
import 'package:calculateur_etranger/domain/fire/effects/terminal_effect_model.dart';
import 'package:calculateur_etranger/domain/fire/input/fire_request.dart';
import 'package:calculateur_etranger/domain/fire/models/fire_shots_result.dart';
import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';
import 'package:calculateur_etranger/domain/fire/utils/salves_planner.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/models/effects/coverage_ellipse.dart';
import 'package:calculateur_etranger/services/balistique_engine.dart';
import 'package:flutter/foundation.dart';

class FireShotsComputer {
  const FireShotsComputer();

  Future<FireShotsResult> compute({
    required FireRequest request,
    required FirePlan firePlan,
    required CalculInput baseInput,
    required double zP,
    required double zO,
    required double prX,
    required double prY,
  }) async {
    final swShots = Stopwatch()..start();
    var nbCalculsBalistiques = 0;

    const terminalEffectFactory = TerminalEffectFactory();
    final TerminalEffectModel terminalEffectModel =
        terminalEffectFactory.resolve();

    final List<TirLineaireShot> shots = <TirLineaireShot>[];
    final List<PieceSoutienOutput> psOutputs = <PieceSoutienOutput>[];

    CalculResult? resultatPrincipal;
    CalculResult? resultatPdAffecte;
    double principalOffsetM = 0.0;
    double principalObjX = prX;
    double principalObjY = prY;

    final pieceById = {for (final p in firePlan.pieces) p.id: p};

    Future<void> computeOneShot({
      required PieceGeom piece,
      required OffsetTarget target,
      int? numeroSalve,
      bool pdOnlyFirst = false,
    }) async {
      final dx = target.x - piece.x;
      final dy = target.y - piece.y;

      final dist = math.sqrt(dx * dx + dy * dy);

      if (kDebugMode) {
        debugPrint(
          '[SHOT GEOMETRY] '
          'piece=${piece.id} '
          'targetIndex=${target.index} '
          'offset=${target.offsetM.toStringAsFixed(2)} '
          'dx=${dx.toStringAsFixed(2)} '
          'dy=${dy.toStringAsFixed(2)} '
          'distance=${dist.toStringAsFixed(2)} '
          'objX=${target.x.toStringAsFixed(2)} '
          'objY=${target.y.toStringAsFixed(2)} '
          'pieceX=${piece.x.toStringAsFixed(2)} '
          'pieceY=${piece.y.toStringAsFixed(2)}',
        );
      }

      var az = math.atan2(dx, dy) * 6400 / (2 * math.pi);
      if (az < 0) az += 6400;

      debugPrint(
        '[SHOT Z] piece=${piece.id} z=${piece.z} fallbackPdZ=$zP targetZ=$zO',
      );
      final input = baseInput.copyWith(
        pdX: piece.x,
        pdY: piece.y,
        pdZ: piece.z ?? zP,
        objX: target.x,
        objY: target.y,
        objZ: zO,
        objD: dist,
        objA: az,
      );

      nbCalculsBalistiques++;
      final swOneShot = Stopwatch()..start();
      final res = await BalistiqueEngine.calculer(input);
      swOneShot.stop();

      if (kDebugMode) {
        debugPrint(
          '[SHOT PERF] piece=${piece.id} '
          'offset=${target.offsetM.toStringAsFixed(1)} m '
          'elapsed=${swOneShot.elapsedMilliseconds} ms',
        );
      }

      final coverage = _buildCoverageEllipse(
        model: terminalEffectModel,
        input: input,
        res: res,
        target: target,
        azimutMil: az,
      );

      shots.add(
        TirLineaireShot(
          nomPiece: piece.id,
          offsetM: target.offsetM,
          objX: target.x,
          objY: target.y,
          resultat: res,
          numeroSalve: numeroSalve,
          count: 1,
          coverageEllipse: coverage,
        ),
      );

      final capturePd =
          pdOnlyFirst ? (piece.isPd && resultatPdAffecte == null) : piece.isPd;

      if (capturePd && resultatPdAffecte == null) {
        resultatPdAffecte = res;
        resultatPrincipal = res;
        principalOffsetM = target.offsetM;
        principalObjX = target.x;
        principalObjY = target.y;
      } else if (resultatPrincipal == null) {
        resultatPrincipal = res;
        principalOffsetM = target.offsetM;
        principalObjX = target.x;
        principalObjY = target.y;
      }

      if (!piece.isPd) {
        psOutputs.add(
          PieceSoutienOutput(
            nom: piece.id,
            xPS: piece.x,
            yPS: piece.y,
            zPS: piece.z,
            offsetM: target.offsetM,
            objX: target.x,
            objY: target.y,
            resultat: res,
          ),
        );
      }
    }

    final salvesOn = request.salves.enabled;

    final isEclairantZonal =
        baseInput.typeTir == TypeTir.eclairant && firePlan.kind.isZonal;

    if (salvesOn && !isEclairantZonal) {
      final plan = SalvesPlanner.buildPlan(
        pieces: firePlan.pieces,
        allocations: firePlan.allocs,
        shotsByPiece: firePlan.desiredShotsByPiece,
        prX: prX,
        prY: prY,
        azimutRefMil: firePlan.azimutMilOut,
        preferenceIdx: request.salves.preferenceIdx,
        lastSalveAroundPd: request.salves.lastSalveAroundPd,
      );

      for (int i = 0; i < plan.salves.length; i++) {
        final salve = plan.salves[i];

        for (final ps in salve.shots) {
          final piece = pieceById[ps.pieceId];
          if (piece == null) continue;

          await computeOneShot(
            piece: piece,
            target: ps.target,
            numeroSalve: i + 1,
          );
        }
      }
    } else {
      for (final alloc in firePlan.allocs) {
        for (final t in alloc.targets) {
          await computeOneShot(
            piece: alloc.piece,
            target: t,
            numeroSalve: isEclairantZonal ? 1 : null,
          );
        }
      }
    }

    swShots.stop();

    if (kDebugMode) {
      debugPrint(
        '[SHOTS PERF] coups=${shots.length} '
        'calculs=$nbCalculsBalistiques '
        'elapsed=${swShots.elapsedMilliseconds} ms',
      );
    }

    return FireShotsResult(
      shots: shots,
      psOutputs: psOutputs,
      resultatPd: resultatPdAffecte ?? resultatPrincipal,
      pdOffset: principalOffsetM,
      pdX: principalObjX,
      pdY: principalObjY,
    );
  }

  CoverageEllipse _buildCoverageEllipse({
    required TerminalEffectModel model,
    required CalculInput input,
    required CalculResult res,
    required OffsetTarget target,
    required double azimutMil,
  }) {
    double angleDeg;

    final angleChute = res.angleChuteDeg;
    final cotangente = res.cotangenteAngleChute;

    if (angleChute != null && angleChute.abs() > 0.001) {
      angleDeg = angleChute;
    } else if (cotangente != null && cotangente.abs() > 0.001) {
      angleDeg = math.atan(1.0 / cotangente.abs()) * 180.0 / math.pi;
    } else {
      angleDeg = 45.0;
    }

    final burstHeightM = _defaultBurstHeightM(input);

    final diametreEfficaciteM = input.typeTir == TypeTir.eclairant
        ? 600.0
        : input.systeme.diametreEfficaciteM;

    final terminalInput = TerminalEffectInput(
      centerX: target.x,
      centerY: target.y,
      azimutMil: azimutMil,
      angleChuteDeg: angleDeg,
      cotangenteAngleChute: res.cotangenteAngleChute,
      effectiveDiameterM: diametreEfficaciteM,
      ecartProbablePorteeM: res.ecartProbablePorteeM,
      ecartProbableDirectionM: res.ecartProbableDirectionM,
      residualVelocityMps: res.vitesseRestanteMps,
      referenceVelocityMps: res.vitesseRestanteMps,
      burstHeightM: burstHeightM,
    );

    return model.build(terminalInput);
  }

  double _defaultBurstHeightM(CalculInput input) {
    final fuseName = input.fusee.name.toUpperCase();

    if (fuseName.contains('RALEC')) return 9.0;
    if (fuseName.contains('PROX')) return 9.0;

    return 0.0;
  }
}
