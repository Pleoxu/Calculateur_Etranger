import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calculateur_etranger/domain/fire/models/fire_command_level.dart';
import 'package:calculateur_etranger/domain/fire/models/type_charge_caesar.dart';
import 'package:calculateur_etranger/presentation/fire/models/piece_soutien.dart';
import 'package:calculateur_etranger/domain/entities/meteo_row.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';
import 'package:calculateur_etranger/domain/fire/input/fire_request.dart';
import 'package:calculateur_etranger/domain/fire/models/tir_complet_input.dart'
    show LinearFiringMode, ObjectifInputMode, ObservateurObjMode;

class TirCompletState {
  final FireCommandLevel commandLevel;

  /// Famille de charges CAESAR.
  ///
  /// Sans effet pour les autres systèmes d'arme.
  final TypeChargeCaesar typeChargeCaesar;

  /// Système d'arme actif. Il permet de résoudre la compatibilité de fusée
  /// lorsqu'aucune munition CAESAR n'est explicitement sélectionnée.
  final Systeme systeme;

  final bool pieceUtm;
  final ObjectifInputMode objectifMode;

  bool get objUtm => objectifMode == ObjectifInputMode.utm;
  bool get objDaz => objectifMode == ObjectifInputMode.daz;
  bool get objLat => objectifMode == ObjectifInputMode.lat;

  final TypeTir typeTir;

  /// Munition explicitement sélectionnée pour le tir.
  ///
  /// Nullable pendant la migration afin de préserver les systèmes dont le
  /// référentiel de munitions n'est pas encore constitué.
  final TypeMunition? typeMunition;

  /// Famille M252 transportée dans l'état de formulaire.
  ///
  /// Donnée structurelle uniquement ; le moteur M252 reste non connecté.
  final M252MunitionFamily? m252MunitionFamily;

  final bool natureEnabled;
  final int natureIdx;
  final NatureTirSelection? natureSelection;

  final bool tirVertical;

  final bool masseEnabled;
  final int carreaux;

  final bool tirSimilaire;
  final int simCarreaux;
  final TypeFusee? simFusee;
  final double? tPrev;
  final double? tAct;
  final double? v0Prev;

  final bool fuseeEnabled;
  final TypeFusee fusee;

  final bool meteo;
  final String? meteoFileName;
  final List<MeteoRow>? meteoRows;
  final double? meteoStationAltM;

  final bool forcerCharge;
  final int? chargeForcee;

  /// Charge forcée en format String pour MO-120 (ex. 'CH0', 'CH1/2').
  /// Prioritaire sur [chargeForcee] quand non null.
  final String? chargeForceeStr;

  // ─────────────────────── Observateur ───────────────────────
  final bool observateurEnabled;
  final ObservateurObjMode observateurObjMode;

  final bool autrePieces;
  final List<PieceSoutien> piecesSoutien;

  final Map<String, int> coupsParPieceByPiece;
  final LinearFiringMode linearFiringMode;
  final List<String> selectedLinearRoles;

  final bool busy;
  final FireRequest? lastRequest;
  final CalculResult? lastResult;
  final TirCompletOutput? lastOutput;

  final double? niveauBLocal;
  final double? siteBLocalM;
  final double? latitudePieceDeg;
  final double? deltaAltMet;

  const TirCompletState({
    this.commandLevel = FireCommandLevel.ue,
    this.typeChargeCaesar = TypeChargeCaesar.fr,
    this.systeme = Systeme.caesar,
    this.pieceUtm = true,
    this.objectifMode = ObjectifInputMode.daz,
    this.typeTir = TypeTir.appui,
    this.typeMunition = TypeMunition.oeF5Fr,
    this.m252MunitionFamily,
    this.natureEnabled = false,
    this.natureIdx = 0,
    this.natureSelection,
    this.tirVertical = false,
    this.masseEnabled = false,
    this.carreaux = 4,
    this.tirSimilaire = false,
    this.simCarreaux = 4,
    this.simFusee,
    this.tPrev,
    this.tAct,
    this.v0Prev,
    this.fuseeEnabled = false,
    this.fusee = TypeFusee.frappe,
    this.meteo = false,
    this.meteoFileName,
    this.meteoRows,
    this.meteoStationAltM,
    this.forcerCharge = false,
    this.chargeForcee,
    this.chargeForceeStr,
    this.observateurEnabled = false,
    this.observateurObjMode = ObservateurObjMode.daz,
    this.autrePieces = false,
    this.piecesSoutien = const [],
    this.coupsParPieceByPiece = const {},
    this.linearFiringMode = LinearFiringMode.libre,
    this.selectedLinearRoles = const [],
    this.busy = false,
    this.lastRequest,
    this.lastResult,
    this.lastOutput,
    this.niveauBLocal,
    this.siteBLocalM,
    this.latitudePieceDeg,
    this.deltaAltMet,
  });

