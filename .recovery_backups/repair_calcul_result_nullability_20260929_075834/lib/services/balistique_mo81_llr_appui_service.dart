// lib/services/balistique_mo81_llr_appui_service.dart
//
// Pipeline dédié MO81 LLR — APPUI.
// Munition raccordée : OE 81 F2 / CH1 à CH6.
//
// Principe important : T1 n'est PAS transformé en correction de portée au début.
// T1 sert d'abord à déterminer le niveau météo, puis sa correction de site est
// appliquée seulement à la fin sur la hausse issue de T2.

import 'package:flutter/foundation.dart';

import '../models/calcul_data.dart';
import 'tableau_b_mo81_llr_service.dart';
import 'tableau_c_service.dart';
import 'tableau_d_service.dart' as tableau_d;
import 'tableau_e_service.dart';
import 'tableau_f_service.dart';
import 'mo81_llr_charge_selector.dart';

class BalistiqueMo81LlrAppuiService {
  const BalistiqueMo81LlrAppuiService._();

  static const String _variant = 'MO81_LLR_OE_81_F2';

  static String _t1Path(String charge) =>
      'assets/secure_enc/tableaux/MO81_LLR/T1/'
      '${_variant}_T1_$charge.btbl.gz.enc';

  static String _t2Path(String charge) =>
      'assets/secure_enc/tableaux/MO81_LLR/T2/'
      '${_variant}_T2_$charge.ftbl.gz.enc';

  static String _t3Path(String charge) =>
      'assets/secure_enc/tableaux/MO81_LLR/T3/'
      '${_variant}_T3_$charge.etbl.gz.enc';

  static const String _annexe1Path =
      'assets/secure_enc/tableaux/MO81_LLR/Annexe_1/'
      'MO81_LLR_ANNEXE_1.ctbl.gz.enc';

