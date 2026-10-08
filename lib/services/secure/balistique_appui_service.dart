// lib/services/balistique_appui_service.dart
//
// PIPELINE APPUI (assets "Appui_*")

import 'package:flutter/foundation.dart';

import '../../models/calcul_data.dart';
import '../../utils/charge_utils.dart' show choisirChargeEnum;

import '../annexe1_service.dart';
import '../tableau_b_service.dart';
import '../tableau_c_service.dart';
import '../tableau_d_service.dart' as tableau_d;
import '../tableau_e_service.dart';
import '../tableau_f_service.dart';
import '../tableau_g_service.dart';
import '../tableau_h_service.dart';
import '../tableau_i_service.dart';
import '../v0_service.dart';

class BalistiqueAppuiService {
  const BalistiqueAppuiService._();

  static const String _typeAssets = 'Appui';

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

  static String _autoChargeFor(double distanceM) =>
      choisirChargeEnum(distanceM, typeTir: TypeTir.appui);

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

    final bool tirMontagne = input.tirMontagne;

    final double distanceTopo = input.objD;
    final double azimutMil = input.objA;
    final double denivelee = input.objAlt - input.pdZ;
    final double latitudePieceDeg = input.pdLatitudeDeg ?? 45.0;

    final bool chargeForcee = _isChargeForced(input);

    final String chargeEst = chargeForcee
        ? _normalizeForcedCharge(input)
        : _autoChargeFor(distanceTopo);

    _throwIfHorsPortee(
      chargeEst,
      context:
          'Out of range (fire support): distance=${distanceTopo.toStringAsFixed(0)}m',
    );

