import 'package:calculateur_etranger/domain/fire/effects/generic_geometric_effect_model.dart';
import 'package:calculateur_etranger/domain/fire/effects/munition_terminal_effect_model.dart';
import 'package:calculateur_etranger/domain/fire/effects/terminal_effect_model.dart';
import 'package:calculateur_etranger/domain/fire/effects/terminal_effect_profile.dart';

class TerminalEffectFactory {
  const TerminalEffectFactory();

  TerminalEffectModel resolve({TerminalEffectProfile? profile}) {
    if (profile != null && profile.validated) {
      return MunitionTerminalEffectModel(profile);
    }

    return const GenericGeometricEffectModel();
  }
}
