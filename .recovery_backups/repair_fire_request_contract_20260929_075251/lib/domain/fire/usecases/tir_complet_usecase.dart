// lib/domain/fire/usecases/tir_complet_usecase.dart

import 'package:calculateur_etranger/domain/fire/effects/fire_shots_computer.dart';
import 'package:calculateur_etranger/domain/fire/factories/fire_calcul_input_factory.dart';
import 'package:calculateur_etranger/domain/fire/models/tir_complet_input.dart';
import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';
import 'package:calculateur_etranger/domain/fire/utils/salves_planner.dart';
import 'package:calculateur_etranger/domain/mortar81/m252/m252_asset_probe.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/services/balistique_engine.dart';

class TirCompletUsecase {
  final FireCalculInputFactory _calculInputFactory;
  final FireShotsComputer _shotsComputer;

  TirCompletUsecase({
    FireCalculInputFactory? calculInputFactory,
    FireShotsComputer? shotsComputer,
  })  : _calculInputFactory =
            calculInputFactory ?? const FireCalculInputFactory(),
        _shotsComputer = shotsComputer ?? const FireShotsComputer();

  Future<TirCompletOutput> execute(TirCompletInput input) async {
    final baseInput = _calculInputFactory.create(input);

    // 1. Calcul balistique de la trajectoire principale
    final mainResult = await BalistiqueEngine.calculer(baseInput);

    // 2. Traitement des sondes d'assets si M252
    String? assetProbeKey;
    if (baseInput.systeme == Systeme.mo81M252 &&
        baseInput.m252MunitionFamily != null) {
      assetProbeKey = m252AssetProbe(baseInput.m252MunitionFamily!);
    }

    // 3. Exécution de la simulation des tirs multiples / salves
    final shotsResult = await _shotsComputer.computeShots(
      baseInput: baseInput,
      baseResult: mainResult,
    );

    return TirCompletOutput(
      resultat: mainResult,
      shots: shotsResult,
      assetKey: assetProbeKey,
    );
  }
}