  int get lineaireParSafe => (natureSelection?.lineairePar ?? 1).clamp(1, 12);
  int get nbCoupsBaseSafe => (natureSelection?.nbCoups ?? 1).clamp(1, 40);

  int _supportCountFromCoupsMap() {
    if (coupsParPieceByPiece.isEmpty) return 0;

    return coupsParPieceByPiece.keys
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty && e != 'PD')
        .toSet()
        .length;
  }

  int get nbCoupsTotalFromNatureSelection {
    final sel = natureSelection;
    if (!natureEnabled || sel == null) return 1;

    if (sel.nature == NatureTirType.ponctuel) {
      if (!autrePieces) {
        return nbCoupsBaseSafe.clamp(1, 400);
      }

      final int supportCount = math.max(
        piecesSoutien.length,
        _supportCountFromCoupsMap(),
      );

      // Le nombre de pièces doit refléter les pièces réellement configurées.
      // Ne pas appliquer ici une limite d'effectif implicite : les contrôles
      // d'UI et de configuration décident quelles pièces sont disponibles.
      final int piecesCount = math.max(1, 1 + supportCount);
      return (nbCoupsBaseSafe * piecesCount).clamp(1, 400);
    }

    return (nbCoupsBaseSafe * lineaireParSafe).clamp(1, 200);
  }

  TirCompletState copyWith({
    FireCommandLevel? commandLevel,
    TypeChargeCaesar? typeChargeCaesar,
    Systeme? systeme,
    bool? pieceUtm,
    bool? observateurEnabled,
    ObservateurObjMode? observateurObjMode,
    ObjectifInputMode? objectifMode,
    TypeTir? typeTir,
    TypeMunition? typeMunition,
    bool clearTypeMunition = false,
    M252MunitionFamily? m252MunitionFamily,
    bool clearM252MunitionFamily = false,
    bool? natureEnabled,
    int? natureIdx,
    NatureTirSelection? natureSelection,
    bool removeNatureSelection = false,
    bool? tirVertical,
    bool? masseEnabled,
    int? carreaux,
    bool? tirSimilaire,
    int? simCarreaux,
    TypeFusee? simFusee,
    double? tPrev,
    double? tAct,
    double? v0Prev,
    bool removeTirSimilaireValues = false,
    bool? fuseeEnabled,
    TypeFusee? fusee,
    bool? meteo,
    String? meteoFileName,
    List<MeteoRow>? meteoRows,
    double? meteoStationAltM,
    bool removeMeteo = false,
    bool? forcerCharge,
    int? chargeForcee,
    String? chargeForceeStr,
    bool removeChargeForcee = false,
    bool removeChargeForceeStr = false,
    bool? autrePieces,
    List<PieceSoutien>? piecesSoutien,
    Map<String, int>? coupsParPieceByPiece,
    LinearFiringMode? linearFiringMode,
    List<String>? selectedLinearRoles,
    bool? busy,
    FireRequest? lastRequest,
    CalculResult? lastResult,
    TirCompletOutput? lastOutput,
    bool removeLastRequest = false,
    bool removeLastResult = false,
    bool removeLastOutput = false,
    double? niveauBLocal,
    double? siteBLocalM,
    double? latitudePieceDeg,
    double? deltaAltMet,
  }) {
    return TirCompletState(
      commandLevel: commandLevel ?? this.commandLevel,
      typeChargeCaesar: typeChargeCaesar ?? this.typeChargeCaesar,
      systeme: systeme ?? this.systeme,
      pieceUtm: pieceUtm ?? this.pieceUtm,
      observateurEnabled: observateurEnabled ?? this.observateurEnabled,
      observateurObjMode: observateurObjMode ?? this.observateurObjMode,
      objectifMode: objectifMode ?? this.objectifMode,
      typeTir: typeTir ?? this.typeTir,
      typeMunition:
          clearTypeMunition ? null : (typeMunition ?? this.typeMunition),
      m252MunitionFamily: clearM252MunitionFamily
          ? null
          : (m252MunitionFamily ?? this.m252MunitionFamily),
      natureEnabled: natureEnabled ?? this.natureEnabled,
      natureIdx: natureIdx ?? this.natureIdx,
      natureSelection: removeNatureSelection
          ? null
          : (natureSelection ?? this.natureSelection),
      tirVertical: tirVertical ?? this.tirVertical,
      masseEnabled: masseEnabled ?? this.masseEnabled,
      carreaux: carreaux ?? this.carreaux,
      tirSimilaire: tirSimilaire ?? this.tirSimilaire,
      simCarreaux: simCarreaux ?? this.simCarreaux,
      simFusee: removeTirSimilaireValues ? null : (simFusee ?? this.simFusee),
      tPrev: removeTirSimilaireValues ? null : (tPrev ?? this.tPrev),
      tAct: removeTirSimilaireValues ? null : (tAct ?? this.tAct),
      v0Prev: removeTirSimilaireValues ? null : (v0Prev ?? this.v0Prev),
      fuseeEnabled: fuseeEnabled ?? this.fuseeEnabled,
      fusee: fusee ?? this.fusee,
      meteo: meteo ?? this.meteo,
      meteoFileName: removeMeteo ? null : (meteoFileName ?? this.meteoFileName),
      meteoRows: removeMeteo ? null : (meteoRows ?? this.meteoRows),
      meteoStationAltM:
          removeMeteo ? null : (meteoStationAltM ?? this.meteoStationAltM),
      forcerCharge: forcerCharge ?? this.forcerCharge,
      chargeForcee:
          removeChargeForcee ? null : (chargeForcee ?? this.chargeForcee),
      chargeForceeStr: removeChargeForceeStr
          ? null
          : (chargeForceeStr ?? this.chargeForceeStr),
      autrePieces: autrePieces ?? this.autrePieces,
      piecesSoutien: piecesSoutien ?? this.piecesSoutien,
      coupsParPieceByPiece: coupsParPieceByPiece ?? this.coupsParPieceByPiece,
      linearFiringMode: linearFiringMode ?? this.linearFiringMode,
      selectedLinearRoles: selectedLinearRoles ?? this.selectedLinearRoles,
      busy: busy ?? this.busy,
      lastRequest: removeLastRequest ? null : (lastRequest ?? this.lastRequest),
      lastResult: removeLastResult ? null : (lastResult ?? this.lastResult),
      lastOutput: removeLastOutput ? null : (lastOutput ?? this.lastOutput),
      niveauBLocal: niveauBLocal ?? this.niveauBLocal,
      siteBLocalM: siteBLocalM ?? this.siteBLocalM,
      latitudePieceDeg: latitudePieceDeg ?? this.latitudePieceDeg,
      deltaAltMet: deltaAltMet ?? this.deltaAltMet,
    );
  }
}

