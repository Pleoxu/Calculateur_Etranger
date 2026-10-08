import 'package:flutter/foundation.dart';

import 'package:calculateur_etranger/domain/entities/meteo_row.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/services/m252/m252_table_codec.dart';
import 'package:calculateur_etranger/services/m252/m819_table_codec.dart';
import 'package:calculateur_etranger/services/m252/m819_profile.dart';
import 'package:calculateur_etranger/services/m252/m819_table_repository.dart';

/// M252 screening pipeline for RP M819 / M772.
///
/// Table D supplies both the trajectory/range correction factors and the
/// nominal M772 setting. Table F supplies M772 setting corrections only.
class BalistiqueMo81M252M819Service {
  const BalistiqueMo81M252M819Service._();

  static const double referencePowderTemperatureF = 70.0;
  static const double referencePowderTemperatureC =
      (referencePowderTemperatureF - 32.0) * 5.0 / 9.0;

  static bool supportsMunition(M252MunitionFamily? family) =>
      M819Profiles.supportsMunition(family);

  /// Uses the lowest published Table-D RB value in overlap areas.
  /// In case of a tie on RB, selects the lowest charge to save tube life.
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
    final usable = <({M819Profile profile, M819ReferenceTables tables})>[];

    for (final profile in candidates) {
      final tables = await M819TableRepository(profile: profile).load();
      if (tables.supportsDistance(distanceM)) {
        usable.add((profile: profile, tables: tables));
      }
    }

    if (usable.isEmpty) {
      throw UnsupportedError(
        'No loaded RP M819/M772 table set contains '
        '${distanceM.toStringAsFixed(0)} m.',
      );
    }

    if (usable.length == 1) return usable.single.profile;

    final ranked = <({M819Profile profile, double rbM})>[
      for (final candidate in usable)
        (
          profile: candidate.profile,
          rbM: candidate.tables.trajectory
              .atDistance(distanceM)
              .probableBurstRangeErrorM,
        ),
    ];

    // Tri prioritaire par plus faible écart probable (rbM),
    // puis départage par numéro de charge le plus faible pour préserver le tube.
    ranked.sort((left, right) {
      final diffRb = left.rbM - right.rbM;
      if (diffRb.abs() > 0.000001) {
        return diffRb.compareTo(0.0);
      }
      return left.profile.chargeLabel.compareTo(right.profile.chargeLabel);
    });

