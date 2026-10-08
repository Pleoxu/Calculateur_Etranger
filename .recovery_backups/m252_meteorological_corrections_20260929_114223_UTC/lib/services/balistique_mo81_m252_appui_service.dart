import 'package:flutter/foundation.dart';

import 'package:calculateur_etranger/domain/entities/meteo_row.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/services/m252/m252_table_codec.dart';
import 'package:calculateur_etranger/services/m252/m252_table_repository.dart';

/// M252 reference pipeline for M821A1 / charge 3 only.
///
/// It uses only the supplied foreign AEBTL, BEBTL, CEBTL, DEBTL and EEBTL
/// assets. No French table, French resolver, or CAESAR-specific coefficient is
/// used. The qualified domain is deliberately restricted to the overlap of D
/// and E: 1525..2300 m.
class BalistiqueMo81M252AppuiService {
  const BalistiqueMo81M252AppuiService._();

  static const double minimumRangeM = 1525.0;
  static const double maximumRangeM = 2300.0;
  static const String charge = 'CH3';
  static const String typeAssets = 'M252_M821A1_CH3';
  // Zero row of CEBTL: the M252 source expresses powder temperature in °F.
  static const double referencePowderTemperatureF = 70.0;
  static const double referencePowderTemperatureC =
      (referencePowderTemperatureF - 32.0) * 5.0 / 9.0;

