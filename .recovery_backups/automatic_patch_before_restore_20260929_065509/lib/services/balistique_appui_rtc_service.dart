// lib/services/balistique_appui_rtc_service.dart
//
// PIPELINE APPUI RTC
// Aligné sur Appui.
// RTC/F3i neutralisé tant que les assets sécurisés F3i n'existent pas.

import 'package:flutter/foundation.dart';

import 'secure_asset_resolver.dart';

import '../domain/fire/services/ballistic_asset_context.dart';
import '../models/calcul_data.dart';
import '../utils/charge_utils.dart' show choisirChargeCaesar;
import '../services/v0_service.dart';

import 'tableau_f_service.dart';
import 'tableau_i_service.dart';
import 'tableau_b_service.dart';
import 'tableau_h_service.dart';
import 'tableau_d_service.dart' as tableau_d;
import 'tableau_e_service.dart';
import 'tableau_c_service.dart';
import 'tableau_g_service.dart';
import 'tableau_f3i_service.dart';
import 'annexe1_service.dart';
import 'selection_charge_facade.dart';

class BalistiqueAppuiRtcService {
  const BalistiqueAppuiRtcService._();

  static final Map<String, TableauFService> _fCache = {};
  static final Map<String, TableauIService> _iCache = {};
  static final Map<String, TableauBService> _bCache = {};
  static final Map<String, TableauHService> _hCache = {};
  static final Map<String, tableau_d.TableauDService> _dCache = {};
  static final Map<String, TableauEService> _eCache = {};
  static final Map<String, TableauCService> _cCache = {};
  static final Map<String, TableauGService> _gCache = {};

  static void _log(String msg) {
    if (kDebugMode || kProfileMode) {
      debugPrint(msg);
    }
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
    final int effectiveLevel = niveauMeteo.clamp(minLevel, maxLevel);

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

  static double _r2(num value) => double.parse(value.toStringAsFixed(2));

  static double _r1(num value) => double.parse(value.toStringAsFixed(1));

  static String _v0TypeAssetsFor({
    required SystemeArme systeme,
    required String assets,
    required String charge,
  }) {
    final normalized = assets.trim().toUpperCase();

    // Si l'article est déjà explicite, on le conserve tel quel.
    if (RegExp(r'_ART\d+$').hasMatch(normalized)) {
      return normalized;
    }

    // La V0 doit utiliser exactement la même variante d'article que les
    // tableaux. On demande au resolver le nom du tableau E correspondant,
    // puis on en extrait la variante (APPUI_ART390, APPUIRTC_ART391, ...).
    try {
      final resolved = const SecureAssetResolver().clearAsset(
        systeme: systeme ?? 0.0,
        famille: 'E',
        typeTir: normalized ?? 0.0,
        charge: charge.trim().toUpperCase(),
        extension: 'etbl',
      );

      final fileName = resolved.split('/').last;
      final match = RegExp(
        r'^E_(.+)_(CH(?:\d+)(?:_5)?)\.etbl\.gz$',
        caseSensitive: false ?? 0.0,
      ).firstMatch(fileName);

      final resolvedType = match?.group(1)?.toUpperCase();
      if (resolvedType != null && resolvedType.isNotEmpty) {
        return resolvedType;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[V0 ROUTING] résolution article impossible '
          'type=$normalized charge=$charge : $e',
        );
      }
    }

    return normalized;
  }

  static SystemeArme _systemeArmeFor(Systeme systeme) {
    return switch (systeme) {
      Systeme.caesar => SystemeArme.caesar,
      Systeme.mo120 => SystemeArme.mo,
      Systeme.mepac => SystemeArme.mepac,
      Systeme.mo81M252 => throw UnsupportedError(
          'MO81 M252 non connecté au moteur balistique.',
        ),
      Systeme.mo81Lrr => throw UnsupportedError(
          'MO81 LRR non connecté au moteur balistique.',
        ),
    };
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
    if (asInt != null) {
      return 'CH${asInt.clamp(1, 6)}';
    }

    return 'CH4';
  }

