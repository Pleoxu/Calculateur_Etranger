import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:calculateur_etranger/domain/fire/input/fire_request.dart';

import 'package:calculateur_etranger/domain/fire/models/tir_complet_input.dart';
import 'package:calculateur_etranger/domain/fire/models/type_charge_caesar.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/presentation/fire/helpers/coups_repartition_helper.dart';
import 'package:calculateur_etranger/presentation/fire/state/tir_complet_state.dart';
import 'package:calculateur_etranger/presentation/fire/state/tir_header_state.dart';

class FireRequestMapper {
  const FireRequestMapper._();

  static FireRequest fromControllerInputs({
    required TirHeaderState header,
    required TirCompletState tirState,
    required TextEditingController xCtrl,
    required TextEditingController yCtrl,
    required TextEditingController zCtrl,
    required TextEditingController zoneCtrl,
    required TextEditingController latCtrl,
    required TextEditingController lonCtrl,
    required TextEditingController altCtrl,
    required TextEditingController distCtrl,
    required TextEditingController azCtrl,
    required TextEditingController altObjCtrl,
    required TextEditingController xObjCtrl,
    required TextEditingController yObjCtrl,
    required TextEditingController zObjCtrl,
    // Observateur (optionnels)
    TextEditingController? obsXCtrl,
    TextEditingController? obsYCtrl,
    TextEditingController? obsZCtrl,
    TextEditingController? obsDistCtrl,
    TextEditingController? obsAzCtrl,
    TextEditingController? obsAltObjCtrl,
    TextEditingController? obsXObjCtrl,
    TextEditingController? obsYObjCtrl,
    TextEditingController? obsZObjCtrl,
    bool forceOecl = false,
  }) {
    final doctrineContext = _resolveDoctrineContext(tirState);

    final resolvedTypeTir = forceOecl ? TypeTir.eclairant : header.typeTir;

    final TypeMunition? candidateMunition =
        header.typeMunition ?? tirState.typeMunition;

    final List<TypeMunition> munitionsDisponibles = munitionsDisponiblesPour(
      systeme: header.systeme,
      typeTir: resolvedTypeTir,
    );

    final TypeMunition? resolvedMunition = candidateMunition != null &&
            munitionsDisponibles.contains(candidateMunition)
        ? candidateMunition
        : munitionParDefautPour(
            systeme: header.systeme,
            typeTir: resolvedTypeTir,
          );

    final FuseeCompatibility fuseeCompatibility = fuseeCompatibilityPour(
      systeme: header.systeme,
      typeTir: resolvedTypeTir,
      munition: resolvedMunition,
    );

    final TypeFusee resolvedFusee =
        fuseeCompatibility.normalise(tirState.fusee);

    final resolvedM252MunitionFamily = header.systeme == Systeme.mo81M252
        ? (header.m252MunitionFamily ?? tirState.m252MunitionFamily)
        : null;
    if (kDebugMode && header.systeme == Systeme.mo81M252) {
      debugPrint(
        '[M252 SELECTION] label=${header.mo81MunitionLabel} '
        'header=${header.m252MunitionFamily} '
        'form=${tirState.m252MunitionFamily} '
        'request=$resolvedM252MunitionFamily',
      );
    }

    // Résolution observateur : si actif, on calcule les UTM de l'objectif
    // depuis la position de l'observateur et on force le mode UTM.
    FireTargetInput target;
    if (tirState.observateurEnabled && obsXCtrl != null && obsYCtrl != null) {
      target = _buildTargetFromObservateur(
        tirState: tirState,
        obsXCtrl: obsXCtrl,
        obsYCtrl: obsYCtrl,
        obsZCtrl: obsZCtrl,
        obsDistCtrl: obsDistCtrl,
        obsAzCtrl: obsAzCtrl,
        obsAltObjCtrl: obsAltObjCtrl,
        obsXObjCtrl: obsXObjCtrl,
        obsYObjCtrl: obsYObjCtrl,
        obsZObjCtrl: obsZObjCtrl,
      );
    } else {
      target = _buildTargetFromControllers(
        tirState: tirState,
        distCtrl: distCtrl,
        azCtrl: azCtrl,
        altObjCtrl: altObjCtrl,
        xObjCtrl: xObjCtrl,
        yObjCtrl: yObjCtrl,
        zObjCtrl: zObjCtrl,
      );
    }

    return FireRequest(
      systeme: header.systeme,
      typeTir: resolvedTypeTir,
      typeMunition: resolvedMunition,
      m252MunitionFamily: resolvedM252MunitionFamily,
      typeChargeCaesar:
          resolvedMunition?.typeChargeCaesar ?? tirState.typeChargeCaesar,
      fusee: resolvedFusee,
      piece: FirePieceInput(
        utmX: _parseDouble(xCtrl.text),
        utmY: _parseDouble(yCtrl.text),
        altitude: _parseDouble(zCtrl.text) ?? _parseDouble(altCtrl.text),
        utmZone: _cleanString(zoneCtrl.text),
        latitude: _parseDouble(latCtrl.text),
        longitude: _parseDouble(lonCtrl.text),
      ),
      target: target,
      tirVertical: tirState.tirVertical,
      forcerCharge: tirState.forcerCharge,
      // Pour MO-120 : chargeForceeStr est prioritaire sur chargeForcee
      chargeForcee:
          tirState.chargeForceeStr != null ? null : tirState.chargeForcee,
      chargeForceeStr: tirState.chargeForceeStr,
      doctrine: FireDoctrineInput(
        nature: doctrineContext.nature,
        shotPlan: FireShotPlanInput(
          nbCoups: doctrineContext.totalCoups,
          par: doctrineContext.par,
          coupsParPiece: doctrineContext.coupsParPiece,
        ),
        zonal: FireZonalDoctrineInput(
          longueurM: doctrineContext.zonalLongueurM,
          profondeurM: doctrineContext.profondeurM,
          debordementPct: doctrineContext.debordementPct,
          recouvrementPct: doctrineContext.recouvrementPct,
          zonalMode: doctrineContext.zonalMode,
          pointZonal: doctrineContext.pointZonal,
          azimutLargeurMil: doctrineContext.azimutLargeurMil,
          azimutProfondeurMil: doctrineContext.azimutProfondeurMil,
          isZonalPreset: doctrineContext.isZonalPreset,
        ),
        lineaire: FireLinearDoctrineInput(
          longueurM: doctrineContext.lineaireLongueurM,
          referencePoint: doctrineContext.linearReferencePoint,
          azimutLineaireMil: doctrineContext.azimutLineaireMil,
          firingMode: doctrineContext.linearFiringMode,
          selectedRoles: doctrineContext.selectedLinearRoles,
        ),
      ),
      salves: FireSalvoOptions(
        enabled: doctrineContext.salvesEnabled,
        preferenceIdx: doctrineContext.salvesPreferenceIdx,
        lastSalveAroundPd: doctrineContext.lastSalveAroundPd,
      ),
      masseEnabled: tirState.masseEnabled,
      carreaux: tirState.carreaux,
      tirSimilaire: tirState.tirSimilaire,
      simCarreaux: tirState.simCarreaux,
      simFusee: tirState.simFusee,
      tPrev: tirState.tPrev,
      tAct: tirState.tAct,
      v0Prev: tirState.v0Prev,
      meteo: tirState.meteo
          ? FireMeteoInput(
              fileName: tirState.meteoFileName,
              rows: tirState.meteoRows ?? const [],
              stationAltM: tirState.meteoStationAltM,
            )
          : null,
      supportPieces: [
        for (final ps in tirState.piecesSoutien)
          FireSupportPieceInput(
            pieceId: ps.nom,
            distanceM: ps.distanceM,
            azimutMil: ps.azimutMil,
            deltaZPd: ps.deltaZPd,
            // L'UI conserve le ΔZ/PD. Le moteur reçoit toujours Z absolu.
            zPS: _parseDouble(zCtrl.text) == null
                ? ps.zPS
                : _parseDouble(zCtrl.text)! + ps.deltaZPd,
          ),
      ],
    );
  }