    final bService1 = _bCache.putIfAbsent(
      _key(_typeAssets, chargeEst, tirMontagne),
      () => TableauBService(
        typeTir: _typeAssets,
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

    final String charge =
        chargeForcee ? chargeEst : _autoChargeFor(distanceCorrigee1);

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
      niveauMeteo = bRow1?.niveauMeteo ?? (input.niveauMeteoB ?? 5);
      distanceCorrigee = distanceCorrigee1;
    } else {
      final bService2 = _bCache.putIfAbsent(
        _key(_typeAssets, charge, tirMontagne),
        () => TableauBService(
          typeTir: _typeAssets,
          charge: charge,
          tirMontagne: tirMontagne,
        ),
      );

      final TableauBRow? bRow2 = await bService2.chercher(
        distanceTopoM: distanceTopo,
        deniveleeM: denivelee,
      );

      corrSiteM = bRow2?.correctionSiteM ?? 0.0;
      niveauMeteo = bRow2?.niveauMeteo ?? (input.niveauMeteoB ?? 5);
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

    final cacheKey = _key(_typeAssets, charge, tirMontagne);

    final fService = _fCache.putIfAbsent(
      cacheKey,
      () => TableauFService(typeTir: _typeAssets, charge: charge),
    );

    final iService = _iCache.putIfAbsent(
      cacheKey,
      () => TableauIService(
        typeTir: _typeAssets,
        charge: charge,
        tirMontagne: tirMontagne,
        snapAzToStepMil: 100,
      ),
    );

    final hService = _hCache.putIfAbsent(
      cacheKey,
      () => TableauHService(typeTir: _typeAssets, charge: charge, debug: true),
    );

    final dService = _dCache.putIfAbsent(
      cacheKey,
      () => tableau_d.TableauDService(typeTir: _typeAssets, verbose: true),
    );

    final eService = _eCache.putIfAbsent(
      cacheKey,
      () =>
          TableauEService(typeTir: _typeAssets, charge: charge, verbose: true),
    );

    final cService = _cCache.putIfAbsent(
      cacheKey,
      () => TableauCService(typeTir: _typeAssets, niveauMeteo: niveauMeteo),
    );

    final gService = _gCache.putIfAbsent(
      cacheKey,
      () => TableauGService(
        typeTir: _typeAssets,
        charge: charge,
        tirMontagne: tirMontagne,
        verbose: true,
      ),
    );

    double? metAzMil;
    double? metVKn;
    double? metTbK;
    double? metPress;

    if (input.meteoOn &&
        input.meteoRows != null &&
        input.meteoRows!.isNotEmpty) {
      final meteoRow = _meteoRowForLevel(
        input.meteoRows!,
        niveauMeteo,
        '[${_typeAssets.toUpperCase()}:MET]',
      );

      niveauMeteoEffectif = meteoRow.level;

      metAzMil = meteoRow.azimutMils.toDouble();
      metVKn = meteoRow.vKn.toDouble();
      metTbK = (meteoRow.tempPercent / 100.0) * 288.15;
      metPress = (meteoRow.pressPercent / 100.0) * 1013.25;

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

    if (input.meteoOn &&
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

      // Convention commune :
      // - le tableau C fournit le signe de Wz ;
      // - la correction latérale appliquée à la noire est l'opposé
      //   de la composante Wz multipliée par le coefficient du tableau F.
      wzMil = -(wzKn * kWz);

      final int deltaMil =
          (((metAzMil.round() - azimutMil.round()) % 6400) + 6400) % 6400;

      ventArriere = deltaMil >= 1600 && deltaMil <= 4800;

      final double kVent =
          ventArriere ? coeffsLong.kVentPlus : coeffsLong.kVentMoins;

      ventLongKnAbs = (metVKn * wx1).abs();
      wxM = kVent * ventLongKnAbs;

      _log(
        '[APPUI:VENT SIGN] '
        'azVent=${metAzMil.toStringAsFixed(1)} '
        'azTir=${azimutMil.toStringAsFixed(1)} '
        'vKn=${metVKn.toStringAsFixed(2)} '
        'wxTable=${wx1.toStringAsFixed(4)} '
        'wzTable=${wz1.toStringAsFixed(4)} '
        'wzKn=${wzKn.toStringAsFixed(2)} '
        'kWz=${kWz.toStringAsFixed(4)} '
        'wzMil=${wzMil.toStringAsFixed(2)} '
        'wxM=${wxM.toStringAsFixed(2)}',
      );
    }

    double masseM = 0.0;
    double deltaCarreaux = 0.0;

    if (input.carreauxMasseObus != null) {
      deltaCarreaux = input.carreauxMasseObus! - 4;
    } else if (input.simCarreaux != null) {
      deltaCarreaux = input.simCarreaux! - 4;
    }

    if (input.fusee == TypeFusee.ralec) {
      deltaCarreaux -= 0.2;
    }

    if (deltaCarreaux != 0.0 && coeffsLong != null) {
      final double kMasse =
          deltaCarreaux < 0 ? coeffsLong.kMasseMoins : coeffsLong.kMassePlus;

      masseM = kMasse * deltaCarreaux.abs();
    }

    _log(
      '[APPUI:MASSE] carreauxMasseObus=${input.carreauxMasseObus} '
      'simCarreaux=${input.simCarreaux} '
      'deltaCarreaux=$deltaCarreaux '
      'masseM=$masseM',
    );

    double deltaTBM = 0.0;

    if (input.meteoOn && coeffsLong != null && metTbK != null) {
      final double deltaAltM = input.meteoStationAltM != null
          ? input.pdZ - input.meteoStationAltM!
          : 0.0;

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
    }

    double deltaPBM = 0.0;

    if (input.meteoOn && coeffsLong != null && metPress != null) {
      final double deltaAltM = input.meteoStationAltM != null
          ? input.pdZ - input.meteoStationAltM!
          : 0.0;

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
    }

    double rotxM = await hService.rotxM(
      distance: distanceCorrigee,
      gisementMil: azimutMil.round(),
      latitudeDeg: latitudePieceDeg,
      tirMontagne: tirMontagne,
    );

    double deltaV0M = 0.0;

    if (input.simV0Prev != null &&
        input.simTempActC != null &&
        coeffsLong != null) {
      await eService.load();

      final v0Service = V0Service();

      final double vTab =
          (await v0Service.v0Ref(typeTirAssets: _typeAssets, charge: charge)) ??
              0.0;

      final double tempPrevC = input.simTempPrevC ?? 21.0;
      final double tempActC = input.simTempActC ?? 21.0;

      final double dVtempAct =
          (await eService.deltaVoTemp(tempPoudreC: tempActC)) ?? 0.0;

      final double dVtempPrev =
          (await eService.deltaVoTemp(tempPoudreC: tempPrevC)) ?? 0.0;

      final double dCarPrev = ((input.simCarreaux ?? 4) - 4).toDouble();

      final double dVmassePrev = dCarPrev != 0.0
          ? (await eService.deltaVoParCarreaux(
                charge: charge,
                deltaCarreaux: dCarPrev,
              ) ??
              0.0)
          : 0.0;

      final double v0MesTabPrev = input.simV0Prev! - dVtempPrev - dVmassePrev;
      final double deltaUsure = v0MesTabPrev - vTab;
      final double deltaV0Totale = deltaUsure + dVtempAct;

      final double kChoisi =
          deltaV0Totale < 0 ? coeffsLong.kV0Moins : coeffsLong.kV0Plus;

      deltaV0M = kChoisi * deltaV0Totale.abs();

      _log(
        '[APPUI:V0] vTab=$vTab '
        'dVtempPrev=$dVtempPrev '
        'dVmassePrev=$dVmassePrev '
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

    // wzMil porte déjà son signe. Il doit donc être ajouté au total,
    // et non soustrait une seconde fois.
    final double totalCorrectionAzimutMil = deriveMil + rotzMil + wzMil;
    final double noireMil = azimutMil - totalCorrectionAzimutMil;

    _log(
      '[APPUI:NOIRE SIGN] '
      'azimuth=${azimutMil.toStringAsFixed(2)} '
      'derive=${deriveMil.toStringAsFixed(2)} '
      'rotZ=${rotzMil.toStringAsFixed(2)} '
      'wzMil=${wzMil.toStringAsFixed(2)} '
      'totalAz=${totalCorrectionAzimutMil.toStringAsFixed(2)} '
      'noire=${noireMil.toStringAsFixed(2)}',
    );

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

      // Récupération des données de dispersion depuis le tableau G.
      // Le builder GTBL_V2 stocke l'angle de chute en millièmes.
      final gRow = await gService.rowInterpolated(
        distanceM: porteeAViser,
        tirMontagne: tirMontagne,
      );
      angleChuteDeg = gRow.angleChute * 360.0 / 6400.0;
      cotangenteAngleChute = gRow.cotangenteAngleChute;
      ecartProbablePorteeM = gRow.ecartProbablePortee;
      ecartProbableDirectionM = gRow.ecartProbableDirection;
      vitesseRestanteMps = gRow.vitesseRestante;
    } catch (_) {}

    final double aqeMil = aeMil + siteTotalAsMil + acsMil;

    final double tempsVolFinal = await fService.tempageSeconds(
          distance: distanceCorrigee,
          tirMontagne: tirMontagne,
        ) ??
        0.0;

    if (_tracePerf && sw.elapsedMilliseconds > 0) {
      debugPrint('[APPUI PERF] ${sw.elapsedMilliseconds} ms');
    }

    return CalculResult(
      portee: porteeAViser,
      noireMil: noireMil,
      charge: charge,
      typeAssets: _typeAssets,
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
      // CalculResult expose désormais des valeurs numériques non nullables.
      // Une donnée balistique indisponible est représentée par sa valeur neutre.
      deltaZStationM: input.meteoOn ? input.pdZ - input.meteoStationAltM : 0.0,
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
  }
}
