// lib/services/balistique_mo81_llr_eclairant_service.dart
import 'package:flutter/foundation.dart';

import '../models/calcul_data.dart';
import 'mo81_llr_charge_selector.dart';
import 'mo81_llr_oecl_meteo_service.dart';
import 'tableau_c_service.dart';
import 'tableau_d_service.dart' as tableau_d;
import 'tableau_e_service.dart';
import 'tableau_f_service.dart';
import 'tableau_ecl_service.dart';

class BalistiqueMo81LlrEclairantService {
  const BalistiqueMo81LlrEclairantService._();

  static const String _annexe1Path =
      'assets/secure_enc/tableaux/MO81_LLR/Annexe_1/'
      'MO81_LLR_ANNEXE_1.ctbl.gz.enc';

  static const String _annexe2Path =
      'assets/secure_enc/tableaux/MO81_LLR/Annexe_2/'
      'MO81_LLR_ANNEXE_2.dtbl.gz.enc';

  static void _log(String message) {
    if (kDebugMode) debugPrint('[MO81 LLR OECL] $message');
  }

  static bool _isSupportedMunition(TypeMunition? munition) {
    return munition == TypeMunition.oecl81F1 ||
        munition == TypeMunition.oecl81F3 ||
        munition == TypeMunition.oeclIr81F2;
  }

  static String _variantFor(TypeMunition munition) {
    switch (munition) {
      case TypeMunition.oecl81F1:
        return 'MO81_LLR_OECL_81_F1';
      case TypeMunition.oecl81F3:
        return 'MO81_LLR_OECL_81_F3';
      case TypeMunition.oeclIr81F2:
        return 'MO81_LLR_OECL_IR_81_F2';
      default:
        throw StateError(
          'Munition éclairante MO81 LLR non supportée : $munition.',
        );
    }
  }

  static String _normalizeCharge(String raw) {
    final value = raw.trim().toUpperCase().replaceAll(' ', '');
    return value.startsWith('CH') ? value : 'CH$value';
  }

  /// Pour le PROJ 81 IR F2, la doctrine prescrit de choisir la charge
  /// depuis les tableaux ECL, en conditions standard et à dénivelée nulle :
  /// la charge la plus faible dont l'AE est comprise entre 1000 et 1100 mil,
  /// ou à défaut l'AE le plus proche de cette plage.
  static Future<String> _selectIr81F2ChargeFromEcl({
    required TypeMunition munition,
    required double distanceM,
  }) async {
    final variant = _variantFor(munition);
    const charges = <String>['CH1', 'CH2', 'CH3', 'CH4', 'CH5'];
    final candidates = <MapEntry<String, double>>[];

    for (final charge in charges) {
      final service = TableauEclService(
        typeTir: 'OECL',
        charge: charge,
        // Les tables ECL IR F2 ont été normalisées sur la branche false.
        // Cette valeur désigne le sous-tableau de données, sans ajouter de
        // correction de dénivelée.
        tirMontagne: false,
        // Certaines charges IR F2 sont encodées dans la branche opposée.
        // Le service effectue alors un repli contrôlé uniquement si nécessaire.
        allowBranchFallback: munition == TypeMunition.oeclIr81F2,
        verbose: kDebugMode,
        encryptedPathOverride: _eclPath(
          munition: munition,
          variant: variant,
          charge: charge,
        ),
      );

      try {
        // hausseMil() borne volontairement hors tableau pour les calculs
        // historiques. Une charge ne doit toutefois jamais être candidate à
        // la sélection doctrinale si elle ne couvre pas la distance demandée.
        if (!await service.couvrePortee(distanceM: distanceM)) {
          _log(
            'CHARGE ECL $variant D=${distanceM.toStringAsFixed(1)} '
            '$charge hors domaine',
          );
          continue;
        }

        final hausse = await service.hausseMil(distanceM: distanceM);
        candidates.add(MapEntry<String, double>(charge, hausse));
        _log(
          'CHARGE ECL $variant D=${distanceM.toStringAsFixed(1)} '
          '$charge AE=${hausse.toStringAsFixed(2)} mil',
        );
      } catch (error) {
        // Une table absente ne rend pas les autres charges inutilisables.
        _log('CHARGE ECL $variant $charge indisponible : $error');
      }
    }

    if (candidates.isEmpty) {
      throw StateError(
        'MO81 LLR OECL : aucune table ECL exploitable pour '
        '$variant à ${distanceM.toStringAsFixed(0)} m.',
      );
    }

    int chargeNumber(MapEntry<String, double> entry) =>
        int.tryParse(entry.key.substring(2)) ?? 999;

    final inDoctrineWindow = candidates
        .where((entry) => entry.value >= 1000.0 && entry.value <= 1100.0)
        .toList()
      ..sort((a, b) => chargeNumber(a).compareTo(chargeNumber(b)));

    final selected = inDoctrineWindow.isNotEmpty
        ? inDoctrineWindow.first
        : (candidates
              ..sort((a, b) {
                final byDistance = (a.value - 1050.0).abs().compareTo(
                      (b.value - 1050.0).abs(),
                    );
                return byDistance != 0
                    ? byDistance
                    : chargeNumber(a).compareTo(chargeNumber(b));
              }))
            .first;

    _log(
      'CHARGE ECL sélection doctrinale $variant '
      '=> ${selected.key} AE=${selected.value.toStringAsFixed(2)} mil',
    );
    return selected.key;
  }

