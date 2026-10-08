import 'dart:io';
import 'dart:typed_data';

import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/services/balistique_mo81_m252_appui_service.dart';
import 'package:calculateur_etranger/services/m252/m252_table_codec.dart';
import 'package:calculateur_etranger/services/m252/m252_table_repository.dart';
import 'package:calculateur_etranger/presentation/fire/state/tir_header_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late M252TableRepository repository;

  setUpAll(() async {
    const clearRoot = 'assets/secure/tableaux/foreign/m252';
    final files = <String, String>{
      M252TableRepository.windPath: '$clearRoot/A/A.aebtl.gz',
      M252TableRepository.airDensityPath: '$clearRoot/B/B.bebtl.gz',
      M252TableRepository.powderTemperaturePath: '$clearRoot/C/C_CH3.cebtl.gz',
      M252TableRepository.trajectoryPath: '$clearRoot/D/D_CH3.debtl.gz',
      M252TableRepository.dispersionPath: '$clearRoot/E/E_CH3.eebtl.gz',
    };

    final payloads = <String, Uint8List>{
      for (final entry in files.entries)
        entry.key: Uint8List.fromList(await File(entry.value).readAsBytes()),
    };

    repository = M252TableRepository(
      decryptAsset: (path) async {
        final payload = payloads[path];
        if (payload == null) throw StateError('Missing test asset: $path');
        return payload;
      },
    );
  });

  test('decodes all five M252 CH3 formats and preserves reference rows',
      () async {
    final tables = await repository.load();

    expect(tables.wind.length, 65);
    expect(tables.wind.atAngleMil(800).wz, closeTo(0.71, 0.001));
    expect(tables.wind.atAngleMil(1600).wx, closeTo(0.0, 0.001));

    expect(tables.airDensity.rows, hasLength(41));
    final air = tables.airDensity.atAbsoluteDeltaAltitude(250);
    expect(air.deltaTemperaturePct, closeTo(-0.6, 0.001));
    expect(air.deltaPressurePct, closeTo(-2.4, 0.001));

    expect(tables.powderTemperature.rows, hasLength(35));
    expect(tables.powderTemperature.atFahrenheit(70).deltaVoMs,
        closeTo(0.0, 0.001));

    expect(tables.trajectory.rows, hasLength(125));
    final trajectory = tables.trajectory.atDistance(2000);
    expect(trajectory.elevationMil, closeTo(1364.0, 0.001));
    expect(trajectory.timeOfFlightS, closeTo(45.4, 0.001));
    expect(trajectory.turnsPer100m, 1);

    expect(tables.dispersion.rows, hasLength(33));
    final dispersion = tables.dispersion.atDistance(2000);
    expect(dispersion.probableRangeErrorM, closeTo(10.0, 0.001));
    expect(dispersion.remainingVelocityMs, closeTo(195.0, 0.001));
  });

  test('selecting M252 defaults to the qualified M821A1 family', () {
    final header = TirHeaderNotifier();
    header.setSysteme(Systeme.mo81M252);

    expect(header.state.m252MunitionFamily, M252MunitionFamily.m821a1);
    expect(header.state.mo81MunitionLabel, 'M821A1');
  });

  test('calculates the neutral 2000 m M821A1 / CH3 reference solution',
      () async {
    final result = await BalistiqueMo81M252AppuiService.calculer(
      const CalculInput(
        systeme: Systeme.mo81M252,
        typeTir: TypeTir.appui,
        m252MunitionFamily: M252MunitionFamily.m821a1,
        chargeForcee: 'CH3',
        distanceM: 2000,
        azimutObjectifMil: 1200,
      ),
      tables: repository,
    );

    expect(result.estValide, isTrue);
    expect(result.charge, 'CH3');
    expect(result.typeAssets, 'M252_M821A1_CH3');
    expect(result.porteeCorrigeeM, closeTo(2000.0, 0.001));
    expect(result.aqeMil, closeTo(1364.0, 0.001));
    expect(result.noireMil, closeTo(1200.0, 0.001));
    expect(result.tempsVolS, closeTo(45.4, 0.001));
    expect(result.ecartProbablePorteeM, closeTo(10.0, 0.001));
  });

  test('rejects a charge or range outside the qualified CH3 reference domain',
      () async {
    await expectLater(
      BalistiqueMo81M252AppuiService.calculer(
        const CalculInput(
          systeme: Systeme.mo81M252,
          typeTir: TypeTir.appui,
          m252MunitionFamily: M252MunitionFamily.m821a1,
          chargeForcee: 'CH2',
          distanceM: 2000,
        ),
        tables: repository,
      ),
      throwsA(isA<UnsupportedError>()),
    );

    await expectLater(
      BalistiqueMo81M252AppuiService.calculer(
        const CalculInput(
          systeme: Systeme.mo81M252,
          typeTir: TypeTir.appui,
          m252MunitionFamily: M252MunitionFamily.m821a1,
          chargeForcee: 'CH3',
          distanceM: 2301,
        ),
        tables: repository,
      ),
      throwsA(isA<M252TableRangeException>()),
    );
  });
}
