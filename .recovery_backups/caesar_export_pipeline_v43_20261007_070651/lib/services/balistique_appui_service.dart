// lib/services/balistique_appui_service.dart
//
// PIPELINE APPUI (assets "Appui_*")

import 'package:flutter/foundation.dart';

import 'secure_asset_resolver.dart';

import '../domain/fire/services/ballistic_asset_context.dart';
import '../models/calcul_data.dart';
import '../utils/charge_utils.dart' show choisirChargeCaesar;

import 'annexe1_service.dart';
import 'selection_charge_facade.dart';
import 'tableau_b_service.dart';
import 'tableau_c_service.dart';
import 'tableau_d_service.dart' as tableau_d;
import 'tableau_e_service.dart';
import 'tableau_f_service.dart';
import 'tableau_g_service.dart';
import 'tableau_h_service.dart';
import 'tableau_i_service.dart';
import 'v0_service.dart';

class BalistiqueAppuiService {
  const BalistiqueAppuiService._();

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

  static void _log(String msg) {
    if (_traceTP || kDebugMode) debugPrint(msg);
  }

  static T _meteoRowForLevel<T>(
    List<T> rows,
    int niveauMeteo,
    String logPrefix,
  ) {
    if (rows.isEmpty) {
      throw StateError('$logPrefix no weather line available');
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
        'outside weather message [$minLevel..$maxLevel] -> levelPicked=$pickedLevel',
      );
    } else {
      _log('$logPrefix niveauWanted=$niveauMeteo niveauPicked=$pickedLevel');
    }

