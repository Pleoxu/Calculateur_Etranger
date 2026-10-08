import 'dart:io';

import 'package:calculateur_etranger/domain/entities/meteo_row.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/services/balistique_mo81_m252_m853a1_service.dart';
import 'package:calculateur_etranger/services/m252/m853a1_profile.dart';
import 'package:calculateur_etranger/services/m252/m853a1_table_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, Uint8List> payloads;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    payloads = <String, Uint8List>{
      for (final profile in M853A1Profiles.all)
        for (final table in const <String>['A', 'B', 'C', 'D', 'E', 'F'])
          profile.encryptedPath(table): Uint8List.fromList(
            await File(
              'assets/secure/${profile.clearPath(table)}',
            ).readAsBytes(),
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

  test(
    'decodes all six M853A1/M772 CH3 assets and preserves Table F blanks',
    () async {
      final tables = await M853A1TableRepository(
        profile: M853A1Profiles.m853a1M772Ch3,
        decryptAsset: (path) async => payloads[path]!,
      ).load();

      expect(tables.wind.length, 65);
      expect(tables.airDensity.rows, hasLength(41));
      expect(tables.powderTemperature.rows, hasLength(35));
      expect(tables.trajectory.rows, hasLength(111));
      expect(tables.effects.rows, hasLength(111));
      expect(tables.fuzeFactors.rows, hasLength(11));

      final row = tables.trajectory.atDistance(3500);
      expect(row.elevationMil, closeTo(1090.0, 0.001));
      expect(row.fuzeSetting, closeTo(39.6, 0.001));
      expect(row.timeOfFlightS, closeTo(39.5, 0.001));
      expect(row.probableBurstRangeErrorM, closeTo(20.0, 0.001));
      expect(row.weatherLine, 5);
      expect(row.headwindMPerKnot, isNotNull);
      expect(row.airDensityIncreaseMPerPct, isNotNull);

      final factors = tables.fuzeFactors.atFuzeSetting(39.6);
      expect(factors.fuzeSetting, closeTo(39.6, 0.001));
      expect(factors.v0Dec, isNotNull);
    },
  );

  test('selects the published lowest-RB charge in M853A1 overlaps', () async {
    expect(
      await BalistiqueMo81M252M853A1Service.selectProfileFor(distanceM: 1100),
      M853A1Profiles.m853a1M772Ch1,
    );
    expect(
      await BalistiqueMo81M252M853A1Service.selectProfileFor(distanceM: 1500),
      M853A1Profiles.m853a1M772Ch2,
    );
    expect(
      await BalistiqueMo81M252M853A1Service.selectProfileFor(distanceM: 2000),
      M853A1Profiles.m853a1M772Ch2,
    );
    expect(
      await BalistiqueMo81M252M853A1Service.selectProfileFor(distanceM: 3500),
      M853A1Profiles.m853a1M772Ch3,
    );
    expect(
      await BalistiqueMo81M252M853A1Service.selectProfileFor(distanceM: 4500),
      M853A1Profiles.m853a1M772Ch4,
    );
  });

  test(
    'calculates source-anchored nominal references for CH1 through CH4',
    () async {
      const references = <({
        String charge,
        double distanceM,
        double aqeMil,
        double fuzeSetting,
        double timeToBurstS,
        double probableBurstRangeErrorM,
        String profile,
      })>[
        (
          charge: 'CH1',
          distanceM: 1100,
          aqeMil: 1223,
          fuzeSetting: 23.5,
          timeToBurstS: 23.4,
          probableBurstRangeErrorM: 8,
          profile: 'M853A1_M772_CH1',
        ),
        (
          charge: 'CH2',
          distanceM: 1500,
          aqeMil: 1338,
          fuzeSetting: 35.5,
          timeToBurstS: 35.4,
          probableBurstRangeErrorM: 11,
          profile: 'M853A1_M772_CH2',
        ),
        (
          charge: 'CH3',
          distanceM: 3500,
          aqeMil: 1090,
          fuzeSetting: 39.6,
          timeToBurstS: 39.5,
          probableBurstRangeErrorM: 20,
          profile: 'M853A1_M772_CH3',
        ),
        (
          charge: 'CH4',
          distanceM: 4500,
          aqeMil: 1045,
          fuzeSetting: 43.1,
          timeToBurstS: 43.0,
          probableBurstRangeErrorM: 24,
          profile: 'M853A1_M772_CH4',
        ),
      ];

      for (final reference in references) {
        final result = await BalistiqueMo81M252M853A1Service.calculer(
          CalculInput(
            systeme: Systeme.mo81M252,
            typeTir: TypeTir.eclairant,
            m252MunitionFamily: M252MunitionFamily.illM853a1,
            distanceM: reference.distanceM,
            azimutObjectifMil: 1508,
            objAlt: 370,
          ),
        );

        expect(result.charge, reference.charge);
        expect(result.aqeMil, closeTo(reference.aqeMil, 0.001));
        expect(result.m772FuzeSetting, closeTo(reference.fuzeSetting, 0.001));
        expect(result.tempsVolS, closeTo(reference.timeToBurstS, 0.001));
        expect(
          result.ecartProbablePorteeM,
          closeTo(reference.probableBurstRangeErrorM, 0.001),
        );
        expect(result.details['profile'], reference.profile);
        expect(
          result.details['timeOfFlightToBurstS'],
          closeTo(reference.timeToBurstS, 0.001),
        );
        expect(result.details['tableFCorrectionsApplied'], isFalse);
      }
    },
  );

  test('calculates a nominal M853A1 illumination solution', () async {
    final result = await BalistiqueMo81M252M853A1Service.calculer(
      const CalculInput(
        systeme: Systeme.mo81M252,
        typeTir: TypeTir.eclairant,
        m252MunitionFamily: M252MunitionFamily.illM853a1,
        distanceM: 1100,
        azimutObjectifMil: 1508,
        objAlt: 370,
      ),
      tables: M853A1TableRepository(
        profile: M853A1Profiles.m853a1M772Ch1,
        decryptAsset: (path) async => payloads[path]!,
      ),
    );

    expect(result.charge, 'CH1');
    expect(result.aqeMil, closeTo(1223.0, 0.001));
    expect(result.tempsVolS, closeTo(23.4, 0.001));
    expect(result.m772FuzeSetting, closeTo(23.5, 0.001));
    expect(result.hasM772FuzeSetting, isTrue);
    expect(result.isOECL, isTrue);
    expect(result.ecartProbablePorteeM, closeTo(8.0, 0.001));
    expect(result.details['profile'], 'M853A1_M772_CH1');
    expect(result.details['timeOfFlightToBurstS'], closeTo(23.4, 0.001));
    expect(result.details['illuminationBurstHeightAglM'], 475.0);
    expect(result.details['illuminationBurstAltitudeM'], 845.0);
    expect(result.details['illuminationEffectiveDiameterM'], 1200.0);
    expect(result.details['tableFCorrectionsApplied'], isFalse);
  });

  test(
    'applies Table D range and Table F M772 corrections from the MET line',
    () async {
      final result = await BalistiqueMo81M252M853A1Service.calculer(
        const CalculInput(
          systeme: Systeme.mo81M252,
          typeTir: TypeTir.eclairant,
          m252MunitionFamily: M252MunitionFamily.illM853a1,
          distanceM: 1500,
          azimutObjectifMil: 0,
          objAlt: 370,
          meteoOn: true,
          pdZ: 370,
          meteoStationAltM: 370,
          meteoRows: <MeteoRow>[
            MeteoRow(
              level: 4,
              azimutMils: 0,
              vKn: 2,
              tempPermil: 970,
              pressPermil: 1020,
              sourceType: 'METB',
            ),
          ],
        ),
      );

      // At 1500 m, CH2 Table D gives: Wx=+4.4 m/kn, T−=−0.2 m/%,
      // rho+=+4.2 m/%. The source inputs therefore produce
      // +8.8 −0.6 +8.4 = +16.6 m before the corrected D/E lookup.
      expect(result.charge, 'CH2');
      expect(result.porteeCorrigeeM, closeTo(1516.6, 0.01));
      expect(result.wxM, closeTo(8.8, 0.01));
      expect(result.deltaTBM, closeTo(-0.6, 0.01));
      expect(result.deltaPBM, closeTo(8.4, 0.01));
      expect(result.aqeMil, isNot(closeTo(1338.0, 0.001)));
      expect(result.m772FuzeSetting, isNot(closeTo(35.5, 0.001)));
      expect(result.tempageDetails, isNotNull);
      expect(result.tempageDetails!.totalCorrectionsGlobal, isNot(0.0));
      expect(result.details['weatherLineFromTableD'], 4);
      expect(result.details['weatherLineLoaded'], 4);
      expect(result.details['weatherApplied'], isTrue);
      expect(result.details['tableFCorrectionsApplied'], isTrue);
      expect(
        result.details['timeOfFlightMeaning'],
        'muzzle_to_burst_deployment_event',
      );
    },
  );

  test('applies the enabled 0 °C powder correction to M853A1 ΔV0', () async {
    final result = await BalistiqueMo81M252M853A1Service.calculer(
      const CalculInput(
        systeme: Systeme.mo81M252,
        typeTir: TypeTir.eclairant,
        m252MunitionFamily: M252MunitionFamily.illM853a1,
        distanceM: 1500,
        azimutObjectifMil: 0,
        objAlt: 370,
        simTempActC: 0.0,
        simTemperatureCorrectionEnabled: true,
      ),
    );

    expect(
      BalistiqueMo81M252M853A1Service.referencePowderTemperatureC,
      closeTo(21.111111, 0.000001),
    );
    expect(result.charge, 'CH2');
    expect(result.details['powderTemperatureCorrectionEnabled'], isTrue);
    expect(result.deltaV0M, isNot(0.0));
    expect(result.details['tableD_deltaV0M'], isNot(0.0));
    expect(result.details['tableF_deltaV0'], isNot(0.0));
    expect(result.porteeCorrigeeM, isNot(closeTo(1500.0, 0.001)));
  });
}
