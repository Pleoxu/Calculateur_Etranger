import 'package:calculateur_etranger/domain/fire/effects/terminal_effect_input.dart';
import 'package:calculateur_etranger/models/effects/coverage_ellipse.dart';

abstract interface class TerminalEffectModel {
  CoverageEllipse build(TerminalEffectInput input);
}