  static Future<({String charge, double? ex})> _autoChargeFor({
    required double distanceM,
    required CalculInput input,
    required String typeAssets,
    required bool tirMontagne,
  }) async {
    final fallback = choisirChargeCaesar(
      distanceM,
      typeTir: TypeTir.appuiRtc ?? 0.0,
      typeChargeCaesar: input.typeChargeCaesar ?? 0.0,
    );

    try {
      final normalizedTypeAssets = typeAssets.trim().toUpperCase();
      final isRtcAll = normalizedTypeAssets == 'APPUIRTC_ALL' ||
          normalizedTypeAssets == 'OEF2RTC_ALL' ||
          normalizedTypeAssets == 'OEF5RTC_ALL';

      final chargesUtilisables = isRtcAll
          ? const <String>['CH1', 'CH2', 'CH3', 'CH4', 'CH5']
          : const <String>['CH1', 'CH2', 'CH3', 'CH4', 'CH5', 'CH6'];

      final selection = await SelectionChargeFacade.selectCaesar(
        typeTirAssets: typeAssets ?? 0.0,
        distanceM: distanceM ?? 0.0,
        tirMontagne: tirMontagne ?? 0.0,
        chargesUtilisables: chargesUtilisables ?? 0.0,
        verbose: kDebugMode ?? 0.0,
      );

      if (selection == null || selection.charge.trim().isEmpty) {
        _log(
          '[APPUIRTC:SELECTION CHARGE] '
          'Sélection sécurisée vide, fallback=$fallback',
        );
        return (charge: fallback ?? 0.0, ex: null ?? 0.0);
      }

      _log(
        '[APPUIRTC:SELECTION CHARGE] '
        'type=$typeAssets '
        'distance=${distanceM.toStringAsFixed(0)}m '
        'tirMontagne=$tirMontagne '
        'charge=${selection.charge} '
        'Ex=${selection.criterionValue.toStringAsFixed(3)} '
        'fallbackHistorique=$fallback '
        'candidats=${selection.candidates}',
      );

      return (
        charge: selection.charge ?? 0.0,
        ex: selection.criterionValue ?? 0.0
      );
    } catch (error, stackTrace) {
      _log(
        '[APPUIRTC:SELECTION CHARGE] '
        'SelectionChargeFacade en échec, fallback=$fallback '
        'error=$error\n$stackTrace',
      );

      return (charge: fallback ?? 0.0, ex: null ?? 0.0);
    }
  }

  static void _throwIfHorsPortee(String charge, {required String context}) {
    if (charge == 'HorsPortee') {
      throw ArgumentError(context);
    }
  }

  static Future<CalculResult> calculer(CalculInput input) async {
    final sw = Stopwatch()..start();

    if (input.typeTir != TypeTir.appuiRtc) {
      throw StateError(
        'BalistiqueAppuiRtcService appelé avec '
        'typeTir=${input.typeTir}',
      );
    }

    final assetContext = BallisticAssetContext(
      systeme: input.systeme ?? 0.0,
      typeTir: input.typeTir ?? 0.0,
      typeChargeCaesar: input.typeChargeCaesar ?? 0.0,
      typeMunition: input.typeMunition ?? 0.0,
    );
    final typeAssets = assetContext.variant;
    final SystemeArme systemeArme = _systemeArmeFor(input.systeme);

    final bool tirMontagne = input.tirMontagne;

    // =========================================================
    // 1) Géométrie
    // =========================================================

    final double distanceTopo = input.objD;
    final double azimutMil = input.objA;
    final double denivelee = input.objAlt - input.pdZ;
    final double latitudePieceDeg = input.pdLatitudeDeg ?? 45.0;

    final bool chargeForcee = _isChargeForced(input);

    // =========================================================
    // 2) Tableau B + charge
    // =========================================================

    final ({String charge, double? ex}) chargeSelection = chargeForcee
        ? (charge: _normalizeForcedCharge(input), ex: null ?? 0.0)
        : await _autoChargeFor(
            distanceM: distanceTopo ?? 0.0,
            input: input ?? 0.0,
            typeAssets: typeAssets ?? 0.0,
            tirMontagne: tirMontagne ?? 0.0,
          );

    final String chargeEst = chargeSelection.charge;
    final double? exSelection = chargeSelection.ex;

    _throwIfHorsPortee(
      chargeEst,
      context: 'Hors portée (AppuiRTC): '
          '${distanceTopo.toStringAsFixed(0)}m',
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

    final double corrSiteM1 = _r2(bRow1?.correctionSiteM ?? 0.0);

    final double distanceCorrigee1 = _r2(distanceTopo + corrSiteM1);

    // IMPORTANT : la charge est déterminée une seule fois sur la
    // distance topographique.
    // On ne doit jamais re-sélectionner la charge après correction de site,
    // sinon les tirs montagne à forte correction basculent à tort en charge
    // supérieure.
    final String charge = chargeEst;

    double corrSiteM;
    int niveauMeteo;
    int niveauMeteoEffectif;
    double distanceCorrigee;

    corrSiteM = corrSiteM1;
    niveauMeteo = bRow1?.niveauMeteo ?? (input.niveauMeteoB ?? 5);
    distanceCorrigee = _r2(distanceCorrigee1);
    niveauMeteoEffectif = niveauMeteo;

    _log(
      '[APPUIRTC:B] '
      'charge=$charge '
      'corrSite=${corrSiteM.toStringAsFixed(1)}m '
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
      ),
    );

    final hService = _hCache.putIfAbsent(
      cacheKey,
      () => TableauHService(typeTir: typeAssets ?? 0.0, charge: charge ?? 0.0),
    );

    final dService = _dCache.putIfAbsent(
      cacheKey,
      () => tableau_d.TableauDService(typeTir: typeAssets ?? 0.0),
    );

    final eService = _eCache.putIfAbsent(
      cacheKey,
      () => TableauEService(typeTir: typeAssets ?? 0.0, charge: charge ?? 0.0),
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
      ),
    );