  static FireRequest fromUi({required dynamic state}) {
    final resolvedMunition =
        _readFirst(state, const ['typeMunition']) as TypeMunition?;

    return FireRequest(
      systeme: state.systeme as Systeme,
      typeTir: state.typeTir as TypeTir,
      typeMunition: resolvedMunition,
      m252MunitionFamily: state.systeme == Systeme.mo81M252
          ? _readFirst(state, const ['m252MunitionFamily'])
              as M252MunitionFamily?
          : null,
      typeChargeCaesar: resolvedMunition?.typeChargeCaesar ??
          _asTypeChargeCaesar(_readFirst(state, const ['typeChargeCaesar'])),
      fusee: state.fusee as TypeFusee?,
      piece: _mapPiece(state),
      target: _mapTarget(state),
      tirVertical: _asBool(state.tirVertical),
      forcerCharge: _asBool(state.forcerCharge),
      chargeForcee: _asInt(state.chargeForcee),
      doctrine: _mapDoctrine(state),
      salves: _mapSalves(state),
      masseEnabled: _asBool(state.masseEnabled),
      carreaux: _asInt(state.carreaux) ?? 0,
      tirSimilaire: _asBool(state.tirSimilaire),
      simCarreaux: _asInt(state.simCarreaux) ?? 0,
      simFusee: _readFirst(state, const ['simFusee']) as TypeFusee?,
      tPrev: _asDouble(state.tPrev),
      tAct: _asDouble(state.tAct),
      v0Prev: _asDouble(state.v0Prev),
      meteo: _mapMeteo(state),
      supportPieces: _mapSupportPieces(state),
    );
  }

