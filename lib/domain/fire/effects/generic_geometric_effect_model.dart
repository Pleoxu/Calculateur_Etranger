import 'dart:math' as math;

import 'package:calculateur_etranger/domain/fire/effects/terminal_effect_input.dart';
import 'package:calculateur_etranger/domain/fire/effects/terminal_effect_model.dart';
import 'package:calculateur_etranger/models/effects/coverage_ellipse.dart';
import 'package:flutter/foundation.dart';

class GenericGeometricEffectModel implements TerminalEffectModel {
  const GenericGeometricEffectModel({
    this.maxElongationFactor = 4.0,
    this.visualElongationK = 0.5,
    this.visualLambda = 2.0,
    this.visualForwardAlpha = 1.0,
    this.visualRearBeta = 0.5,
    this.frontActiveThreshold = 0.0,
  });

  final double maxElongationFactor;
  final double visualElongationK;
  final double visualLambda;
  final double visualForwardAlpha;
  final double visualRearBeta;
  final double frontActiveThreshold;

  @override
  CoverageEllipse build(TerminalEffectInput input) {
    final thetaRad = input.angleChuteDeg * math.pi / 180.0;
    final safeSin = math.sin(thetaRad).abs().clamp(0.20, 1.0).toDouble();
    final safeCos = math.cos(thetaRad).abs().clamp(0.0, 1.0).toDouble();

    final radius = math.max(1.0, input.effectiveDiameterM / 2.0);

    // Priorité à la cotangente officielle issue du tableau G.
    //
    // 1 / sin(theta) = sqrt(1 + cot(theta)^2)
    //
    // Le calcul depuis l'angle en degrés reste disponible comme repli lorsque
    // la cotangente n'est pas renseignée ou n'est pas exploitable.
    final cot = input.cotangenteAngleChute;
    final hasValidCot = cot != null && cot.isFinite;

    final projectionFactor =
        hasValidCot ? math.sqrt(1.0 + cot * cot) : 1.0 / safeSin;

    final semiMinorAxis = radius;
    final semiMajorAxis = math.min(
      math.max(radius * projectionFactor, radius),
      radius * maxElongationFactor,
    );

    final residualVelocity = input.residualVelocityMps;
    final referenceVelocity = input.referenceVelocityMps;
    final velocityRatio = residualVelocity != null &&
            residualVelocity > 0.0 &&
            referenceVelocity != null &&
            referenceVelocity > 0.0
        ? (residualVelocity / referenceVelocity).clamp(0.25, 2.0).toDouble()
        : 1.0;

    final visualSemiMajorAxis =
        radius * (1.0 + visualElongationK * velocityRatio * safeCos);
    final visualSemiMinorAxis = math.max(1.0, radius * safeSin);

    if (kDebugMode) {
      debugPrint(
        '[TERMINAL EFFECT] '
        'model=generic '
        'angle=${input.angleChuteDeg.toStringAsFixed(2)} '
        'cot=${input.cotangenteAngleChute?.toStringAsFixed(4)} '
        'factor=${projectionFactor.toStringAsFixed(4)} '
        'diameter=${input.effectiveDiameterM.toStringAsFixed(2)} '
        'major=${semiMajorAxis.toStringAsFixed(2)} '
        'minor=${semiMinorAxis.toStringAsFixed(2)} '
        'epp=${input.ecartProbablePorteeM?.toStringAsFixed(2)} '
        'epd=${input.ecartProbableDirectionM?.toStringAsFixed(2)}',
      );
    }

    return CoverageEllipse(
      centerX: input.centerX,
      centerY: input.centerY,
      azimutMil: input.azimutMil,
      semiMajorAxis: semiMajorAxis,
      semiMinorAxis: semiMinorAxis,
      lethalRadius: radius,
      angleChuteDeg: input.angleChuteDeg,
      burstHeightM: input.burstHeightM,
      visualSemiMajorAxis: visualSemiMajorAxis,
      visualSemiMinorAxis: visualSemiMinorAxis,
      visualLambda: visualLambda,
      visualForwardAlpha: visualForwardAlpha,
      visualRearBeta: visualRearBeta,
      frontActiveThreshold: frontActiveThreshold,
      directionalAlpha: 0.0,
      forwardBackwardRatio: 1.0,
    );
  }
}