  static const String _annexe2Path =
      'assets/secure_enc/tableaux/MO81_LLR/Annexe_2/'
      'MO81_LLR_ANNEXE_2.dtbl.gz.enc';

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[MO81 LLR] $message');
    }
  }

  static Future<String> _chargeFor(
    CalculInput input, {
    required double distanceTopo,
  }) async {
    final forced = input.chargeForcee?.trim().toUpperCase();

    if (forced != null && forced.isNotEmpty) {
      final normalized = forced.startsWith('CH') ? forced : 'CH$forced';
      const allowed = {'CH1', 'CH2', 'CH3', 'CH4', 'CH5', 'CH6'};
      if (!allowed.contains(normalized)) {
        throw StateError(
          'MO81 LLR / OE 81 F2 : charge invalide $forced '
          '(attendu CH1 à CH6).',
        );
      }
      _log('CHARGE FORCEE D=${distanceTopo.toStringAsFixed(1)} => $normalized');
      return normalized;
    }

    try {
      final choice = await Mo81LlrChargeSelector.selectForDistance(
        distanceM: distanceTopo,
        munition: TypeMunition.oe81F2,
        verbose: kDebugMode,
      );

      _log(
        'CHARGE AUTO D=${distanceTopo.toStringAsFixed(1)} '
        '=> ${choice.charge} hausse=${choice.hausseMil.toStringAsFixed(2)} mil',
      );

      return choice.charge;
    } on StateError catch (error) {
      // La bande 1000–1100 mil est une règle de choix préférentiel, pas une
      // limite de portée. Si aucune charge n'entre dans cette bande mais qu'une
      // table T2 possède bien une solution à la distance demandée, on retient
      // la charge dont la hausse est la plus proche de la bande.
      final message = error.toString();
      if (!message.contains('aucune charge')) {
        rethrow;
      }

      const charges = <String>['CH1', 'CH2', 'CH3', 'CH4', 'CH5', 'CH6'];
      final candidats = <({String charge, double hausseMil})>[];

      for (final charge in charges) {
        final service = TableauFService(
          typeTir: _variant,
          charge: charge,
          verbose: false,
          encryptedPathOverride: _t2Path(charge),
        );

        final hausse = await service.hausseMil(
          distance: distanceTopo,
          tirMontagne: input.tirMontagne,
        );

        if (hausse != null && hausse.isFinite && hausse > 0.0) {
          candidats.add((charge: charge, hausseMil: hausse));
        }
      }

      if (candidats.isEmpty) {
        throw StateError(
          'MO81 LLR / OE 81 F2 : aucune charge CH1 à CH6 '
          'ne possède de solution T2 pour '
          'D=${distanceTopo.toStringAsFixed(0)} m.',
        );
      }

      double ecartBande(double hausseMil) {
        if (hausseMil < 1000.0) return 1000.0 - hausseMil;
        if (hausseMil > 1100.0) return hausseMil - 1100.0;
        return 0.0;
      }

      candidats.sort((a, b) {
        final cmp = ecartBande(a.hausseMil).compareTo(ecartBande(b.hausseMil));
        if (cmp != 0) return cmp;

        final na = int.parse(a.charge.substring(2));
        final nb = int.parse(b.charge.substring(2));
        return na.compareTo(nb);
      });

      final fallback = candidats.first;
      _log(
        'CHARGE AUTO FALLBACK D=${distanceTopo.toStringAsFixed(1)} '
        '=> ${fallback.charge} '
        'hausse=${fallback.hausseMil.toStringAsFixed(2)} mil '
        '(écart bande 1000–1100 = '
        '${ecartBande(fallback.hausseMil).toStringAsFixed(2)} mil)',
      );

      return fallback.charge;
    }
  }

  static T _meteoRowForLevel<T>(List<T> rows, int niveau) {
    if (rows.isEmpty) {
      throw StateError('MO81 LLR : message météo vide.');
    }

    final sorted = [...rows]..sort(
        (a, b) => ((a as dynamic).level as int).compareTo(
          (b as dynamic).level as int,
        ),
      );

    final minLevel = (sorted.first as dynamic).level as int;
    final maxLevel = (sorted.last as dynamic).level as int;
    final effective = niveau.clamp(minLevel, maxLevel).toInt();

    return sorted.firstWhere(
      (row) => ((row as dynamic).level as int) == effective,
      orElse: () => sorted.reduce((a, b) {
        final da = (((a as dynamic).level as int) - effective).abs();
        final db = (((b as dynamic).level as int) - effective).abs();
        return da <= db ? a : b;
      }),
    );
  }

  static Future<double> _coef(
    TableauFService fService, {
    required double distance,
    required bool tirMontagne,
    required String field,
  }) async {
    return await fService.coefficientLongitudinal(
          distance: distance,
          tirMontagne: tirMontagne,
          field: field,
        ) ??
        0.0;
  }

  static Future<CalculResult> calculer(CalculInput input) async {
    final sw = Stopwatch()..start();

    if (input.systeme != Systeme.mo81Lrr) {
      throw StateError(
        'BalistiqueMo81LlrAppuiService appelé avec systeme=${input.systeme}.',
      );
    }

    if (input.typeTir != TypeTir.appui) {
      throw StateError(
        'BalistiqueMo81LlrAppuiService appelé avec typeTir=${input.typeTir}.',
      );
    }

    if (input.typeMunition != TypeMunition.oe81F2) {
      throw StateError(
        'MO81 LLR Appui : tables balistiques non encore intégrées pour '
        '${input.typeMunition?.label ?? "munition non sélectionnée"}. '
        'Sélectionner OE 81 F2.',
      );
    }

    final distanceTopo = input.objD;
    final charge = await _chargeFor(input, distanceTopo: distanceTopo);
    final azimutMil = input.objA;
    final deniveleeM = input.objAlt - input.pdZ;
    final tirMontagne = input.tirMontagne;
    final latitudePieceDeg = input.pdLatitudeDeg ?? 45.0;

    // ---------------------------------------------------------------------
    // 1) T1 : niveau météo + correction de site.
    // IMPORTANT : la correction de site est mémorisée mais n'est PAS ajoutée
    // à la distance topographique. Elle sera appliquée à la hausse en final.
    // ---------------------------------------------------------------------
    _log(
      'ASSETS charge=$charge '
      'T1=${_t1Path(charge)} '
      'T2=${_t2Path(charge)} '
      'T3=${_t3Path(charge)}',
    );

    final bService = TableauBMo81LlrService(
      tirMontagne: tirMontagne,
      verbose: kDebugMode,
      encryptedPath: _t1Path(charge),
    );

    final bRow = await bService.chercher(
      distanceTopoM: distanceTopo,
      deniveleeM: deniveleeM,
    );

    if (bRow == null || !bRow.valid) {
      throw StateError(
        'MO81 LLR T1 inexploitable pour '
        'D=${distanceTopo.toStringAsFixed(1)} m '
        'ΔZ=${deniveleeM.toStringAsFixed(1)} m : '
        '${bRow?.warning ?? "aucune ligne"}',
      );
    }

    final correctionSiteMil = bRow.correctionSiteMil;
    final niveauMeteo = bRow.niveauMeteo;
    var niveauMeteoEffectif = niveauMeteo;

    _log(
      'T1 D=${distanceTopo.toStringAsFixed(1)} '
      'ΔZ=${deniveleeM.toStringAsFixed(1)} '
      'LN=$niveauMeteo corrSite=${correctionSiteMil.toStringAsFixed(2)} mil',
    );

    // ---------------------------------------------------------------------
    // 2) T2 / T3 / Annexes MO81 LLR.
    // ---------------------------------------------------------------------
    final fService = TableauFService(
      typeTir: _variant,
      charge: charge,
      verbose: kDebugMode,
      encryptedPathOverride: _t2Path(charge),
    );

    final eService = TableauEService(
      typeTir: _variant,
      charge: charge,
      verbose: kDebugMode,
      encryptedPathOverride: _t3Path(charge),
    );

    final cService = TableauCService(
      typeTir: _variant,
      niveauMeteo: niveauMeteo,
      verbose: kDebugMode,
      encryptedPath: _annexe1Path,
    );

    final dService = tableau_d.TableauDService(
      typeTir: _variant,
      verbose: kDebugMode,
      encryptedPath: _annexe2Path,
    );

    // Les coefficients T2 sont pris à la distance topographique.
    final deriveRaw = await fService.deriveMil(
          distance: distanceTopo,
          tirMontagne: tirMontagne,
        ) ??
        0.0;

    final kWz = await fService.correctionWz(
          distance: distanceTopo,
          tirMontagne: tirMontagne,
        ) ??
        0.0;

    final kVent = await _coef(
      fService,
      distance: distanceTopo,
      tirMontagne: tirMontagne,
      field: 'correctionVentMoins',
    );

    final kTemp = await _coef(
      fService,
      distance: distanceTopo,
      tirMontagne: tirMontagne,
      field: 'correctionTempMoins',
    );

    final kPress = await _coef(
      fService,
      distance: distanceTopo,
      tirMontagne: tirMontagne,
      field: 'correctionPressionMoins',
    );

    final kV0 = await _coef(
      fService,
      distance: distanceTopo,
      tirMontagne: tirMontagne,
      field: 'correctionV0Moins',
    );

    // Arrondi doctrinal des corrections directionnelles élémentaires.
    final deriveMil = deriveRaw.roundToDouble();

    double wzMil = 0.0;
    double wxM = 0.0;
    double deltaTBM = 0.0;
    double deltaPBM = 0.0;

    final meteoRowsDisponibles =
        input.meteoRows != null && input.meteoRows!.isNotEmpty;
    final meteoActive = input.meteoOn || meteoRowsDisponibles;

    if (meteoActive && meteoRowsDisponibles) {
      final meteoRow = _meteoRowForLevel(input.meteoRows!, niveauMeteo);
      niveauMeteoEffectif = meteoRow.level as int;

      final metAzMil = (meteoRow.azimutMils as num).toDouble();
      final metVKn = (meteoRow.vKn as num).toDouble();

      // Annexe 1 : composantes du vent.
      final comp = await cService.composantesVent(
        directionVent: metAzMil.round(),
        gisementTir: azimutMil.round(),
      );

      final wxCoef = (comp['wx'] as num).toDouble(); // longitudinal
      final wzCoef = (comp['wz'] as num).toDouble(); // transversal

      final ventLongKn = metVKn * wxCoef;
      final ventTransKn = metVKn * wzCoef;

      // Convention MO81 LLR :
      // - composante longitudinale positive -> correction de portée négative ;
      // - composante transversale positive -> correction de gisement positive.
      wxM = (-ventLongKn.sign * kVent * ventLongKn.abs()).roundToDouble();
      wzMil = (ventTransKn * kWz).roundToDouble();

      // Annexe 2 : correction des valeurs TB / DB du sondage selon ΔZ MDP.
      final deltaAltM = input.meteoStationAltM != null
          ? input.pdZ - input.meteoStationAltM!
          : 0.0;

      final tbPctSondage = (meteoRow.tempPercent as num).toDouble();
      final dTb = await dService.valueTbPctAtAbsDelta(deltaAltM: deltaAltM);
      final tbApplied = deltaAltM < 0 ? -dTb : dTb;
      final tbCorrPct = tbPctSondage + tbApplied;
      final deltaTbPct = tbCorrPct - 100.0;

      deltaTBM = (kTemp * deltaTbPct.abs()).roundToDouble();

      final pressPctSondage = (meteoRow.pressPercent as num).toDouble();
      final pressHpa = pressPctSondage / 100.0 * 1013.25;
      final (_, deltaPressPct) = await dService.pbPercentCorrige(
        pbHpa: pressHpa,
        deltaAltM: deltaAltM,
      );

      deltaPBM = (kPress * deltaPressPct.abs()).roundToDouble();

      _log(
        'MET LN=$niveauMeteoEffectif '
        'WxCoef=${wxCoef.toStringAsFixed(3)} '
        'WzCoef=${wzCoef.toStringAsFixed(3)} '
        'Wx=$wxM m Wz=$wzMil mil '
        'TB=${tbPctSondage.toStringAsFixed(1)}'
        '->${tbCorrPct.toStringAsFixed(1)}% ΔR_TB=$deltaTBM m '
        'DB=${pressPctSondage.toStringAsFixed(1)}% '
        'ΔDB=${deltaPressPct.toStringAsFixed(2)}% ΔR_DB=$deltaPBM m',
      );
    }

    // ---------------------------------------------------------------------
    // 3) T3 : température de poudre -> ΔV0 -> correction de portée.
    //
    // Le champ existant simTempActC est utilisé tant qu'un champ dédié
    // "température poudre actuelle" n'a pas été créé dans CalculInput.
    // À 21 °C, T3 donne par définition la référence 0.
    // ---------------------------------------------------------------------
    final tempPoudreC = input.simTempActC ?? 21.0;
    final deltaVoTemp =
        (await eService.deltaVoTemp(tempPoudreC: tempPoudreC)) ?? 0.0;

    final deltaV0M = (-kV0 * deltaVoTemp).roundToDouble();

    // MO81 OE 81 F2 : correction masse non applicable dans T2.
    const masseM = 0.0;
    const rotxM = 0.0;
    const rotzMil = 0.0;
    const rtcM = 0.0;

    final totalLongM = wxM + deltaTBM + deltaPBM + deltaV0M + masseM;
    final porteeAViser = distanceTopo + totalLongM;

    // ---------------------------------------------------------------------
    // 4) T2 : hausse à la portée corrigée.
    // ---------------------------------------------------------------------
    final hausseT2 = await fService.hausseMil(
          distance: porteeAViser,
          tirMontagne: tirMontagne,
        ) ??
        0.0;

    final tempsVol = await fService.tempageSeconds(
          distance: porteeAViser,
          tirMontagne: tirMontagne,
        ) ??
        0.0;

    // ---------------------------------------------------------------------
    // 5) FINAL : seulement maintenant on applique T1 sur la hausse.
    // ---------------------------------------------------------------------
    final aqeMil = hausseT2 + correctionSiteMil;

    final totalCorrectionAzimutMil = deriveMil + wzMil;

    // Convention MO81 LLR validée sur l'exercice de référence :
    // 5080 + 9 (vent) + 6 (dérive) = 5095.
    final gisementFinalMil = azimutMil + totalCorrectionAzimutMil;

    _log(
      'FINAL Dtopo=${distanceTopo.toStringAsFixed(1)} '
      'ΔR=${totalLongM.toStringAsFixed(1)} '
      'Dviser=${porteeAViser.toStringAsFixed(1)} '
      'hausseT2=${hausseT2.toStringAsFixed(2)} '
      'corrSiteT1=${correctionSiteMil.toStringAsFixed(2)} '
      'AQE=${aqeMil.toStringAsFixed(2)} '
      'az=${azimutMil.toStringAsFixed(0)} '
      '+derive=${deriveMil.toStringAsFixed(0)} '
      '+vent=${wzMil.toStringAsFixed(0)} '
      '=ABG=${gisementFinalMil.toStringAsFixed(0)} '
      '(${sw.elapsedMicroseconds} µs)',
    );

    return CalculResult(
      portee: porteeAViser,
      noireMil: gisementFinalMil,
      charge: charge,
      typeAssets: _variant,
      tempsVolS: tempsVol,
      tempageDetails: null,
      aqeMil: aqeMil,
      deriveMil: deriveMil,
      rotzMilAbs: rotzMil,
      wzMil: wzMil,
      totalCorrectionAzimutMil: totalCorrectionAzimutMil,
      aeMil: hausseT2,

      // Pour le MO81 LLR, le "site" utile est directement la correction T1
      // appliquée à la hausse finale.
      siteBrutMil: 0.0,
      corrSiteVraiMil: correctionSiteMil,
      siteTotalAsMil: correctionSiteMil,
      acsMil: 0.0,

      wxM: wxM,
      rotxM: rotxM,
      masseM: masseM,
      deltaV0M: deltaV0M,
      deltaTBM: deltaTBM,
      deltaPBM: deltaPBM,
      rtcM: rtcM,
      totalLongM: totalLongM,
      latitudePieceDeg: latitudePieceDeg,
      distanceTopoM: distanceTopo,
      azimutMil: azimutMil,
      deniveleeM: deniveleeM,
      correctionSiteBM: correctionSiteMil,
      niveauMeteoBUsed: niveauMeteoEffectif,
      deltaZStationM: input.meteoStationAltM != null
          ? input.pdZ - input.meteoStationAltM!
          : null,
      angleChuteDeg: null,
      cotangenteAngleChute: null,
      ecartProbablePorteeM: null,
      ecartProbableDirectionM: null,
      vitesseRestanteMps: null,
    );
  }
}