  static _ResolvedDoctrineContext _resolveDoctrineContext(
    TirCompletState tirState,
  ) {
    final selection = tirState.natureSelection;
    final nature = _resolveFireNature(tirState, selection);
    final pieces = _resolvePieceIds(tirState);
    final totalCoups = _resolveTotalCoups(
      nature: nature,
      selection: selection,
      piecesCount: pieces.length,
    );
    final par = _resolvePar(nature: nature, selection: selection);
    final coupsParPiece = _resolveCoupsParPiece(
      tirState: tirState,
      pieces: pieces,
      totalCoups: totalCoups,
    );

    final isZonal = nature == FireNature.zonal;
    final zonalLongueurM =
        isZonal ? (selection?.longueurZonaleM ?? selection?.longueurM) : null;
    final lineaireLongueurM = !isZonal ? selection?.longueurM : null;

    return _ResolvedDoctrineContext(
      nature: nature,
      totalCoups: totalCoups,
      par: par,
      zonalLongueurM: zonalLongueurM,
      lineaireLongueurM: lineaireLongueurM,
      profondeurM: isZonal ? selection?.profondeurM : null,
      debordementPct: selection?.pourcentageDebordement,
      recouvrementPct: selection?.pourcentageRecouvrement,
      zonalMode: selection?.zonalMode ?? ZonalMode.otan,
      pointZonal: selection?.pointZonal,
      azimutLargeurMil: selection?.azimutLargeurMil,
      azimutProfondeurMil: selection?.azimutProfondeurMil,
      linearReferencePoint: _mapLinearReferencePoint(
        selection?.pointApplicationLineaire,
      ),
      azimutLineaireMil: selection?.azimutMil,
      linearFiringMode: _mapLinearFiringMode(tirState.linearFiringMode),
      selectedLinearRoles: tirState.selectedLinearRoles,
      coupsParPiece: coupsParPiece,
      salvesEnabled: selection?.salvesEnabled ?? false,
      salvesPreferenceIdx: selection?.salvesPreferenceIdx ?? 0,
      lastSalveAroundPd: selection?.lastSalveAroundPd ?? true,
      isZonalPreset: _isZonalPresetSelection(selection),
    );
  }

  static bool _isZonalPresetSelection(NatureTirSelection? selection) {
    if (selection == null) return false;
    if (selection.nature != NatureTirType.zonal) return false;
    if (selection.zonalMode != ZonalMode.force) return false;
    if ((selection.nbCoups ?? 0) != 8) return false;

    final l = selection.longueurZonaleM ?? selection.longueurM ?? 0.0;
    final p = selection.profondeurM ?? 0.0;
    if (l <= 0 || p <= 0) return false;

    const presetSizes = <double>[100.0, 150.0, 200.0];
    final isSquare = (l - p).abs() <= 1.0;
    return isSquare && presetSizes.any((size) => (l - size).abs() <= 1.0);
  }

  static List<String> _resolvePieceIds(TirCompletState tirState) {
    return <String>['PD', for (final ps in tirState.piecesSoutien) ps.nom];
  }

  static FireNature _resolveFireNature(
    TirCompletState tirState,
    NatureTirSelection? selection,
  ) {
    if (!tirState.natureEnabled || selection == null) {
      return FireNature.ponctuel;
    }

    switch (selection.nature) {
      case NatureTirType.lineaire:
        return FireNature.lineaire;
      case NatureTirType.zonal:
        return FireNature.zonal;
      case NatureTirType.ponctuel:
        return FireNature.ponctuel;
    }
  }

  static int _resolvePar({
    required FireNature nature,
    required NatureTirSelection? selection,
  }) {
    if (nature == FireNature.ponctuel) {
      return 1;
    }

    // Pour les zonaux spécifiques carrés, on transmet le nombre de salves
    // via `par` afin que l'adaptateur legacy le réinjecte dans
    // TirCompletInput.lineairePar. Le moteur s'en sert ensuite pour générer
    // toutes les positions de salve, pas seulement le total de coups.
    if (nature == FireNature.zonal) {
      if (_isZonalPresetSelection(selection)) {
        return (selection?.lineairePar ?? 1).clamp(1, 3);
      }
      return 1;
    }

    return (selection?.lineairePar ?? 1).clamp(1, 12);
  }

  static int _resolveTotalCoups({
    required FireNature nature,
    required NatureTirSelection? selection,
    required int piecesCount,
  }) {
    if (selection == null) {
      return 0;
    }

    final baseCoups =
        (selection.nbCoups ?? (nature == FireNature.ponctuel ? 1 : 3)).clamp(
      1,
      400,
    );

    if (nature == FireNature.zonal) {
      // Pour les zonaux spécifiques carrés (Neutralisation / Interdiction /
      // Destruction), `lineairePar` est réutilisé côté UI comme nombre de
      // salves choisi par la nature de l’ennemi :
      // Infanterie=1S, Blindés=2S, Char=3S.
      if (_isZonalPresetSelection(selection)) {
        final nbSalves = (selection.lineairePar ?? 1).clamp(1, 3);
        return (baseCoups * nbSalves).clamp(1, 9999);
      }
      return baseCoups;
    }

    if (nature == FireNature.ponctuel) {
      final count = piecesCount <= 0 ? 1 : piecesCount;
      return (baseCoups * count).clamp(1, 9999);
    }

    final par = (selection.lineairePar ?? 1).clamp(1, 12);
    return (baseCoups * par).clamp(1, 9999);
  }