class TirCompletNotifier extends StateNotifier<TirCompletState> {
  TirCompletNotifier() : super(const TirCompletState());

  void setCommandLevel(FireCommandLevel level) {
    state = state.copyWith(commandLevel: level);
  }

  void setTypeChargeCaesar(TypeChargeCaesar type) {
    state = state.copyWith(typeChargeCaesar: type);
  }

  FuseeCompatibility _fuseeCompatibility({
    Systeme? systeme,
    TypeTir? typeTir,
    TypeMunition? munition,
  }) {
    return fuseeCompatibilityPour(
      systeme: systeme ?? state.systeme,
      typeTir: typeTir ?? state.typeTir,
      munition: munition,
    );
  }

  void _applyFusee(
    TypeFusee requested, {
    required FuseeCompatibility compatibility,
    required bool enabled,
  }) {
    state = state.copyWith(
      fusee: compatibility.normalise(requested),
      // Une fusée imposée reste toujours active. Pour les autres munitions,
      // l'activation conserve la sémantique historique du switch UI.
      fuseeEnabled: compatibility.estVerrouillee || enabled,
    );
  }

  void setSysteme(Systeme systeme) {
    final TypeMunition? munition = munitionParDefautPour(
      systeme: systeme,
      typeTir: state.typeTir,
    );
    final compatibility = _fuseeCompatibility(
      systeme: systeme,
      munition: munition,
    );

    final m252Items = systeme == Systeme.mo81M252
        ? m252MunitionsDisponiblesPour(state.typeTir)
        : const <M252MunitionFamily>[];
    final m252Munition = m252Items.isEmpty ? null : m252Items.first;

    // Recaler les carreaux de référence lors d'un changement de système.
    // CAESAR = 4 ; MEPAC / MO-120 = 2.
    // Les systèmes MO81 ne passent pas par cette logique de carreaux.
    final int referenceCarreaux = switch (systeme) {
      Systeme.caesar ||
      Systeme.mepac ||
      Systeme.mo120 =>
        systeme.carreauxReference,
      Systeme.mo81M252 || Systeme.mo81Lrr => state.simCarreaux,
    };

    state = state.copyWith(
      systeme: systeme,
      carreaux: referenceCarreaux,
      simCarreaux: referenceCarreaux,
      typeMunition: munition,
      clearTypeMunition: munition == null,
      m252MunitionFamily: m252Munition,
      clearM252MunitionFamily: m252Munition == null,
      typeChargeCaesar: systeme == Systeme.caesar
          ? (munition?.typeChargeCaesar ?? state.typeChargeCaesar)
          : TypeChargeCaesar.fr,
      fusee: compatibility.reference,
      fuseeEnabled: compatibility.estVerrouillee,
    );
  }