  static Future<String> _chargeFor(
    CalculInput input, {
    required TypeMunition munition,
    required double distanceM,
  }) async {
    final forced = input.chargeForcee?.trim();

    if (forced != null && forced.isNotEmpty) {
      return _normalizeCharge(forced);
    }

    // Le PROJ 81 IR F2 impose une sélection à partir de l'AE ECL, non
    // depuis le tableau T2. L'exercice de référence donne ainsi CH5 à 3500 m.
    if (munition == TypeMunition.oeclIr81F2) {
      return _selectIr81F2ChargeFromEcl(
        munition: munition,
        distanceM: distanceM,
      );
    }

    final choice = await Mo81LlrChargeSelector.selectForDistance(
      distanceM: distanceM,
      munition: munition,
      verbose: kDebugMode,
    );
    return choice.charge;
  }

  static String _t2Path({
    required TypeMunition munition,
    required String variant,
    required String charge,
  }) {
    final tableId = '${variant}_T2_$charge';

    return 'assets/secure_enc/tableaux/MO81_LLR/T2/'
        '$tableId.ftbl.gz.enc';
  }

  static String _t3Path({
    required TypeMunition munition,
    required String variant,
    required String charge,
  }) {
    final tableId = '${variant}_T3_$charge';

    return 'assets/secure_enc/tableaux/MO81_LLR/T3/'
        '$tableId.etbl.gz.enc';
  }

  static String _eclPath({
    required TypeMunition munition,
    required String variant,
    required String charge,
  }) {
    final tableId = '${variant}_ECL_$charge';

    return 'assets/secure_enc/tableaux/MO81_LLR/ECL/'
        '$tableId.ecltbl.gz.enc';
  }

  static T _meteoRowForLevel<T>(List<T> rows, int niveau) {
    if (rows.isEmpty) {
      throw StateError('MO81 LLR : message météo vide.');
    }

    for (final row in rows) {
      if (((row as dynamic).level as int) == niveau) {
        return row;
      }
    }

    throw StateError(
      'MO81 LLR OECL : ligne météo LN${niveau.toString().padLeft(2, '0')} '
      'absente du message météo.',
    );
  }

  static Future<double> _coef(
    TableauFService service, {
    required double distance,
    required bool tirMontagne,
    required String field,
  }) async {
    return await service.coefficientLongitudinal(
          distance: distance,
          tirMontagne: tirMontagne,
          field: field,
        ) ??
        0.0;
  }

