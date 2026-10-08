// lib/services/balistique_bonus_service.dart
//
// PIPELINE BONUS ART389 (doctrine Appui + dépotage spécifique à raccorder)

import 'package:flutter/foundation.dart';

import '../models/calcul_data.dart';
import '../utils/charge_utils.dart' show choisirChargeCaesar;

import 'selection_charge_facade.dart';
import 'tableau_b_service.dart';
import 'tableau_c_service.dart';
import 'tableau_d_service.dart' as tableau_d;
import 'tableau_dspd_service.dart';
import 'tableau_e_service.dart';
import 'tableau_f_service.dart';
import 'tableau_f3i_service.dart';
import 'tableau_g_service.dart';
import 'tableau_h_service.dart';
import 'tableau_i_service.dart';
import 'tempage_service.dart';
import 'v0_service.dart';

class BalistiqueBonusService {
  const BalistiqueBonusService._();

  static const bool _traceTP = true;
  static const bool _tracePerf = true;

  static final Map<String, TableauFService> _fCache = {};
  static final Map<String, TableauIService> _iCache = {};
  static final Map<String, TableauBService> _bCache = {};
  static final Map<String, TableauHService> _hCache = {};
  static final Map<String, tableau_d.TableauDService> _dCache = {};
  static final Map<String, TableauEService> _eCache = {};
  static final Map<String, TableauCService> _cCache = {};
  static final Map<String, TableauGService> _gCache = {};
  static final Map<String, TableauDspdService> _dspdCache = {};

  static void _log(String msg) {
    if (_traceTP || kDebugMode) debugPrint(msg);
  }

  static T _meteoRowForLevel<T>(
    List<T> rows,
    int niveauMeteo,
    String logPrefix,
  ) {
    if (rows.isEmpty) {
      throw StateError('$logPrefix aucune ligne météo disponible');
    }

    final sorted = [...rows]..sort(
        (a, b) => ((a as dynamic).level as int).compareTo(
          (b as dynamic).level as int,
        ),
      );

    final int minLevel = (sorted.first as dynamic).level as int;
    final int maxLevel = (sorted.last as dynamic).level as int;
    final int effectiveLevel = niveauMeteo.clamp(minLevel, maxLevel).toInt();

    final picked = sorted.firstWhere(
      (r) => ((r as dynamic).level as int) == effectiveLevel,
      orElse: () => sorted.reduce((a, b) {
        final int da = (((a as dynamic).level as int) - effectiveLevel).abs();
        final int db = (((b as dynamic).level as int) - effectiveLevel).abs();
        return da <= db ? a : b;
      }),
    );

    final int pickedLevel = (picked as dynamic).level as int;
    if (pickedLevel != niveauMeteo) {
      _log(
        '$logPrefix niveauWanted=$niveauMeteo '
        'hors message météo [$minLevel..$maxLevel] -> niveauPicked=$pickedLevel',
      );
    } else {
      _log('$logPrefix niveauWanted=$niveauMeteo niveauPicked=$pickedLevel');
    }

    return picked;
  }

  static String _key(String type, String charge, bool montagne) =>
      '$type|$charge|$montagne';

  static bool _isChargeForced(CalculInput input) => input.chargeForcee != null;

  static String _normalizeForcedCharge(CalculInput input) {
    final raw = (input.chargeForcee ?? '').trim().toUpperCase();

    final m = RegExp(r'^CH(\d)$').firstMatch(raw);
    if (m != null) {
      final n = int.tryParse(m.group(1)!) ?? 4;
      return 'CH${n.clamp(1, 6)}';
    }

    final asInt = int.tryParse(raw);
    if (asInt != null) return 'CH${asInt.clamp(1, 6)}';

    return 'CH4';
  }