  void setTypeTir(TypeTir type) {
    if (type == state.typeTir) {
      return;
    }

    // Le type de tir, le système et la munition déterminent conjointement la
    // politique de fusée. On sélectionne directement la munition par défaut
    // lorsqu'elle existe, afin d'éviter tout état transitoire ambigu.
    final TypeMunition? munition = munitionParDefautPour(
      systeme: state.systeme,
      typeTir: type,
    );
    final compatibility = _fuseeCompatibility(
      typeTir: type,
      munition: munition,
    );

    final m252Items = state.systeme == Systeme.mo81M252
        ? m252MunitionsDisponiblesPour(type)
        : const <M252MunitionFamily>[];
    final currentM252 = state.m252MunitionFamily;
    final resolvedM252 = m252Items.isEmpty
        ? null
        : (currentM252 != null && m252Items.contains(currentM252)
            ? currentM252
            : m252Items.first);

    state = state.copyWith(
      typeTir: type,
      typeMunition: munition,
      clearTypeMunition: munition == null,
      m252MunitionFamily: resolvedM252,
      clearM252MunitionFamily: resolvedM252 == null,
      typeChargeCaesar: munition?.typeChargeCaesar ?? state.typeChargeCaesar,
      fusee: compatibility.reference,
      fuseeEnabled: compatibility.estVerrouillee,
    );
  }

  void setM252MunitionFamily(M252MunitionFamily family) {
    if (state.systeme != Systeme.mo81M252) {
      return;
    }

    final disponibles = m252MunitionsDisponiblesPour(state.typeTir);
    if (!disponibles.contains(family)) {
      return;
    }

    state = state.copyWith(m252MunitionFamily: family);
  }

  void setTypeMunition(TypeMunition? type) {
    // Une munition null est résolue vers la munition par défaut du contexte,
    // lorsqu'elle existe. La fusée est toujours remise sur la référence de la
    // politique nouvellement sélectionnée.
    final TypeMunition? munition = type ??
        munitionParDefautPour(
          systeme: state.systeme,
          typeTir: state.typeTir,
        );
    final compatibility = _fuseeCompatibility(munition: munition);

    state = state.copyWith(
      typeMunition: munition,
      typeChargeCaesar: munition?.typeChargeCaesar ?? state.typeChargeCaesar,
      clearTypeMunition: munition == null,
      fusee: compatibility.reference,
      fuseeEnabled: compatibility.estVerrouillee,
    );
  }

  void togglePieceUtm() => state = state.copyWith(pieceUtm: !state.pieceUtm);

  void setObjectifMode(ObjectifInputMode mode) {
    state = state.copyWith(objectifMode: mode);
  }

  void cycleObjectifMode() {
    final next = switch (state.objectifMode) {
      ObjectifInputMode.utm => ObjectifInputMode.daz,
      ObjectifInputMode.daz => ObjectifInputMode.lat,
      ObjectifInputMode.lat => ObjectifInputMode.utm,
    };
    state = state.copyWith(objectifMode: next);
  }

  // Compatibilité anciens appels
  void toggleObjUtm() => cycleObjectifMode();