    return picked;
  }

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
    // puis on en extrait la variante (APPUI_ART390, ...).
    try {
      final resolved = const SecureAssetResolver().clearAsset(
        systeme: systeme,
        famille: 'E',
        typeTir: normalized,
        charge: charge.trim().toUpperCase(),
        extension: 'etbl',
      );

      final fileName = resolved.split('/').last;
      final match = RegExp(
        r'^E_(.+)_(CH(?:\d+)(?:_5)?)\.etbl\.gz$',
        caseSensitive: false,
      ).firstMatch(fileName);

      final resolvedType = match?.group(1)?.toUpperCase();
      if (resolvedType != null && resolvedType.isNotEmpty) {
        return resolvedType;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[V0 ROUTING] unable to resolve article'
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
          'MO81 M252 not connected to ballistic engine.',
        ),
      Systeme.mo81Lrr => throw UnsupportedError(
          'MO81 LRR not connected to ballistic engine.',
        ),
      Systeme.l118Lg => throw UnsupportedError(
          'L118 LG is catalog/UI only and is not connected to the ballistic engine.',
        ),
      Systeme.m109 => throw UnsupportedError(
          'M109 is catalog/UI only and is not connected to the ballistic engine.',
        ),
      Systeme.caesarExport => throw UnsupportedError(
          'CAESAR export is catalog/UI only and is not connected to the ballistic engine.',
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
      typeTir: TypeTir.appui,
      typeChargeCaesar: input.typeChargeCaesar,
    );

    try {
      final selection = await SelectionChargeFacade.selectCaesar(
        typeTirAssets: typeAssets,
        distanceM: distanceM,
        tirMontagne: tirMontagne,
        verbose: kDebugMode,
      );

      if (selection == null) {
        _log(
          '[APPUI:SELECTION CHARGE] '
          'No candidate by Ex '
          'type=$typeAssets '
          'distance=${distanceM.toStringAsFixed(0)}m '
          'tirMontagne=$tirMontagne '
          '=> fallback=$fallback',
        );

        return fallback;
      }

      _log(
        '[APPUI:SELECTION CHARGE] '
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
      _log(
        '[APPUI:SELECTION CHARGE] '
        'Selection by Ex failed '
        'type=$typeAssets '
        'distance=${distanceM.toStringAsFixed(0)}m '
        'tirMontagne=$tirMontagne '
        '=> fallback=$fallback : $error',
      );

      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
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
      _log('[APPUI:SANE] $label invalid: $v -> 0');
      return 0.0;
    }

    if (v.abs() > 100000) {
      _log('[APPUI:SANE] $label aberrant: $v -> 0');
      return 0.0;
    }

    return v;
  }

  static Future<CalculResult> calculer(CalculInput input) async {
    final sw = Stopwatch()..start();

    if (input.typeTir != TypeTir.appui) {
      throw StateError(
        'BalistiqueAppuiService called with typeTir=${input.typeTir}',
      );
    }

    final assetContext = BallisticAssetContext(
      systeme: input.systeme,
      typeTir: input.typeTir,
      typeChargeCaesar: input.typeChargeCaesar,
      typeMunition: input.typeMunition,
      m252MunitionFamily: input.m252MunitionFamily,
    );
    final typeAssets = assetContext.variant;
    final SystemeArme systemeArme = _systemeArmeFor(input.systeme);

    final bool meteoRowsDisponibles =
        input.meteoRows != null && input.meteoRows!.isNotEmpty;
    final bool meteoActive = input.meteoOn || meteoRowsDisponibles;

    if (input.meteoOn != meteoRowsDisponibles) {
      _log(
        '[APPUI:METEO STATE] inconsistency '
        'meteoOn=${input.meteoOn} '
        'rows=${input.meteoRows?.length ?? 0} '
        '=> utilisationMeteo=$meteoActive',
      );
    }

    final bool tirMontagne = input.tirMontagne;

    final double distanceTopo = input.objD;
    final double azimutMil = input.objA;
    final double denivelee = input.objAlt - input.pdZ;
    final double latitudePieceDeg = input.pdLatitudeDeg;

    final bool chargeForcee = _isChargeForced(input);

    final String chargeEst = chargeForcee
        ? _normalizeForcedCharge(input)
        : await _autoChargeFor(
            distanceM: distanceTopo,
            input: input,
            typeAssets: typeAssets,
            tirMontagne: tirMontagne,
          );

    _throwIfHorsPortee(
      chargeEst,
      context:
          'Out of range (fire support): distance=${distanceTopo.toStringAsFixed(0)}m',
    );

    final bService1 = _bCache.putIfAbsent(
      _key(typeAssets, chargeEst, tirMontagne),
      () => TableauBService(
        typeTir: typeAssets,
        charge: chargeEst,
        tirMontagne: tirMontagne,
      ),
    );

    final TableauBRow? bRow1 = await bService1.chercher(
      distanceTopoM: distanceTopo,
      deniveleeM: denivelee,
    );

    final double corrSiteM1 = bRow1?.correctionSiteM ?? 0.0;
    final double distanceCorrigee1 = distanceTopo + corrSiteM1;

    final String charge = chargeEst;

    _throwIfHorsPortee(
      charge,
      context:
          'Out of range (fire support) after site correction: distCorr=${distanceCorrigee1.toStringAsFixed(0)}m',
    );

    double corrSiteM;
    int niveauMeteo;
    int niveauMeteoEffectif;
    double distanceCorrigee;

    if (charge == chargeEst) {
      corrSiteM = corrSiteM1;
      niveauMeteo = bRow1?.niveauMeteo ?? input.niveauMeteoB;
      distanceCorrigee = distanceCorrigee1;
    } else {
      final bService2 = _bCache.putIfAbsent(
        _key(typeAssets, charge, tirMontagne),
        () => TableauBService(
          typeTir: typeAssets,
          charge: charge,
          tirMontagne: tirMontagne,
        ),
      );

      final TableauBRow? bRow2 = await bService2.chercher(
        distanceTopoM: distanceTopo,
        deniveleeM: denivelee,
      );

      corrSiteM = bRow2?.correctionSiteM ?? 0.0;
      niveauMeteo = bRow2?.niveauMeteo ?? input.niveauMeteoB;
      distanceCorrigee = distanceTopo + corrSiteM;
    }

    niveauMeteoEffectif = niveauMeteo;

    _log(
      '[APPUI:B] charge=$charge${chargeForcee ? " (FORCED)" : ""} '
      'corrSite=${corrSiteM.toStringAsFixed(1)}m '
      'level=$niveauMeteo '
      'distTopo=${distanceTopo.toStringAsFixed(1)}m '
      'distCorr=${distanceCorrigee.toStringAsFixed(1)}m',
    );

    final cacheKey = _key(typeAssets, charge, tirMontagne);

    final fService = _fCache.putIfAbsent(
      cacheKey,
      () => TableauFService(typeTir: typeAssets, charge: charge),
    );

    final iService = _iCache.putIfAbsent(
      cacheKey,
      () => TableauIService(
        typeTir: typeAssets,
        charge: charge,
        tirMontagne: tirMontagne,
        snapAzToStepMil: 100,
      ),
    );

    final hService = _hCache.putIfAbsent(
      cacheKey,
      () => TableauHService(typeTir: typeAssets, charge: charge, debug: true),
    );

    final dService = _dCache.putIfAbsent(
      cacheKey,
      () => tableau_d.TableauDService(typeTir: typeAssets, verbose: true),
    );

    final eService = _eCache.putIfAbsent(
      cacheKey,
      () => TableauEService(typeTir: typeAssets, charge: charge, verbose: true),
    );

    final cService = _cCache.putIfAbsent(
      cacheKey,
      () => TableauCService(typeTir: typeAssets, niveauMeteo: niveauMeteo),
    );

    final gService = _gCache.putIfAbsent(
      cacheKey,
      () => TableauGService(
        typeTir: typeAssets,
        charge: charge,
        tirMontagne: tirMontagne,
        verbose: true,
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
        '[APPUI:METEO RAW] '
        'rows=${input.meteoRows!.length} '
        'level=${meteoRow.level} '
        'azimutMils=${meteoRow.azimutMils} '
        'vKn=${meteoRow.vKn} '
        'tempPercent=${meteoRow.tempPercent} '
        'pressPercent=${meteoRow.pressPercent}',
      );

      _log(
        '[APPUI:MET] niveauWanted=$niveauMeteo '
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
          distance: distanceCorrigee,
          tirMontagne: tirMontagne,
        ) ??
        0.0;

    deriveMil = await fService.deriveMil(
          distance: distanceCorrigee,
          tirMontagne: tirMontagne,
        ) ??
        0.0;

    coeffsLong = await fService.correctionsLongitudinales(
      distance: distanceCorrigee,
      tirMontagne: tirMontagne,
    );

    double rotzMil = 0.0;

    await iService.load();

    rotzMil = (await iService.rotZ(
          distance: distanceCorrigee,
          azimutMil: azimutMil.round(),
          latitudeDeg: latitudePieceDeg,
          tirMontagne: tirMontagne,
          absolute: false,
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

      final double wzKn = metVKn * wz1;
      wzMil = -(wzKn * kWz);

      _log(
        '[APPUI:WZ SIGN] '
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
        '[APPUI:VENT] '
        'azVent=$metAzMil azTir=$azimutMil '
        'vKn=$metVKn wx1=$wx1 wz1=$wz1 '
        'ventArriere=$ventArriere '
        'kVent=$kVent kWz=$kWz '
        'Wx=$wxM Wz=$wzMil',
      );
    } else if (meteoActive) {
      _log(
        '[APPUI:VENT] not calculated '
        'coeffsLong=${coeffsLong != null} '
        'metAzMil=$metAzMil metVKn=$metVKn',
      );
    }

    double masseM = 0.0;
    double deltaCarreaux = 0.0;

    final bool isArt387 = input.typeMunition.artReference == 'ART387';

    const double masseFuseeReferenceArt387G = 950.0;
    const double grammesParCarreauArt387 = 500.0;

    if (input.carreauxMasseObus != 0) {
      deltaCarreaux = (input.carreauxMasseObus - 4).toDouble();

      if (isArt387 && input.fusee.masseGNullable != null) {
        final double deltaFuseeCarreaux =
            (input.fusee.masseGNullable! - masseFuseeReferenceArt387G) /
                grammesParCarreauArt387;

        deltaCarreaux += deltaFuseeCarreaux;
      }
    } else if (input.simCarreaux != 0.0) {
      deltaCarreaux = input.simCarreaux - 4.0;
    }

    if (deltaCarreaux != 0.0 && coeffsLong != null) {
      final double kMasse =
          deltaCarreaux < 0 ? coeffsLong.kMasseMoins : coeffsLong.kMassePlus;

      masseM = kMasse * deltaCarreaux.abs();
    }

    _log(
      '[APPUI:MASSE] '
      'art=${input.typeMunition.artReference} '
      'fusee=${input.fusee} '
      'masseFuseeG=${input.fusee.masseGNullable} '
      'carreauxMasseObus=${input.carreauxMasseObus} '
      'simCarreaux=${input.simCarreaux} '
      'deltaCarreaux=$deltaCarreaux '
      'masseM=$masseM',
    );

    double deltaTBM = 0.0;

    if (meteoActive && coeffsLong != null && metTbK != null) {
      final double deltaAltM = input.pdZ - input.meteoStationAltM;

      final double tbPctSondage = double.parse(
        (metTbK / 288.15 * 100.0).toStringAsFixed(1),
      );

      final double dVal = await dService.valueTbPctAtAbsDelta(
        deltaAltM: deltaAltM,
      );

      final double applied = deltaAltM < 0 ? -dVal : dVal;

      final double tbCorrPct = double.parse(
        (tbPctSondage + applied).toStringAsFixed(1),
      );

      final double deltaTbPct = double.parse(
        (tbCorrPct - 100.0).toStringAsFixed(1),
      );

      final double kTemp =
          deltaTbPct < 0 ? coeffsLong.kTempMoins : coeffsLong.kTempPlus;

      deltaTBM = (kTemp * deltaTbPct.abs()).roundToDouble();

      _log(
        '[APPUI:TEMP] '
        'tbPctSondage=$tbPctSondage '
        'deltaAltM=$deltaAltM dVal=$dVal applied=$applied '
        'tbCorrPct=$tbCorrPct deltaTbPct=$deltaTbPct '
        'kTemp=$kTemp => deltaTBM=$deltaTBM',
      );
    } else if (meteoActive) {
      _log(
        '[APPUI:TEMP] not calculated '
        'coeffsLong=${coeffsLong != null} metTbK=$metTbK',
      );
    }

    double deltaPBM = 0.0;

    if (meteoActive && coeffsLong != null && metPress != null) {
      final double deltaAltM = input.pdZ - input.meteoStationAltM;

      final (_, deltaPbPctSigned) = await dService.pbPercentCorrige(
        pbHpa: metPress,
        deltaAltM: deltaAltM,
      );

      final double kP = deltaPbPctSigned < 0
          ? coeffsLong.kPressionMoins
          : coeffsLong.kPressionPlus;

      final double absArr = double.parse(
        deltaPbPctSigned.abs().toStringAsFixed(1),
      );

      deltaPBM = kP * absArr;

      _log(
        '[APPUI:PRESS] '
        'pressHpa=$metPress '
        'deltaAltM=$deltaAltM '
        'deltaPbPctSigned=$deltaPbPctSigned '
        'kP=$kP => deltaPBM=$deltaPBM',
      );
    } else if (meteoActive) {
      _log(
        '[APPUI:PRESS] not calculated '
        'coeffsLong=${coeffsLong != null} metPress=$metPress',
      );
    }

    double rotxM = await hService.rotxM(
      distance: distanceCorrigee,
      gisementMil: azimutMil.round(),
      latitudeDeg: latitudePieceDeg,
      tirMontagne: tirMontagne,
    );

    double deltaV0M = 0.0;

    if (input.simV0Prev != 0.0 &&
        input.simTempActC != 0.0 &&
        coeffsLong != null) {
      await eService.load();

      final v0Service = V0Service(systeme: systemeArme);

      final String v0TypeAssets = _v0TypeAssetsFor(
        systeme: systemeArme,
        assets: typeAssets,
        charge: charge,
      );

      final double vTab = (await v0Service.v0Ref(
            typeTirAssets: v0TypeAssets,
            charge: charge,
          )) ??
          0.0;

      _log(
        '[APPUI:V0 ROUTING] typeCore=$typeAssets '
        'typeV0=$v0TypeAssets charge=$charge vTab=$vTab',
      );

      final double tempPrevC =
          input.simTempPrevC != 0.0 ? input.simTempPrevC : 21.0;
      final double tempActC =
          input.simTempActC != 0.0 ? input.simTempActC : 21.0;

      final double dVtempAct =
          (await eService.deltaVoTemp(tempPoudreC: tempActC)) ?? 0.0;

      final double dVtempPrev =
          (await eService.deltaVoTemp(tempPoudreC: tempPrevC)) ?? 0.0;

      final double dCarPrev =
          (input.simCarreaux != 0.0 ? input.simCarreaux : 4.0) - 4.0;

      final double dVmassePrev = dCarPrev != 0.0
          ? (await eService.deltaVoParCarreaux(
                charge: charge,
                deltaCarreaux: dCarPrev,
              ) ??
              0.0)
          : 0.0;

      double dVfuseePrev = 0.0;
      double deltaFuseePrevCarreaux = 0.0;

      if (isArt387 && input.fusee.masseGNullable != null) {
        deltaFuseePrevCarreaux =
            (input.fusee.masseGNullable! - masseFuseeReferenceArt387G) /
                grammesParCarreauArt387;

        dVfuseePrev = (await eService.deltaVoParCarreaux(
              charge: charge,
              deltaCarreaux: deltaFuseePrevCarreaux,
            ) ??
            0.0);
      }

      final double v0MesTabPrev =
          input.simV0Prev - dVtempPrev - dVmassePrev - dVfuseePrev;
      final double deltaUsure = v0MesTabPrev - vTab;
      final double deltaV0Totale = deltaUsure + dVtempAct;

      final double kChoisi =
          deltaV0Totale < 0 ? coeffsLong.kV0Moins : coeffsLong.kV0Plus;

      deltaV0M = kChoisi * deltaV0Totale.abs();

      _log(
        '[APPUI:V0] typeV0=$v0TypeAssets vTab=$vTab '
        'simFusee=${input.simFusee} '
        'dVtempPrev=$dVtempPrev '
        'dCarPrev=$dCarPrev '
        'dVmassePrev=$dVmassePrev '
        'deltaFuseePrevCarreaux=$deltaFuseePrevCarreaux '
        'dVfuseePrev=$dVfuseePrev '
        'dVtempAct=$dVtempAct '
        'v0MesTabPrev=$v0MesTabPrev '
        'deltaUsure=$deltaUsure '
        'deltaV0Totale=$deltaV0Totale '
        'deltaV0M=$deltaV0M',
      );
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

    _log(
      '[APPUI:METEO RESULT] '
      'active=$meteoActive rows=${input.meteoRows?.length ?? 0} '
      'Wx=$wxM Wz=$wzMil deltaT=$deltaTBM deltaP=$deltaPBM',
    );

    final double totalCorrectionAzimutMil = deriveMil + rotzMil + wzMil;
    final double noireMil = azimutMil - totalCorrectionAzimutMil;

    final double totalLongM =
        wxM + rotxM + masseM + deltaV0M + deltaTBM + deltaPBM;

    final double porteeAViser = distanceTopo + totalLongM;

    final double aeMil = await fService.hausseMil(
          distance: porteeAViser,
          tirMontagne: tirMontagne,
        ) ??
        0.0;

    final double siteBrutMil = denivelee / (distanceTopo / 1000.0);

    double corrSiteVraiMil = 0.0;

    try {
      corrSiteVraiMil = await Annexe1Service.correctionSiteVrai(siteBrutMil);
    } catch (_) {}

    final double siteTotalAsMil = siteBrutMil + corrSiteVraiMil;

    double acsMil = 0.0;
    double? angleChuteDeg;
    double? cotangenteAngleChute;
    double? ecartProbablePorteeM;
    double? ecartProbableDirectionM;
    double? vitesseRestanteMps;

    try {
      final double k = await gService.kAcs(
        distanceM: porteeAViser,
        asMil: siteTotalAsMil,
      );

      acsMil = siteTotalAsMil.abs() * k;

      final gRow = await gService.rowInterpolated(
        distanceM: porteeAViser,
        tirMontagne: tirMontagne,
      );

      _log(
        '[APPUI:TABLEAU G TERMINAL RAW] '
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
        '[APPUI:TABLEAU G TERMINAL ASSIGNED] '
        'angleDeg=$angleChuteDeg '
        'cot=$cotangenteAngleChute '
        'epp=$ecartProbablePorteeM '
        'epd=$ecartProbableDirectionM '
        'vRest=$vitesseRestanteMps',
      );
    } catch (error, stackTrace) {
      _log('[APPUI:TABLEAU G TERMINAL ERROR] $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    final double aqeMil = aeMil + siteTotalAsMil + acsMil;

    final double tempsVolFinal = await fService.tempageSeconds(
          distance: distanceCorrigee,
          tirMontagne: tirMontagne,
        ) ??
        0.0;

    if (kDebugMode) {
      debugPrint('========== DEBUG BEARING ALIGNMENT ==========');
      debugPrint('azimutInitial = $azimutMil');
      debugPrint('wzMil = -(wzKn * kWz) = $wzMil');
      debugPrint('derive = $deriveMil');
      debugPrint('rotZ = $rotzMil');
      debugPrint('totalCorrectionAzimut = $totalCorrectionAzimutMil');
      debugPrint('finalResult (Firing bearing) = $noireMil');
      debugPrint('================================================');
    }

    if (_tracePerf && sw.elapsedMilliseconds > 0) {
      debugPrint('[APPUI PERF] ${sw.elapsedMilliseconds} ms');
    }

    return CalculResult(
      portee: porteeAViser,
      noireMil: noireMil,
      charge: charge,
      typeAssets: typeAssets,
      tempsVolS: tempsVolFinal,
      tempageDetails: null,
      aqeMil: aqeMil,
      deriveMil: deriveMil,
      rotzMilAbs: rotzMil,
      wzMil: wzMil,
      totalCorrectionAzimutMil: totalCorrectionAzimutMil,
      aeMil: aeMil,
      siteBrutMil: siteBrutMil,
      corrSiteVraiMil: corrSiteVraiMil,
      siteTotalAsMil: siteTotalAsMil,
      acsMil: acsMil,
      wxM: wxM,
      rotxM: rotxM,
      masseM: masseM,
      deltaV0M: deltaV0M,
      deltaTBM: deltaTBM,
      deltaPBM: deltaPBM,
      rtcM: 0.0,
      totalLongM: totalLongM,
      latitudePieceDeg: latitudePieceDeg,
      distanceTopoM: distanceTopo,
      azimutMil: azimutMil,
      deniveleeM: denivelee,
      correctionSiteBM: corrSiteM,
      niveauMeteoBUsed: niveauMeteoEffectif,
      deltaZStationM: input.pdZ - input.meteoStationAltM,
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