  static Future<CalculResult> calculer(CalculInput input) async {
    if (input.systeme != Systeme.mo81Lrr ||
        input.typeTir != TypeTir.eclairant ||
        !_isSupportedMunition(input.typeMunition)) {
      throw StateError(
        'Pipeline réservé à MO81 LLR / Éclairant '
        '(OECL 81 F1, OECL 81 F3 ou OECL IR 81 F2).',
      );
    }

    final munition = input.typeMunition!;
    final variant = _variantFor(munition);
    final distanceTopo = input.objD;
    final charge = await _chargeFor(
      input,
      munition: munition,
      distanceM: distanceTopo,
    );

    final t2Path = _t2Path(
      munition: munition,
      variant: variant,
      charge: charge,
    );
    final t3Path = _t3Path(
      munition: munition,
      variant: variant,
      charge: charge,
    );
    final eclPath = _eclPath(
      munition: munition,
      variant: variant,
      charge: charge,
    );

    final azimutMil = input.objA;
    final deniveleeM = input.objAlt - input.pdZ;
    final tirMontagne = input.tirMontagne;

    // Les tables ECL MO81, y compris IR F2 après normalisation, sont lues
    // dans la branche standard false. Le mode T2 reste piloté par l'entrée.
    final bool eclTirMontagne = false;

    final latitudePieceDeg = input.pdLatitudeDeg ?? 45.0;

    _log(
      'munition=$munition variant=$variant charge=$charge '
      'D=${distanceTopo.toStringAsFixed(1)} '
      'tirMontagneT2=$tirMontagne '
      'tirMontagneECL=$eclTirMontagne '
      'T2=$t2Path T3=$t3Path ECL=$eclPath',
    );

    final fService = TableauFService(
      typeTir: variant,
      charge: charge,
      verbose: kDebugMode,
      encryptedPathOverride: t2Path,
    );

    final eService = TableauEService(
      typeTir: variant,
      charge: charge,
      verbose: kDebugMode,
      encryptedPathOverride: t3Path,
    );

    final eclService = TableauEclService(
      typeTir: 'OECL',
      charge: charge,
      tirMontagne: eclTirMontagne,
      allowBranchFallback: munition == TypeMunition.oeclIr81F2,
      verbose: kDebugMode,
      encryptedPathOverride: eclPath,
    );

    final dService = tableau_d.TableauDService(
      typeTir: variant,
      verbose: kDebugMode,
      encryptedPath: _annexe2Path,
    );

    // Niveau météo OECL :
    // Dt -> ECL portée sans dépotage -> T2 flèche F à cette portée
    // -> correction Z batterie / Z MDP -> arrondi -> LN.
    final porteeSansDepotageM = await eclService.porteeNonFonctionnementM(
      distanceM: distanceTopo,
    );

    if (porteeSansDepotageM == null) {
      throw StateError(
        'MO81 LLR OECL : portée sans dépotage absente de la table ECL '
        'pour Dt=${distanceTopo.toStringAsFixed(0)} m.',
      );
    }

    final flecheM = await fService.flecheM(
      distance: porteeSansDepotageM,
      tirMontagne: tirMontagne,
    );

    if (flecheM == null) {
      throw StateError(
        'MO81 LLR OECL : flèche F absente du FTBL. '
        'Régénérer le T2 de la munition/charge sélectionnée au format FTBL_V2.',
      );
    }

    final zMdpM = input.meteoStationAltM;
    if (zMdpM == null) {
      throw StateError(
        'MO81 LLR OECL : altitude de la station météo / MDP requise.',
      );
    }

    final meteoSelection = Mo81LlrOeclMeteoService.computeFromTableValues(
      distanceTopoM: distanceTopo,
      porteeSansDepotageM: porteeSansDepotageM,
      flecheM: flecheM,
      zBatterieM: input.pdZ,
      zMdpM: zMdpM,
      verbose: kDebugMode,
    );

    final niveauMeteo = meteoSelection.ligneMeteo;

    final cService = TableauCService(
      typeTir: variant,
      niveauMeteo: niveauMeteo,
      verbose: kDebugMode,
      encryptedPath: _annexe1Path,
    );

    final deriveMil = ((await fService.deriveMil(
              distance: distanceTopo,
              tirMontagne: tirMontagne,
            )) ??
            0.0)
        .roundToDouble();

    // OECL : les coefficients de vent T2 sont lus/interpolés à la portée
    // correspondant au point d'impact en absence de dépotage (ECL),
    // et non à la distance topographique de début d'éclairement.
    final kWz = await fService.correctionWz(
          distance: porteeSansDepotageM,
          tirMontagne: tirMontagne,
        ) ??
        0.0;

    final kVent = await _coef(
      fService,
      distance: porteeSansDepotageM,
      tirMontagne: tirMontagne,
      field: 'correctionVentMoins',
    );

    // OECL : comme pour le vent, les coefficients T2 de température
    // balistique et de densité balistique sont lus/interpolés à la portée
    // correspondant au point d'impact en absence de dépotage.
    final kTemp = await _coef(
      fService,
      distance: porteeSansDepotageM,
      tirMontagne: tirMontagne,
      field: 'correctionTempMoins',
    );

    final kPress = await _coef(
      fService,
      distance: porteeSansDepotageM,
      tirMontagne: tirMontagne,
      field: 'correctionPressionMoins',
    );

    final kV0 = await _coef(
      fService,
      distance: distanceTopo,
      tirMontagne: tirMontagne,
      field: 'correctionV0Moins',
    );

    double wzMil = 0.0; // valeur physique affichée : module de correction Wy/Wz
    double corrVentGisementMil = 0.0; // valeur algébrique appliquée à la noire
    double wxM = 0.0;
    double deltaTBM = 0.0;
    double deltaPBM = 0.0;
    var niveauMeteoEffectif = niveauMeteo;

    final meteoRowsDisponibles =
        input.meteoRows != null && input.meteoRows!.isNotEmpty;
    final meteoActive = input.meteoOn || meteoRowsDisponibles;

    if (meteoActive && meteoRowsDisponibles) {
      final meteoRow = _meteoRowForLevel(input.meteoRows!, niveauMeteo);
      niveauMeteoEffectif = meteoRow.level as int;

      final metAzMil = (meteoRow.azimutMils as num).toDouble();
      final metVKn = (meteoRow.vKn as num).toDouble();

      final comp = await cService.composantesVent(
        directionVent: metAzMil.round(),
        gisementTir: azimutMil.round(),
      );

      // L'annexe 1 fournit les modules des composantes unitaires.
      // Le sens est déduit de l'angle vent/tir :
      //   longitudinal : A (avant) / W (arrière)
      //   transversal : D (droite) / G (gauche)
      //
      // On arrondit d'abord chaque composante balistique au 1/10 kn,
      // puis on applique le coefficient T2 interpolé à
      // porteeSansDepotageM.
      final wxUnitaire = ((comp['wx'] as num).toDouble()).abs();
      final wyUnitaire = ((comp['wz'] as num).toDouble()).abs();

      final angleVentTir =
          (((metAzMil.round() - azimutMil.round()) % 6400) + 6400) % 6400;

      final bool wxNul = angleVentTir == 1600 || angleVentTir == 4800;
      final bool wyNul = angleVentTir == 0 || angleVentTir == 3200;

      final bool ventArriere =
          !wxNul && angleVentTir > 1600 && angleVentTir < 4800;
      final bool ventAvant = !wxNul && !ventArriere;

      // Pour l'angle 3800 mil de l'exemple de référence :
      // Wy est dirigé de gauche vers droite => correction G.
      final bool correctionGauche =
          !wyNul && angleVentTir > 3200 && angleVentTir < 6400;
      final bool correctionDroite = !wyNul && !correctionGauche;

      double arrondiDixieme(double value) =>
          double.parse(value.toStringAsFixed(1));

      final wxKn = wxNul ? 0.0 : arrondiDixieme(wxUnitaire * metVKn);
      final wyKn = wyNul ? 0.0 : arrondiDixieme(wyUnitaire * metVKn);

      // Sens des corrections issu de la définition A/W et G/D :
      //   W -> correction de portée négative
      //   A -> correction de portée positive
      //   G -> correction de gisement positive
      //   D -> correction de gisement négative
      final wxAbsM = (wxKn * kVent.abs()).roundToDouble();
      final wyAbsMil = (wyKn * kWz.abs()).roundToDouble();

      wxM = wxNul
          ? 0.0
          : ventArriere
              ? -wxAbsM
              : wxAbsM;

      // wzMil reste la valeur physique affichée (module), accompagnée du sens G/D.
      // La traduction algébrique vers la noire est séparée :
      //   G => diminution du gisement
      //   D => augmentation du gisement
      wzMil = wyNul ? 0.0 : wyAbsMil;
      corrVentGisementMil = wyNul
          ? 0.0
          : correctionGauche
              ? -wyAbsMil
              : wyAbsMil;

      final sensWx = wxNul
          ? '-'
          : ventArriere
              ? 'W'
              : 'A';
      final sensWy = wyNul
          ? '-'
          : correctionGauche
              ? 'G'
              : 'D';

      _log(
        'VENT angle=$angleVentTir '
        'Wx1=${wxUnitaire.toStringAsFixed(2)} '
        'Wy1=${wyUnitaire.toStringAsFixed(2)} '
        'V=${metVKn.toStringAsFixed(1)}kn '
        'Wx=${wxKn.toStringAsFixed(1)}kn($sensWx) '
        'Wy=${wyKn.toStringAsFixed(1)}kn($sensWy) '
        'kVent@${porteeSansDepotageM.toStringAsFixed(0)}='
        '${kVent.toStringAsFixed(2)} '
        'kWz@${porteeSansDepotageM.toStringAsFixed(0)}='
        '${kWz.toStringAsFixed(2)} '
        '=> dR_Wx=${wxM.toStringAsFixed(0)}m '
        'dG_Wy=${wzMil.toStringAsFixed(0)}mil($sensWy) '
        'corrNoire=${corrVentGisementMil.toStringAsFixed(0)}mil',
      );

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
        'Dimpact=${porteeSansDepotageM.toStringAsFixed(0)} '
        'F=${flecheM.toStringAsFixed(0)} '
        'Fcorr=${meteoSelection.flecheCorrigeeM.toStringAsFixed(0)} '
        'V=${metVKn.toStringAsFixed(1)}kn '
        'angle=$angleVentTir '
        'Wx=${wxM.toStringAsFixed(0)} m '
        'Wy=${wzMil.toStringAsFixed(0)} mil '
        'TB=${tbPctSondage.toStringAsFixed(1)}'
        '->${tbCorrPct.toStringAsFixed(1)}% ΔR_TB=$deltaTBM m '
        'DB=${pressPctSondage.toStringAsFixed(1)}% '
        'ΔDB=${deltaPressPct.toStringAsFixed(2)}% ΔR_DB=$deltaPBM m',
      );
    }

