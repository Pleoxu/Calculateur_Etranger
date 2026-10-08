// lib/services/balistique_mo120_appui_service.dart
//
// PIPELINE APPUI MO-120 RTF1
//
// Convention d'assets :
//   - Tableaux B, E, F, G, I : préfixe "MO_APPUI" (ex. MO_B_APPUI_CH0)
//   - Tableau H principal     : préfixe "MO_H_APPUI" (ex. MO_H_APPUI_CH0)
//   - Tableau H facteurs lat  : H_FACTEURLATITUDE (commun Caesar/MO-120)
//   - Tableaux C et D         : communs Caesar/MO-120 (assets "Appui")
//
// Charges : CH0 à CH10 (14 charges), sélection via choisirChargeMo120().

import 'package:flutter/foundation.dart';

import '../models/calcul_data.dart';
import '../utils/charge_utils.dart' show choisirChargeMo120;

import 'annexe1_service.dart';
import 'tableau_b_service.dart';
import 'tableau_c_service.dart';
import 'tableau_d_service.dart' as tableau_d;
import 'tableau_e_service.dart';
import 'tableau_f_service.dart';
import 'tableau_g_service.dart';
import 'tableau_h_service.dart';
import 'tableau_i_service.dart';
import 'secure_asset_resolver.dart';
import 'v0_service.dart';

class BalistiqueMo120AppuiService {
  const BalistiqueMo120AppuiService._();

  /// Préfixe utilisé pour les assets spécifiques MO-120.
  static const String _typeAssets = 'MO_APPUI';

  static const bool _traceTP = true;

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

  static String _key(String charge, bool tirMontagne) =>
      '${_typeAssets}_${charge}_TM$tirMontagne';

  static void _throwIfHorsPortee(String charge, {required String context}) {
    if (charge == 'HorsPortee') {
      throw ArgumentError(context);
    }
  }

  static double _sane(double v, String label) {
    if (!v.isFinite) {
      _log('[MO120:SANE] $label invalide: $v -> 0');
      return 0.0;
    }
    if (v.abs() > 100000) {
      _log('[MO120:SANE] $label aberrant: $v -> 0');
      return 0.0;
    }
    return v;
  }

  static bool _isChargeForced(CalculInput input) =>
      input.chargeForcee != null && input.chargeForcee!.trim().isNotEmpty;

  static String _normalizeForcedCharge(CalculInput input) =>
      input.chargeForcee!.trim().toUpperCase();

  static String _autoChargeFor(double distance) => choisirChargeMo120(distance);