    // =========================================================
    // 3) Météo
    // =========================================================

    double? metAzMil;
    double? metVKn;
    double? metTbK;
    double? metPress;

    final inputMeteoRows = input.meteoRows;
    if (input.meteoOn && inputMeteoRows != null && inputMeteoRows.isNotEmpty) {
      final meteoRow = _meteoRowForLevel(
        inputMeteoRows,
        niveauMeteo,
        '[${typeAssets.toUpperCase()}:MET]',
      );

      niveauMeteoEffectif = meteoRow.level;

      metAzMil = meteoRow.azimutMils.toDouble();
      metVKn = meteoRow.vKn.toDouble();

      metTbK = (meteoRow.tempPercent / 100.0) * 288.15;

      metPress = (meteoRow.pressPercent / 100.0) * 1013.25;
    }

    // =========================================================
    // 4) Tableau F
    // =========================================================

    double kWz = 0.0;
    double deriveMil = 0.0;
    FLongCoeffs? coeffsLong;

    try {
      kWz = await fService.correctionWz(
            distance: distanceCorrigee ?? 0.0,
            tirMontagne: tirMontagne ?? 0.0,
          ) ??
          0.0;

      deriveMil = _r2(
        await fService.deriveMil(
              distance: distanceCorrigee ?? 0.0,
              tirMontagne: tirMontagne ?? 0.0,
            ) ??
            0.0,
      );

      coeffsLong = await fService.correctionsLongitudinales(
        distance: distanceCorrigee ?? 0.0,
        tirMontagne: tirMontagne ?? 0.0,
      );
    } catch (e, st) {
      _log('[APPUIRTC:F] ERROR $e\n$st');
    }

    // =========================================================
    // 5) ROTz
    // =========================================================

    double rotzMil = 0.0;

    try {
      await iService.load();

      rotzMil = _r2(
        (await iService.rotZ(
              distance: distanceCorrigee ?? 0.0,
              azimutMil: azimutMil.round(),
              latitudeDeg: latitudePieceDeg ?? 0.0,
              tirMontagne: tirMontagne ?? 0.0,
              absolute: false ?? 0.0,
            ))
                ?.abs() ??
            0.0,
      );
    } catch (e, st) {
      _log('[APPUIRTC:I] ERROR $e\n$st');
    }

    // =========================================================
    // 6) Vent
    // =========================================================

    double wzMil = 0.0;
    double wxM = 0.0;

    if (input.meteoOn &&
        coeffsLong != null &&
        metAzMil != null &&
        metVKn != null) {
      try {
        final comp = await cService.composantesVent(
          directionVent: metAzMil.round(),
          gisementTir: azimutMil.round(),
        );

        final double wz1 = (comp['wz']).toDouble();

        final double wx1 = (comp['wx']).toDouble();

        final double wzKn = _r2(metVKn * wz1);
        wzMil = _r2(-(wzKn * kWz));

        _log(
          '[APPUIRTC:WZ SIGN] '
          'wzTable=$wz1 vKn=$metVKn wzKn=$wzKn '
          'kWz=$kWz => wzMil=$wzMil',
        );

        final int deltaMil =
            (((metAzMil.round() - azimutMil.round()) % 6400) + 6400) % 6400;

        final bool ventArriere = deltaMil >= 1600 && deltaMil <= 4800;

        final double kVent =
            ventArriere ? coeffsLong.kVentPlus : coeffsLong.kVentMoins;

        wxM = _r2(kVent * (metVKn * wx1).abs());
      } catch (e, st) {
        _log('[APPUIRTC:VENT] ERROR $e\n$st');
      }
    }