    return ranked.first.profile;
  }

  static Future<CalculResult> calculer(
    CalculInput input, {
    M819TableRepository? tables,
  }) async {
    _validateInput(input);
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
    if (!reference.supportsDistance(input.distanceM)) {
      throw UnsupportedError(
        'Selected profile ${selectedProfile.id} does not contain '
        'the requested distance in its loaded M819 tables.',
      );
    }

    // LINE NO. is selected before Table-D range corrections are applied.
    final initial = reference.trajectory.atDistance(input.distanceM);
    final meteoActive = _hasMeteorology(input);
    final weather = meteoActive
        ? _requiredWeatherForTableLine(
            input,
            initial.weatherLine,
            selectedProfile,
          )
        : null;
    final windDirectionMil = weather?.azimutMils.toDouble() ?? 0.0;
    final windKnots = weather?.vKn.toDouble() ?? 0.0;
    final rawTemperaturePct = weather?.tempPercent ?? 100.0;
    final rawPressurePct = weather?.pressPercent ?? 100.0;

    // Table B corrects the MET station values to the mortar altitude. It does
    // not supply a target/site correction.
    final stationToGunM =
        meteoActive ? input.pdZ - input.meteoStationAltM : 0.0;
    final atmosphere = meteoActive
        ? reference.airDensity.atAbsoluteDeltaAltitude(stationToGunM)
        : null;
    final stationSign = stationToGunM < 0.0 ? -1.0 : 1.0;
    final temperaturePct = rawTemperaturePct +
        (atmosphere == null
            ? 0.0
            : stationSign * atmosphere.deltaTemperaturePct);
    // The MET B input is Pb%. Table D/F name its resulting effect density.
    final densityPct = rawPressurePct +
        (atmosphere == null ? 0.0 : stationSign * atmosphere.deltaPressurePct);

    final relativeWindMil = _normalizeMil(
      windDirectionMil - input.azimutObjectifMil,
    );
    final wind = reference.wind.atAngleMil(relativeWindMil);
    final crossWindKnots = windKnots * wind.wz;
    final longitudinalWindKnots = (windKnots * wind.wx).abs();
    final tailwind = relativeWindMil >= 1600.0 && relativeWindMil <= 4800.0;

    final deltaWindMil = -crossWindKnots *
        _requireFactor(
          initial.azimuthCorrectionMilPerKnot,
          label: 'Table D cross-wind azimuth correction',
          needed: crossWindKnots != 0.0,
          profile: selectedProfile,
          distanceM: input.distanceM,
        );
    final deltaWindRangeM = longitudinalWindKnots *
        _requireFactor(
          tailwind ? initial.tailwindMPerKnot : initial.headwindMPerKnot,
          label: tailwind
              ? 'Table D tailwind range correction'
              : 'Table D headwind range correction',
          needed: longitudinalWindKnots != 0.0,
          profile: selectedProfile,
          distanceM: input.distanceM,
        );

    final temperatureDifferencePct = temperaturePct - 100.0;
    final deltaTemperatureM = _signedFactor(
      temperatureDifferencePct,
      decrease: initial.airTemperatureDecreaseMPerPct,
      increase: initial.airTemperatureIncreaseMPerPct,
      label: 'Table D air-temperature range correction',
      profile: selectedProfile,
      distanceM: input.distanceM,
    );
    final densityDifferencePct = densityPct - 100.0;
    final deltaDensityM = _signedFactor(
      densityDifferencePct,
      decrease: initial.airDensityDecreaseMPerPct,
      increase: initial.airDensityIncreaseMPerPct,
      label: 'Table D air-density range correction',
      profile: selectedProfile,
      distanceM: input.distanceM,
    );

    var deltaV0Ms = 0.0;
    if (input.simTemperatureCorrectionEnabled) {
      deltaV0Ms =
          reference.powderTemperature.atCelsius(input.simTempActC).deltaVoMs -
              reference.powderTemperature
                  .atFahrenheit(referencePowderTemperatureF)
                  .deltaVoMs;
    }
    final deltaV0M = _signedFactor(
      deltaV0Ms,
      decrease: initial.v0DecreaseMPerMs,
      increase: initial.v0IncreaseMPerMs,
      label: 'Table D muzzle-velocity range correction',
      profile: selectedProfile,
      distanceM: input.distanceM,
    );
    final totalLongM =
        deltaWindRangeM + deltaTemperatureM + deltaDensityM + deltaV0M;
    final correctedRangeM = input.distanceM + totalLongM;
    _validateCorrectedRange(correctedRangeM, selectedProfile, reference);

    // Table D is sampled at corrected range. Table F then only corrects the
    // M772 setting, never the Table-D time of flight to deployment.
    //
    // The currently archived Table-E payload uses a non-FT 81-AR-2 schema.
    // It is loaded for asset compatibility only and must not be mapped to a
    // trajectory height or a deployment correction before its reconstruction.
    final trajectory = reference.trajectory.atDistance(correctedRangeM);
    final factors = reference.fuzeFactors.atNearestPublishedFuzeSetting(
      trajectory.fuzeSetting,
    );
    final deltaFuzeWind = longitudinalWindKnots *
        _requireFactor(
          tailwind ? factors.tailwind : factors.headwind,
          label: tailwind
              ? 'Table F tailwind M772 correction'
              : 'Table F headwind M772 correction',
          needed: longitudinalWindKnots != 0.0,
          profile: selectedProfile,
          distanceM: correctedRangeM,
        );
    final deltaFuzeTemperature = _signedFactor(
      temperatureDifferencePct,
      decrease: factors.airTemperatureDec,
      increase: factors.airTemperatureInc,
      label: 'Table F air-temperature M772 correction',
      profile: selectedProfile,
      distanceM: correctedRangeM,
    );
    final deltaFuzeDensity = _signedFactor(
      densityDifferencePct,
      decrease: factors.airDensityDec,
      increase: factors.airDensityInc,
      label: 'Table F air-density M772 correction',
      profile: selectedProfile,
      distanceM: correctedRangeM,
    );
    final deltaFuzeV0 = _signedFactor(
      deltaV0Ms,
      decrease: factors.v0Dec,
      increase: factors.v0Inc,
      label: 'Table F muzzle-velocity M772 correction',
      profile: selectedProfile,
      distanceM: correctedRangeM,
    );
    final totalFuzeCorrection =
        deltaFuzeWind + deltaFuzeTemperature + deltaFuzeDensity + deltaFuzeV0;
    final finalFuzeSetting = trajectory.fuzeSetting + totalFuzeCorrection;
    final firingBearingMil = _normalizeMil(
      input.azimutObjectifMil + deltaWindMil,
    );
    final correctionsApplied =
        meteoActive || input.simTemperatureCorrectionEnabled;

    if (kDebugMode) {
      debugPrint(
        '[M819 MET] LN=${weather?.level.toString().padLeft(2, '0') ?? '--'} '
        'raw(Dir=${weather?.azimutMils ?? 0}mil,V=${weather?.vKn ?? 0}kn,'
        'T=${rawTemperaturePct.toStringAsFixed(1)}%,Pb=${rawPressurePct.toStringAsFixed(1)}%) '
        'A(Wz=${wind.wz.toStringAsFixed(3)},Wx=${wind.wx.toStringAsFixed(3)}) '
        'B(ΔZstation→gun=${stationToGunM.toStringAsFixed(0)}m,'
        'ΔT=${(atmosphere == null ? 0.0 : stationSign * atmosphere.deltaTemperaturePct).toStringAsFixed(2)}%,'
        'ΔPb=${(atmosphere == null ? 0.0 : stationSign * atmosphere.deltaPressurePct).toStringAsFixed(2)}%) '
        'D(Wz=${deltaWindMil.toStringAsFixed(2)}mil,Wx=${deltaWindRangeM.toStringAsFixed(2)}m,'
        'T=${deltaTemperatureM.toStringAsFixed(2)}m,ρ=${deltaDensityM.toStringAsFixed(2)}m,'
        'V0=${deltaV0M.toStringAsFixed(2)}m) '
        'F(Wx=${deltaFuzeWind.toStringAsFixed(3)},T=${deltaFuzeTemperature.toStringAsFixed(3)},'
        'ρ=${deltaFuzeDensity.toStringAsFixed(3)},V0=${deltaFuzeV0.toStringAsFixed(3)}) '
        'range=${correctedRangeM.toStringAsFixed(2)}m M772=${finalFuzeSetting.toStringAsFixed(3)}.',
      );
      debugPrint(
        '[M819 PROFILE] profile=${selectedProfile.id} '
        'D=${input.distanceM.toStringAsFixed(1)}m '
        'AE=${trajectory.elevationMil.toStringAsFixed(1)}mil '
        'M772=${finalFuzeSetting.toStringAsFixed(3)} '
        'TOF_to_burst=${trajectory.timeOfFlightS.toStringAsFixed(1)}s '
        'RB=${trajectory.probableBurstRangeErrorM.toStringAsFixed(1)}m '
        'LN=${initial.weatherLine}.',
      );
    }

    return CalculResult(
      hausseMil: trajectory.elevationMil,
      aeMil: trajectory.elevationMil,
      aqeMil: trajectory.elevationMil,
      azimutMil: input.azimutObjectifMil,
      gisementMil: firingBearingMil,
      noireMil: firingBearingMil,
      wzMil: deltaWindMil,
      totalCorrectionAzimutMil: deltaWindMil,
      wxM: deltaWindRangeM,
      deltaTBM: deltaTemperatureM,
      deltaPBM: deltaDensityM,
      deltaV0M: deltaV0M,
      totalLongM: totalLongM,
      porteeM: input.distanceM,
      porteeCorrigeeM: correctedRangeM,
      portee: correctedRangeM,
      distanceTopoM: input.distanceM,
      deniveleeM: input.deltaAltitudeM,
      tempsVolS: trajectory.timeOfFlightS,
      flecheM: 0.0,
      charge: selectedProfile.chargeLabel,
      chargeLabel: selectedProfile.chargeLabel,
      typeAssets: 'M252_${selectedProfile.id}',
      m772FuzeSetting: finalFuzeSetting,
      tempageDetails: TempageDetails(
        tNominal: trajectory.fuzeSetting,
        deltaTvent: deltaFuzeWind,
        deltaTTb: deltaFuzeTemperature,
        deltaTPb: deltaFuzeDensity,
        deltaTV0: deltaFuzeV0,
        totalCorrectionsGlobal: totalFuzeCorrection,
        tFusee: finalFuzeSetting,
      ),
      corrEclPour50mMil: 0.0,
      corrEclDeniveleeMil: 0.0,
      ecartProbablePorteeM: trajectory.probableBurstRangeErrorM,
      ecartProbableDirectionM: 0.0,
      deltaZStationM: stationToGunM,
      niveauMeteoBUsed: weather?.level ?? initial.weatherLine,
      details: <String, dynamic>{
        'pipeline': 'M252_M819_M772',
        'profile': selectedProfile.id,
        'm252Cartridge': M252MunitionFamily.rpM819.label,
        'm252Fuze': M252MunitionFamily.rpM819.defaultFuze,
        'tables': const <String>[
          'AEBTL_V1',
          'BEBTL_V1',
          'CEBTL_V1',
          'M819DTBL_V2',
          'M819ETBL_V1',
          'M819FTBL_V1',
        ],
        'tableEStatus': 'withheld_pending_ft81_ar2_schema_reconstruction',
        'weatherLineFromTableD': initial.weatherLine,
        'weatherLineLoaded': weather?.level,
        'weatherApplied': meteoActive && weather != null,
        'meteoSource': weather?.sourceType,
        'tableA_relativeWindMil': relativeWindMil,
        'tableA_wzFactor': wind.wz,
        'tableA_wxFactor': wind.wx,
        'tableA_crossWindKnots': crossWindKnots,
        'tableA_longitudinalWindKnots': longitudinalWindKnots,
        'tableB_stationToGunDeltaAltitudeM': stationToGunM,
        'tableB_temperatureAdjustmentPct': atmosphere == null
            ? 0.0
            : stationSign * atmosphere.deltaTemperaturePct,
        'tableB_pressureAdjustmentPct': atmosphere == null
            ? 0.0
            : stationSign * atmosphere.deltaPressurePct,
        'tableD_deltaCrossWindMil': deltaWindMil,
        'tableD_deltaLongitudinalWindM': deltaWindRangeM,
        'tableD_deltaTemperatureM': deltaTemperatureM,
        'tableD_deltaDensityM': deltaDensityM,
        'tableD_deltaV0M': deltaV0M,
        'tableD_rangeM': correctedRangeM,
        'tableF_nominalM772Setting': trajectory.fuzeSetting,
        'tableF_publishedM772Setting': factors.fuzeSetting,
        'tableF_deltaWind': deltaFuzeWind,
        'tableF_deltaTemperature': deltaFuzeTemperature,
        'tableF_deltaDensity': deltaFuzeDensity,
        'tableF_deltaV0': deltaFuzeV0,
        'tableF_totalCorrection': totalFuzeCorrection,
        'tableF_finalM772Setting': finalFuzeSetting,
        'tableFCorrectionsApplied': correctionsApplied,
        'powderTemperatureCorrectionEnabled':
            input.simTemperatureCorrectionEnabled,
        'timeOfFlightToBurstS': trajectory.timeOfFlightS,
        'timeOfFlightMeaning': 'muzzle_to_M772_event',
      },
    );
  }

  static void _validateInput(CalculInput input) {
    if (input.systeme != Systeme.mo81M252 ||
        input.typeTir != TypeTir.appui ||
        input.m252MunitionFamily != M252MunitionFamily.rpM819) {
      throw ArgumentError(
        'RP M819 pipeline requires MO81 M252 / Special Fires / '
        'Screening / RP M819.',
      );
    }
    if (input.tirMontagne) {
      throw UnsupportedError('RP M819/M772 mountain-fire data is not loaded.');
    }
  }

  static bool _hasMeteorology(CalculInput input) =>
      input.meteoOn ||
      input.meteo != null ||
      (input.meteoRows != null && input.meteoRows!.isNotEmpty);

  static MeteoRow _requiredWeatherForTableLine(
    CalculInput input,
    int tableLine,
    M819Profile profile,
  ) {
    final rows = input.meteoRows ??
        (input.meteo == null ? const <MeteoRow>[] : <MeteoRow>[input.meteo!]);
    for (final row in rows) {
      if (row.level == tableLine) return row;
    }
    final available =
        rows.map((row) => row.level.toString().padLeft(2, '0')).join(', ');
    throw StateError(
      'RP M819/M772 ${profile.id}: Table D requires MET line '
      '${tableLine.toString().padLeft(2, '0')}; loaded lines: '
      '${available.isEmpty ? 'none' : available}.',
    );
  }

  static void _validateCorrectedRange(
    double rangeM,
    M819Profile profile,
    M819ReferenceTables reference,
  ) {
    if (!reference.supportsDistance(rangeM)) {
      final minimum = reference.trajectory.minimumDistanceM;
      final maximum = reference.trajectory.maximumDistanceM;
      throw M252TableRangeException(
        table: 'M819 ${profile.id} loaded-table corrected range',
        value: rangeM,
        minimum: minimum ?? rangeM,
        maximum: maximum ?? rangeM,
      );
    }
  }

  static double _requireFactor(
    double? value, {
    required String label,
    required bool needed,
    required M819Profile profile,
    required double distanceM,
  }) {
    if (!needed) return 0.0;
    if (value != null) return value;
    throw UnsupportedError(
      '${profile.id}: $label is not published at '
      '${distanceM.toStringAsFixed(1)} m; the requested correction is not applied.',
    );
  }

  static double _signedFactor(
    double delta, {
    required double? decrease,
    required double? increase,
    required String label,
    required M819Profile profile,
    required double distanceM,
  }) {
    if (delta == 0.0) return 0.0;
    return delta.abs() *
        _requireFactor(
          delta < 0.0 ? decrease : increase,
          label: label,
          needed: true,
          profile: profile,
          distanceM: distanceM,
        );
  }

  static double _normalizeMil(double value) {
    var normalized = value % 6400.0;
    if (normalized < 0.0) normalized += 6400.0;
    return normalized;
  }
}