  static Map<String, int> _resolveCoupsParPiece({
    required TirCompletState tirState,
    required List<String> pieces,
    required int totalCoups,
  }) {
    if (pieces.isEmpty || totalCoups <= 0) {
      return const {};
    }

    final equitable = _buildEquitableDistribution(
      pieces: pieces,
      totalCoups: totalCoups,
    );

    final user = tirState.coupsParPieceByPiece;
    final isUserValid = _isUserDistributionValid(
      user: user,
      pieces: pieces,
      totalCoups: totalCoups,
    );

    if (isUserValid) {
      return normalizeToTotal(
        input: user,
        totalCoups: totalCoups,
        piecesOrdered: pieces,
        maxPerPiece: 9999,
      );
    }

    if (user.isEmpty) {
      return equitable;
    }

    return _sanitizeAndNormalizeDistribution(
      user: user,
      pieces: pieces,
      totalCoups: totalCoups,
    );
  }

  /// Résout la cible depuis les champs observateur.
  /// Mode DAZ : X_obj = X_obs + D×sin(Az), Y_obj = Y_obs + D×cos(Az)
  /// Mode UTM  : coordonnées saisies directement
  static FireTargetInput _buildTargetFromObservateur({
    required TirCompletState tirState,
    required TextEditingController obsXCtrl,
    required TextEditingController obsYCtrl,
    TextEditingController? obsZCtrl,
    TextEditingController? obsDistCtrl,
    TextEditingController? obsAzCtrl,
    TextEditingController? obsAltObjCtrl,
    TextEditingController? obsXObjCtrl,
    TextEditingController? obsYObjCtrl,
    TextEditingController? obsZObjCtrl,
  }) {
    final obsX = _parseDouble(obsXCtrl.text);
    final obsY = _parseDouble(obsYCtrl.text);
    final obsZ = _parseDouble(obsZCtrl?.text);

    if (obsX == null || obsY == null) {
      // Données insuffisantes — retour en mode DAZ vide
      return const FireTargetInput(mode: FireTargetMode.utm);
    }

    if (tirState.observateurObjMode == ObservateurObjMode.daz) {
      final dist = _parseDouble(obsDistCtrl?.text);
      final az = _parseDouble(obsAzCtrl?.text);
      final altObj = _parseDouble(obsAltObjCtrl?.text);

      if (dist == null || az == null || dist <= 0) {
        return const FireTargetInput(mode: FireTargetMode.utm);
      }

      final azRad = az * 2.0 * math.pi / 6400.0;
      final objX = obsX + dist * math.sin(azRad);
      final objY = obsY + dist * math.cos(azRad);
      final objZ = altObj ?? obsZ;

      return FireTargetInput(
        mode: FireTargetMode.utm,
        utmX: objX,
        utmY: objY,
        altitude: objZ,
      );
    } else {
      // Mode UTM direct depuis l'observateur
      final objX = _parseDouble(obsXObjCtrl?.text);
      final objY = _parseDouble(obsYObjCtrl?.text);
      final objZ = _parseDouble(obsZObjCtrl?.text) ?? obsZ;

      return FireTargetInput(
        mode: FireTargetMode.utm,
        utmX: objX,
        utmY: objY,
        altitude: objZ,
      );
    }
  }

  static FireTargetInput _buildTargetFromControllers({
    required TirCompletState tirState,
    required TextEditingController distCtrl,
    required TextEditingController azCtrl,
    required TextEditingController altObjCtrl,
    required TextEditingController xObjCtrl,
    required TextEditingController yObjCtrl,
    required TextEditingController zObjCtrl,
  }) {
    switch (tirState.objectifMode) {
      case ObjectifInputMode.utm:
        return FireTargetInput(
          mode: FireTargetMode.utm,
          utmX: _parseDouble(xObjCtrl.text),
          utmY: _parseDouble(yObjCtrl.text),
          altitude: _parseDouble(zObjCtrl.text),
        );
      case ObjectifInputMode.daz:
        return FireTargetInput(
          mode: FireTargetMode.daz,
          distanceM: _parseDouble(distCtrl.text),
          azimutMil: _parseDouble(azCtrl.text),
          altitude: _parseDouble(altObjCtrl.text),
        );
      case ObjectifInputMode.lat:
        return FireTargetInput(
          mode: FireTargetMode.latLon,
          latitude: _parseDouble(xObjCtrl.text),
          longitude: _parseDouble(yObjCtrl.text),
          altitude: _parseDouble(zObjCtrl.text),
        );
    }
  }

  static FirePieceInput _mapPiece(dynamic s) {
    return FirePieceInput(
      utmX: _asDouble(_readFirst(s, const ['pieceUtmX', 'xPiece'])),
      utmY: _asDouble(_readFirst(s, const ['pieceUtmY', 'yPiece'])),
      altitude: _asDouble(
        _readFirst(s, const ['pieceAlt', 'zPiece', 'altPiece']),
      ),
      utmZone: _asString(_readFirst(s, const ['pieceUtmZone', 'zone'])),
      latitude: _asDouble(_readFirst(s, const ['pieceLat', 'latPiece'])),
      longitude: _asDouble(_readFirst(s, const ['pieceLon', 'lonPiece'])),
    );
  }

