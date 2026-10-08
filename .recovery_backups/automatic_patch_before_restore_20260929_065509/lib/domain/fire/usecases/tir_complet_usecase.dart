// lib/domain/fire/usecases/tir_complet_usecase.dart

import '../factories/fire_calcul_input_factory.dart';
import '../services/fire_shots_computer.dart'; // Importation du bon service (et non effects/fire_shots_computer.dart)

class TirCompletUseCase {
  final FireCalculInputFactory inputFactory;
  final FireShotsComputer shotsComputer;

  TirCompletUseCase({
    required this.inputFactory,
    required this.shotsComputer,
  });

// Remplacez les appels au constructeur de résultats par la bonne signature requis :
// Veillez à transmettre l'ensemble des paramètres requis (prX, prY, pdX, pdY, firePlan, etc.)
}
