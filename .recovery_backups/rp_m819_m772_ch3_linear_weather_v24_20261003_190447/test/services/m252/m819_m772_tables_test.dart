import 'dart:io';
import 'dart:math' as math;

import 'package:calculateur_etranger/domain/entities/meteo_row.dart';
import 'package:calculateur_etranger/domain/fire/effects/fire_shots_computer.dart';
import 'package:calculateur_etranger/domain/fire/input/fire_request.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan_kind.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/services/balistique_mo81_m252_m819_service.dart';
import 'package:calculateur_etranger/services/m252/m819_profile.dart';
import 'package:calculateur_etranger/services/m252/m819_table_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, Uint8List> payloads;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    payloads = <String, Uint8List>{
      for (final profile in M819Profiles.all)
        for (final table in const <String>['A', 'B', 'C', 'D', 'E', 'F'])
          profile.encryptedPath(table): Uint8List.fromList(
            await File('assets/secure/${profile.clearPath(table)}')
                .readAsBytes(),
          ),
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('secure_assets'), (
      call,
    ) async {
      if (call.method != 'decryptAsset') {
        throw MissingPluginException('Unexpected secure-assets method.');
      }
      final path = (call.arguments as Map<Object?, Object?>)['path'];
      final payload = payloads[path];
      if (payload == null) throw StateError('Missing test asset: $path');
      return payload;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('secure_assets'), null);
  });

  test('decodes all six M819/M772 CH3 assets including the completed Table D',
      () async {
    final repository = M819TableRepository(
      profile: M819Profiles.m819M772Ch3,
      decryptAsset: (path) async => payloads[path]!,
    );
    final tables = await repository.load();

    expect(tables.wind.length, 65);
    expect(tables.airDensity.rows, hasLength(41));
    expect(tables.powderTemperature.rows, isNotEmpty);
    expect(tables.trajectory.rows, hasLength(107));
    expect(tables.effects.rows, hasLength(107));
    expect(tables.fuzeFactors.rows, hasLength(12));

    final base = tables.trajectory.atDistance(1325);
    expect(base.elevationMil, closeTo(1421.0, 0.001));
    expect(base.fuzeSetting, closeTo(41.9, 0.001));
    expect(base.probableBurstRangeErrorM, closeTo(10.0, 0.001));
    expect(base.weatherLine, 5);
    expect(base.azimuthCorrectionMilPerKnot, closeTo(4.3, 0.001));
    expect(base.v0DecreaseMPerMs, isNull,
        reason: 'No unavailable correction may be invented for CH3.');

    final factors = tables.fuzeFactors.atFuzeSetting(40.2);
    expect(factors.fuzeSetting, closeTo(40.2, 0.001));
  });

  test('selects the published lowest-RB charge in overlaps', () async {
    expect(
      await BalistiqueMo81M252M819Service.selectProfileFor(distanceM: 1100),
      M819Profiles.m819M772Ch2,
    );
    expect(
      await BalistiqueMo81M252M819Service.selectProfileFor(distanceM: 2000),
      M819Profiles.m819M772Ch3,
    );
    expect(
      await BalistiqueMo81M252M819Service.selectProfileFor(distanceM: 4000),
      M819Profiles.m819M772Ch4,
    );
    expect(
      BalistiqueMo81M252M819Service.selectProfileFor(distanceM: 1700),
      throwsA(isA<StateError>()),
      reason: 'A published RB tie must not be resolved arbitrarily.',
    );
  });

  test('calculates the nominal RP M819/M772 CH3 reference and exposes M772',
      () async {
    final result = await BalistiqueMo81M252M819Service.calculer(
      const CalculInput(
        systeme: Systeme.mo81M252,
        typeTir: TypeTir.appui,
        m252MunitionFamily: M252MunitionFamily.rpM819,
        distanceM: 2500,
        azimutObjectifMil: 1508,
      ),
      tables: M819TableRepository(
        profile: M819Profiles.m819M772Ch3,
        decryptAsset: (path) async => payloads[path]!,
      ),
    );

    expect(result.charge, 'CH3');
    expect(result.aqeMil, closeTo(1250.0, 0.001));
    expect(result.tempsVolS, closeTo(43.5, 0.001));
    expect(result.m772FuzeSetting, closeTo(40.2, 0.001));
    expect(result.hasM772FuzeSetting, isTrue);
    expect(result.m772FuzeSettingFormate, '40.2');
    expect(result.ecartProbablePorteeM, closeTo(13.0, 0.001));
    expect(result.details['tableFCorrectionsApplied'], isFalse);
  });

  test('applies published C, D and F corrections to RP M819 CH2', () async {
    const nominalInput = CalculInput(
      systeme: Systeme.mo81M252,
      typeTir: TypeTir.appui,
      m252MunitionFamily: M252MunitionFamily.rpM819,
      distanceM: 1500,
      azimutObjectifMil: 1508,
    );
    const correctedInput = CalculInput(
      systeme: Systeme.mo81M252,
      typeTir: TypeTir.appui,
      m252MunitionFamily: M252MunitionFamily.rpM819,
      distanceM: 1500,
      azimutObjectifMil: 1508,
      meteoOn: true,
      meteoRows: <MeteoRow>[
        MeteoRow(
          level: 4,
          azimutMils: 1600,
          vKn: 5,
          tempPermil: 970,
          pressPermil: 1020,
          sourceType: 'METB',
        ),
      ],
      simTemperatureCorrectionEnabled: true,
      simTempActC: 0,
    );

    final nominal = await BalistiqueMo81M252M819Service.calculer(nominalInput);
    final corrected =
        await BalistiqueMo81M252M819Service.calculer(correctedInput);

    expect(nominal.charge, 'CH2');
    expect(corrected.charge, 'CH2');
    expect(corrected.details['weatherApplied'], isTrue);
    expect(corrected.details['weatherLineFromTableD'], 4);
    expect(corrected.deltaV0M, isNot(0.0));
    expect(corrected.totalLongM, isNot(0.0));
    expect(corrected.m772FuzeSetting, isNot(nominal.m772FuzeSetting));
    expect(corrected.tempageDetails, isNotNull);
    expect(corrected.tempageDetails!.deltaTV0, isNot(0.0));
    expect(corrected.details['tableD_deltaV0M'], isNot(0.0));
    expect(corrected.details['tableF_deltaV0'], isNot(0.0));
  });

  test('applies published Table D CH3 corrections at 2250 m with MET line 05',
      () async {
    final repository = M819TableRepository(
      profile: M819Profiles.m819M772Ch3,
      decryptAsset: (path) async => payloads[path]!,
    );
    final tables = await repository.load();
    final source = tables.trajectory.atDistance(2250);

    expect(source.weatherLine, 5);
    expect(source.v0DecreaseMPerMs, closeTo(15.3, 0.001));
    expect(source.v0IncreaseMPerMs, closeTo(-13.4, 0.001));
    expect(source.headwindMPerKnot, closeTo(7.3, 0.001));
    expect(source.tailwindMPerKnot, closeTo(-6.2, 0.001));
    expect(source.airTemperatureDecreaseMPerPct, closeTo(-0.1, 0.001));
    expect(source.airTemperatureIncreaseMPerPct, closeTo(0.2, 0.001));
    expect(source.airDensityDecreaseMPerPct, closeTo(-6.7, 0.001));
    expect(source.airDensityIncreaseMPerPct, closeTo(6.7, 0.001));

    const input = CalculInput(
      systeme: Systeme.mo81M252,
      typeTir: TypeTir.appui,
      m252MunitionFamily: M252MunitionFamily.rpM819,
      distanceM: 2250,
      azimutObjectifMil: 3325,
      meteoOn: true,
      meteoRows: <MeteoRow>[
        MeteoRow(
          level: 5,
          azimutMils: 3325,
          vKn: 20,
          tempPermil: 1039,
          pressPermil: 976,
          sourceType: 'METB',
        ),
      ],
      simTemperatureCorrectionEnabled: true,
      simTempActC: 25,
    );

    final result = await BalistiqueMo81M252M819Service.calculer(
      input,
      tables: repository,
    );

    expect(result.charge, 'CH3');
    expect(result.details['weatherApplied'], isTrue);
    expect(result.details['weatherLineFromTableD'], 5);
    expect(result.details['weatherLineLoaded'], 5);
    expect(result.details['tableD_deltaLongitudinalWindM'], isNot(0.0));
    expect(result.details['tableD_deltaTemperatureM'], isNot(0.0));
    expect(result.details['tableD_deltaDensityM'], isNot(0.0));
    expect(result.details['tableD_deltaV0M'], isNot(0.0));
    expect(result.tempageDetails, isNotNull);
    expect(result.tempageDetails!.tFusee, isNot(40.7));
    expect(result.details['tableFCorrectionsApplied'], isTrue);
  });

  test('recalculates M819 settings for every allocated linear offset',
      () async {
    const request = FireRequest(
      systeme: Systeme.mo81M252,
      typeTir: TypeTir.appui,
      m252MunitionFamily: M252MunitionFamily.rpM819,
      fusee: TypeFusee.frappe,
      piece: FirePieceInput(
        utmX: 729350.0,
        utmY: 5153945.0,
        altitude: 345.0,
        utmZone: '30T',
      ),
      target: FireTargetInput(
        mode: FireTargetMode.utm,
        utmX: 729075.0,
        utmY: 5151712.0,
        altitude: 345.0,
      ),
      doctrine: FireDoctrineInput(
        nature: FireNature.lineaire,
        shotPlan: FireShotPlanInput(nbCoups: 4, par: 2),
      ),
      salves: FireSalvoOptions(
        enabled: false,
        preferenceIdx: 0,
        lastSalveAroundPd: false,
      ),
      tirVertical: true,
      forcerCharge: false,
      masseEnabled: false,
      carreaux: 4,
      tirSimilaire: false,
      simCarreaux: 4,
    );

    const pd = PieceGeom(
      id: 'PD',
      x: 729350.0,
      y: 5153945.0,
      z: 345.0,
      isPd: true,
    );
    const ps1 = PieceGeom(
      id: 'PS1',
      x: 729400.0,
      y: 5153945.0,
      z: 345.0,
      isPd: false,
    );
    const targets = <OffsetTarget>[
      OffsetTarget(index: 0, offsetM: -37.5, x: 729039.9, y: 5151697.6),
      OffsetTarget(index: 1, offsetM: 37.5, x: 729109.2, y: 5151726.3),
      OffsetTarget(index: 2, offsetM: -12.5, x: 729063.0, y: 5151707.1),
      OffsetTarget(index: 3, offsetM: 12.5, x: 729086.1, y: 5151716.7),
    ];

    final firePlan = FirePlan(
      kind: FirePlanKind.lineaire,
      zoneLargeurM: 75.0,
      zoneProfondeurM: 0.0,
      azimutMilOut: 3325.0,
      azimutLargeurMil: 0.0,
      azimutProfondeurMil: 0.0,
      nbPositions: targets.length,
      nbCoupsTotal: targets.length,
      gridNL: targets.length,
      gridNP: 1,
      allTargets: targets,
      pieces: const <PieceGeom>[pd, ps1],
      allocs: <PieceAllocation>[
        PieceAllocation(
            piece: pd, targets: <OffsetTarget>[targets[0], targets[2]]),
        PieceAllocation(
          piece: ps1,
          targets: <OffsetTarget>[targets[1], targets[3]],
        ),
      ],
      desiredShotsByPiece: const <String, int>{'PD': 2, 'PS1': 2},
    );

    const baseInput = CalculInput(
      systeme: Systeme.mo81M252,
      typeTir: TypeTir.appui,
      m252MunitionFamily: M252MunitionFamily.rpM819,
      distanceM: 2250.0,
      azimutObjectifMil: 3325.0,
      pdX: 729350.0,
      pdY: 5153945.0,
      pdZ: 345.0,
      objX: 729075.0,
      objY: 5151712.0,
      objZ: 345.0,
      objD: 2250.0,
      objA: 3325.0,
      objAlt: 345.0,
    );

    final output = await const FireShotsComputer().compute(
      request: request,
      firePlan: firePlan,
      baseInput: baseInput,
      zP: 345.0,
      zO: 345.0,
      prX: 729075.0,
      prY: 5151712.0,
    );

    expect(output.shots, hasLength(4));
    final pieces = <String, PieceGeom>{'PD': pd, 'PS1': ps1};
    for (final shot in output.shots) {
      final piece = pieces[shot.nomPiece]!;
      final dx = shot.objX - piece.x;
      final dy = shot.objY - piece.y;
      final expectedDistance = math.sqrt(dx * dx + dy * dy);
      var expectedAzimuth = math.atan2(dx, dy) * 6400.0 / (2.0 * math.pi);
      if (expectedAzimuth < 0.0) expectedAzimuth += 6400.0;

      expect(shot.resultat.distanceTopoM, closeTo(expectedDistance, 0.001));
      expect(shot.resultat.azimutMil, closeTo(expectedAzimuth, 0.001));
      expect(shot.resultat.charge, 'CH3');
    }

    expect(
      output.shots.map((shot) => shot.resultat.azimutMil).toSet().length,
      greaterThan(1),
      reason: 'A distinct offset target must receive its own firing bearing.',
    );
    expect(
      output.shots.map((shot) => shot.resultat.aqeMil).toSet().length,
      greaterThan(1),
      reason: 'A distinct range must receive its own elevation setting.',
    );
  });
}