  // ── Point d'entrée principal ─────────────────────────────────────────────
  static Future<CalculResult> calculer(CalculInput input) async {
    assert(
      input.systeme == Systeme.mo120,
      'BalistiqueMo120AppuiService ne gère que Systeme.mo120',
    );

    final bool tirMontagne = input.tirMontagne;
    final double distanceTopo = input.objD;
    final double azimutMil = input.objA;
    final double denivelee = input.objAlt - input.pdZ;
    final double latitudePieceDeg = input.pdLatitudeDeg ?? 45.0;

    // ── Sélection de charge ──────────────────────────────────────────────
    final bool chargeForcee = _isChargeForced(input);
    final String charge = chargeForcee
        ? _normalizeForcedCharge(input)
        : _autoChargeFor(distanceTopo);

    _throwIfHorsPortee(
      charge,
      context:
          'Hors portée MO-120 : distance=${distanceTopo.toStringAsFixed(0)} m',
    );

    final cacheKey = _key(charge, tirMontagne);

    // ── Tableau B : correction de site ──────────────────────────────────
    final bService = _bCache.putIfAbsent(
      cacheKey,
      () => TableauBService(
        systeme: SystemeArme.mo,
        typeTir: 'APPUI',
        charge: charge,
        tirMontagne: tirMontagne,
      ),
    );

    final TableauBRow? bRow = await bService.chercher(
      distanceTopoM: distanceTopo,
      deniveleeM: denivelee,
    );

    final double corrSiteM = bRow?.correctionSiteM ?? 0.0;
    final int niveauMeteo = bRow?.niveauMeteo ?? (input.niveauMeteoB ?? 1);
    final double distanceCorrigee = distanceTopo + corrSiteM;

    _log(
      '[MO120:B] charge=$charge${chargeForcee ? " (FORCÉE)" : ""} '
      'corrSite=${corrSiteM.toStringAsFixed(1)} m '
      'niveauMeteo=$niveauMeteo '
      'distTopo=${distanceTopo.toStringAsFixed(1)} m '
      'distCorr=${distanceCorrigee.toStringAsFixed(1)} m',
    );

    // ── Services tableaux ────────────────────────────────────────────────
    final fService = _fCache.putIfAbsent(
      cacheKey,
      () => TableauFService(
        systeme: SystemeArme.mo,
        typeTir: 'APPUI',
        charge: charge,
      ),
    );

    final iService = _iCache.putIfAbsent(
      cacheKey,
      () => TableauIService(
        systeme: SystemeArme.mo,
        typeTir: 'APPUI',
        charge: charge,
        tirMontagne: tirMontagne,
        snapAzToStepMil: 100,
      ),
    );

    // Tableau H : assets principaux MO_H_APPUI_CHx,
    // facteurs latitude H_FACTEURLATITUDE (commun, chargé automatiquement).
    final hService = _hCache.putIfAbsent(
      cacheKey,
      () => TableauHService(
        systeme: SystemeArme.mo,
        typeTir: 'APPUI',
        charge: charge,
      ),
    );

    // Tableaux C et D : communs Caesar / MO-120
    final dService = _dCache.putIfAbsent(
      cacheKey,
      () => tableau_d.TableauDService(typeTir: 'Appui', verbose: true),
    );

    final eService = _eCache.putIfAbsent(
      cacheKey,
      () => TableauEService(
        systeme: SystemeArme.mo,
        typeTir: 'APPUI',
        charge: charge,
        verbose: true,
      ),
    );

    final cService = _cCache.putIfAbsent(
      cacheKey,
      () => TableauCService(typeTir: 'Appui', niveauMeteo: niveauMeteo),
    );

    final gService = _gCache.putIfAbsent(
      cacheKey,
      () => TableauGService(
        systeme: SystemeArme.mo,
        typeTir: 'APPUI',
        charge: charge,
        tirMontagne: tirMontagne,
        verbose: true,
      ),
    );

    // ── Météo ────────────────────────────────────────────────────────────
    double? metAzMil;
    double? metVKn;
    double? metTbK;
    double? metPress;

    if (input.meteoOn &&
        input.meteoRows != null &&
        input.meteoRows!.isNotEmpty) {
      final rows = input.meteoRows!;
      // Chercher la ligne au niveau météo issu du tableau B
      final sorted = [...rows]..sort(
          (a, b) => ((a as dynamic).level as int).compareTo(
            (b as dynamic).level as int,
          ),
        );
      final picked = sorted.reduce((a, b) {
        final da = (((a as dynamic).level as int) - niveauMeteo).abs();
        final db = (((b as dynamic).level as int) - niveauMeteo).abs();
        return da <= db ? a : b;
      });
      metAzMil = ((picked as dynamic).azimutMils as num).toDouble();
      metVKn = ((picked as dynamic).vKn as num).toDouble();
      metTbK =
          ((picked as dynamic).tempPercent as num).toDouble() / 100.0 * 288.15;
      metPress = ((picked as dynamic).pressPercent as num).toDouble() /
          100.0 *
          1013.25;
    }

    // ── Tableau F : coefficients balistiques ────────────────────────────
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

    // ── Tableau I : correction gisement rotation Terre ───────────────────
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

    // ── Vent (Tableau C + Tableau F) ─────────────────────────────────────
    double wzMil = 0.0;
    double wxM = 0.0;

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
      wzMil = -(wzKn * kWz);

      _log(
        '[MO120:WZ SIGN] '
        'wzTable=$wz1 vKn=$metVKn wzKn=$wzKn '
        'kWz=$kWz => wzMil=$wzMil',
      );

      final int deltaMil =
          (((metAzMil.round() - azimutMil.round()) % 6400) + 6400) % 6400;
      final bool ventArriere = deltaMil >= 1600 && deltaMil <= 4800;
      final double kVent =
          ventArriere ? coeffsLong.kVentPlus : coeffsLong.kVentMoins;
      final double ventLongKnAbs = (metVKn * wx1).abs();
      wxM = kVent * ventLongKnAbs;
    }

    // ── Masse obus ────────────────────────────────────────────────────────
    // MO-120 : masse tabulaire = 2 carreaux.
    //
    // La correction directe de portée doit être lue explicitement dans les
    // colonnes correctionMasseMoins / correctionMassePlus du tableau F.
    // Cette lecture dédiée évite toute confusion avec les coefficients de vent.
    double masseM = 0.0;
    final double deltaCarreaux =
        ((input.carreauxMasseObus ?? input.simCarreaux ?? 2) - 2).toDouble();

    if (deltaCarreaux.abs() > 1e-9) {
      masseM = await fService.correctionMasseM(
        distance: distanceCorrigee,
        tirMontagne: tirMontagne,
        deltaCarreaux: deltaCarreaux,
      );
    }

