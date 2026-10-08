import 'dart:io';
import 'dart:typed_data';

import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/domain/entities/meteo_row.dart';
import 'package:calculateur_etranger/domain/meteo/metb_parser.dart';
import 'package:calculateur_etranger/presentation/fire/dialogs/mo81_powder_temperature_dialog.dart';
import 'package:calculateur_etranger/presentation/fire/state/tir_complet_state.dart';
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
    expect(trajectory.weatherLine, 5);
    expect(tables.trajectory.atDistance(4350).weatherLine, 4);

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

  test('uses the CEBTL zero row at 70 °F / 21.1 °C', () {
    expect(BalistiqueMo81M252AppuiService.referencePowderTemperatureF, 70.0);
    expect(
      BalistiqueMo81M252AppuiService.referencePowderTemperatureC,
      closeTo(21.111111, 0.000001),
    );
    expect(
      PowderTemperatureUnit.fahrenheit.toCelsius(70.0),
      closeTo(
          BalistiqueMo81M252AppuiService.referencePowderTemperatureC, 0.000001),
    );
    expect(
      PowderTemperatureUnit.celsius.fromCelsius(
        BalistiqueMo81M252AppuiService.referencePowderTemperatureC,
      ),
      closeTo(21.111111, 0.000001),
    );
  });

  test('stores only the M252 current powder temperature', () {
    final notifier = TirCompletNotifier();
    notifier.setTirSimilaireValues(
      carreaux: 4,
      tPrev: 12.0,
      tAct: 15.0,
      v0: 195.0,
    );

    notifier.setTirSimilaireMo81M252(temperaturePoudreActuelleC: 0.0);

    expect(notifier.state.tirSimilaire, isTrue);
    expect(notifier.state.tAct, 0.0);
    expect(notifier.state.tPrev, isNull);
    expect(notifier.state.v0Prev, isNull);
    expect(notifier.state.simFusee, notifier.state.fusee);
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
    expect(result.niveauMeteoBUsed, 5);
    expect(result.details['weatherLineFromTableD'], 5);
  });

  test('selects the loaded MET row identified by Table D LINE NO.', () async {
    const level4 = MeteoRow(
      level: 4,
      azimutMils: 1000,
      vKn: 2,
      tempPermil: 990,
      pressPermil: 990,
      sourceType: 'METB',
    );
    const level5 = MeteoRow(
      level: 5,
      azimutMils: 2000,
      vKn: 7,
      tempPermil: 1010,
      pressPermil: 990,
      sourceType: 'METB',
    );
    final result = await BalistiqueMo81M252AppuiService.calculer(
      const CalculInput(
        systeme: Systeme.mo81M252,
        typeTir: TypeTir.appui,
        m252MunitionFamily: M252MunitionFamily.m821a1,
        chargeForcee: 'CH3',
        distanceM: 1811,
        meteoOn: true,
        meteoRows: <MeteoRow>[level4, level5],
        pdZ: 100,
        objZ: 100,
        meteoStationAltM: 0,
      ),
      tables: repository,
    );

    expect(result.niveauMeteoBUsed, 5);
    expect(result.details['weatherLineFromTableD'], 5);
    expect(result.details['weatherLineLoaded'], 5);
    expect(result.details['weatherApplied'], isTrue);
    expect(result.details['windKnots'], 7.0);
    expect(result.details['meteoRawTemperaturePct'], 101.0);
    expect(result.details['meteoRawPressurePct'], 99.0);
    expect(result.details['tableA_wzFactor'], closeTo(0.92, 0.001));
    expect(result.details['tableA_wxFactor'], closeTo(0.38, 0.001));
    expect(result.details['tableB_temperatureAdjustmentPct'],
        closeTo(-0.2, 0.001));
    expect(
        result.details['tableB_pressureAdjustmentPct'], closeTo(-1.0, 0.001));
    expect(result.details['tableD_deltaCrossWindMil'], isNot(0.0));
    expect(result.details['tableD_deltaLongitudinalWindM'], isNot(0.0));
    expect(result.details['tableD_deltaTemperatureM'], isNot(0.0));
    expect(result.details['tableD_deltaPressureM'], isNot(0.0));
  });

  test('restores the exercise corrections from MET line 05', () async {
    // MET B form: level / wind direction (hundreds of mils) / knots /
    // temperature ratio / pressure ratio. The parser restores 050 to 1050‰.
    final exerciseRow = MetBParser.parse('05 18 11 050 977').single;
    expect(exerciseRow.azimutMils, 1800);
    expect(exerciseRow.vKn, 11);
    expect(exerciseRow.tempPermil, 1050);
    expect(exerciseRow.pressPermil, 977);

    final result = await BalistiqueMo81M252AppuiService.calculer(
      CalculInput(
        systeme: Systeme.mo81M252,
        typeTir: TypeTir.appui,
        m252MunitionFamily: M252MunitionFamily.m821a1,
        chargeForcee: 'CH3',
        distanceM: 1811,
        // Bearing recorded in the exercise geometry. Do not round it before
        // evaluating Table A; the output is displayed rounded to 0.01 mil.
        azimutObjectifMil: 4824.997721,
        // Deliberately leave `meteoOn` false: loaded MET data must still
        // trigger Tables A, B and D.
        meteoRows: <MeteoRow>[exerciseRow],
        // Table B uses the objective, not the piece, as its altitude
        // reference: 459 m - 370 m = +89 m.
        pdZ: 34,
        objZ: 459,
        meteoStationAltM: 370,
        simTempActC: 25.0,
        simTemperatureCorrectionEnabled: true,
      ),
      tables: repository,
    );

    expect(result.details['weatherApplied'], isTrue);
    expect(result.niveauMeteoBUsed, 5);
    expect(result.wzMil, closeTo(-6.545, 0.001));
    expect(result.wxM, closeTo(-62.843, 0.001));
    expect(result.deltaZStationM, closeTo(89.0, 0.001));
    expect(result.deltaTBM, closeTo(-1.440, 0.001));
    expect(result.deltaPBM, closeTo(-18.961, 0.001));
    expect(result.deltaV0M, closeTo(-4.206, 0.001));
  });

  test('rejects MET correction when the Table D line is absent', () async {
    const level4 = MeteoRow(
      level: 4,
      azimutMils: 1000,
      vKn: 9,
      tempPermil: 990,
      pressPermil: 990,
      sourceType: 'METB',
    );
    await expectLater(
      BalistiqueMo81M252AppuiService.calculer(
        const CalculInput(
          systeme: Systeme.mo81M252,
          typeTir: TypeTir.appui,
          m252MunitionFamily: M252MunitionFamily.m821a1,
          chargeForcee: 'CH3',
          distanceM: 1811,
          meteoOn: true,
          meteoRows: <MeteoRow>[level4],
        ),
        tables: repository,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('applies a 0 °C powder correction when explicitly enabled', () async {
    const neutral = CalculInput(
      systeme: Systeme.mo81M252,
      typeTir: TypeTir.appui,
      m252MunitionFamily: M252MunitionFamily.m821a1,
      chargeForcee: 'CH3',
      distanceM: 2000,
    );
    const zeroC = CalculInput(
      systeme: Systeme.mo81M252,
      typeTir: TypeTir.appui,
      m252MunitionFamily: M252MunitionFamily.m821a1,
      chargeForcee: 'CH3',
      distanceM: 2000,
      simTempActC: 0.0,
      simTemperatureCorrectionEnabled: true,
    );

    final neutralResult = await BalistiqueMo81M252AppuiService.calculer(
      neutral,
      tables: repository,
    );
    final zeroCResult = await BalistiqueMo81M252AppuiService.calculer(
      zeroC,
      tables: repository,
    );

    expect(neutralResult.deltaV0M, 0.0);
    expect(zeroCResult.deltaV0M, isNot(0.0));
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