  static FireTargetInput _mapTarget(dynamic s) {
    final objectifMode = _readFirst(s, const ['objectifMode', 'targetMode']);

    if (objectifMode == ObjectifInputMode.utm) {
      return FireTargetInput(
        mode: FireTargetMode.utm,
        utmX: _asDouble(_readFirst(s, const ['objUtmX', 'xObj'])),
        utmY: _asDouble(_readFirst(s, const ['objUtmY', 'yObj'])),
        altitude: _asDouble(_readFirst(s, const ['objAlt', 'zObj', 'altObj'])),
      );
    }

    if (objectifMode == ObjectifInputMode.daz) {
      return FireTargetInput(
        mode: FireTargetMode.daz,
        distanceM: _asDouble(
          _readFirst(s, const ['objDistance', 'distanceObj']),
        ),
        azimutMil: _asDouble(_readFirst(s, const ['objAzimut', 'azimutObj'])),
        altitude: _asDouble(_readFirst(s, const ['objAlt', 'zObj', 'altObj'])),
      );
    }

    if (objectifMode == ObjectifInputMode.lat) {
      return FireTargetInput(
        mode: FireTargetMode.latLon,
        latitude: _asDouble(_readFirst(s, const ['objLat', 'latObj'])),
        longitude: _asDouble(_readFirst(s, const ['objLon', 'lonObj'])),
        altitude: _asDouble(_readFirst(s, const ['objAlt', 'zObj', 'altObj'])),
      );
    }

    return FireTargetInput(
      mode: FireTargetMode.utm,
      utmX: _asDouble(_readFirst(s, const ['objUtmX', 'xObj'])),
      utmY: _asDouble(_readFirst(s, const ['objUtmY', 'yObj'])),
      altitude: _asDouble(_readFirst(s, const ['objAlt', 'zObj', 'altObj'])),
    );
  }

  static FireDoctrineInput _mapDoctrine(dynamic s) {
    final natureIdx = _asInt(_readFirst(s, const ['natureIdx'])) ?? 0;

    final nature = _mapNature(natureIdx);
    final rawLongueur = _asDouble(
      _readFirst(s, const ['longueur', 'longueurLineaire', 'longueurZonale']),
    );

    return FireDoctrineInput(
      nature: nature,
      shotPlan: FireShotPlanInput(
        nbCoups: _asInt(_readFirst(s, const ['nbCoups'])) ?? 0,
        par: _asInt(_readFirst(s, const ['par', 'lineairePar'])) ?? 1,
        coupsParPiece: _asStringIntMap(
          _readFirst(s, const ['coupsParPiece', 'coupsParPieceByPiece']),
        ),
      ),
      zonal: FireZonalDoctrineInput(
        longueurM: nature == FireNature.zonal ? rawLongueur : null,
        profondeurM: _asDouble(
          _readFirst(s, const ['profondeur', 'profondeurZonale']),
        ),
        debordementPct: _asDouble(
          _readFirst(s, const ['debordement', 'pourcentageDebordement']),
        ),
        recouvrementPct: _asDouble(
          _readFirst(s, const ['recouvrement', 'pourcentageRecouvrement']),
        ),
        zonalMode: (_readFirst(s, const ['zonalMode']) as ZonalMode?) ??
            ZonalMode.otan,
        pointZonal: _readFirst(s, const ['pointZonal']) as PointZonal?,
        azimutLargeurMil: _asDouble(
          _readFirst(s, const ['azimutLargeur', 'azimutLargeurMil']),
        ),
        azimutProfondeurMil: _asDouble(
          _readFirst(s, const ['azimutProfondeur', 'azimutProfondeurMil']),
        ),
        isZonalPreset: _asBool(_readFirst(s, const ['isZonalPreset'])) ||
            _isZonalPresetDynamic(s, nature, rawLongueur),
      ),
      lineaire: FireLinearDoctrineInput(
        longueurM: nature == FireNature.lineaire ? rawLongueur : null,
        referencePoint: _asBool(
          _readFirst(s, const [
            'depuisExtremite',
            'lineaireDepuisExtremite',
          ]),
        )
            ? FireLinearReferencePoint.extremity
            : FireLinearReferencePoint.center,
        azimutLineaireMil: _asDouble(
          _readFirst(s, const ['azimutLineaire', 'azimutLineaireMil']),
        ),
        firingMode: _mapLinearFiringMode(
          _readFirst(s, const ['linearFiringMode']),
        ),
        selectedRoles: _asStringList(
          _readFirst(s, const ['selectedLinearRoles']),
        ),
      ),
    );
  }