  static Future<CalculResult> calculer(
    CalculInput input, {
    M252TableRepository? tables,
  }) async {
    _validateInput(input);
    final reference = await (tables ?? M252TableRepository()).load();

    // Table D, column 5 (`LINE NO.`), is the doctrinal source of the
    // meteorological level. It is discrete, so it is taken from the trajectory
    // row before applying range corrections.
    final initial = reference.trajectory.atDistance(input.distanceM);
    final weatherLineFromTableD = initial.weatherLine;
    // When MET is activated, Table D's LINE NO. is mandatory. Scalar legacy
    // overrides are deliberately ignored in that mode: corrections must come
    // from the exact MET row prescribed by the firing table.
    final MeteoRow? weather = input.meteoOn
        ? _requiredWeatherForTableLine(
            input,
            weatherLineFromTableD,
            input.distanceM,
          )
        : null;
    final windDirectionMil =
        weather?.azimutMils.toDouble() ?? input.meteoAzVentMil ?? 0.0;
    final windKnots = weather?.vKn.toDouble() ?? input.meteoVKn ?? 0.0;
    final rawTemperaturePct =
        weather?.tempPercent ?? input.metTempPercent ?? 100.0;
    final rawPressurePct =
        weather?.pressPercent ?? input.metPressPercent ?? 100.0;

    final deltaStationAltitudeM = input.pdZ - input.meteoStationAltM;
    final air = input.meteoOn
        ? reference.airDensity.atAbsoluteDeltaAltitude(deltaStationAltitudeM)
        : null;
    final altitudeSign = deltaStationAltitudeM < 0 ? -1.0 : 1.0;
    final temperaturePct = rawTemperaturePct +
        (air == null ? 0.0 : altitudeSign * air.deltaTemperaturePct);
    final pressurePct = rawPressurePct +
        (air == null ? 0.0 : altitudeSign * air.deltaPressurePct);

    // First evaluate at the topographic range. Atmospheric and wind effects
    // are expressed in range metres, then the trajectory table is sampled at
    // the corrected range just like the existing fire-support pipeline.
    final wind =
        reference.wind.atAngleMil(windDirectionMil - input.azimutObjectifMil);
    final crossWindKnots = windKnots * wind.wz;
    final longitudinalWindKnots = (windKnots * wind.wx).abs();
    final deltaWindMil = -(crossWindKnots * initial.crosswindMilPerKnot);

    final relativeWind =
        _normalizeMil(windDirectionMil - input.azimutObjectifMil);
    final tailwind = relativeWind >= 1600.0 && relativeWind <= 4800.0;
    final deltaWindRangeM = longitudinalWindKnots *
        (tailwind ? initial.tailwindMPerKnot : initial.headwindMPerKnot);

    final temperatureDifferencePct = temperaturePct - 100.0;
    final deltaTemperatureM = _signedCoefficient(
      temperatureDifferencePct,
      negative: initial.temperatureMinusMPerPct,
      positive: initial.temperaturePlusMPerPct,
    );
    final pressureDifferencePct = pressurePct - 100.0;
    final deltaPressureM = _signedCoefficient(
      pressureDifferencePct,
      negative: initial.pressureMinusMPerPct,
      positive: initial.pressurePlusMPerPct,
    );

    var deltaV0M = 0.0;
    if (input.simTemperatureCorrectionEnabled) {
      // The table reference is the 70 °F / 21.1 °C zero row supplied by the
      // source. The initial-velocity correction does not infer an unavailable
      // V0 reference value; it applies only the documented powder-temperature
      // delta.
      final deltaVo =
          reference.powderTemperature.atCelsius(input.simTempActC).deltaVoMs -
              reference.powderTemperature
                  .atFahrenheit(referencePowderTemperatureF)
                  .deltaVoMs;
      deltaV0M = _signedCoefficient(
        deltaVo,
        negative: initial.v0MinusMPerMs,
        positive: initial.v0PlusMPerMs,
      );
    }

    final totalLongM =
        deltaWindRangeM + deltaTemperatureM + deltaPressureM + deltaV0M;
    if (kDebugMode && weather != null) {
      debugPrint(
        '[M252 MET] LN=${weather.level.toString().padLeft(2, '0')} '
        'A(Wz=${wind.wz.toStringAsFixed(3)},Wx=${wind.wx.toStringAsFixed(3)}) '
        'B(ΔT=${(air == null ? 0.0 : altitudeSign * air.deltaTemperaturePct).toStringAsFixed(2)}%,'
        'ΔP=${(air == null ? 0.0 : altitudeSign * air.deltaPressurePct).toStringAsFixed(2)}%) '
        'D(Wz=${deltaWindMil.toStringAsFixed(2)}mil,Wx=${deltaWindRangeM.toStringAsFixed(2)}m,'
        'T=${deltaTemperatureM.toStringAsFixed(2)}m,P=${deltaPressureM.toStringAsFixed(2)}m) '
        'C(V0=${deltaV0M.toStringAsFixed(2)}m) '
        'total=${totalLongM.toStringAsFixed(2)}m.',
      );
    }
    final correctedRangeM = input.distanceM + totalLongM;
    _validateRange(correctedRangeM);

    final trajectory = reference.trajectory.atDistance(correctedRangeM);
    final dispersion = reference.dispersion.atDistance(correctedRangeM);

    final siteMil = input.deltaAltitudeM / (input.distanceM / 1000.0);
    final aqeMil = trajectory.elevationMil + siteMil;
    final azimuthCorrectionMil = trajectory.driftMil + deltaWindMil;
    final firingBearingMil =
        _normalizeMil(input.azimutObjectifMil - azimuthCorrectionMil);

    return CalculResult(
      hausseMil: aqeMil,
      aqeMil: aqeMil,
      aeMil: trajectory.elevationMil,
      azimutMil: input.azimutObjectifMil,
      gisementMil: firingBearingMil,
      noireMil: firingBearingMil,
      deriveMil: trajectory.driftMil,
      wzMil: deltaWindMil,
      totalCorrectionAzimutMil: azimuthCorrectionMil,
      porteeM: input.distanceM,
      porteeCorrigeeM: correctedRangeM,
      portee: correctedRangeM,
      distanceTopoM: input.distanceM,
      deniveleeM: input.deltaAltitudeM,
      tempsVolS: trajectory.timeOfFlightS,
      vitesseRestanteMps: dispersion.remainingVelocityMs,
      flecheM: dispersion.trajectoryHeightM,
      charge: charge,
      chargeLabel: charge,
      typeAssets: typeAssets,
      wxM: deltaWindRangeM,
      deltaTBM: deltaTemperatureM,
      deltaPBM: deltaPressureM,
      deltaV0M: deltaV0M,
      totalLongM: totalLongM,
      siteBrutMil: siteMil,
      siteTotalAsMil: siteMil,
      corrSiteVraiMil: 0.0,
      acsMil: 0.0,
      correctionSiteBM: 0.0,
      deltaZStationM: deltaStationAltitudeM,
      latitudePieceDeg: input.pdLatitudeDeg,
      ecartProbablePorteeM: dispersion.probableRangeErrorM,
      ecartProbableDirectionM: dispersion.probableDirectionErrorM,
      angleChuteDeg: dispersion.impactAngleMil * 360.0 / 6400.0,
      cotangenteAngleChute: dispersion.impactCotangent,
      niveauMeteoBUsed: weather?.level ?? weatherLineFromTableD,
      details: <String, dynamic>{
        'pipeline': 'M252_M821A1_CH3_REFERENCE',
        'tables': const <String>[
          'AEBTL_V1',
          'BEBTL_V1',
          'CEBTL_V1',
          'DEBTL_V2',
          'EEBTL_V1'
        ],
        'qualifiedRangeM': const <double>[minimumRangeM, maximumRangeM],
        'weatherLineFromTableD': weatherLineFromTableD,
        'weatherLineLoaded': weather?.level,
        'weatherApplied': input.meteoOn && weather != null,
        // Values of the exact MET line required by Table D column 5.
        'meteoSource': weather?.sourceType,
        'meteoWindDirectionMil': weather?.azimutMils,
        'meteoWindKnots': weather?.vKn,
        'meteoRawTemperaturePct': weather?.tempPercent,
        'meteoRawPressurePct': weather?.pressPercent,
        // Table A: wind components in the firing-plane reference frame.
        'tableA_relativeWindMil': relativeWind,
        'tableA_wzFactor': wind.wz,
        'tableA_wxFactor': wind.wx,
        'tableA_crossWindKnots': crossWindKnots,
        'tableA_longitudinalWindKnots': longitudinalWindKnots,
        // Table B: station-to-piece atmospheric adjustment.
        'tableB_stationToPieceDeltaAltitudeM': deltaStationAltitudeM,
        'tableB_temperatureAdjustmentPct':
            air == null ? 0.0 : altitudeSign * air.deltaTemperaturePct,
        'tableB_pressureAdjustmentPct':
            air == null ? 0.0 : altitudeSign * air.deltaPressurePct,
        // Table D: coefficients and resulting firing corrections.
        'tableD_crossWindMilPerKnot': initial.crosswindMilPerKnot,
        'tableD_headwindMPerKnot': initial.headwindMPerKnot,
        'tableD_tailwindMPerKnot': initial.tailwindMPerKnot,
        'tableD_temperatureMinusMPerPct': initial.temperatureMinusMPerPct,
        'tableD_temperaturePlusMPerPct': initial.temperaturePlusMPerPct,
        'tableD_pressureMinusMPerPct': initial.pressureMinusMPerPct,
        'tableD_pressurePlusMPerPct': initial.pressurePlusMPerPct,
        'tableD_deltaCrossWindMil': deltaWindMil,
        'tableD_deltaLongitudinalWindM': deltaWindRangeM,
        'tableD_deltaTemperatureM': deltaTemperatureM,
        'tableD_deltaPressureM': deltaPressureM,
        // Table C: powder-temperature / V0 correction when the option is enabled.
        'tableC_deltaV0M': deltaV0M,
        'windDirectionMil': windDirectionMil,
        'windKnots': windKnots,
        'temperaturePct': temperaturePct,
        'pressurePct': pressurePct,
        'powderTemperatureCorrectionEnabled':
            input.simTemperatureCorrectionEnabled,
        'powderTemperatureC':
            input.simTemperatureCorrectionEnabled ? input.simTempActC : null,
        'powderTemperatureReferenceF': referencePowderTemperatureF,
        'featuresNotQualified': const <String>[
          'tirMontagne',
          'projectileMassVariation',
          'rotationCorrections',
          'similarFireMeasuredV0',
        ],
      },
    );
  }