    _log(
      '[MO120:MASSE] '
      'distance=${distanceCorrigee.toStringAsFixed(3)} '
      'carreaux=${(input.carreauxMasseObus ?? input.simCarreaux ?? 2)} '
      'reference=2 '
      'delta=${deltaCarreaux.toStringAsFixed(1)} '
      'masseM=${masseM.toStringAsFixed(2)}',
    );

    // ── Tableau D : correction température balistique ────────────────────
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

    // ── Tableau D : correction pression balistique ───────────────────────
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

    // ── Tableau H : correction portée rotation Terre ─────────────────────
    double rotxM = await hService.rotxM(
      distance: distanceCorrigee,
      gisementMil: azimutMil.round(),
      latitudeDeg: latitudePieceDeg,
      tirMontagne: tirMontagne,
    );

    // ── Tableau E : correction V0 (tir similaire) ────────────────────────
    //
    // Méthode MO-120 conforme au manuel :
    //
    // 1) Ramener la V0 mesurée du tir précédent aux conditions tabulaires :
    //      V0 ramenée = V0 mesurée - ΔV masse précédent - ΔV température précédent
    //
    // 2) Comparer cette V0 ramenée à la V0 tabulaire :
    //      ΔV usure/lot = V0 ramenée - V0 tabulaire
    //
    // 3) Ajouter l'effet de la température poudre du tir actuel :
    //      ΔV0 total = ΔV usure/lot + ΔV température actuelle
    //
    // Exemple officiel :
    //      289.4 - 2.6 - 0.3 = 286.5
    //      286.5 - 290.5 = -4.0
    //      -4.0 + 0.5 = -3.5 m/s
    double deltaV0M = 0.0;
    if (input.simV0Prev != null &&
        input.simTempActC != null &&
        coeffsLong != null) {
      await eService.load();

      final v0Service = V0Service(systeme: SystemeArme.mo);
      final double? vTabNullable = await v0Service.v0Ref(
        typeTirAssets: _typeAssets,
        charge: charge,
      );

      if (vTabNullable == null || vTabNullable <= 0.0) {
        _log(
          '[MO120:V0] V0 tabulaire introuvable ou invalide '
          'charge=$charge v0=$vTabNullable -> correction V0 ignorée',
        );
      } else {
        final double vTab = vTabNullable;
        final double v0Mesuree = input.simV0Prev!;
        final double tempPrevC = input.simTempPrevC ?? 21.0;
        final double tempActC = input.simTempActC ?? 21.0;

        final double dVtempPrev =
            (await eService.deltaVoTemp(tempPoudreC: tempPrevC)) ?? 0.0;
        final double dVtempAct =
            (await eService.deltaVoTemp(tempPoudreC: tempActC)) ?? 0.0;

        // MO-120 : masse tabulaire = 2 carreaux.
        // Exemple officiel : masse mesurée = 1 carreau => delta = -1.
        // Avec deltaV/carreau = -2.6, cela donne :
        //     (-1) * (-2.6) = +2.6 m/s.
        final double dCarPrev = ((input.simCarreaux ?? 2) - 2).toDouble();
        final double dVmassePrev = dCarPrev != 0.0
            ? (await eService.deltaVoParCarreaux(
                  charge: charge,
                  deltaCarreaux: dCarPrev,
                ) ??
                0.0)
            : 0.0;

        final double v0RameneeTabulaire = v0Mesuree - dVmassePrev - dVtempPrev;

        final double deltaUsureLot = v0RameneeTabulaire - vTab;
        final double deltaV0Totale = deltaUsureLot + dVtempAct;

        final double kChoisi =
            deltaV0Totale < 0 ? coeffsLong.kV0Moins : coeffsLong.kV0Plus;

        deltaV0M = kChoisi * deltaV0Totale.abs();

        _log(
          '[MO120:V0] '
          'charge=$charge '
          'v0Mesuree=${v0Mesuree.toStringAsFixed(1)} '
          'v0Table=${vTab.toStringAsFixed(1)} '
          'tempPrev=${tempPrevC.toStringAsFixed(1)} '
          'dVtempPrev=${dVtempPrev.toStringAsFixed(2)} '
          'tempAct=${tempActC.toStringAsFixed(1)} '
          'dVtempAct=${dVtempAct.toStringAsFixed(2)} '
          'dCarPrev=${dCarPrev.toStringAsFixed(1)} '
          'dVmassePrev=${dVmassePrev.toStringAsFixed(2)} '
          'v0Ramenee=${v0RameneeTabulaire.toStringAsFixed(2)} '
          'deltaUsureLot=${deltaUsureLot.toStringAsFixed(2)} '
          'deltaV0Totale=${deltaV0Totale.toStringAsFixed(2)} '
          'kV0=${kChoisi.toStringAsFixed(2)} '
          'deltaV0M=${deltaV0M.toStringAsFixed(2)}',
        );
      }
    }