  static bool _isZonalPresetDynamic(
    dynamic state,
    FireNature nature,
    double? rawLongueur,
  ) {
    if (nature != FireNature.zonal) return false;

    final mode = _readFirst(state, const ['zonalMode']);
    if (mode is ZonalMode && mode != ZonalMode.force) return false;

    final nbCoups = _asInt(_readFirst(state, const ['nbCoups']));
    if (nbCoups != 8) return false;

    final l = rawLongueur ?? 0.0;
    final p = _asDouble(
          _readFirst(state, const ['profondeur', 'profondeurZonale']),
        ) ??
        0.0;
    if (l <= 0 || p <= 0) return false;

    const presetSizes = <double>[100.0, 150.0, 200.0];
    return (l - p).abs() <= 1.0 &&
        presetSizes.any((size) => (l - size).abs() <= 1.0);
  }

  static FireLinearReferencePoint _mapLinearReferencePoint(
    PointApplicationLineaire? value,
  ) {
    switch (value) {
      case PointApplicationLineaire.extremite:
        return FireLinearReferencePoint.extremity;
      case PointApplicationLineaire.gauche:
        return FireLinearReferencePoint.left;
      case PointApplicationLineaire.droite:
        return FireLinearReferencePoint.right;
      case PointApplicationLineaire.centre:
      default:
        return FireLinearReferencePoint.center;
    }
  }

  static FireLinearFiringMode _mapLinearFiringMode(dynamic value) {
    if (value is FireLinearFiringMode) {
      return value;
    }

    if (value is LinearFiringMode) {
      switch (value) {
        case LinearFiringMode.sectionWithPd:
          return FireLinearFiringMode.sectionWithPd;
        case LinearFiringMode.sectionWithoutPd:
          return FireLinearFiringMode.sectionWithoutPd;
        case LinearFiringMode.batteryWithPd:
          return FireLinearFiringMode.batteryWithPd;
        case LinearFiringMode.libre:
          return FireLinearFiringMode.libre;
      }
    }

    final normalized = value?.toString().trim().toLowerCase();
    switch (normalized) {
      case 'linearfiringmode.sectionwithpd':
      case 'sectionwithpd':
        return FireLinearFiringMode.sectionWithPd;
      case 'linearfiringmode.sectionwithoutpd':
      case 'sectionwithoutpd':
        return FireLinearFiringMode.sectionWithoutPd;
      case 'linearfiringmode.batterywithpd':
      case 'batterywithpd':
        return FireLinearFiringMode.batteryWithPd;
      case 'linearfiringmode.libre':
      case 'libre':
      default:
        return FireLinearFiringMode.libre;
    }
  }

  static FireNature _mapNature(int idx) {
    switch (idx) {
      case 1:
        return FireNature.lineaire;
      case 2:
        return FireNature.zonal;
      case 0:
      default:
        return FireNature.ponctuel;
    }
  }

  static FireSalvoOptions _mapSalves(dynamic s) {
    return FireSalvoOptions(
      enabled: _asBool(_readFirst(s, const ['salvesEnabled'])),
      preferenceIdx: _asInt(
            _readFirst(s, const ['salvePreferenceIdx', 'salvesPreferenceIdx']),
          ) ??
          0,
      lastSalveAroundPd: _asBool(_readFirst(s, const ['lastSalveAroundPd'])),
    );
  }

  static FireMeteoInput? _mapMeteo(dynamic s) {
    final meteoEnabled = _asBool(
      _readFirst(s, const ['meteoEnabled', 'meteo']),
    );

    if (!meteoEnabled) {
      return null;
    }

    final rows = _readFirst(s, const ['meteoRows']);
    final typedRows = rows is List ? List.of(rows) : const [];

    return FireMeteoInput(
      fileName: _asString(_readFirst(s, const ['meteoFileName'])),
      rows: typedRows.cast(),
      stationAltM: _asDouble(
        _readFirst(s, const ['stationAlt', 'meteoStationAltM']),
      ),
    );
  }

  static List<FireSupportPieceInput> _mapSupportPieces(dynamic s) {
    final raw = _readFirst(s, const ['supportPieces', 'piecesSoutien']);

    if (raw is! List) {
      return const [];
    }

    return raw.map<FireSupportPieceInput>((dynamic p) {
      return FireSupportPieceInput(
        pieceId: _asString(
              _readPieceField(p, const ['pieceId', 'id', 'nom', 'name']),
            ) ??
            'PS',
        distanceM: _asDouble(
              _readPieceField(p, const ['distance', 'distanceM', 'dist']),
            ) ??
            0,
        azimutMil: _asDouble(
              _readPieceField(p, const ['azimut', 'azimutMil', 'az']),
            ) ??
            0,
        deltaZPd: _asDouble(
          _readPieceField(p, const ['deltaZPd', 'deltaZ', 'dz']),
        ),
        zPS: _asDouble(_readPieceField(p, const ['zPS', 'z', 'altitude'])),
      );
    }).toList(growable: false);
  }

  static dynamic _readFirst(dynamic obj, List<String> names) {
    for (final name in names) {
      final value = _tryRead(obj, name);
      if (value != null) return value;
    }
    return null;
  }

