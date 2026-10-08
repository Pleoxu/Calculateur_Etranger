import 'package:flutter/foundation.dart';

import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/services/m252/m819_profile.dart';
import 'package:calculateur_etranger/services/m252/m819_table_repository.dart';

/// RP M819 / M772 M252 pipeline.
///
/// The delivered stage is deliberately limited to the published **nominal**
/// solution: Table D elevation, M772 setting, time of flight, LINE NO. and
/// probable burst errors. Table F is decrypted and exposed in the result, but
/// its non-standard-condition factors are not yet automatically applied: their
/// input-unit and rounding sequence must be validated with an exercise first.
class BalistiqueMo81M252M819Service {
  const BalistiqueMo81M252M819Service._();

  static bool supportsMunition(M252MunitionFamily? family) =>
      M819Profiles.supportsMunition(family);

  static Future<M819Profile> selectProfileFor({
    required double distanceM,
    String? requestedCharge,
  }) async {
    final candidates = M819Profiles.candidatesFor(
      munition: M252MunitionFamily.rpM819,
      distanceM: distanceM,
      charge: requestedCharge,
    );
    if (candidates.isEmpty) {
      final domains = M819Profiles.all
          .map(
            (profile) => '${profile.chargeLabel} '
                '(${profile.minimumRangeM.toStringAsFixed(0)}–'
                '${profile.maximumRangeM.toStringAsFixed(0)} m)',
          )
          .join(', ');
      throw UnsupportedError(
        'No qualified RP M819/M772 charge matches '
        '${distanceM.toStringAsFixed(0)} m. Available: $domains.',
      );
    }
    if (candidates.length == 1) return candidates.single;

    final ranked = await Future.wait<({M819Profile profile, double rbM})>([
      for (final profile in candidates)
        () async {
          final tables = await M819TableRepository(profile: profile).load();
          return (
            profile: profile,
            rbM: tables.trajectory
                .atDistance(distanceM)
                .probableBurstRangeErrorM,
          );
        }(),
    ]);
    ranked.sort((left, right) => left.rbM.compareTo(right.rbM));
    const tieToleranceM = 0.000001;
    if (ranked.length > 1 &&
        (ranked[0].rbM - ranked[1].rbM).abs() <= tieToleranceM) {
      throw StateError(
        'RP M819/M772 charge selection is tied at '
        '${distanceM.toStringAsFixed(0)} m '
        '(${ranked[0].profile.chargeLabel} and '
        '${ranked[1].profile.chargeLabel}, RB '
        '${ranked[0].rbM.toStringAsFixed(3)} m).',
      );
    }
    return ranked.first.profile;
  }

  static Future<CalculResult> calculer(
    CalculInput input, {
    M819TableRepository? tables,
  }) async {
    if (input.systeme != Systeme.mo81M252 ||
        input.typeTir != TypeTir.appui ||
        input.m252MunitionFamily != M252MunitionFamily.rpM819) {
      throw ArgumentError(
        'RP M819 pipeline requires MO81 M252 / Special Fires / RP M819.',
      );
    }
    if (input.tirMontagne) {
      throw UnsupportedError('RP M819/M772 mountain-fire data is not loaded.');
    }
    if (input.meteoOn ||
        input.meteo != null ||
        (input.meteoRows != null && input.meteoRows!.isNotEmpty) ||
        input.simTemperatureCorrectionEnabled) {
      throw UnsupportedError(
        'RP M819/M772 non-standard corrections are not qualified yet. '
        'Run the nominal exercise first; Table F remains preserved for the '
        'next correction-validation stage.',
      );
    }

    final selectedProfile = await selectProfileFor(
      distanceM: input.distanceM,
      requestedCharge: input.chargeForcee,
    );
    final repository = tables ?? M819TableRepository(profile: selectedProfile);
    if (repository.profile.id != selectedProfile.id) {
      throw ArgumentError(
        'RP M819 pipeline requires profile ${selectedProfile.id}; '
        'received ${repository.profile.id}.',
      );
    }
    final reference = await repository.load();
    final trajectory = reference.trajectory.atDistance(input.distanceM);
    final effects = reference.effects.atDistance(input.distanceM);
    final factors = reference.fuzeFactors.atFuzeSetting(trajectory.fuzeSetting);

    if (kDebugMode) {
      debugPrint(
        '[M819 PROFILE] profile=${selectedProfile.id} '
        'D=${input.distanceM.toStringAsFixed(1)}m '
        'AE=${trajectory.elevationMil.toStringAsFixed(1)}mil '
        'M772=${trajectory.fuzeSetting.toStringAsFixed(1)} '
        'RB=${trajectory.probableBurstRangeErrorM.toStringAsFixed(1)}m '
        'LN=${trajectory.weatherLine}.',
      );
    }

    return CalculResult(
      hausseMil: trajectory.elevationMil,
      aeMil: trajectory.elevationMil,
      aqeMil: trajectory.elevationMil,
      azimutMil: input.azimutObjectifMil,
      gisementMil: input.azimutObjectifMil,
      noireMil: input.azimutObjectifMil,
      porteeM: input.distanceM,
      porteeCorrigeeM: input.distanceM,
      portee: input.distanceM,
      distanceTopoM: input.distanceM,
      deniveleeM: 0.0,
      tempsVolS: trajectory.timeOfFlightS,
      flecheM: effects.trajectoryHeightM ?? 0.0,
      charge: selectedProfile.chargeLabel,
      chargeLabel: selectedProfile.chargeLabel,
      typeAssets: 'M252_${selectedProfile.id}',
      m772FuzeSetting: trajectory.fuzeSetting,
      ecartProbablePorteeM: trajectory.probableBurstRangeErrorM,
      ecartProbableDirectionM: 0.0,
      niveauMeteoBUsed: trajectory.weatherLine,
      details: <String, dynamic>{
        'pipeline': 'M252_M819_M772_NOMINAL',
        'profile': selectedProfile.id,
        'm252Cartridge': M252MunitionFamily.rpM819.label,
        'm252Fuze': M252MunitionFamily.rpM819.defaultFuze,
        'nominalM772FuzeSetting': trajectory.fuzeSetting,
        'timeOfFlightS': trajectory.timeOfFlightS,
        'weatherLineFromTableD': trajectory.weatherLine,
        'tableD_azimuthCorrectionMilPerKnot':
            trajectory.azimuthCorrectionMilPerKnot,
        'tableD_probableBurstHeightErrorM':
            trajectory.probableBurstHeightErrorM,
        'tableD_probableBurstTimeErrorS': trajectory.probableBurstTimeErrorS,
        'tableD_probableBurstRangeErrorM': trajectory.probableBurstRangeErrorM,
        'tableE_trajectoryHeightM': effects.trajectoryHeightM,
        'tableE_impactDistanceM': effects.impactDistanceM,
        'tableF_factorsAtNominalM772': <String, double>{
          'v0Dec': factors.v0Dec,
          'v0Inc': factors.v0Inc,
          'headwind': factors.headwind,
          'tailwind': factors.tailwind,
          'airTemperatureDec': factors.airTemperatureDec,
          'airTemperatureInc': factors.airTemperatureInc,
          'airDensityDec': factors.airDensityDec,
          'airDensityInc': factors.airDensityInc,
        },
        'tableFCorrectionsApplied': false,
        'correctionStatus': 'nominal_only_pending_exercise_validation',
      },
    );
  }
}
