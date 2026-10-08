import 'package:calculateur_etranger/domain/fire/adapters/fire_request_legacy_adapter.dart';
import 'package:calculateur_etranger/domain/fire/effects/fire_shots_computer.dart';
import 'package:calculateur_etranger/domain/fire/factories/fire_calcul_input_factory.dart';
import 'package:calculateur_etranger/domain/fire/input/fire_request.dart';
import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';
import 'package:calculateur_etranger/domain/fire/services/fire_geometry_resolver.dart';
import 'package:calculateur_etranger/domain/fire/usecases/build_fire_plan_usecase.dart';
import 'package:calculateur_etranger/services/balistique_engine.dart';

class TirCompletUsecase {
  final FireCalculInputFactory _calculInputFactory;
  final FireRequestLegacyAdapter _legacyAdapter;
  final FireGeometryResolver _geometryResolver;
  final BuildFirePlanUsecase _firePlanUsecase;
  final FireShotsComputer _shotsComputer;

  TirCompletUsecase({
    FireCalculInputFactory? calculInputFactory,
    FireRequestLegacyAdapter? legacyAdapter,
    FireGeometryResolver? geometryResolver,
    BuildFirePlanUsecase? firePlanUsecase,
    FireShotsComputer? shotsComputer,
  })  : _calculInputFactory =
            calculInputFactory ?? const FireCalculInputFactory(),
        _legacyAdapter = legacyAdapter ?? const FireRequestLegacyAdapter(),
        _geometryResolver = geometryResolver ?? const FireGeometryResolver(),
        _firePlanUsecase = firePlanUsecase ?? const BuildFirePlanUsecase(),
        _shotsComputer = shotsComputer ?? const FireShotsComputer();

  /// Exécute un tir à partir du contrat utilisé par le contrôleur.
  ///
  /// Les calculateurs et le plan de tir historique utilisent encore
  /// [TirCompletInput]. L'adaptateur est volontairement confiné ici : le reste
  /// de l'application conserve le contrat typé [FireRequest].
  Future<TirCompletOutput> run(FireRequest request) async {
    final geometry = _geometryResolver.resolve(request);
    final baseInput = _calculInputFactory.create(
      request: request,
      geometry: geometry,
    );

    final pieceAltitudeM = request.piece.altitude ?? 0.0;
    final targetAltitudeM = request.target.altitude ?? pieceAltitudeM;

    final legacyInput = _legacyAdapter.toLegacy(request).copyWith(
          xPiece: geometry.pdX,
          yPiece: geometry.pdY,
          zPiece: pieceAltitudeM,
          xObj: geometry.objXfinal,
          yObj: geometry.objYfinal,
          zObj: targetAltitudeM,
          distanceObj: geometry.distanceTopo,
          azimutObj: geometry.azimutMil,
        );

    final firePlan = _firePlanUsecase.build(
      input: legacyInput,
      prX: geometry.objXfinal,
      prY: geometry.objYfinal,
      azimutMil: geometry.azimutMil,
    );

    // Ce calcul initial détecte les erreurs de trajectoire avant le calcul de
    // toutes les salves et sert de repli si le plan ne produit aucun tir.
    final mainResult = await BalistiqueEngine.calculer(baseInput);

    final shotsResult = await _shotsComputer.compute(
      request: request,
      firePlan: firePlan,
      baseInput: baseInput,
      zP: pieceAltitudeM,
      zO: targetAltitudeM,
      prX: geometry.objXfinal,
      prY: geometry.objYfinal,
    );

    final resultatPd = shotsResult.resultatPd ?? mainResult;

    return TirCompletOutput(
      resultatPrincipal: resultatPd,
      resultatPd: resultatPd,
      psOutputs: shotsResult.psOutputs,
      shots: shotsResult.shots,
      firePlan: firePlan,
      pdOffset: shotsResult.pdOffset,
      pdX: shotsResult.pdX,
      pdY: shotsResult.pdY,
      prX: geometry.objXfinal,
      prY: geometry.objYfinal,
      coups: shotsResult.shots.isEmpty
          ? firePlan.nbCoupsTotal
          : shotsResult.shots.length,
      debordPct: request.doctrine.zonal.debordementPct ?? 0.0,
      latitudePieceDeg: geometry.latitudeDeg,
      deltaAltMet:
          pieceAltitudeM - (request.meteo?.stationAltM ?? pieceAltitudeM),
      niveauBLocal: resultatPd.niveauMeteoBUsed.toDouble(),
      siteBLocalM: resultatPd.correctionSiteBM,
    );
  }
}
