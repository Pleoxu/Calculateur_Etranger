// lib/services/balistique_core_service.dart
//
// PHASE 2D — CORE SERVICE (moteur commun)
// Moteur algébrique pur + arrondis doctrinaux intermédiaires.
import 'package:flutter/foundation.dart';
import 'secure_asset_resolver.dart';
import '../domain/fire/services/ballistic_asset_context.dart';
import '../models/calcul_data.dart';
import '../utils/charge_utils.dart' show choisirChargeCaesar, choisirChargeEnum;
import 'selection_charge_facade.dart';
import 'tableau_b_service.dart';
import 'tableau_c_service.dart';
import 'tableau_d_service.dart' as tableau_d;
import 'tableau_e_service.dart';
import 'tableau_f3i_service.dart';
import 'tableau_f_service.dart';
import 'tableau_h_service.dart';
import 'tableau_i_service.dart';
import 'v0_service.dart';

class BalistiqueCoreResult {
  final String typeAssets;
  final TypeTir typeEnum;
  final bool tirMontagne;
  final String charge;
  final double distanceTopoM;
  final double deniveleeM;
  final double azimutMil;
  final double latitudePieceDeg;
  final double correctionSiteBM;
  final int niveauMeteoBUsed;
  final double distanceCorrigeeM;
  final double? metAzMil;
  final double? metVKn;
  final double? metTbK;
  final double? metPressHpa;
  final double deriveMil;
  final double rotzMilAbs;
  final double wzMil;
  final double totalCorrectionAzimutMil;
  final double noireMil;
  final double wxM;
  final double rotxM;
  final double masseM;
  final double deltaTBM;
  final double deltaPBM;
  final double deltaTbPctSigned;
  final double deltaDbPctSigned;
  final double deltaV0MpsSigned;
  final double ventLongKnAbs;
  final bool ventArriere;
  final double deltaV0M;
  final double rtcM;
  final double totalLongM;
  final double porteeAViserM;
  final double aeMil;

  const BalistiqueCoreResult({
    required this.typeAssets,
    required this.typeEnum,
    required this.tirMontagne,
    required this.charge,
    required this.distanceTopoM,
    required this.deniveleeM,
    required this.azimutMil,
    required this.latitudePieceDeg,
    required this.correctionSiteBM,
    required this.niveauMeteoBUsed,
    required this.distanceCorrigeeM,
    this.metAzMil,
    this.metVKn,
    this.metTbK,
    this.metPressHpa,
    required this.deriveMil,
    required this.rotzMilAbs,
    required this.wzMil,
    required this.totalCorrectionAzimutMil,
    required this.noireMil,
    required this.wxM,
    required this.rotxM,
    required this.masseM,
    required this.deltaTBM,
    required this.deltaPBM,
    required this.deltaTbPctSigned,
    required this.deltaDbPctSigned,
    required this.deltaV0MpsSigned,
    required this.ventLongKnAbs,
    required this.ventArriere,
    required this.deltaV0M,
    required this.rtcM,
    required this.totalLongM,
    required this.porteeAViserM,
    required this.aeMil,
  });
}

class BalistiqueCoreService {
  const BalistiqueCoreService._();
  static final Map<String, TableauBService> _bCache = {};
  static final Map<String, TableauFService> _fCache = {};
  static final Map<String, TableauIService> _iCache = {};
  static final Map<String, TableauHService> _hCache = {};
  static final Map<String, tableau_d.TableauDService> _dCache = {};
  static final Map<String, TableauEService> _eCache = {};
  static final Map<String, TableauF3iService> _f3iCache = {};
  static final Map<String, TableauCService> _cCache = {};
  static String _key(String typeAssets, String charge, bool montagne) =>
      '$typeAssets|$charge|$montagne';
  static double _round1(double v) => (v * 10.0).roundToDouble() / 10.0;
  static double _round2(double v) => (v * 100.0).roundToDouble() / 100.0;