  void setNatureEnabled(bool enabled) {
    if (!enabled) {
      state = state.copyWith(
        natureEnabled: false,
        natureIdx: 0,
        removeNatureSelection: true,
        autrePieces: false,
        coupsParPieceByPiece: const <String, int>{},
        linearFiringMode: LinearFiringMode.libre,
        selectedLinearRoles: const <String>[],
        removeLastRequest: true,
        removeLastResult: true,
        removeLastOutput: true,
        niveauBLocal: null,
        siteBLocalM: null,
        latitudePieceDeg: null,
        deltaAltMet: null,
      );
      return;
    }

    state = state.copyWith(
      natureEnabled: true,
      natureIdx: state.natureIdx,
      removeLastRequest: true,
      removeLastResult: true,
      removeLastOutput: true,
      niveauBLocal: null,
      siteBLocalM: null,
      latitudePieceDeg: null,
      deltaAltMet: null,
    );
  }

  NatureTirSelection _normalizeNatureSelection(NatureTirSelection sel) {
    if (sel.nature == NatureTirType.ponctuel) {
      return sel.copyWith(
        nbCoups: sel.nbCoups ?? 1,
        lineairePar: 1,
        longueurM: 0.0,
        longueurZonaleM: 0.0,
        profondeurM: 0.0,
      );
    }

    final par = (sel.lineairePar ?? 1).clamp(1, 12);
    return sel.copyWith(lineairePar: par);
  }

  void setNatureSelection(NatureTirSelection selection) {
    final sel = _normalizeNatureSelection(selection);

    final int idx = switch (sel.nature) {
      NatureTirType.ponctuel => 0,
      NatureTirType.lineaire => 1,
      NatureTirType.zonal => 2,
    };

    if (sel.nature == NatureTirType.ponctuel) {
      final int nbCoups = (sel.nbCoups ?? 1).clamp(1, 400);

      state = state.copyWith(
        natureSelection: sel,
        natureIdx: idx,
        natureEnabled: sel.enabled,
        autrePieces: false,
        coupsParPieceByPiece: <String, int>{'PD': nbCoups},
        linearFiringMode: LinearFiringMode.libre,
        selectedLinearRoles: const <String>[],
        removeLastRequest: true,
        removeLastResult: true,
        removeLastOutput: true,
        niveauBLocal: null,
        siteBLocalM: null,
        latitudePieceDeg: null,
        deltaAltMet: null,
      );

      return;
    }

    state = state.copyWith(
      natureSelection: sel,
      natureIdx: idx,
      natureEnabled: sel.enabled,
      removeLastRequest: true,
      removeLastResult: true,
      removeLastOutput: true,
      niveauBLocal: null,
      siteBLocalM: null,
      latitudePieceDeg: null,
      deltaAltMet: null,
    );
  }

  void setLineairePar(int value) {
    final sel = state.natureSelection;
    if (sel == null) return;

    final par = value.clamp(1, 12);
    if (sel.nature == NatureTirType.ponctuel) {
      state = state.copyWith(natureSelection: sel.copyWith(lineairePar: 1));
      return;
    }
    state = state.copyWith(natureSelection: sel.copyWith(lineairePar: par));
  }

  void setTirVertical(bool value) => state = state.copyWith(tirVertical: value);

  void setMasseEnabled(bool enabled) =>
      state = state.copyWith(masseEnabled: enabled);

  void setCarreaux(int value) => state = state.copyWith(carreaux: value);

  void setTirSimilaireEnabled(bool enabled) {
    if (!enabled) {
      state = state.copyWith(
        tirSimilaire: false,
        removeTirSimilaireValues: true,
      );
    } else {
      state = state.copyWith(tirSimilaire: true);
    }
  }

  void setTirSimilaireValues({
    required int carreaux,
    TypeFusee? fusee,
    double? tPrev,
    double? tAct,
    double? v0,
  }) {
    state = state.copyWith(
      tirSimilaire: true,
      simCarreaux: carreaux,
      simFusee: fusee,
      tPrev: tPrev,
      tAct: tAct,
      v0Prev: v0,
    );
  }

  /// Tir similaire simplifié pour le MO81 LLR.
  ///
  /// Les tables donnent directement la V0 de référence de la charge et
  /// utilisent 21 °C comme température de référence. L'utilisateur ne saisit
  /// donc que la température de poudre actuelle.
  void setTirSimilaireMo81Llr({
    required double tempPoudreActuelleC,
    required double v0ReferenceMps,
  }) {
    state = state.copyWith(
      tirSimilaire: true,
      simFusee: state.fusee,
      tPrev: 21.0,
      tAct: tempPoudreActuelleC,
      v0Prev: v0ReferenceMps,
    );
  }

  void setFuseeEnabled(bool enabled) {
    final compatibility = _fuseeCompatibility(munition: state.typeMunition);

    if (!enabled || compatibility.estVerrouillee) {
      _applyFusee(
        compatibility.reference,
        compatibility: compatibility,
        enabled: false,
      );
      return;
    }

    _applyFusee(
      state.fusee,
      compatibility: compatibility,
      enabled: true,
    );
  }