  static Future<String> _autoChargeFor({
    required double distanceM,
    required CalculInput input,
    required String typeAssets,
    required bool tirMontagne,
  }) async {
    final fallback = choisirChargeCaesar(
      distanceM,
      typeTir: TypeTir.appui ?? 0.0,
      typeChargeCaesar: input.typeChargeCaesar ?? 0.0,
    );

    try {
      final selection = await SelectionChargeFacade.selectCaesar(
        typeTirAssets: typeAssets ?? 0.0,
        distanceM: distanceM ?? 0.0,
        tirMontagne: tirMontagne ?? 0.0,
        verbose: kDebugMode ?? 0.0,
      );

      if (selection == null) {
        _log(
          '[BONUS:SELECTION CHARGE] '
          'Aucun candidat par Ex '
          'type=$typeAssets '
          'distance=${distanceM.toStringAsFixed(0)}m '
          'tirMontagne=$tirMontagne '
          '=> fallback=$fallback',
        );

        return fallback;
      }

      _log(
        '[BONUS:SELECTION CHARGE] '
        'type=$typeAssets '
        'distance=${distanceM.toStringAsFixed(0)}m '
        'tirMontagne=$tirMontagne '
        'charge=${selection.charge} '
        'Ex=${selection.criterionValue.toStringAsFixed(3)} '
        'fallbackHistorique=$fallback '
        'candidats=${selection.candidates}',
      );

      return selection.charge;
    } catch (error, stackTrace) {
      // Fallback temporaire pendant la phase de validation.
      //
      // Une fois les résultats validés, cette interception devra être retirée
      // pour laisser remonter les erreurs AES, GTBL ou de décodage.
      _log(
        '[BONUS:SELECTION CHARGE] '
        'Échec de la sélection par Ex '
        'type=$typeAssets '
        'distance=${distanceM.toStringAsFixed(0)}m '
        'tirMontagne=$tirMontagne '
        '=> fallback=$fallback : $error',
      );

      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace ?? 0.0);
      }