    final tempPoudreC = input.simTempActC ?? 21.0;
    final deltaVoTemp =
        (await eService.deltaVoTemp(tempPoudreC: tempPoudreC)) ?? 0.0;
    final deltaV0M = (-kV0 * deltaVoTemp).roundToDouble();

    final totalLongM = wxM + deltaTBM + deltaPBM + deltaV0M;
    final porteeAViser = distanceTopo + totalLongM;

    final aeMil = await eclService.hausseMil(distanceM: porteeAViser);

    final tempageNominal = await eclService.tempageS(distanceM: porteeAViser);

    if (tempageNominal == null) {
      throw StateError(
        'MO81 LLR OECL : tempage DM183 F absent de la table ECL.',
      );
    }

    final corrEclPour50mMil = await eclService.corrHaussePar50mMil(
      distanceM: porteeAViser,
    );

    final corrTempagePour50mS = await eclService.corrTempagePar50mS(
      distanceM: porteeAViser,
    );

    // Pas de T1 en éclairant.
    // Les coefficients ECL sont appliqués directement "par 50 m".
    final facteurDeniveleeEcl = deniveleeM / 50.0;
    final corrHausseDeniveleeMil = corrEclPour50mMil * facteurDeniveleeEcl;
    final corrTempageDeniveleeBrutS = corrTempagePour50mS * facteurDeniveleeEcl;

