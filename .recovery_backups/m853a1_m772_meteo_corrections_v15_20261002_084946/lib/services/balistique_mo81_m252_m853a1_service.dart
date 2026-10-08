import 'package:flutter/foundation.dart';

import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/services/m252/m853a1_profile.dart';
import 'package:calculateur_etranger/services/m252/m853a1_table_repository.dart';

/// M252 illumination pipeline for ILL M853A1 with M772 fuze.
///
/// Table D supplies the elevation, nominal M772 setting, time of flight to the
/// burst/deployment event, LINE NO. and probable burst errors. The setting is
/// retained separately from time of flight; it is not substituted for it.
///
/// The published Table F correction factors are preserved and exposed, but are
/// not applied until their units, signs and rounding sequence are qualified
/// against a documented illumination exercise.
class BalistiqueMo81M252M853A1Service {
  const BalistiqueMo81M252M853A1Service._();

  static const double illuminationBurstHeightAglM = 475.0;
  static const double illuminationDiameterM = 1200.0;
  static const double illuminationRadiusM = illuminationDiameterM / 2;
  static const double illuminationMinCandela = 525000.0;
  static const double illuminationMaxCandela = 600000.0;
  static const double illuminationBurnMinS = 50.0;
  static const double illuminationBurnMaxS = 60.0;

  static bool supportsMunition(M252MunitionFamily? family) =>
      M853A1Profiles.supportsMunition(family);

