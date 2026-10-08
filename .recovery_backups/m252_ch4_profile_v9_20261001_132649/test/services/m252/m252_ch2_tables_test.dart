import 'dart:io';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/services/balistique_mo81_m252_appui_service.dart';
import 'package:calculateur_etranger/services/m252/m252_profile.dart';
import 'package:calculateur_etranger/services/m252/m252_table_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = M252Profiles.m821M734Ch2;
  late M252TableRepository repository;
  late Map<String, Uint8List> profilePayloads;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    profilePayloads = <String, Uint8List>{
      for (final candidate in M252Profiles.all)
        for (final tableId in const <String>['A', 'B', 'C', 'D', 'E'])
          candidate.encryptedPath(tableId): Uint8List.fromList(
            await File(
              'assets/secure/tableaux/foreign/m252/profiles/${candidate.id}/'
              '$tableId/${candidate.tableFiles[tableId]}',
            ).readAsBytes(),
          ),
    };
    repository = M252TableRepository(
      profile: profile,
      decryptAsset: (path) async {
        final payload = profilePayloads[path];
        if (payload == null) throw StateError('Missing CH2 test asset: $path');
        return payload;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('secure_assets'), (
      call,
    ) async {
      if (call.method != 'decryptAsset') {
        throw MissingPluginException('Unexpected secure-assets method.');
      }
      final path = (call.arguments as Map<Object?, Object?>)['path'];
      final payload = profilePayloads[path];
      if (payload == null) throw StateError('Missing mock asset: $path');
      return payload;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('secure_assets'), null);
  });

  test('decodes the five CH2 assets and preserves audited source rows',
      () async {
    final tables = await repository.load();

    expect(tables.wind.length, 65);
    expect(tables.airDensity.rows, hasLength(41));

    expect(tables.powderTemperature.rows, hasLength(35));
    expect(
      tables.powderTemperature.atFahrenheit(-40).deltaVoMs,
      closeTo(-4.9, 0.001),
    );
    expect(
      tables.powderTemperature.atFahrenheit(70).deltaVoMs,
      closeTo(0.0, 0.001),
    );
    expect(
      tables.powderTemperature.atFahrenheit(130).deltaVoMs,
      closeTo(3.5, 0.001),
    );

    expect(tables.trajectory.rows, hasLength(92));
    final trajectory = tables.trajectory.atDistance(1250);
    expect(trajectory.elevationMil, closeTo(1402.0, 0.001));
    expect(trajectory.timeOfFlightS, closeTo(39.5, 0.001));
    expect(trajectory.weatherLine, 5);
    expect(tables.trajectory.atDistance(3125).weatherLine, 4);

    expect(tables.dispersion.rows, hasLength(92));
    final dispersion = tables.dispersion.atDistance(1250);
    expect(dispersion.probableRangeErrorM, closeTo(10.0, 0.001));
    expect(dispersion.probableDirectionErrorM, closeTo(7.0, 0.001));
    expect(tables.dispersion.atDistance(3125).probableRangeErrorM,
        closeTo(17.0, 0.001));
  });

  test('qualifies only the complete CH2 correction domain', () async {
    expect(profile.minimumRangeM, 1125.0);
    expect(profile.maximumRangeM, 3125.0);
    expect(
      M252Profiles.candidatesFor(
        munition: M252MunitionFamily.m821a1,
        distanceM: 1125,
      ),
      containsAll(<M252Profile>[M252Profiles.m821M734Ch1, profile]),
    );
    expect(
      M252Profiles.candidatesFor(
        munition: M252MunitionFamily.m821a1,
        distanceM: 3125,
      ),
      <M252Profile>[profile],
    );
    expect(
      M252Profiles.candidatesFor(
        munition: M252MunitionFamily.m821a1,
        distanceM: 3150,
      ),
      isNot(contains(profile)),
      reason: 'Table D no longer publishes the V0 DEC correction at 3150 m.',
    );
  });

  test('selects CH2 where it has the lowest published EPP', () async {
    expect(
      await BalistiqueMo81M252AppuiService.selectProfileFor(
        family: M252MunitionFamily.m821a1,
        distanceM: 1250,
      ),
      profile,
    );
    expect(
      await BalistiqueMo81M252AppuiService.selectProfileFor(
        family: M252MunitionFamily.m821a2,
        distanceM: 2400,
      ),
      profile,
    );
    expect(
      await BalistiqueMo81M252AppuiService.selectProfileFor(
        family: M252MunitionFamily.m821a1,
        distanceM: 1525,
      ),
      M252Profiles.m821M734Ch3,
      reason: 'CH3 publishes a lower EPP at 1525 m.',
    );
    await expectLater(
      BalistiqueMo81M252AppuiService.selectProfileFor(
        family: M252MunitionFamily.m821a1,
        distanceM: 1125,
      ),
      throwsA(isA<StateError>()),
      reason: 'CH1 and CH2 are tied at 10 m EPP; no priority is invented.',
    );
  });

  test('calculates the neutral 1250 m M821A1 / M734 CH2 reference', () async {
    final result = await BalistiqueMo81M252AppuiService.calculer(
      const CalculInput(
        systeme: Systeme.mo81M252,
        typeTir: TypeTir.appui,
        m252MunitionFamily: M252MunitionFamily.m821a1,
        distanceM: 1250,
        azimutObjectifMil: 1200,
      ),
      tables: repository,
    );

    expect(result.estValide, isTrue);
    expect(result.charge, 'CH2');
    expect(result.typeAssets, 'M252_M821_M734_CH2');
    expect(result.porteeCorrigeeM, closeTo(1250.0, 0.001));
    expect(result.aqeMil, closeTo(1402.0, 0.001));
    expect(result.tempsVolS, closeTo(39.5, 0.001));
    expect(result.ecartProbablePorteeM, closeTo(10.0, 0.001));
    expect(result.ecartProbableDirectionM, closeTo(7.0, 0.001));
    expect(result.niveauMeteoBUsed, 5);
    expect(result.details['profile'], 'M821_M734_CH2');
    expect(result.details['weatherLineFromTableD'], 5);
    expect(result.details['m252Cartridge'], 'M821A1');
    expect(result.details['m252Fuze'], 'M734');
    expect(result.details['qualifiedRangeM'], <double>[1125.0, 3125.0]);
  });
}