    // Exemple officiel : arrondi de la correction de tempage au 1/10 s
    // avant application au tempage nominal.
    final corrTempageDeniveleeS =
        (corrTempageDeniveleeBrutS * 10.0).roundToDouble() / 10.0;

    final aqeMil = aeMil + corrHausseDeniveleeMil;
    // OECL : il s'agit du tempage final de la fusée, pas d'un temps de vol.
    final tempageFinalS = tempageNominal + corrTempageDeniveleeS;

    // Les tableaux MO81 IR fournissent le nominal ECL et la correction liée
    // à la hauteur d'éclairement. Ils ne fournissent pas de corrections
    // temporelles distinctes vent/TB/PB/V0 : ces éléments restent donc nuls
    // dans le détail de tempage, sans être reconstruits depuis la portée.
    final tempageDetails = TempageDetails(
      tNominal: tempageNominal,
      deltaTvent: 0.0,
      deltaTTb: 0.0,
      deltaTPb: 0.0,
      deltaTV0: 0.0,
      deltaTMun: 0.0,
      deltaTMasse: 0.0,
      deltaTEvent50m: corrTempagePour50mS,
      deltaTDenivelee: corrTempageDeniveleeS,
      tFusee: tempageFinalS,
    );

    const rotzMil = 0.0;