  static MeteoRow _requiredWeatherForTableLine(
    CalculInput input,
    int tableLine,
    double rangeM,
  ) {
    final rows = input.meteoRows ??
        (input.meteo == null ? const <MeteoRow>[] : <MeteoRow>[input.meteo!]);
    for (final row in rows) {
      if (row.level == tableLine) return row;
    }

    final available =
        rows.map((row) => row.level.toString().padLeft(2, '0')).join(', ');
    throw StateError(
      'M252 M821A1 / CH3: Table D requires MET line '
      '${tableLine.toString().padLeft(2, '0')} at ${rangeM.toStringAsFixed(0)} m; '
      'loaded lines: ${available.isEmpty ? 'none' : available}.',
    );
  }

  static void _validateInput(CalculInput input) {
    if (input.systeme != Systeme.mo81M252) {
      throw ArgumentError('The M252 pipeline requires Systeme.mo81M252.');
    }
    if (input.typeTir != TypeTir.appui) {
      throw UnsupportedError('M252 illuminating tables are not loaded.');
    }
    if (input.m252MunitionFamily != M252MunitionFamily.m821a1) {
      throw UnsupportedError(
        'Only M252 M821A1 / CH3 is qualified; selected=${input.m252MunitionFamily}.',
      );
    }
    if (!_isCharge3(input.chargeForcee)) {
      throw UnsupportedError(
        'Only M252 charge 3 is qualified; selected=${input.chargeForcee}.',
      );
    }
    if (input.tirMontagne) {
      throw UnsupportedError('M252 CH3 mountain-fire data is not loaded.');
    }
    _validateRange(input.distanceM);
  }

  static bool _isCharge3(String? value) {
    if (value == null || value.trim().isEmpty) return true;
    final normalized = value
        .trim()
        .toUpperCase()
        .replaceAll('CHARGE.', '')
        .replaceAll('CH', '');
    return normalized == '3';
  }

  static void _validateRange(double rangeM) {
    if (rangeM < minimumRangeM || rangeM > maximumRangeM) {
      throw M252TableRangeException(
        table: 'M252 M821A1 / CH3 qualified range',
        value: rangeM,
        minimum: minimumRangeM,
        maximum: maximumRangeM,
      );
    }
  }

  static double _signedCoefficient(
    double delta, {
    required double negative,
    required double positive,
  }) {
    if (delta == 0.0) return 0.0;
    return delta.abs() * (delta < 0.0 ? negative : positive);
  }

  static double _normalizeMil(double value) {
    var normalized = value % 6400.0;
    if (normalized < 0.0) normalized += 6400.0;
    return normalized;
  }
}
