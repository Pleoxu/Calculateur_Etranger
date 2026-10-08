import 'package:calculateur_etranger/domain/fire/ports/fire_ballistics_computer.dart';
import 'package:calculateur_etranger/services/balistique_engine.dart';

class LegacyFireBallisticsComputer implements FireBallisticsComputer {
  const LegacyFireBallisticsComputer();

  @override
  Future<dynamic> compute(dynamic calculInput) {
    return BalistiqueEngine.calculer(calculInput);
  }
}