  static dynamic _readPieceField(dynamic obj, List<String> names) {
    for (final name in names) {
      final value = _tryRead(obj, name);
      if (value != null) return value;
    }
    return null;
  }

  static dynamic _tryRead(dynamic obj, String name) {
    try {
      switch (name) {
        case 'systeme':
          return obj.systeme;
        case 'typeTir':
          return obj.typeTir;
        case 'typeMunition':
          return obj.typeMunition;
        case 'typeChargeCaesar':
          return obj.typeChargeCaesar;
        case 'fusee':
          return obj.fusee;
        case 'tirVertical':
          return obj.tirVertical;
        case 'forcerCharge':
          return obj.forcerCharge;
        case 'chargeForcee':
          return obj.chargeForcee;
        case 'masseEnabled':
          return obj.masseEnabled;
        case 'carreaux':
          return obj.carreaux;
        case 'tirSimilaire':
          return obj.tirSimilaire;
        case 'simCarreaux':
          return obj.simCarreaux;
        case 'simFusee':
          return obj.simFusee;
        case 'tPrev':
          return obj.tPrev;
        case 'tAct':
          return obj.tAct;
        case 'v0Prev':
          return obj.v0Prev;
        case 'pieceUtmX':
          return obj.pieceUtmX;
        case 'xPiece':
          return obj.xPiece;
        case 'pieceUtmY':
          return obj.pieceUtmY;
        case 'yPiece':
          return obj.yPiece;
        case 'pieceAlt':
          return obj.pieceAlt;
        case 'zPiece':
          return obj.zPiece;
        case 'altPiece':
          return obj.altPiece;
        case 'pieceUtmZone':
          return obj.pieceUtmZone;
        case 'zone':
          return obj.zone;
        case 'pieceLat':
          return obj.pieceLat;
        case 'latPiece':
          return obj.latPiece;
        case 'pieceLon':
          return obj.pieceLon;
        case 'lonPiece':
          return obj.lonPiece;
        case 'objectifMode':
          return obj.objectifMode;
        case 'targetMode':
          return obj.targetMode;
        case 'objUtmX':
          return obj.objUtmX;
        case 'xObj':
          return obj.xObj;
        case 'objUtmY':
          return obj.objUtmY;
        case 'yObj':
          return obj.yObj;
        case 'objAlt':
          return obj.objAlt;
        case 'zObj':
          return obj.zObj;
        case 'altObj':
          return obj.altObj;
        case 'objDistance':
          return obj.objDistance;
        case 'distanceObj':
          return obj.distanceObj;
        case 'objAzimut':
          return obj.objAzimut;
        case 'azimutObj':
          return obj.azimutObj;
        case 'objLat':
          return obj.objLat;
        case 'latObj':
          return obj.latObj;
        case 'objLon':
          return obj.objLon;
        case 'lonObj':
          return obj.lonObj;
        case 'natureIdx':
          return obj.natureIdx;
        case 'nbCoups':
          return obj.nbCoups;
        case 'par':
          return obj.par;
        case 'lineairePar':
          return obj.lineairePar;
        case 'longueur':
          return obj.longueur;
        case 'longueurLineaire':
          return obj.longueurLineaire;
        case 'longueurZonale':
          return obj.longueurZonale;
        case 'profondeur':
          return obj.profondeur;
        case 'profondeurZonale':
          return obj.profondeurZonale;
        case 'debordement':
          return obj.debordement;
        case 'pourcentageDebordement':
          return obj.pourcentageDebordement;
        case 'recouvrement':
          return obj.recouvrement;
        case 'pourcentageRecouvrement':
          return obj.pourcentageRecouvrement;
        case 'zonalMode':
          return obj.zonalMode;
        case 'pointZonal':
          return obj.pointZonal;
        case 'azimutLargeur':
          return obj.azimutLargeur;
        case 'azimutLargeurMil':
          return obj.azimutLargeurMil;
        case 'azimutProfondeur':
          return obj.azimutProfondeur;
        case 'azimutProfondeurMil':
          return obj.azimutProfondeurMil;
        case 'depuisExtremite':
          return obj.depuisExtremite;
        case 'lineaireDepuisExtremite':
          return obj.lineaireDepuisExtremite;
        case 'azimutLineaire':
          return obj.azimutLineaire;
        case 'azimutLineaireMil':
          return obj.azimutLineaireMil;
        case 'linearFiringMode':
          return obj.linearFiringMode;
        case 'selectedLinearRoles':
          return obj.selectedLinearRoles;
        case 'coupsParPiece':
          return obj.coupsParPiece;
        case 'coupsParPieceByPiece':
          return obj.coupsParPieceByPiece;
        case 'salvesEnabled':
          return obj.salvesEnabled;
        case 'salvePreferenceIdx':
          return obj.salvePreferenceIdx;
        case 'salvesPreferenceIdx':
          return obj.salvesPreferenceIdx;
        case 'lastSalveAroundPd':
          return obj.lastSalveAroundPd;
        case 'meteoEnabled':
          return obj.meteoEnabled;
        case 'meteo':
          return obj.meteo;
        case 'meteoFileName':
          return obj.meteoFileName;
        case 'meteoRows':
          return obj.meteoRows;
        case 'stationAlt':
          return obj.stationAlt;
        case 'meteoStationAltM':
          return obj.meteoStationAltM;
        case 'supportPieces':
          return obj.supportPieces;
        case 'piecesSoutien':
          return obj.piecesSoutien;
        case 'pieceId':
          return obj.pieceId;
        case 'id':
          return obj.id;
        case 'nom':
          return obj.nom;
        case 'name':
          return obj.name;
        case 'distance':
          return obj.distance;
        case 'distanceM':
          return obj.distanceM;
        case 'dist':
          return obj.dist;
        case 'azimut':
          return obj.azimut;
        case 'azimutMil':
          return obj.azimutMil;
        case 'az':
          return obj.az;
        case 'deltaZPd':
          return obj.deltaZPd;
        case 'zPS':
          return obj.zPS;
        case 'z':
          return obj.z;
        case 'altitude':
          return obj.altitude;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static TypeChargeCaesar _asTypeChargeCaesar(dynamic value) {
    if (value is TypeChargeCaesar) return value;

    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'typechargecaesar.allemande' ||
        normalized == 'allemande' ||
        normalized == 'all') {
      return TypeChargeCaesar.allemande;
    }

    return TypeChargeCaesar.fr;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == 'true' || v == '1' || v == 'yes';
    }
    return false;
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim().replaceAll(',', '.'));
    }
    return null;
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static String? _cleanString(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _parseDouble(String? value) {
    if (value == null) return null;
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  static Map<String, int> _buildEquitableDistribution({
    required List<String> pieces,
    required int totalCoups,
  }) {
    if (pieces.isEmpty || totalCoups <= 0) return const {};
    return normalizeToTotal(
      input: const {},
      totalCoups: totalCoups,
      piecesOrdered: pieces,
      maxPerPiece: 9999,
    );
  }

  static bool _isUserDistributionValid({
    required Map<String, int> user,
    required List<String> pieces,
    required int totalCoups,
  }) {
    if (pieces.isEmpty || totalCoups <= 0) return false;
    if (user.isEmpty) return false;
    if (user.length != pieces.length) return false;

    final userKeys = user.keys.toSet();
    final piecesKeys = pieces.toSet();

    if (userKeys.length != pieces.length) return false;
    if (!userKeys.containsAll(piecesKeys)) return false;
    if (!piecesKeys.containsAll(userKeys)) return false;

    var sum = 0;
    for (final piece in pieces) {
      final value = user[piece];
      if (value == null || value < 0) return false;
      sum += value;
    }

    return sum == totalCoups;
  }

  static Map<String, int> _sanitizeAndNormalizeDistribution({
    required Map<String, int> user,
    required List<String> pieces,
    required int totalCoups,
  }) {
    final sanitized = <String, int>{
      for (final piece in pieces)
        piece: ((user[piece] ?? 0) < 0 ? 0 : (user[piece] ?? 0)),
    };

    return normalizeToTotal(
      input: sanitized,
      totalCoups: totalCoups,
      piecesOrdered: pieces,
      maxPerPiece: 9999,
    );
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList(growable: false);
    }
    return const [];
  }

  static Map<String, int> _asStringIntMap(dynamic value) {
    if (value is Map) {
      final out = <String, int>{};
      value.forEach((key, val) {
        final parsed = _asInt(val);
        if (parsed != null) {
          out[key.toString()] = parsed;
        }
      });
      return out;
    }
    return const {};
  }
}

class _ResolvedDoctrineContext {
  final FireNature nature;
  final int totalCoups;
  final int par;
  final double? zonalLongueurM;
  final double? lineaireLongueurM;
  final double? profondeurM;
  final double? debordementPct;
  final double? recouvrementPct;
  final ZonalMode zonalMode;
  final PointZonal? pointZonal;
  final double? azimutLargeurMil;
  final double? azimutProfondeurMil;
  final FireLinearReferencePoint linearReferencePoint;
  final double? azimutLineaireMil;
  final FireLinearFiringMode linearFiringMode;
  final List<String> selectedLinearRoles;
  final Map<String, int> coupsParPiece;
  final bool salvesEnabled;
  final int salvesPreferenceIdx;
  final bool lastSalveAroundPd;
  final bool isZonalPreset;

  const _ResolvedDoctrineContext({
    required this.nature,
    required this.totalCoups,
    required this.par,
    required this.zonalLongueurM,
    required this.lineaireLongueurM,
    required this.profondeurM,
    required this.debordementPct,
    required this.recouvrementPct,
    required this.zonalMode,
    required this.pointZonal,
    required this.azimutLargeurMil,
    required this.azimutProfondeurMil,
    required this.linearReferencePoint,
    required this.azimutLineaireMil,
    required this.linearFiringMode,
    required this.selectedLinearRoles,
    required this.coupsParPiece,
    required this.salvesEnabled,
    required this.salvesPreferenceIdx,
    required this.lastSalveAroundPd,
    required this.isZonalPreset,
  });
}