  /// Resolves overlapping qualified charges using the lowest published
  /// Table-D probable burst-range error (RB), never merely the first range.
  static Future<M853A1Profile> selectProfileFor({
    required double distanceM,
    String? requestedCharge,
  }) async {
    final candidates = M853A1Profiles.candidatesFor(
      munition: M252MunitionFamily.illM853a1,
      distanceM: distanceM,
      charge: requestedCharge,
    );
    if (candidates.isEmpty) {
      final domains = M853A1Profiles.all
          .map(
            (profile) => '${profile.chargeLabel} '
                '(${profile.minimumRangeM.toStringAsFixed(0)}–'
                '${profile.maximumRangeM.toStringAsFixed(0)} m)',
          )
          .join(', ');
      throw UnsupportedError(
        'No qualified ILL M853A1/M772 charge matches '
        '${distanceM.toStringAsFixed(0)} m. Available: $domains.',
      );
    }
    if (candidates.length == 1) return candidates.single;

    final ranked = await Future.wait<({M853A1Profile profile, double rbM})>([
      for (final profile in candidates)
        () async {
          final tables = await M853A1TableRepository(profile: profile).load();
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
        'ILL M853A1/M772 charge selection is tied at '
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
    M853A1TableRepository? tables,
  }) async {
    if (input.systeme != Systeme.mo81M252 ||
        input.typeTir != TypeTir.eclairant ||
        input.m252MunitionFamily != M252MunitionFamily.illM853a1) {
      throw ArgumentError(
        'ILL M853A1 pipeline requires MO81 M252 / Special Fires / '
        'Illumination / ILL M853A1.',
      );
    }
    if (input.tirMontagne) {
      throw UnsupportedError(
        'ILL M853A1/M772 mountain-fire data is not loaded.',
      );
    }
    final hasUnqualifiedCorrections = input.meteoOn ||
        input.meteo != null ||
        (input.meteoRows != null && input.meteoRows!.isNotEmpty) ||
        input.simTemperatureCorrectionEnabled;

    final selectedProfile = await selectProfileFor(
      distanceM: input.distanceM,
      requestedCharge: input.chargeForcee,
    );
    final repository =
        tables ?? M853A1TableRepository(profile: selectedProfile);
    if (repository.profile.id != selectedProfile.id) {
      throw ArgumentError(
        'ILL M853A1 pipeline requires profile ${selectedProfile.id}; '
        'received ${repository.profile.id}.',
      );
    }

    final reference = await repository.load();
    final trajectory = reference.trajectory.atDistance(input.distanceM);
    final effects = reference.effects.atDistance(input.distanceM);
    final factors = reference.fuzeFactors.atFuzeSetting(trajectory.fuzeSetting);
    final burstAltitudeM = input.objAlt + illuminationBurstHeightAglM;

    if (hasUnqualifiedCorrections && kDebugMode) {
      debugPrint(
        '[M853A1 METEO] meteorological input received; nominal result '
        'retained and Table F corrections are not applied pending '
        'exercise validation.',
      );
    }

    if (kDebugMode) {
      debugPrint(
        '[M853A1 PROFILE] profile=${selectedProfile.id} '
        'D=${input.distanceM.toStringAsFixed(1)}m '
        'AE=${trajectory.elevationMil.toStringAsFixed(1)}mil '
        'M772=${trajectory.fuzeSetting.toStringAsFixed(1)} '
        'TOF_to_burst=${trajectory.timeOfFlightS.toStringAsFixed(1)}s '
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
      deniveleeM: input.deltaAltitudeM,
      // Table D time of flight ends at the burst/deployment event.
      tempsVolS: trajectory.timeOfFlightS,
      flecheM: effects.trajectoryHeightM ?? 0.0,
      charge: selectedProfile.chargeLabel,
      chargeLabel: selectedProfile.chargeLabel,
      typeAssets: 'M252_OECL_${selectedProfile.id}',
      m772FuzeSetting: trajectory.fuzeSetting,
      corrEclPour50mMil: effects.elevationForBurstHeight50mMil ?? 0.0,
      corrEclDeniveleeMil: 0.0,
      ecartProbablePorteeM: trajectory.probableBurstRangeErrorM,
      ecartProbableDirectionM: 0.0,
      niveauMeteoBUsed: trajectory.weatherLine,
      details: <String, dynamic>{
        'pipeline': 'M252_M853A1_M772_NOMINAL',
        'profile': selectedProfile.id,
        'm252Cartridge': M252MunitionFamily.illM853a1.label,
        'm252Fuze': M252MunitionFamily.illM853a1.defaultFuze,
        'nominalM772FuzeSetting': trajectory.fuzeSetting,
        'timeOfFlightToBurstS': trajectory.timeOfFlightS,
        'timeOfFlightMeaning': 'muzzle_to_burst_deployment_event',
        'weatherLineFromTableD': trajectory.weatherLine,
        'illuminationBurstHeightAglM': illuminationBurstHeightAglM,
        'illuminationBurstReference': 'target_ground_level',
        'illuminationBurstAltitudeM': burstAltitudeM,
        'illuminationEffectiveDiameterM': illuminationDiameterM,
        'illuminationEffectiveRadiusM': illuminationRadiusM,
        'illuminationIntensityCandela': <double>[
          illuminationMinCandela,
          illuminationMaxCandela,
        ],
        'illuminationBurnDurationS': <double>[
          illuminationBurnMinS,
          illuminationBurnMaxS,
        ],
        'tableD_azimuthCorrectionMilPerKnot':
            trajectory.azimuthCorrectionMilPerKnot,
        'tableD_probableBurstHeightErrorM':
            trajectory.probableBurstHeightErrorM,
        'tableD_probableBurstTimeErrorS': trajectory.probableBurstTimeErrorS,
        'tableD_probableBurstRangeErrorM': trajectory.probableBurstRangeErrorM,
        'tableE_maxOrdinateM': effects.trajectoryHeightM,
        'tableE_impactDistanceM': effects.impactDistanceM,
        'tableF_factorsAtNominalM772': <String, double?>{
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
        'correctionStatus': hasUnqualifiedCorrections
            ? 'nominal_retained_weather_corrections_pending_validation'
            : 'nominal_only_pending_exercise_validation',
        'weatherInputReceived': hasUnqualifiedCorrections,
        if (hasUnqualifiedCorrections)
          'weatherCorrectionMessage':
              'Meteorological data accepted. Nominal M853A1/M772 values are '
                  'retained; Table F corrections are pending exercise validation.',
      },
    );
  }
}