    // ── Assainissement des valeurs ────────────────────────────────────────
    deriveMil = _sane(deriveMil, 'deriveMil');
    rotzMil = _sane(rotzMil, 'rotzMil');
    wzMil = _sane(wzMil, 'wzMil');
    wxM = _sane(wxM, 'wxM');
    rotxM = _sane(rotxM, 'rotxM');
    masseM = _sane(masseM, 'masseM');
    deltaV0M = _sane(deltaV0M, 'deltaV0M');
    deltaTBM = _sane(deltaTBM, 'deltaTBM');
    deltaPBM = _sane(deltaPBM, 'deltaPBM');

    // ── Calcul hausse et azimut ──────────────────────────────────────────
    final double totalCorrectionAzimutMil = deriveMil + rotzMil + wzMil;
    final double noireMil = azimutMil - totalCorrectionAzimutMil;
    final double totalLongM =
        wxM + rotxM + masseM + deltaV0M + deltaTBM + deltaPBM;
    final double porteeAViser = distanceTopo + totalLongM;

    _log(
      '[MO120:LONG] '
      'wxM=${wxM.toStringAsFixed(2)} '
      'deltaTBM=${deltaTBM.toStringAsFixed(2)} '
      'deltaPBM=${deltaPBM.toStringAsFixed(2)} '
      'masseM=${masseM.toStringAsFixed(2)} '
      'rotxM=${rotxM.toStringAsFixed(2)} '
      'deltaV0M=${deltaV0M.toStringAsFixed(2)} '
      'totalLongM=${totalLongM.toStringAsFixed(2)} '
      'porteeAViser=${porteeAViser.toStringAsFixed(2)}',
    );

    // ── Tableau F : hausse ───────────────────────────────────────────────
    final double aeMil = await fService.hausseMil(
          distance: porteeAViser,
          tirMontagne: tirMontagne,
        ) ??
        0.0;

    // ── Site ─────────────────────────────────────────────────────────────
    final double siteBrutMil = denivelee / (distanceTopo / 1000.0);
    double corrSiteVraiMil = 0.0;
    try {
      corrSiteVraiMil = await Annexe1Service.correctionSiteVrai(siteBrutMil);
    } catch (_) {}
    final double siteTotalAsMil = siteBrutMil + corrSiteVraiMil;

    // ── Tableau G : données supplémentaires ─────────────────────────────
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
        '[MO120:APPUI:TABLEAU G TERMINAL RAW] '
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
        '[MO120:APPUI:TABLEAU G TERMINAL ASSIGNED] '
        'angleDeg=$angleChuteDeg '
        'cot=$cotangenteAngleChute '
        'epp=$ecartProbablePorteeM '
        'epd=$ecartProbableDirectionM '
        'vRest=$vitesseRestanteMps',
      );
    } catch (error, stackTrace) {
      _log('[MO120:APPUI:TABLEAU G TERMINAL ERROR] $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    final double aqeMil = aeMil + siteTotalAsMil + acsMil;

    // ── Tableau F : temps de vol ─────────────────────────────────────────
    final double tempsVolFinal = await fService.tempageSeconds(
          distance: distanceCorrigee,
          tirMontagne: tirMontagne,
        ) ??
        0.0;

    _log(
      '[MO120] charge=$charge '
      'dist=${distanceTopo.toStringAsFixed(0)} m '
      'portee=${porteeAViser.toStringAsFixed(0)} m '
      'AE=${aeMil.toStringAsFixed(1)} mil '
      'noire=${noireMil.toStringAsFixed(1)} mil',
    );

    _log(
      '[MO120:LATERAL FINAL] '
      'deriveMil=${deriveMil.toStringAsFixed(6)} '
      'rotzMil=${rotzMil.toStringAsFixed(6)} '
      'wzMil=${wzMil.toStringAsFixed(6)} '
      'totalAz=${totalCorrectionAzimutMil.toStringAsFixed(6)} '
      'noire=${noireMil.toStringAsFixed(6)}',
    );

    _log(
      '[MO120:LONG FINAL] '
      'wxM=${wxM.toStringAsFixed(6)} '
      'rotxM=${rotxM.toStringAsFixed(6)} '
      'masseM=${masseM.toStringAsFixed(6)} '
      'deltaTBM=${deltaTBM.toStringAsFixed(6)} '
      'deltaPBM=${deltaPBM.toStringAsFixed(6)} '
      'deltaV0M=${deltaV0M.toStringAsFixed(6)} '
      'totalLongM=${totalLongM.toStringAsFixed(6)}',
    );

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
      niveauMeteoBUsed: niveauMeteo,
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
