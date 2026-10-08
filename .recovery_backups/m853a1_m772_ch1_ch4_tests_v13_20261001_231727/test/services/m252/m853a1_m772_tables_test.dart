import 'dart:io';

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

  test('decodes all six M853A1/M772 CH3 assets and preserves Table F blanks',
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

    final factors = tables.fuzeFactors.atFuzeSetting(39.6);
    expect(factors.fuzeSetting, closeTo(39.6, 0.001));
    expect(factors.v0Dec, isNotNull);
  });

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

  test('rejects unqualified M853A1 non-standard corrections', () {
    expect(
      BalistiqueMo81M252M853A1Service.calculer(
        const CalculInput(
          systeme: Systeme.mo81M252,
          typeTir: TypeTir.eclairant,
          m252MunitionFamily: M252MunitionFamily.illM853a1,
          distanceM: 1100,
          meteoOn: true,
        ),
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
