import 'dart:io';

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

  test('rejects unqualified M772 non-standard corrections', () {
    expect(
      BalistiqueMo81M252M819Service.calculer(
        const CalculInput(
          systeme: Systeme.mo81M252,
          typeTir: TypeTir.appui,
          m252MunitionFamily: M252MunitionFamily.rpM819,
          distanceM: 2500,
          meteoOn: true,
        ),
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