    // Correction latérale finale :
    // - wzMil conserve le module affiché (ex. 17 mil G)
    // - corrVentGisementMil est la valeur algébrique réellement appliquée
    //   au gisement (G = -, D = +).
    final totalCorrectionAzimutMil = deriveMil + corrVentGisementMil + rotzMil;

    // Normalisation dans l'intervalle [0, 6400).
    final gisementFinalMil =
        ((azimutMil + totalCorrectionAzimutMil) % 6400.0 + 6400.0) % 6400.0;

    _log(
      'TEMPAGE DM183 F '
      'DT=${porteeAViser.toStringAsFixed(0)} '
      'nominal=${tempageNominal.toStringAsFixed(2)}s '
      'corr50=${corrTempagePour50mS.toStringAsFixed(2)}s '
      'dz=${deniveleeM.toStringAsFixed(0)}m '
      'corrDzBrut=${corrTempageDeniveleeBrutS.toStringAsFixed(2)}s '
      'corrDz=${corrTempageDeniveleeS.toStringAsFixed(1)}s '
      'final=${tempageFinalS.toStringAsFixed(1)}s',
    );

    _log(
      'charge=$charge D=${distanceTopo.toStringAsFixed(1)} '
      'Dviser=${porteeAViser.toStringAsFixed(1)} '
      'hausseECL=${aeMil.toStringAsFixed(2)} '
      'AQE=${aqeMil.toStringAsFixed(2)} '
      'tempage=${tempageFinalS.toStringAsFixed(2)} '
      'derive=${deriveMil.toStringAsFixed(0)} '
      'Wz=${wzMil.toStringAsFixed(0)} '
      'corrVentGis=${corrVentGisementMil.toStringAsFixed(0)} '
      'noire=${gisementFinalMil.toStringAsFixed(0)} '
      'Wx=${wxM.toStringAsFixed(0)} '
      'dTB=${deltaTBM.toStringAsFixed(0)} '
      'dPB=${deltaPBM.toStringAsFixed(0)} '
      'dV0=${deltaV0M.toStringAsFixed(0)}',
    );

    return CalculResult(
      portee: porteeAViser,
      noireMil: gisementFinalMil,
      charge: charge,
      typeAssets: variant,
      // Champ historique conservé pour compatibilité avec CalculResult/UI.
      // En OECL, cette valeur représente le tempage.
      tempsVolS: tempageFinalS,
      tempageDetails: tempageDetails,
      aqeMil: aqeMil,
      deriveMil: deriveMil,
      rotzMilAbs: rotzMil,
      wzMil: wzMil,
      totalCorrectionAzimutMil: totalCorrectionAzimutMil,
      aeMil: aeMil,
      siteBrutMil: 0.0,
      corrSiteVraiMil: 0.0,
      siteTotalAsMil: 0.0,
      acsMil: 0.0,
      wxM: wxM,
      rotxM: 0.0,
      masseM: 0.0,
      deltaV0M: deltaV0M,
      deltaTBM: deltaTBM,
      deltaPBM: deltaPBM,
      rtcM: 0.0,
      totalLongM: totalLongM,
      corrEclPour50mMil: corrEclPour50mMil,
      corrEclDeniveleeMil: corrHausseDeniveleeMil,
      latitudePieceDeg: latitudePieceDeg,
      distanceTopoM: distanceTopo,
      azimutMil: azimutMil,
      deniveleeM: deniveleeM,
      correctionSiteBM: 0.0,
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