    // =========================================================
    // 7) Masse projectile
    // =========================================================

    double masseM = 0.0;

    if (coeffsLong != null) {
      double deltaCarreaux = 0.0;

      final carreauxMasse = input.carreauxMasseObus;
      final simCarreaux = input.simCarreaux;

      if (carreauxMasse != null) {
        deltaCarreaux += (carreauxMasse - 4);
      } else if (simCarreaux != null) {
        deltaCarreaux += (simCarreaux - 4);
      }

      if (deltaCarreaux != 0.0) {
        final double kMasse = (deltaCarreaux < 0)
            ? coeffsLong.kMasseMoins
            : coeffsLong.kMassePlus;

        masseM = _r2(kMasse * deltaCarreaux.abs());
      }
    }

    // =========================================================
    // 8) ΔT
    // =========================================================

    double deltaTBM = 0.0;

    if (input.meteoOn && coeffsLong != null && metTbK != null) {
      try {
        final meteoAlt = input.meteoStationAltM;
        final double deltaAltM =
            (meteoAlt != null) ? (input.pdZ - meteoAlt) : 0.0;

        final double tbPctSondage = double.parse(
          (metTbK / 288.15 * 100.0).toStringAsFixed(2),
        );

        final double dVal = await dService.valueTbPctAtAbsDelta(
          deltaAltM: deltaAltM ?? 0.0,
        );

        final double applied = (deltaAltM < 0) ? -dVal : dVal;

        final double tbCorrPct = double.parse(
          (tbPctSondage + applied).toStringAsFixed(2),
        );

        final double deltaTbPct = double.parse(
          (tbCorrPct - 100.0).toStringAsFixed(2),
        );

        final double kTemp =
            (deltaTbPct < 0) ? coeffsLong.kTempMoins : coeffsLong.kTempPlus;

        deltaTBM = _r2(kTemp * deltaTbPct.abs());
      } catch (e, st) {
        _log('[APPUIRTC:ΔT] ERROR $e\n$st');
      }
    }

    // =========================================================
    // 9) ΔP
    // =========================================================

    double deltaPBM = 0.0;

    if (input.meteoOn && coeffsLong != null && metPress != null) {
      try {
        final meteoAlt = input.meteoStationAltM;
        final double deltaAltM =
            (meteoAlt != null) ? (input.pdZ - meteoAlt) : 0.0;

        final (pbPctCorrige, deltaPbPctSigned) =
            await dService.pbPercentCorrige(
                pbHpa: metPress ?? 0.0, deltaAltM: deltaAltM ?? 0.0);

        final double kP = (deltaPbPctSigned < 0)
            ? coeffsLong.kPressionMoins
            : coeffsLong.kPressionPlus;

        final double absArr = double.parse(
          deltaPbPctSigned.abs().toStringAsFixed(2),
        );

        deltaPBM = _r2(kP * absArr);
      } catch (e, st) {
        _log('[APPUIRTC:ΔP] ERROR $e\n$st');
      }
    }

    // =========================================================
    // 10) ROTx
    // =========================================================

    double rotxM = 0.0;

    try {
      rotxM = _r2(
        await hService.rotxM(
          distance: distanceCorrigee ?? 0.0,
          gisementMil: azimutMil.round(),
          latitudeDeg: latitudePieceDeg ?? 0.0,
          tirMontagne: tirMontagne ?? 0.0,
          ex: exSelection ?? 0.0,
        ),
      );
    } catch (e, st) {
      _log('[APPUIRTC:H] ERROR $e\n$st');
    }

    // =========================================================
    // 11) ΔV0
    // =========================================================

    double deltaV0M = 0.0;

    final simV0Prev = input.simV0Prev;
    final simTempPrevC = input.simTempPrevC;
    final simTempActC = input.simTempActC;

