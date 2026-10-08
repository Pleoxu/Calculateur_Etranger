import 'dart:math' as math;

import 'package:calculateur_etranger/domain/fire/effects/terminal_effect_factory.dart';
import 'package:calculateur_etranger/domain/fire/effects/terminal_effect_input.dart';
import 'package:calculateur_etranger/domain/fire/effects/terminal_effect_model.dart';
import 'package:calculateur_etranger/domain/fire/effects/terminal_effect_profile.dart';
import 'package:calculateur_etranger/models/effects/coverage_ellipse.dart';

class FragmentationService {
  const FragmentationService({this.factory = const TerminalEffectFactory()});

  final TerminalEffectFactory factory;

  CoverageEllipse buildEllipse({
    required double centerX,
    required double centerY,
    required double azimutMil,
    required double angleChuteDeg,
    double? ecartProbablePorteeM,
    double? ecartProbableDirectionM,
    double? residualVelocityMps,
    double? referenceVelocityMps,
    double lethalRadius = 0.0,
    double burstHeightM = 0.0,
    double visualElongationK = 0.5,
    double visualLambda = 2.0,
    double visualForwardAlpha = 1.0,
    double visualRearBeta = 0.5,
    double frontActiveThreshold = 0.0,
    TerminalEffectProfile? profile,
  }) {
    final effectiveDiameterM = math.max(2.0, lethalRadius * 2.0);

    final input = TerminalEffectInput(
      centerX: centerX,
      centerY: centerY,
      azimutMil: azimutMil,
      angleChuteDeg: angleChuteDeg,
      effectiveDiameterM: effectiveDiameterM,
      ecartProbablePorteeM: ecartProbablePorteeM,
      ecartProbableDirectionM: ecartProbableDirectionM,
      residualVelocityMps: residualVelocityMps,
      referenceVelocityMps: referenceVelocityMps,
      burstHeightM: burstHeightM,
    );

    final TerminalEffectModel model = factory.resolve(profile: profile);
    return model.build(input);
  }

  double densityAt({
    required double distanceM,
    required double lambda,
    double d0 = 1.0,
  }) {
    return d0 * math.exp(-lambda * distanceM);
  }
}
