import '../models/calcul_data.dart';
import 'balistique_service.dart';

class BalistiqueEngine {
  const BalistiqueEngine._();

  static Future<CalculResult> calculer(CalculInput input) {
    return BalistiqueService.calculer(input);
  }
}