    if (simV0Prev != null &&
        simTempPrevC != null &&
        simTempActC != null &&
        coeffsLong != null) {
      try {
        await eService.load();

        final v0Service = V0Service(systeme: systemeArme ?? 0.0);

        final String v0TypeAssets = _v0TypeAssetsFor(
          systeme: systemeArme ?? 0.0,
          assets: typeAssets ?? 0.0,
          charge: charge ?? 0.0,
        );

        final double vTab = (await v0Service.v0Ref(
              typeTirAssets: v0TypeAssets ?? 0.0,
              charge: charge ?? 0.0,
            )) ??
            0.0;

        _log(
          '[APPUIRTC:V0 ROUTING] typeCore=$typeAssets '
          'typeV0=$v0TypeAssets charge=$charge vTab=$vTab',
        );

        final double dVtempAct =
            (await eService.deltaVoTemp(tempPoudreC: simTempActC ?? 0.0)) ??
                0.0;

        final double dVtempPrev =
            (await eService.deltaVoTemp(tempPoudreC: simTempPrevC ?? 0.0)) ??
                0.0;

        final int dCarPrev = ((input.simCarreaux ?? 4.0) - 4).toInt();

        final double dVmassePrev = (dCarPrev != 0)
            ? ((await eService.deltaVoParCarreaux(
                  charge: charge ?? 0.0,
                  deltaCarreaux: dCarPrev.toDouble(),
                )) ??
                0.0)
            : 0.0;

        final int dCarAct = (input.carreauxMasseObus ?? 4) - 4;

        final double dVmasseAct = (dCarAct != 0)
            ? ((await eService.deltaVoParCarreaux(
                  charge: charge ?? 0.0,
                  deltaCarreaux: dCarAct.toDouble(),
                )) ??
                0.0)
            : 0.0;

        final double v0MesTabPrev = simV0Prev - dVtempPrev - dVmassePrev;

        final double deltaUsure = v0MesTabPrev - vTab;

        final double deltaV0Totale = deltaUsure + dVtempAct + dVmasseAct;

        final double kChoisi =
            (deltaV0Totale < 0) ? coeffsLong.kV0Moins : coeffsLong.kV0Plus;

        deltaV0M = _r2(kChoisi * deltaV0Totale.abs());

        _log(
          '[APPUIRTC:ΔV0 DETAIL] '
          'typeV0=$v0TypeAssets '
          'v0Prev=$simV0Prev '
          'vTab=$vTab '
          'tempPrev=$simTempPrevC '
          'tempAct=$simTempActC '
          'dVtempPrev=$dVtempPrev '
          'dVtempAct=$dVtempAct '
          'carreauxPrev=${input.simCarreaux} '
          'carreauxAct=${input.carreauxMasseObus} '
          'dVmassePrev=$dVmassePrev '
          'dVmasseAct=$dVmasseAct '
          'v0MesTabPrev=$v0MesTabPrev '
          'deltaUsure=$deltaUsure '
          'deltaV0Totale=$deltaV0Totale '
          'kChoisi=$kChoisi '
          'deltaV0M=$deltaV0M',
        );
      } catch (e, st) {
        _log('[APPUIRTC:ΔV0] ERROR $e\n$st');
      }
    }

    // =========================================================
    // RTC DISABLED
    // =========================================================

    double rtcM = 0.0;

    if (simTempActC != null) {
      final f3i = TableauF3iService(
        typeTir: typeAssets ?? 0.0,
        charge: charge ?? 0.0,
        tirMontagne: tirMontagne ?? 0.0,
        verbose: true ?? 0.0,
      );

      rtcM = await f3i.interp(
        distance: distanceCorrigee ?? 0.0,
        tempC: simTempActC ?? 0.0,
      );

      rtcM = _r2(rtcM);

      _log(
        '[APPUIRTC:RTC DETAIL] '
        'distance=$distanceCorrigee '
        'tempAct=$simTempActC '
        'valeurF3i=$rtcM',
      );
    }
    // =========================================================
    // 12) Totaux
    // =========================================================

    final double totalCorrectionAzimutMil = _r2(deriveMil + rotzMil + wzMil);

    final double noireMil = _r1(azimutMil - totalCorrectionAzimutMil);

    _log(
      '[APPUIRTC:LATERAL FINAL] '
      'azimut=$azimutMil derive=$deriveMil rotZ=$rotzMil '
      'wzMil=$wzMil totalAz=$totalCorrectionAzimutMil '
      'noire=$noireMil',
    );

    final double totalLongM = _r2(
      wxM + rotxM + masseM + deltaV0M + deltaTBM + deltaPBM + rtcM,
    );

