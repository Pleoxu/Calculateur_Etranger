import 'dart:io';
import 'dart:typed_data';

import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/services/balistique_mo81_m252_appui_service.dart';
import 'package:calculateur_etranger/services/m252/m252_profile.dart';
import 'package:calculateur_etranger/services/m252/m252_table_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = M252Profiles.m821M734Ch1;
  late M252TableRepository repository;

  setUpAll(() async {
    final clearRoot =
        'assets/secure/tableaux/foreign/m252/profiles/${profile.id}';
    final payloads = <String, Uint8List>{
      for (final tableId in const <String>['A', 'B', 'C', 'D', 'E'])
        profile.encryptedPath(tableId): Uint8List.fromList(
          await File(
            '$clearRoot/$tableId/${profile.tableFiles[tableId]}',
          ).readAsBytes(),
        ),
    };

    repository = M252TableRepository(
      profile: profile,
      decryptAsset: (path) async {
        final payload = payloads[path];
        if (payload == null) throw StateError('Missing CH1 test asset: $path');
        return payload;
      },
    );
  });

  test(
    'decodes the five CH1 assets and preserves audited source rows',
    () async {
      final tables = await repository.load();

      expect(tables.wind.length, 65);
      expect(tables.airDensity.rows, hasLength(41));

      expect(tables.powderTemperature.rows, hasLength(35));
      expect(
        tables.powderTemperature.atFahrenheit(70).deltaVoMs,
        closeTo(0.0, 0.001),
      );
      expect(
        tables.powderTemperature.atFahrenheit(-40).deltaVoMs,
        closeTo(-3.1, 0.001),
      );
      expect(
        tables.powderTemperature.atFahrenheit(130).deltaVoMs,
        closeTo(2.8, 0.001),
      );

      expect(tables.trajectory.rows, hasLength(71));
      final trajectory = tables.trajectory.atDistance(1000);
      expect(trajectory.elevationMil, closeTo(1337.0, 0.001));
      expect(trajectory.timeOfFlightS, closeTo(29.0, 0.001));
      expect(trajectory.weatherLine, 3);

      expect(tables.dispersion.rows, hasLength(71));
      final dispersion = tables.dispersion.atDistance(500);
      expect(dispersion.probableRangeErrorM, closeTo(6.0, 0.001));
      expect(
        dispersion.probableDirectionErrorM,
        closeTo(4.0, 0.001),
        reason: 'PDF Table E CH1 row 500 m publishes D = +4 m.',
      );
    },
  );

  test('qualifies only the complete CH1 correction domain', () async {
    expect(profile.minimumRangeM, 450.0);
    expect(profile.maximumRangeM, 1875.0);

    expect(
      M252Profiles.candidatesFor(
        munition: M252MunitionFamily.m821a1,
        distanceM: 450,
      ),
      <M252Profile>[profile],
    );
    expect(
      M252Profiles.candidatesFor(
        munition: M252MunitionFamily.m821a1,
        distanceM: 1875,
      ),
      containsAll(<M252Profile>[profile, M252Profiles.m821M734Ch3]),
      reason: 'CH1 and CH3 overlap here; runtime chooses the published Table-E '
          'probable-range-error minimum rather than inventing a priority.',
    );
    expect(
      M252Profiles.candidatesFor(
        munition: M252MunitionFamily.m821a1,
        distanceM: 425,
      ),
      isEmpty,
    );
    expect(
      M252Profiles.candidatesFor(
        munition: M252MunitionFamily.m821a1,
        distanceM: 1900,
      ),
      isNot(contains(profile)),
      reason: 'CH1 ends at 1875 m; CH3 remains a valid separate candidate.',
    );
    expect(
      await BalistiqueMo81M252AppuiService.selectProfileFor(
        family: M252MunitionFamily.m821a2,
        distanceM: 1000,
      ),
      profile,
    );
  });

  test('calculates the neutral 1000 m M821A1 / M734 CH1 reference', () async {
    final result = await BalistiqueMo81M252AppuiService.calculer(
      const CalculInput(
        systeme: Systeme.mo81M252,
        typeTir: TypeTir.appui,
        m252MunitionFamily: M252MunitionFamily.m821a1,
        distanceM: 1000,
        azimutObjectifMil: 1200,
      ),
      tables: repository,
    );

    expect(result.estValide, isTrue);
    expect(result.charge, 'CH1');
    expect(result.typeAssets, 'M252_M821_M734_CH1');
    expect(result.porteeCorrigeeM, closeTo(1000.0, 0.001));
    expect(result.aqeMil, closeTo(1337.0, 0.001));
    expect(result.tempsVolS, closeTo(29.0, 0.001));
    expect(result.ecartProbablePorteeM, closeTo(9.0, 0.001));
    expect(result.ecartProbableDirectionM, closeTo(4.0, 0.001));
    expect(result.niveauMeteoBUsed, 3);
    expect(result.details['profile'], 'M821_M734_CH1');
    expect(result.details['weatherLineFromTableD'], 3);
    expect(result.details['m252Cartridge'], 'M821A1');
    expect(result.details['m252Fuze'], 'M734');
    expect(result.details['qualifiedRangeM'], <double>[450.0, 1875.0]);
  });
}