  static String _typeAssetsFor(
    CalculInput input,
    TypeTir typeEnum, {
    String? forced,
  }) {
    if (forced != null && forced.trim().isNotEmpty) {
      return forced.trim().toUpperCase();
    }

    return BallisticAssetContext(
      systeme: input.systeme,
      typeTir: typeEnum,
      typeChargeCaesar: (input as dynamic).typeChargeCaesar,
      typeMunition: input.typeMunition,
    ).variant;
  }

  static String _v0TypeAssetsFor({
    required SystemeArme systeme,
    required String assets,
    required String charge,
  }) {
    final normalized = assets.trim().toUpperCase();

    if (RegExp(r'_ART\d+$').hasMatch(normalized)) {
      return normalized;
    }

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
          '[CORE:V0 ROUTING] résolution article impossible '
          'type=$normalized charge=$charge : $e',
        );
      }
    }

    return normalized;
  }

  static bool _usesRtcLoop(String assets) {
    switch (assets.trim().toUpperCase()) {
      case 'OECL':
      case 'OECL_ART392':
        return true;
      case 'OECL_ART385':
      case 'OECL_ALL':
        return false;
      case 'APPUIRTC':
      case 'APPUIRTC_ALL':
      case 'OEF2RTC_ALL':
      case 'OEF5RTC_ALL':
        return true;
      default:
        return false;
    }
  }

  static SystemeArme _systemeArmeFor(Systeme systeme) {
    return switch (systeme) {
      Systeme.caesar => SystemeArme.caesar,
      Systeme.mo120 => SystemeArme.mo,
      Systeme.mepac => SystemeArme.mepac,
      Systeme.mo81M252 => SystemeArme.mo,
      Systeme.mo81Lrr => SystemeArme.mo,
    };
  }

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

  static Future<String> _selectCaesarCharge({
    required String typeAssets,
    required double distanceTopoM,
    required bool tirMontagne,
    required TypeTir typeEnum,
    required CalculInput input,
  }) async {
    final String fallback = choisirChargeCaesar(
      distanceTopoM,
      typeTir: typeEnum,
      typeChargeCaesar: (input as dynamic).typeChargeCaesar,
    );

    try {
      final selection = await SelectionChargeFacade.selectCaesar(
        typeTirAssets: typeAssets,
        distanceM: distanceTopoM,
        tirMontagne: tirMontagne,
        verbose: kDebugMode,
      );

      if (selection == null) {
        if (kDebugMode) {
          debugPrint(
            '[CORE:SELECTION CHARGE] '
            'Aucune charge sélectionnée par Ex '
            'type=$typeAssets '
            'distance=${distanceTopoM.toStringAsFixed(0)}m '
            'tirMontagne=$tirMontagne '
            '=> fallback=$fallback',
          );
        }

        return fallback;
      }

      if (kDebugMode) {
        debugPrint(
          '[CORE:SELECTION CHARGE] '
          'type=$typeAssets '
          'distance=${distanceTopoM.toStringAsFixed(0)}m '
          'tirMontagne=$tirMontagne '
          'charge=${selection.charge} '
          'Ex=${selection.criterionValue.toStringAsFixed(3)} '
          'fallbackHistorique=$fallback '
          'candidats=${selection.candidates}',
        );
      }

      return selection.charge;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[CORE:SELECTION CHARGE] '
          'Échec de la sélection par Ex '
          'type=$typeAssets '
          'distance=${distanceTopoM.toStringAsFixed(0)}m '
          'tirMontagne=$tirMontagne '
          '=> fallback=$fallback : $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }

      return fallback;
    }
  }

  static double _sane(double v, String label) {
    if (!v.isFinite) {
      if (kDebugMode) debugPrint('[CORE] $label invalide: $v -> 0');
      return 0.0;
    }
    if (v.abs() > 100000) {
      if (kDebugMode) debugPrint('[CORE] $label aberrant: $v -> 0');
      return 0.0;
    }

    return v;
  }

  static Future<BalistiqueCoreResult> compute(
    CalculInput input, {
    required TypeTir typeEnum,
    String? typeAssets,
  }) async {
    final sw = Stopwatch()..start();
    final String assets = _typeAssetsFor(input, typeEnum, forced: typeAssets);
    final SystemeArme systemeArme = _systemeArmeFor(input.systeme);
    final bool tirMontagne = input.tirMontagne;

    final double distanceTopoM =
        (input as dynamic).objD ?? input.distanceM ?? 0.0;
    final double azimutMil = (input as dynamic).objA ?? 0.0;
    final double deniveleeM = ((input as dynamic).objAlt ?? 0.0) - input.pdZ;
    final double latitudePieceDeg = (input as dynamic).pdLatitudeDeg ?? 45.0;

    final bool chargeForcee = _isChargeForced(input);

    String chargeEst;
    if (chargeForcee) {
      chargeEst = _normalizeForcedCharge(input);
    } else if (input.systeme == Systeme.caesar) {
      chargeEst = await _selectCaesarCharge(
        typeAssets: assets,
        distanceTopoM: distanceTopoM,
        tirMontagne: tirMontagne,
        typeEnum: typeEnum,
        input: input,
      );
    } else {
      chargeEst = choisirChargeEnum(distanceTopoM, typeTir: typeEnum);
    }

    if (chargeEst == 'HorsPortee') {
      throw ArgumentError(
        'Hors portée: type=$assets '
        'distance=${distanceTopoM.toStringAsFixed(0)}m',
      );
    }

    final bService1 = _bCache.putIfAbsent(
      _key(assets, chargeEst, tirMontagne),
      () => TableauBService(
        systeme: systemeArme,
        typeTir: assets,
        charge: chargeEst,
        tirMontagne: tirMontagne,
      ),
    );

    final TableauBRow? bRow1 = await bService1.chercher(
      distanceTopoM: distanceTopoM,
      deniveleeM: deniveleeM,
    );

    final double corrSiteM1 = bRow1?.correctionSiteM ?? 0.0;
    final double distanceCorrigee1 = distanceTopoM + corrSiteM1;

    final String charge = chargeEst;

    final double correctionSiteBM = corrSiteM1;
    final int niveauMeteoBUsed =
        bRow1?.niveauMeteo ?? ((input as dynamic).niveauMeteoB ?? 5);
    final double distanceCorrigeeM = distanceCorrigee1;

    if (kDebugMode) {
      debugPrint(
        '[CORE:B] type=$assets charge=$charge${chargeForcee ? " (FORCÉE)" : ""} '
        'corrSite=${correctionSiteBM.toStringAsFixed(0)}m '
        'niveau=$niveauMeteoBUsed distCorr=${distanceCorrigeeM.toStringAsFixed(0)}m',
      );
    }

    final cacheKey = _key(assets, charge, tirMontagne);

    final fService = _fCache.putIfAbsent(
      cacheKey,
      () => TableauFService(
        systeme: systemeArme,
        typeTir: assets,
        charge: charge,
      ),
    );

    final iService = _iCache.putIfAbsent(
      cacheKey,
      () => TableauIService(
        systeme: systemeArme,
        typeTir: assets,
        charge: charge,
        tirMontagne: tirMontagne,
        snapAzToStepMil: 100,
      ),
    );

    final hService = _hCache.putIfAbsent(
      cacheKey,
      () => TableauHService(
        systeme: systemeArme,
        typeTir: assets,
        charge: charge,
      ),
    );

    final dService = _dCache.putIfAbsent(
      cacheKey,
      () => tableau_d.TableauDService(typeTir: assets, verbose: false),
    );

    final eService = _eCache.putIfAbsent(
      cacheKey,
      () => TableauEService(
        systeme: systemeArme,
        typeTir: assets,
        charge: charge,
        verbose: true,
      ),
    );

    final cService = _cCache.putIfAbsent(
      cacheKey,
      () => TableauCService(typeTir: assets, niveauMeteo: niveauMeteoBUsed),
    );

    double? metAzMil;
    double? metVKn;
    double? metTempPercent;
    double? metPressPercent;

    final meteoRows = input.meteoRows;
    final bool isMeteoOn = (input as dynamic).meteoOn ?? false;
    if (isMeteoOn && meteoRows != null && meteoRows.isNotEmpty) {
      final meteoRow = meteoRows.firstWhere(
        (r) => r.level == niveauMeteoBUsed,
        orElse: () => meteoRows.first,
      );

      metAzMil = meteoRow.azimutMils.toDouble();
      metVKn = meteoRow.vKn.toDouble();
      metTempPercent = meteoRow.tempPercent.toDouble();
      metPressPercent = meteoRow.pressPercent.toDouble();
    }

    double deriveMil = await fService.deriveMil(
          distance: distanceCorrigeeM,
          tirMontagne: tirMontagne,
        ) ??
        0.0;

    final double kWz = await fService.correctionWz(
          distance: distanceCorrigeeM,
          tirMontagne: tirMontagne,
        ) ??
        0.0;

    final FLongCoeffs? coeffsLong = await fService.correctionsLongitudinales(
      distance: distanceCorrigeeM,
      tirMontagne: tirMontagne,
    );

    await iService.load();

    double rotzMilAbs = (await iService.rotZ(
          distance: distanceCorrigeeM,
          azimutMil: azimutMil.round(),
          latitudeDeg: latitudePieceDeg,
          tirMontagne: tirMontagne,
          absolute: false,
        ))
            ?.abs() ??
        0.0;

    double wzMil = 0.0;
    double wxM = 0.0;
    double ventLongKnAbs = 0.0;
    bool ventArriere = false;

    if (isMeteoOn && coeffsLong != null && metAzMil != null && metVKn != null) {
      final comp = await cService.composantesVent(
        directionVent: metAzMil.round(),
        gisementTir: azimutMil.round(),
      );

      final double wx1 = _round2((comp['wx'] as num).toDouble());
      final double wz1 = _round2((comp['wz'] as num).toDouble());

      final double wxKn = _round1(metVKn * wx1);
      final double wzKn = _round1(metVKn * wz1);

      ventLongKnAbs = wxKn.abs();

      final int deltaMil =
          (((metAzMil.round() - azimutMil.round()) % 6400) + 6400) % 6400;

      ventArriere = deltaMil >= 1600 && deltaMil <= 4800;

      final double kVent =
          wxKn >= 0.0 ? coeffsLong.kVentMoins : coeffsLong.kVentPlus;

      wxM = kVent * wxKn.abs();

      wzMil = -(wzKn * kWz);

      if (kDebugMode) {
        debugPrint(
          '[CORE:WZ SIGN] type=$assets '
          'wzTable=$wz1 vKn=$metVKn wzKn=$wzKn '
          'kWz=$kWz => wzMil=$wzMil',
        );
      }
    }

    double masseM = 0.0;

    if (coeffsLong != null) {
      if (assets.toUpperCase() == 'OECL_ART385') {
        if (input.fusee == TypeFusee.fuchsia) {
          const double masseFuseeReferenceG = 950.0;
          const double masseFuseeFuchsiaG = 710.0;
          const double grammesParCarreau = 500.0;

          final double deltaCarreauxFusee =
              (masseFuseeFuchsiaG - masseFuseeReferenceG) / grammesParCarreau;

          final double kMasse = deltaCarreauxFusee < 0.0
              ? coeffsLong.kMasseMoins
              : coeffsLong.kMassePlus;

          masseM = kMasse * deltaCarreauxFusee.abs();

          if (kDebugMode) {
            debugPrint(
              '[CORE:MASSE FUSEE] '
              'type=$assets '
              'fusee=${input.fusee} '
              'mRef=${masseFuseeReferenceG.toStringAsFixed(0)}g '
              'mUtilisee=${masseFuseeFuchsiaG.toStringAsFixed(0)}g '
              'delta=${(masseFuseeFuchsiaG - masseFuseeReferenceG).toStringAsFixed(0)}g '
              'deltaCarreaux=${deltaCarreauxFusee.toStringAsFixed(2)} '
              'kMasse=$kMasse '
              'masseM=${masseM.toStringAsFixed(2)}',
            );
          }
        } else if (kDebugMode) {
          debugPrint(
            '[CORE:MASSE FUSEE] '
            'type=$assets fusee=${input.fusee} '
            'référence FU DE F2 => correction=0m',
          );
        }
      } else if (typeEnum != TypeTir.eclairant) {
        double deltaCarreaux = 0.0;

        final double? carreauxMasse = (input as dynamic).carreauxMasseObus;
        if (carreauxMasse != null) {
          deltaCarreaux += carreauxMasse - 4;
        } else if (input.simCarreaux != null) {
          deltaCarreaux += input.simCarreaux! - 4;
        }

        if (deltaCarreaux != 0.0) {
          final double kMasse = deltaCarreaux < 0.0
              ? coeffsLong.kMasseMoins
              : coeffsLong.kMassePlus;

          masseM = kMasse * deltaCarreaux.abs();
        }
      }
    }

    double deltaTBM = 0.0;
    double deltaTbPctSigned = 0.0;

    if (isMeteoOn && coeffsLong != null && metTempPercent != null) {
      final double deltaAltM = input.meteoStationAltM != null
          ? input.pdZ - input.meteoStationAltM!
          : 0.0;

      final double dVal = await dService.valueTbPctAtAbsDelta(
        deltaAltM: deltaAltM,
      );

      final double applied = deltaAltM < 0.0 ? -dVal : dVal;

      final double tbCorrPct = double.parse(
        (metTempPercent + applied).toStringAsFixed(1),
      );

      deltaTbPctSigned = double.parse((tbCorrPct - 100.0).toStringAsFixed(1));

      final double kTemp = deltaTbPctSigned >= 0.0
          ? coeffsLong.kTempPlus
          : coeffsLong.kTempMoins;

      deltaTBM = kTemp * deltaTbPctSigned.abs();
    }

    double deltaPBM = 0.0;
    double deltaDbPctSigned = 0.0;

    if (isMeteoOn && coeffsLong != null && metPressPercent != null) {
      final double deltaAltM = input.meteoStationAltM != null
          ? input.pdZ - input.meteoStationAltM!
          : 0.0;

      final double dVal = await dService.valuePbPctAtAbsDelta(
        deltaAltM: deltaAltM,
      );

      final double applied = deltaAltM < 0.0 ? -dVal : dVal;

      final double dbCorrPct = double.parse(
        (metPressPercent + applied).toStringAsFixed(1),
      );

      deltaDbPctSigned = double.parse((dbCorrPct - 100.0).toStringAsFixed(1));

      final double kPression = deltaDbPctSigned >= 0.0
          ? coeffsLong.kPressionPlus
          : coeffsLong.kPressionMoins;

      deltaPBM = kPression * deltaDbPctSigned.abs();
    }

    double rotxM = await hService.rotxM(
      distance: distanceCorrigeeM,
      gisementMil: azimutMil.round(),
      latitudeDeg: latitudePieceDeg,
      tirMontagne: tirMontagne,
    );

    double deltaV0M = 0.0;
    double deltaV0MpsSigned = 0.0;

    final double? simV0Prev = (input as dynamic).simV0Prev;
    final double? simTempActC = (input as dynamic).simTempActC;
    final double? simTempPrevC = (input as dynamic).simTempPrevC;

    if (coeffsLong != null && simV0Prev != null && simTempActC != null) {
      final v0Service = V0Service(systeme: systemeArme);

      final String v0Assets = _v0TypeAssetsFor(
        systeme: systemeArme,
        assets: assets,
        charge: charge,
      );

      final double vTab =
          (await v0Service.v0Ref(typeTirAssets: v0Assets, charge: charge)) ??
              0.0;

      if (kDebugMode) {
        debugPrint(
          '[CORE:V0 ROUTING] typeCore=$assets '
          'typeV0=$v0Assets charge=$charge vTab=$vTab',
        );
      }

      final bool isOeclArt385 = assets.toUpperCase() == 'OECL_ART385';

      late final double deltaV0Totale;

      if (isOeclArt385) {
        deltaV0Totale = _round1(simV0Prev - vTab);

        if (kDebugMode) {
          debugPrint(
            '[CORE:V0 ART385] '
            'charge=$charge '
            'v0Prev=$simV0Prev '
            'vTab=$vTab '
            'deltaV0=$deltaV0Totale',
          );
        }
      } else {
        await eService.load();

        final double tempPrevC = simTempPrevC ?? 21.0;
        final double tempTirC = simTempActC ?? 21.0;

        final double dVtempPrev =
            (await eService.deltaVoTemp(tempPoudreC: tempPrevC)) ?? 0.0;

        final double v0MesTabPrev = simV0Prev - dVtempPrev;
        final double deltaUsure = v0MesTabPrev - vTab;

        final double dVtempTir =
            (await eService.deltaVoTemp(tempPoudreC: tempTirC)) ?? 0.0;

        deltaV0Totale = _round1(deltaUsure + dVtempTir);

        if (kDebugMode) {
          debugPrint(
            '[CORE:V0 DETAIL] '
            'type=$assets '
            'typeV0=$v0Assets '
            'charge=$charge '
            'v0Prev=$simV0Prev '
            'vTab=$vTab '
            'tempPrev=$tempPrevC '
            'dVtempPrev=$dVtempPrev '
            'v0MesTabPrev=$v0MesTabPrev '
            'deltaUsure=$deltaUsure '
            'tempTir=$tempTirC '
            'dVtempTir=$dVtempTir '
            'deltaV0Totale=$deltaV0Totale',
          );
        }
      }

      deltaV0MpsSigned = deltaV0Totale;

      final double kV0 =
          deltaV0Totale >= 0.0 ? coeffsLong.kV0Plus : coeffsLong.kV0Moins;

      deltaV0M = kV0 * deltaV0Totale.abs();

      if (kDebugMode) {
        debugPrint(
          '[CORE:V0 RESULT] '
          'type=$assets charge=$charge '
          'deltaV0=$deltaV0Totale '
          'kV0=$kV0 '
          'deltaV0M=$deltaV0M',
        );
      }
    }

    double rtcM = 0.0;

    if (_usesRtcLoop(assets)) {
      final f3iService = _f3iCache.putIfAbsent(
        cacheKey,
        () => TableauF3iService(
          typeTir: assets,
          charge: charge,
          tirMontagne: tirMontagne,
        ),
      );

      final double tempMunitionC = simTempActC ?? 21.0;

      rtcM = await f3iService.interp(
        distance: distanceCorrigeeM,
        tempC: tempMunitionC,
      );
    } else if (kDebugMode) {
      debugPrint(
        '[CORE:RTC] boucle RTC ignorée pour type=$assets '
        '(aucune table F3i requise)',
      );
    }

    deriveMil = _sane(deriveMil, 'deriveMil');
    rotzMilAbs = _sane(rotzMilAbs, 'rotzMilAbs');
    wzMil = _sane(wzMil, 'wzMil');

    wxM = _sane(wxM, 'wxM');
    rotxM = _sane(rotxM, 'rotxM');
    deltaV0M = _sane(deltaV0M, 'deltaV0M');
    deltaTBM = _sane(deltaTBM, 'deltaTBM');
    deltaPBM = _sane(deltaPBM, 'deltaPBM');
    rtcM = _sane(rtcM, 'rtcM');
    masseM = _sane(masseM, 'masseM');

    final double totalCorrectionAzimutMil = deriveMil + rotzMilAbs + wzMil;
    final double noireMil = azimutMil - totalCorrectionAzimutMil;

    if (kDebugMode) {
      debugPrint(
        '[CORE:LATERAL FINAL] type=$assets '
        'azimut=$azimutMil derive=$deriveMil rotZ=$rotzMilAbs '
        'wzMil=$wzMil totalAz=$totalCorrectionAzimutMil '
        'noire=$noireMil',
      );
    }

    final double wxMRounded = wxM.roundToDouble();
    final double rotxMRounded = rotxM.roundToDouble();
    final double deltaTBMRounded = deltaTBM.roundToDouble();
    final double deltaPBMRounded = deltaPBM.roundToDouble();
    final double deltaV0MRounded = deltaV0M.roundToDouble();
    final double rtcMRounded = rtcM.roundToDouble();
    final double masseMRounded = masseM.roundToDouble();

    final double totalLongM = wxMRounded +
        rotxMRounded +
        deltaTBMRounded +
        deltaPBMRounded +
        deltaV0MRounded +
        rtcMRounded +
        masseMRounded;

    final double porteeAViserM = distanceTopoM + totalLongM;

    if (kDebugMode) {
      debugPrint(
        '[CORE:LONG] '
        'baseCalc=${distanceCorrigeeM.toStringAsFixed(1)} '
        'basePav=${distanceTopoM.toStringAsFixed(1)} '
        'wx=${wxMRounded.toStringAsFixed(0)} '
        'rotx=${rotxMRounded.toStringAsFixed(0)} '
        'tb=${deltaTBMRounded.toStringAsFixed(0)} '
        'pb=${deltaPBMRounded.toStringAsFixed(0)} '
        'v0=${deltaV0MRounded.toStringAsFixed(0)} '
        'rtc=${rtcMRounded.toStringAsFixed(0)} '
        'masse=${masseMRounded.toStringAsFixed(0)} '
        '=> total=${totalLongM.toStringAsFixed(0)} '
        'PAV=${porteeAViserM.toStringAsFixed(0)}',
      );
    }

    final double aeMil = await fService.hausseMil(
          distance: porteeAViserM,
          tirMontagne: tirMontagne,
        ) ??
        0.0;

    if (kDebugMode) {
      debugPrint(
        '[CORE] noire=${noireMil.toStringAsFixed(2)} '
        'porteeAViser=${porteeAViserM.toStringAsFixed(0)}m '
        'AE=${aeMil.toStringAsFixed(2)} '
        '(perf ${sw.elapsedMilliseconds}ms)',
      );
    }

    return BalistiqueCoreResult(
      typeAssets: assets,
      typeEnum: typeEnum,
      tirMontagne: tirMontagne,
      charge: charge,
      distanceTopoM: distanceTopoM,
      deniveleeM: deniveleeM,
      azimutMil: azimutMil,
      latitudePieceDeg: latitudePieceDeg,
      correctionSiteBM: correctionSiteBM,
      niveauMeteoBUsed: niveauMeteoBUsed,
      distanceCorrigeeM: distanceCorrigeeM,
      metAzMil: metAzMil,
      metVKn: metVKn,
      metTbK: null,
      metPressHpa: null,
      deriveMil: deriveMil,
      rotzMilAbs: rotzMilAbs,
      wzMil: wzMil,
      totalCorrectionAzimutMil: totalCorrectionAzimutMil,
      noireMil: noireMil,
      wxM: wxMRounded,
      rotxM: rotxMRounded,
      masseM: masseMRounded,
      deltaTBM: deltaTBMRounded,
      deltaPBM: deltaPBMRounded,
      deltaTbPctSigned: deltaTbPctSigned,
      deltaDbPctSigned: deltaDbPctSigned,
      deltaV0MpsSigned: deltaV0MpsSigned,
      ventLongKnAbs: ventLongKnAbs,
      ventArriere: ventArriere,
      deltaV0M: deltaV0MRounded,
      rtcM: rtcMRounded,
      totalLongM: totalLongM,
      porteeAViserM: porteeAViserM,
      aeMil: aeMil,
    );
  }

  static void clearCaches() {
    _bCache.clear();
    _fCache.clear();
    _iCache.clear();
    _hCache.clear();
    _dCache.clear();
    _eCache.clear();
    _f3iCache.clear();
    _cCache.clear();
    SelectionChargeFacade.clearCache();
  }
}