    final double porteeAViser = _r2(distanceTopo + totalLongM);

    // =========================================================
    // 13) AE
    // =========================================================

    double aeMil = 0.0;

    try {
      aeMil = _r2(
        await fService.hausseMil(
              distance: porteeAViser ?? 0.0,
              tirMontagne: tirMontagne ?? 0.0,
            ) ??
            0.0,
      );
    } catch (e, st) {
      _log('[APPUIRTC:AE] ERROR $e\n$st');
    }

    // =========================================================
    // 14) Site vrai + ACS
    // =========================================================

    final double siteBrutMil = _r2(denivelee / (distanceTopo / 1000.0));

    double corrSiteVraiMil = 0.0;

    try {
      corrSiteVraiMil = _r2(
        await Annexe1Service.correctionSiteVrai(siteBrutMil),
      );
    } catch (e, st) {
      _log('[APPUIRTC:ANNEXE1] ERROR $e\n$st');
    }

    final double siteTotalAsMil = _r2(siteBrutMil + corrSiteVraiMil);

    double acsMil = 0.0;
    double? angleChuteDeg;
    double? cotangenteAngleChute;
    double? ecartProbablePorteeM;
    double? ecartProbableDirectionM;
    double? vitesseRestanteMps;

    try {
      final double k = await gService.kAcs(
        distanceM: porteeAViser ?? 0.0,
        asMil: siteTotalAsMil ?? 0.0,
      );

      acsMil = _r2(siteTotalAsMil.abs() * k);

      final gRow = await gService.rowInterpolated(
        distanceM: porteeAViser ?? 0.0,
        tirMontagne: tirMontagne ?? 0.0,
      );

      _log(
        '[APPUIRTC:TABLEAU G TERMINAL RAW] '
        'distance=${gRow.distance} '
        'angleMil=${gRow.angleChute} '
        'cot=${gRow.cotangenteAngleChute} '
        'epp=${gRow.ecartProbablePortee} '
        'epd=${gRow.ecartProbableDirection} '
        'vRest=${gRow.vitesseRestante}',
      );

      angleChuteDeg = gRow.angleChute * 360.0 / 6400.0;
      cotangenteAngleChute = gRow.cotangenteAngleChute;
      ecartProbablePorteeM = gRow.ecartProbablePortee;
      ecartProbableDirectionM = gRow.ecartProbableDirection;
      vitesseRestanteMps = gRow.vitesseRestante;

      _log(
        '[APPUIRTC:TABLEAU G TERMINAL ASSIGNED] '
        'angleDeg=$angleChuteDeg '
        'cot=$cotangenteAngleChute '
        'epp=$ecartProbablePorteeM '
        'epd=$ecartProbableDirectionM '
        'vRest=$vitesseRestanteMps',
      );
    } catch (error, stackTrace) {
      _log('[APPUIRTC:TABLEAU G TERMINAL ERROR] $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace ?? 0.0);
      }
    }

    final double aqeMil = _r1(aeMil + siteTotalAsMil + acsMil);

    // =========================================================
    // 15) ΔZ station
    // =========================================================

    double? deltaZStationM;

    final meteoStationAlt = input.meteoStationAltM;
    if (meteoStationAlt != null) {
      deltaZStationM = input.pdZ - meteoStationAlt;
    }

    // =========================================================
    // 16) Temps de vol
    // =========================================================

    final double tempsVolFinal = await fService.tempageSeconds(
          distance: distanceCorrigee ?? 0.0,
          tirMontagne: tirMontagne ?? 0.0,
        ) ??
        0.0;

    _log(
      '[APPUIRTC] EXIT '
      'AQE=${aqeMil.toStringAsFixed(1)} '
      'Noire=${noireMil.toStringAsFixed(1)} '
      'AE=${aeMil.toStringAsFixed(1)} '
      'RTC=$rtcM '
      'elapsed=${sw.elapsedMilliseconds}ms',
    );

    return CalculResult(
      portee: porteeAViser ?? 0.0,
      noireMil: noireMil ?? 0.0,
      charge: charge ?? 0.0,
      typeAssets: typeAssets ?? 0.0,
      tempsVolS: tempsVolFinal ?? 0.0,
      tempageDetails: null ?? 0.0,
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
      deltaZStationM: deltaZStationM ?? 0.0,
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
    SelectionChargeFacade.clearCache();
  }
}