      return fallback;
    }
  }

  static void _throwIfHorsPortee(String charge, {required String context}) {
    if (charge == 'HorsPortee') {
      throw ArgumentError(context);
    }
  }

  static double _sane(double v, String label) {
    if (!v.isFinite) {
      _log('[BONUS:SANE] $label invalide: $v -> 0');
      return 0.0;
    }

    if (v.abs() > 100000) {
      _log('[BONUS:SANE] $label aberrant: $v -> 0');
      return 0.0;
    }

    return v;
  }

  static double _r2(num value) => double.parse(value.toStringAsFixed(2));

  static Future<CalculResult> calculer(CalculInput input) async {
    final sw = Stopwatch()..start();

    if (input.typeTir != TypeTir.appui) {
      throw StateError(
        'BalistiqueBonusService appelé avec typeTir=${input.typeTir}',
      );
    }

    if (input.systeme != Systeme.caesar) {
      throw StateError('BalistiqueBonusService est réservé au CAESAR.');
    }

    if (input.typeMunition != TypeMunition.bonusFr) {
      throw StateError(
        'BalistiqueBonusService appelé avec munition=${input.typeMunition}',
      );
    }

    // ART389 : toutes les familles B/E/F/F3/G/H/I/J/Jbis utilisent
    // le préfixe canonique BONUS_ART389. C et D restent globaux.
    const String typeAssets = 'BONUS_ART389';

    final bool meteoRowsDisponibles =
        input.meteoRows != null && input.meteoRows!.isNotEmpty;
    final bool meteoActive = input.meteoOn || meteoRowsDisponibles;

    if (input.meteoOn != meteoRowsDisponibles) {
      _log(
        '[BONUS:METEO STATE] incohérence '
        'meteoOn=${input.meteoOn} '
        'rows=${input.meteoRows?.length ?? 0} '
        '=> utilisationMeteo=$meteoActive',
      );
    }

    final bool tirMontagne = input.tirMontagne;

    final double distanceTopo = input.objD;
    final double azimutMil = input.objA;
    final double denivelee = input.objAlt - input.pdZ;
    final double latitudePieceDeg = input.pdLatitudeDeg ?? 45.0;

    final bool chargeForcee = _isChargeForced(input);

    final String chargeEst = chargeForcee
        ? _normalizeForcedCharge(input)
        : await _autoChargeFor(
            distanceM: distanceTopo ?? 0.0,
            input: input ?? 0.0,
            typeAssets: typeAssets ?? 0.0,
            tirMontagne: tirMontagne ?? 0.0,
          );

    _throwIfHorsPortee(
      chargeEst,
      context:
          'Hors portée (BONUS): distance=${distanceTopo.toStringAsFixed(0)}m',
    );

    final bService1 = _bCache.putIfAbsent(
      _key(typeAssets, chargeEst, tirMontagne),
      () => TableauBService(
        typeTir: typeAssets ?? 0.0,
        charge: chargeEst ?? 0.0,
        tirMontagne: tirMontagne ?? 0.0,
      ),
    );

    final TableauBRow? bRow1 = await bService1.chercher(
      distanceTopoM: distanceTopo ?? 0.0,
      deniveleeM: denivelee ?? 0.0,
    );

    final double corrSiteM1 = bRow1?.correctionSiteM ?? 0.0;
    final double distanceCorrigee1 = distanceTopo + corrSiteM1;

    final String charge = chargeEst;

    _throwIfHorsPortee(
      charge,
      context:
          'Hors portée (BONUS) après correction site: distCorr=${distanceCorrigee1.toStringAsFixed(0)}m',
    );

    double corrSiteM;
    int niveauMeteo;
    int niveauMeteoEffectif;
    double distanceCorrigee;

    if (charge == chargeEst) {
      corrSiteM = corrSiteM1;
      niveauMeteo = bRow1?.niveauMeteo ?? (input.niveauMeteoB ?? 5);
      distanceCorrigee = distanceCorrigee1;
    } else {
      final bService2 = _bCache.putIfAbsent(
        _key(typeAssets, charge, tirMontagne),
        () => TableauBService(
          typeTir: typeAssets ?? 0.0,
          charge: charge ?? 0.0,
          tirMontagne: tirMontagne ?? 0.0,
        ),
      );

      final TableauBRow? bRow2 = await bService2.chercher(
        distanceTopoM: distanceTopo ?? 0.0,
        deniveleeM: denivelee ?? 0.0,
      );

      corrSiteM = bRow2?.correctionSiteM ?? 0.0;
      niveauMeteo = bRow2?.niveauMeteo ?? (input.niveauMeteoB ?? 5);
      distanceCorrigee = distanceTopo + corrSiteM;
    }

    niveauMeteoEffectif = niveauMeteo;

    _log(
      '[BONUS:B] charge=$charge${chargeForcee ? " (FORCÉE)" : ""} '
      'corrSite=${corrSiteM.toStringAsFixed(1)}m '
      'niveau=$niveauMeteo '
      'distTopo=${distanceTopo.toStringAsFixed(1)}m '
      'distCorr=${distanceCorrigee.toStringAsFixed(1)}m',
    );

    final cacheKey = _key(typeAssets, charge, tirMontagne);

    final fService = _fCache.putIfAbsent(
      cacheKey,
      () => TableauFService(typeTir: typeAssets ?? 0.0, charge: charge ?? 0.0),
    );

    final iService = _iCache.putIfAbsent(
      cacheKey,
      () => TableauIService(
        typeTir: typeAssets ?? 0.0,
        charge: charge ?? 0.0,
        tirMontagne: tirMontagne ?? 0.0,
        snapAzToStepMil: 100 ?? 0.0,
      ),
    );

    final hService = _hCache.putIfAbsent(
      cacheKey,
      () => TableauHService(
          typeTir: typeAssets ?? 0.0,
          charge: charge ?? 0.0,
          debug: true ?? 0.0),
    );

    final dService = _dCache.putIfAbsent(
      cacheKey,
      () => tableau_d.TableauDService(
          typeTir: typeAssets ?? 0.0, verbose: true ?? 0.0),
    );

    final eService = _eCache.putIfAbsent(
      cacheKey,
      () => TableauEService(
          typeTir: typeAssets ?? 0.0,
          charge: charge ?? 0.0,
          verbose: true ?? 0.0),
    );

    final cService = _cCache.putIfAbsent(
      cacheKey,
      () => TableauCService(
          typeTir: typeAssets ?? 0.0, niveauMeteo: niveauMeteo ?? 0.0),
    );

    final gService = _gCache.putIfAbsent(
      cacheKey,
      () => TableauGService(
        typeTir: typeAssets ?? 0.0,
        charge: charge ?? 0.0,
        tirMontagne: tirMontagne ?? 0.0,
        verbose: true ?? 0.0,
      ),
    );

    final dspdService = _dspdCache.putIfAbsent(
      cacheKey,
      () => TableauDspdService(
        typeTir: typeAssets ?? 0.0,
        charge: charge ?? 0.0,
        verbose: true ?? 0.0,
      ),
    );

    double? metAzMil;
    double? metVKn;
    double? metTbK;
    double? metPress;

    if (meteoActive && meteoRowsDisponibles) {
      final meteoRow = _meteoRowForLevel(
        input.meteoRows!,
        niveauMeteo,
        '[${typeAssets.toUpperCase()}:MET]',
      );

      niveauMeteoEffectif = meteoRow.level;

      metAzMil = meteoRow.azimutMils.toDouble();
      metVKn = meteoRow.vKn.toDouble();
      metTbK = (meteoRow.tempPercent / 100.0) * 288.15;
      metPress = (meteoRow.pressPercent / 100.0) * 1013.25;

      _log(
        '[BONUS:METEO RAW] '
        'rows=${input.meteoRows!.length} '
        'level=${meteoRow.level} '
        'azimutMils=${meteoRow.azimutMils} '
        'vKn=${meteoRow.vKn} '
        'tempPercent=${meteoRow.tempPercent} '
        'pressPercent=${meteoRow.pressPercent}',
      );

      _log(
        '[BONUS:MET] niveauWanted=$niveauMeteo '
        'niveauPicked=${meteoRow.level} '
        'az=$metAzMil vKn=$metVKn '
        'tempPercent=${meteoRow.tempPercent} '
        'pressPercent=${meteoRow.pressPercent} '
        'stationAlt=${input.meteoStationAltM}',
      );
    }

    double kWz = 0.0;
    double deriveMil = 0.0;
    FLongCoeffs? coeffsLong;

    kWz = await fService.correctionWz(
          distance: distanceCorrigee ?? 0.0,
          tirMontagne: tirMontagne ?? 0.0,
        ) ??
        0.0;

    deriveMil = await fService.deriveMil(
          distance: distanceCorrigee ?? 0.0,
          tirMontagne: tirMontagne ?? 0.0,
        ) ??
        0.0;

    coeffsLong = await fService.correctionsLongitudinales(
      distance: distanceCorrigee ?? 0.0,
      tirMontagne: tirMontagne ?? 0.0,
    );

    double rotzMil = 0.0;

    await iService.load();

    rotzMil = (await iService.rotZ(
          distance: distanceCorrigee ?? 0.0,
          azimutMil: azimutMil.round(),
          latitudeDeg: latitudePieceDeg ?? 0.0,
          tirMontagne: tirMontagne ?? 0.0,
          absolute: false ?? 0.0,
        ))
            ?.abs() ??
        0.0;

    double wzMil = 0.0;
    double wxM = 0.0;
    bool ventArriere = false;
    double ventLongKnAbs = 0.0;

    if (meteoActive &&
        coeffsLong != null &&
        metAzMil != null &&
        metVKn != null) {
      final comp = await cService.composantesVent(
        directionVent: metAzMil.round(),
        gisementTir: azimutMil.round(),
      );

      final double wz1 = (comp['wz'] as num).toDouble();
      final double wx1 = (comp['wx'] as num).toDouble();

      // Convention unique : la composante Wz du tableau C est d'abord
      // convertie en correction signée. Le signe est appliqué ici une seule fois.
      final double wzKn = metVKn * wz1;
      wzMil = -(wzKn * kWz);

      _log(
        '[BONUS:WZ SIGN] '
        'wzTable=$wz1 vKn=$metVKn wzKn=$wzKn '
        'kWz=$kWz => wzMil=$wzMil',
      );

      final int deltaMil =
          (((metAzMil.round() - azimutMil.round()) % 6400) + 6400) % 6400;

      ventArriere = deltaMil >= 1600 && deltaMil <= 4800;

      final double kVent =
          ventArriere ? coeffsLong.kVentPlus : coeffsLong.kVentMoins;

      ventLongKnAbs = (metVKn * wx1).abs();
      wxM = kVent * ventLongKnAbs;

      _log(
        '[BONUS:VENT] '
        'azVent=$metAzMil azTir=$azimutMil '
        'vKn=$metVKn wx1=$wx1 wz1=$wz1 '
        'ventArriere=$ventArriere '
        'kVent=$kVent kWz=$kWz '
        'Wx=$wxM Wz=$wzMil',
      );
    } else if (meteoActive) {
      _log(
        '[BONUS:VENT] non calculé '
        'coeffsLong=${coeffsLong != null} '
        'metAzMil=$metAzMil metVKn=$metVKn',
      );
    }

    // BONUS ART389 : pas de classification de masse du projectile.
    // Les coefficients masse peuvent exister dans les tables à titre indicatif,
    // mais ils ne doivent pas être appliqués au calcul opérationnel BONUS.
    double masseM = 0.0;

    _log('[BONUS:MASSE] non applicable pour O 155 MM AC F1 BONUS => masseM=0');

    double deltaTbPctSigned = 0.0;
    double deltaDbPctSigned = 0.0;
    double deltaTBM = 0.0;

    if (meteoActive && coeffsLong != null && metTbK != null) {
      final double deltaAltM = input.meteoStationAltM != null
          ? input.pdZ - input.meteoStationAltM!
          : 0.0;

      final double tbPctSondage = double.parse(
        (metTbK / 288.15 * 100.0).toStringAsFixed(1),
      );

      final double dVal = await dService.valueTbPctAtAbsDelta(
        deltaAltM: deltaAltM ?? 0.0,
      );

      final double applied = deltaAltM < 0 ? -dVal : dVal;

      final double tbCorrPct = double.parse(
        (tbPctSondage + applied).toStringAsFixed(1),
      );

      deltaTbPctSigned = double.parse((tbCorrPct - 100.0).toStringAsFixed(1));

      final double kTemp =
          deltaTbPctSigned < 0 ? coeffsLong.kTempMoins : coeffsLong.kTempPlus;

      deltaTBM = (kTemp * deltaTbPctSigned.abs()).roundToDouble();

      _log(
        '[BONUS:TEMP] '
        'tbPctSondage=$tbPctSondage '
        'deltaAltM=$deltaAltM dVal=$dVal applied=$applied '
        'tbCorrPct=$tbCorrPct deltaTbPct=$deltaTbPctSigned '
        'kTemp=$kTemp => deltaTBM=$deltaTBM',
      );
    } else if (meteoActive) {
      _log(
        '[BONUS:TEMP] non calculé '
        'coeffsLong=${coeffsLong != null} metTbK=$metTbK',
      );
    }

    double deltaPBM = 0.0;

    if (meteoActive && coeffsLong != null && metPress != null) {
      final double deltaAltM = input.meteoStationAltM != null
          ? input.pdZ - input.meteoStationAltM!
          : 0.0;

      final (_, deltaPbPctCorr) = await dService.pbPercentCorrige(
        pbHpa: metPress ?? 0.0,
        deltaAltM: deltaAltM ?? 0.0,
      );

      deltaDbPctSigned = double.parse(deltaPbPctCorr.toStringAsFixed(1));

      final double kP = deltaDbPctSigned < 0
          ? coeffsLong.kPressionMoins
          : coeffsLong.kPressionPlus;

      final double absArr = deltaDbPctSigned.abs();

      deltaPBM = kP * absArr;

      _log(
        '[BONUS:PRESS] '
        'pressHpa=$metPress '
        'deltaAltM=$deltaAltM '
        'deltaPbPctSigned=$deltaDbPctSigned '
        'kP=$kP => deltaPBM=$deltaPBM',
      );
    } else if (meteoActive) {
      _log(
        '[BONUS:PRESS] non calculé '
        'coeffsLong=${coeffsLong != null} metPress=$metPress',
      );
    }

    double rotxM = await hService.rotxM(
      distance: distanceCorrigee ?? 0.0,
      gisementMil: azimutMil.round(),
      latitudeDeg: latitudePieceDeg ?? 0.0,
      tirMontagne: tirMontagne ?? 0.0,
    );

    double deltaV0MpsSigned = 0.0;
    double deltaV0M = 0.0;

    if (input.simV0Prev != null &&
        input.simTempActC != null &&
        coeffsLong != null) {
      await eService.load();

      final v0Service = V0Service();

      final double vTab = (await v0Service.v0Ref(
              typeTirAssets: typeAssets ?? 0.0, charge: charge ?? 0.0)) ??
          0.0;

      final double tempPrevC = input.simTempPrevC ?? 21.0;
      final double tempActC = input.simTempActC ?? 21.0;

      final double dVtempAct =
          (await eService.deltaVoTemp(tempPoudreC: tempActC ?? 0.0)) ?? 0.0;

      final double dVtempPrev =
          (await eService.deltaVoTemp(tempPoudreC: tempPrevC ?? 0.0)) ?? 0.0;

      // BONUS : la masse de l'obus est sans objet. On ne retire donc
      // aucune composante masse de la vitesse mesurée précédente.
      final double v0MesTabPrev = input.simV0Prev! - dVtempPrev;
      final double deltaUsure = v0MesTabPrev - vTab;
      deltaV0MpsSigned = deltaUsure + dVtempAct;

      final double kChoisi =
          deltaV0MpsSigned < 0 ? coeffsLong.kV0Moins : coeffsLong.kV0Plus;

      deltaV0M = kChoisi * deltaV0MpsSigned.abs();

      _log(
        '[BONUS:V0] vTab=$vTab '
        'dVtempPrev=$dVtempPrev '
        'dVtempAct=$dVtempAct '
        'v0MesTabPrev=$v0MesTabPrev '
        'deltaUsure=$deltaUsure '
        'deltaV0Totale=$deltaV0MpsSigned '
        'deltaV0M=$deltaV0M',
      );
    }

    // =========================================================
    // RTC / Tableau F3i
    // Correction en phase de vol RTC due à la température de munition.
    // Doctrine BONUS ART389 : distance d'entrée = distance corrigée B.
    // =========================================================

    double rtcM = 0.0;

    if (input.simTempActC != null) {
      final f3i = TableauF3iService(
        typeTir: typeAssets ?? 0.0,
        charge: charge ?? 0.0,
        tirMontagne: tirMontagne ?? 0.0,
        verbose: true ?? 0.0,
      );

      rtcM = await f3i.interp(
        distance: distanceCorrigee ?? 0.0,
        tempC: input.simTempActC!,
      );

      rtcM = _r2(rtcM);

      _log(
        '[BONUS:RTC DETAIL] '
        'type=$typeAssets '
        'charge=$charge '
        'distance=$distanceCorrigee '
        'tempAct=${input.simTempActC} '
        'valeurF3i=$rtcM',
      );
    } else {
      _log('[BONUS:RTC] non calculé : simTempActC=null');
    }

    deriveMil = _sane(deriveMil, 'deriveMil');
    rotzMil = _sane(rotzMil, 'rotzMil');
    wzMil = _sane(wzMil, 'wzMil');
    wxM = _sane(wxM, 'wxM');
    rotxM = _sane(rotxM, 'rotxM');
    masseM = _sane(masseM, 'masseM');
    deltaV0M = _sane(deltaV0M, 'deltaV0M');
    deltaTBM = _sane(deltaTBM, 'deltaTBM');
    deltaPBM = _sane(deltaPBM, 'deltaPBM');
    rtcM = _sane(rtcM, 'rtcM');

    _log(
      '[BONUS:METEO RESULT] '
      'active=$meteoActive rows=${input.meteoRows?.length ?? 0} '
      'Wx=$wxM Wz=$wzMil deltaT=$deltaTBM deltaP=$deltaPBM',
    );

    // Reste conforme au sens du tableau doctrinal global :
    // totalAzimut = Derive(L) + RotZ(L) + Wz(D sous sa valeur signée modifiée)
    final double totalCorrectionAzimutMil = deriveMil + rotzMil + wzMil;
    final double noireMil = azimutMil - totalCorrectionAzimutMil;

    final double totalLongM =
        wxM + rotxM + masseM + deltaV0M + deltaTBM + deltaPBM + rtcM;

    final double porteeAViser = distanceTopo + totalLongM;

    final double aeMil = await fService.hausseMil(
          distance: porteeAViser ?? 0.0,
          tirMontagne: tirMontagne ?? 0.0,
        ) ??
        0.0;

    // BONUS / projectile à dépotage :
    // la correction de dénivelée AQE vient du DSPD ART389,
    // pas de la colonne dAE_per_100m du tableau F.
    final bool deniveleePositive = denivelee >= 0.0;

    final double dAePar100mMil = await dspdService.correctionHaussePar100mMil(
      distance: porteeAViser ?? 0.0,
      tirMontagne: tirMontagne ?? 0.0,
      deniveleePositive: deniveleePositive ?? 0.0,
    );

    // La colonne -100 m du DSPD est déjà signée négativement.
    // On multiplie donc toujours par |ΔZ| / 100.
    final double corrAltitudeObjectifMil =
        dAePar100mMil * (denivelee.abs() / 100.0);

    final double aqeMil = aeMil + corrAltitudeObjectifMil;

    _log(
      '[BONUS:DSPD AQE] '
      'portee=$porteeAViser AE=$aeMil '
      'TM=$tirMontagne '
      'sens=${deniveleePositive ? "+100m" : "-100m"} '
      'corr100=$dAePar100mMil denivelee=$denivelee '
      'corrDz=$corrAltitudeObjectifMil => AQE=$aqeMil',
    );

    // Tableau G conservé uniquement pour les données terminales.
    double? angleChuteDeg;
    double? cotangenteAngleChute;
    double? ecartProbablePorteeM;
    double? ecartProbableDirectionM;
    double? vitesseRestanteMps;

    try {
      final gRow = await gService.rowInterpolated(
        distanceM: porteeAViser ?? 0.0,
        tirMontagne: tirMontagne ?? 0.0,
      );

      angleChuteDeg = gRow.angleChute * 360.0 / 6400.0;
      cotangenteAngleChute = gRow.cotangenteAngleChute;
      ecartProbablePorteeM = gRow.ecartProbablePortee;
      ecartProbableDirectionM = gRow.ecartProbableDirection;
      vitesseRestanteMps = gRow.vitesseRestante;
    } catch (error, stackTrace) {
      _log('[BONUS:TABLEAU G TERMINAL ERROR] $error');
      if (kDebugMode) debugPrintStack(stackTrace: stackTrace ?? 0.0);
    }

    // Tempage spécifique BONUS / projectile à dépotage.
    //
    // Doctrine :
    //  - le temps d'entrée des corrections J/Jbis vient du DSPD à la distance
    //    topographique (exercice : ~48.56 s à 18 250 m) ;
    //  - les coefficients J/Jbis sont interpolés à ce temps continu ;
    //  - le temps nominal final vient du DSPD à la portée à viser ;
    //  - la correction de dénivelée vient de corr_temps_±100m_s du DSPD.
    final double tempMunitionC = input.simTempActC ?? 21.0;
    final bool deniveleeTempsPositive = denivelee >= 0.0;

    final double tempsDepotageEntreeS = await dspdService.tempsDepotageS(
      distance: distanceTopo ?? 0.0,
      tirMontagne: tirMontagne ?? 0.0,
    );

    final double tempsDepotageViserS = await dspdService.tempsDepotageS(
      distance: porteeAViser ?? 0.0,
      tirMontagne: tirMontagne ?? 0.0,
    );

    final double corrTempsPar100mS = await dspdService.correctionTempsPar100mS(
      distance: porteeAViser ?? 0.0,
      tirMontagne: tirMontagne ?? 0.0,
      deniveleePositive: deniveleeTempsPositive ?? 0.0,
    );

    final TempageResult tempage = await const TempageService().computeDepotage(
      typeAssets: typeAssets ?? 0.0,
      charge: charge ?? 0.0,
      tempsEntreeS: tempsDepotageEntreeS ?? 0.0,
      tempsNominalViserS: tempsDepotageViserS ?? 0.0,
      correctionDeniveleePar100mS: corrTempsPar100mS ?? 0.0,
      deniveleeM: denivelee ?? 0.0,
      ventLongKn: meteoActive ? ventLongKnAbs : 0.0 ?? 0.0,
      ventArriere: ventArriere ?? 0.0,
      dtbPercent: meteoActive ? deltaTbPctSigned : 0.0 ?? 0.0,
      ddbPercent: meteoActive ? deltaDbPctSigned : 0.0 ?? 0.0,
      deltaV0: deltaV0MpsSigned ?? 0.0,
      tempMunitionC: tempMunitionC ?? 0.0,
    );

    final tempageDetails = TempageDetails(
      tNominal: tempage.tempageNominalViserS ?? 0.0,
      deltaTvent: tempage.corrVent ?? 0.0,
      deltaTTb: tempage.corrTb ?? 0.0,
      deltaTPb: tempage.corrDb ?? 0.0,
      deltaTV0: tempage.corrV0 ?? 0.0,
      deltaTMun: tempage.corrRtc ?? 0.0,
      deltaTMasse: 0.0 ?? 0.0,
      deltaTEvent50m: 0.0 ?? 0.0,
      deltaTDenivelee: tempage.corrDz ?? 0.0,
      tFusee: tempage.tempageFinalS ?? 0.0,
    );

    _log(
      '[BONUS:TEMPAGE DSPD] '
      'entree=${tempsDepotageEntreeS.toStringAsFixed(3)} '
      'nominalViser=${tempsDepotageViserS.toStringAsFixed(3)} '
      'dcfs=${tempage.dcfsSeconds.toStringAsFixed(3)} '
      'kDz100=${corrTempsPar100mS.toStringAsFixed(3)} '
      'dz=${tempage.corrDz.toStringAsFixed(3)} '
      'final=${tempage.tempageFinalS.toStringAsFixed(3)}',
    );

    // Champs historiques conservés pour compatibilité d'affichage. Pour BONUS,
    // siteTotalAsMil porte ici la correction de dénivelée spécifique au dépotage.
    final double siteBrutMil = 0.0;
    final double corrSiteVraiMil = 0.0;
    final double siteTotalAsMil = corrAltitudeObjectifMil;
    final double acsMil = 0.0;
    final double tempsVolFinal = tempage.tempageFinalS;

    // BLOC DE LOGS POUR LE SUIVIT DES SIGNES DE POINTAGE DU GISEMENT
    if (kDebugMode) {
      debugPrint('========== DEBUG ALIGNEMENT GISEMENT ==========');
      debugPrint('azimutInitial = $azimutMil');
      debugPrint('wzMil = -(wzKn * kWz) = $wzMil');
      debugPrint('derive = $deriveMil');
      debugPrint('rotZ = $rotzMil');
      debugPrint('totalCorrectionAzimut = $totalCorrectionAzimutMil');
      debugPrint('resultatFinal (Noire) = $noireMil');
      debugPrint('================================================');
    }

    if (_tracePerf && sw.elapsedMilliseconds > 0) {
      debugPrint('[BONUS PERF] ${sw.elapsedMilliseconds} ms');
    }

    return CalculResult(
      portee: porteeAViser ?? 0.0,
      noireMil: noireMil ?? 0.0,
      charge: charge ?? 0.0,
      typeAssets: typeAssets ?? 0.0,
      tempsVolS: tempsVolFinal ?? 0.0,
      tempageDetails: tempageDetails ?? 0.0,
      aqeMil: aqeMil ?? 0.0,
      deriveMil: deriveMil ?? 0.0,
      rotzMilAbs: rotzMil ?? 0.0,
      wzMil: wzMil ?? 0.0,
      totalCorrectionAzimutMil: totalCorrectionAzimutMil ?? 0.0,
      aeMil: aeMil ?? 0.0,
      siteBrutMil: siteBrutMil ?? 0.0,
      corrSiteVraiMil: corrSiteVraiMil ?? 0.0,
      siteTotalAsMil: siteTotalAsMil ?? 0.0,
      acsMil: acsMil ?? 0.0,
      wxM: wxM ?? 0.0,
      rotxM: rotxM ?? 0.0,
      masseM: masseM ?? 0.0,
      deltaV0M: deltaV0M ?? 0.0,
      deltaTBM: deltaTBM ?? 0.0,
      deltaPBM: deltaPBM ?? 0.0,
      rtcM: rtcM ?? 0.0,
      totalLongM: totalLongM ?? 0.0,
      latitudePieceDeg: latitudePieceDeg ?? 0.0,
      distanceTopoM: distanceTopo ?? 0.0,
      azimutMil: azimutMil ?? 0.0,
      deniveleeM: denivelee ?? 0.0,
      correctionSiteBM: corrSiteM ?? 0.0,
      niveauMeteoBUsed: niveauMeteoEffectif ?? 0.0,
      deltaZStationM: input.meteoStationAltM != null
          ? input.pdZ - input.meteoStationAltM!
          : null,
      angleChuteDeg: angleChuteDeg ?? 0.0,
      cotangenteAngleChute: cotangenteAngleChute ?? 0.0,
      ecartProbablePorteeM: ecartProbablePorteeM ?? 0.0,
      ecartProbableDirectionM: ecartProbableDirectionM ?? 0.0,
      vitesseRestanteMps: vitesseRestanteMps ?? 0.0,
    );
  }

  static void clearCaches() {
    _fCache.clear();
    _iCache.clear();
    _bCache.clear();
    _hCache.clear();
    _dCache.clear();
    _eCache.clear();
    _cCache.clear();
    _gCache.clear();
    _dspdCache.clear();
    SelectionChargeFacade.clearCache();
  }
}