  void setFusee(TypeFusee fusee) {
    final compatibility = _fuseeCompatibility(munition: state.typeMunition);
    _applyFusee(
      fusee,
      compatibility: compatibility,
      enabled: true,
    );
  }

  void clearMeteo() {
    state = state.copyWith(meteo: false, removeMeteo: true);
  }

  void setMeteoLoaded({
    required String fileName,
    required List<MeteoRow> rows,
    double? stationAltM,
  }) {
    state = state.copyWith(
      meteo: true,
      meteoFileName: fileName,
      meteoRows: rows,
      meteoStationAltM: stationAltM,
    );
  }

  void clearChargeForcee() {
    state = state.copyWith(
      forcerCharge: false,
      removeChargeForcee: true,
      removeChargeForceeStr: true,
    );
  }

  void setChargeForcee(int charge) {
    state = state.copyWith(
      forcerCharge: true,
      chargeForcee: charge,
      removeChargeForceeStr: true,
    );
  }

  /// Pour MO-120 : charge forcée en String (ex. 'CH0', 'CH1/2', 'CH10').
  void setChargeForceeString(String charge) {
    final normalized = charge.trim().toUpperCase();
    if (normalized.isEmpty) {
      clearChargeForcee();
      return;
    }

    state = state.copyWith(
      forcerCharge: true,
      chargeForceeStr: normalized,
      removeChargeForcee: true,
    );
  }

  void setObservateurEnabled(bool enabled) =>
      state = state.copyWith(observateurEnabled: enabled);

  void setObservateurObjMode(ObservateurObjMode mode) =>
      state = state.copyWith(observateurObjMode: mode);

  void cycleObservateurObjMode() {
    final next = state.observateurObjMode == ObservateurObjMode.daz
        ? ObservateurObjMode.utm
        : ObservateurObjMode.daz;
    state = state.copyWith(observateurObjMode: next);
  }

  void setAutrePiecesEnabled(bool enabled) =>
      state = state.copyWith(autrePieces: enabled);

  void setCoupsParPieceByPiece(Map<String, int> map) {
    state = state.copyWith(coupsParPieceByPiece: Map<String, int>.from(map));
  }

  void setPiecesSoutien(List<PieceSoutien> pieces) {
    state = state.copyWith(piecesSoutien: pieces);
  }

  void setLinearFiringMode(LinearFiringMode mode) {
    state = state.copyWith(linearFiringMode: mode);
  }

  void setSelectedLinearRoles(List<String> roles) {
    state = state.copyWith(selectedLinearRoles: List<String>.from(roles));
  }

  void addPieceSoutien(PieceSoutien ps) {
    final list = [...state.piecesSoutien, ps];
    state = state.copyWith(piecesSoutien: list);
  }

  void removeLastPieceSoutien() {
    if (state.piecesSoutien.isEmpty) return;
    final list = [...state.piecesSoutien]..removeLast();
    state = state.copyWith(piecesSoutien: list);
  }

  void updatePieceSoutien(int index, PieceSoutien ps) {
    if (index < 0 || index >= state.piecesSoutien.length) return;
    final list = [...state.piecesSoutien];
    list[index] = ps;
    state = state.copyWith(piecesSoutien: list);
  }

  void setBusy(bool value) => state = state.copyWith(busy: value);

  void clearResult() {
    state = state.copyWith(
      removeLastRequest: true,
      removeLastResult: true,
      removeLastOutput: true,
      niveauBLocal: null,
      siteBLocalM: null,
      latitudePieceDeg: null,
      deltaAltMet: null,
    );
  }

  void setResult({
    required CalculResult result,
    FireRequest? request,
    TirCompletOutput? output,
    double? niveauBLocal,
    double? siteBLocalM,
    double? latitudePieceDeg,
    double? deltaAltMet,
  }) {
    state = state.copyWith(
      lastRequest: request,
      removeLastRequest: request == null,
      lastResult: result,
      lastOutput: output,
      niveauBLocal: niveauBLocal,
      siteBLocalM: siteBLocalM,
      latitudePieceDeg: latitudePieceDeg,
      deltaAltMet: deltaAltMet,
    );
  }
}

final tirCompletProvider =
    StateNotifierProvider<TirCompletNotifier, TirCompletState>(
  (ref) => TirCompletNotifier(),
);
