import 'dart:math' as math;

import 'package:calculateur_etranger/domain/fire/effects/terminal_effect_input.dart';
import 'package:calculateur_etranger/domain/fire/effects/terminal_effect_model.dart';
import 'package:calculateur_etranger/domain/fire/effects/terminal_effect_profile.dart';
import 'package:calculateur_etranger/models/effects/coverage_ellipse.dart';

class MunitionTerminalEffectModel implements TerminalEffectModel {
  const MunitionTerminalEffectModel(this.profile);

  final TerminalEffectProfile profile;

  @override
  CoverageEllipse build(TerminalEffectInput input) {
    final thetaRad = input.angleChuteDeg * math.pi / 180.0;
    final safeSin = math.sin(thetaRad).abs().clamp(0.20, 1.0).toDouble();

    final radius = math.max(1.0, input.effectiveDiameterM / 2.0);

    final semiMinorAxis = radius * profile.lateralFactor;
    final projected = radius / safeSin;
    final semiMajorAxis = math.min(
      math.max(projected * profile.rearFactor, semiMinorAxis),
      semiMinorAxis * profile.maxElongationFactor,
    );

    return CoverageEllipse(
      centerX: input.centerX,
      centerY: input.centerY,
      azimutMil: input.azimutMil,
      semiMajorAxis: semiMajorAxis,
      semiMinorAxis: semiMinorAxis,
      lethalRadius: radius,
      angleChuteDeg: input.angleChuteDeg,
      burstHeightM: input.burstHeightM,
      directionalAlpha: 0.0,
      forwardBackwardRatio: profile.rearFactor <= 0.0
          ? 1.0
          : profile.forwardFactor / profile.rearFactor,
    );
  }
}
