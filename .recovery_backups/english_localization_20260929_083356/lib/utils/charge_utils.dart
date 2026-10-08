// lib/utils/charge_utils.dart
//
// Sélection de charge encadrée par distances.
// Règles :
// - Appui : règles progressives (80% / 85% / 90%) conservées
// - OECL (Éclairant) : règle UNIQUE à 95%
// - MO-120 Appui : 14 charges (CH0 à CH10), règle à 85%
//
// Une charge est utilisable seulement si distance < seuil(charge).
// On prend la plus petite charge qui vérifie la condition, sinon 'HorsPortee'.

import 'package:calculateur_etranger/domain/fire/models/type_charge_caesar.dart';
import 'package:calculateur_etranger/models/calcul_data.dart' show TypeTir;

typedef MaxMap = Map<String, double>;

const List<String> _ordreChargesStandard = [
  'CH1',
  'CH2',
  'CH3',
  'CH4',
  'CH5',
  'CH6',
];
const List<String> _ordreChargesOecl = ['CH1', 'CH2', 'CH3', 'CH4', 'CH5'];

// Seuils progressifs (Appui)
const Map<String, double> _seuilsProgressifs = {
  'CH1': 0.90,
  'CH2': 0.90,
  'CH3': 0.90,
  'CH4': 0.95,
  'CH5': 0.95,
  'CH6': 0.97,
};

// Seuil unique OECL
const double _seuilOecl = 0.95;

// ==========================
// Portées max par type de tir (valeurs "référence" utilisées par le projet)
// ==========================

const MaxMap _appuiMax = {
  'CH1': 8813,
  'CH2': 13522,
  'CH3': 14865,
  'CH4': 18828,
  'CH5': 23495,
  'CH6': 29152,
};

// CAESAR — charges allemandes (ALL), tir Appui.
const MaxMap _appuiAllMax = {
  'CH1': 8376,
  'CH2': 12764,
  'CH3': 14705,
  'CH4': 18958,
  'CH5': 23280,
  'CH6': 29951,
};

const MaxMap _appuiAllV0 = {
  'CH1': 317,
  'CH2': 467,
  'CH3': 533,
  'CH4': 669,
  'CH5': 797,
  'CH6': 933,
};

const Map<String, double> _seuilsAppuiAll = {
  'CH1': 0.90,
  'CH2': 0.90,
  'CH3': 0.90,
  'CH4': 0.95,
  'CH5': 0.95,
  'CH6': 0.97,
};

// ⚠️ OECL : CH6 non proposée tant que l’asset Tableau F OECL CH6 n’existe pas.
const MaxMap _oeclMax = {
  'CH1': 8816,
  'CH2': 14244,
  'CH3': 16068,
  'CH4': 20933,
  'CH5': 26665,
  'CH6': 36616,
};

// ── MO-120 RTF1 — 14 charges (CH0 à CH10) ──────────────────────────────────
// Portées max issues des tables de tir (Vo de référence)
const List<String> _ordreChargesMo120 = [
  'CH0',
  'CH1/2',
  'CH1',
  'CH1½',
  'CH2',
  'CH2½',
  'CH3',
  'CH4',
  'CH5',
  'CH6',
  'CH7',
  'CH8',
  'CH9',
  'CH10',
];

const MaxMap _mo120AppuiMax = {
  'CH0': 1269,
  'CH1/2': 1700,
  'CH1': 2200,
  'CH1½': 2700,
  'CH2': 3200,
  'CH2½': 3700,
  'CH3': 4200,
  'CH4': 4800,
  'CH5': 5400,
  'CH6': 6000,
  'CH7': 6400,
  'CH8': 6800,
  'CH9': 7400,
  'CH10': 8178,
};

const double _seuilMo120 = 0.85;

// --------------------------
// Sélecteurs
// --------------------------

bool _isOeclLabel(String typeTir) {
  final t = typeTir.trim().toLowerCase();
  return t.contains('ecl') || t.contains('écl') || t.contains('oecl');
}

MaxMap _maxForTypeLabel(String typeTir) {
  final t = typeTir.trim().toLowerCase();
  if (_isOeclLabel(typeTir)) return _oeclMax;
  return _appuiMax;
}

MaxMap _maxForEnum(TypeTir type) {
  switch (type) {
    case TypeTir.eclairant:
      return _oeclMax;
    case TypeTir.appui:
      return _appuiMax;
  }
}

MaxMap _maxForCaesar({
  required TypeTir typeTir,
  required TypeChargeCaesar typeChargeCaesar,
}) {
  if (typeChargeCaesar == TypeChargeCaesar.allemande &&
      typeTir == TypeTir.appui) {
    return _appuiAllMax;
  }

  return _maxForEnum(typeTir);
}

double _coeffForCaesar({
  required String charge,
  required TypeTir typeTir,
  required TypeChargeCaesar typeChargeCaesar,
}) {
  if (typeChargeCaesar == TypeChargeCaesar.allemande &&
      typeTir == TypeTir.appui) {
    return _seuilsAppuiAll[charge] ?? 0.0;
  }

  return _coeffFor(charge, isOecl: typeTir == TypeTir.eclairant);
}

List<String> _ordreForTypeLabel(String typeTir) =>
    _isOeclLabel(typeTir) ? _ordreChargesOecl : _ordreChargesStandard;

List<String> _ordreForEnum(TypeTir type) =>
    (type == TypeTir.eclairant) ? _ordreChargesOecl : _ordreChargesStandard;

double _coeffFor(String charge, {required bool isOecl}) {
  if (isOecl) return _seuilOecl;
  return _seuilsProgressifs[charge] ?? 0.80;
}

// ===============
// API principale
// ===============

String choisirCharge(double distance, {String typeTir = 'Appui'}) {
  final maxMap = _maxForTypeLabel(typeTir);
  final ordre = _ordreForTypeLabel(typeTir);
  final isOecl = _isOeclLabel(typeTir);

  for (final ch in ordre) {
    final max = maxMap[ch];
    if (max == null) continue;
    final coeff = _coeffFor(ch, isOecl: isOecl);
    final seuil = coeff * max;
    if (distance < seuil) return ch;
  }
  return 'HorsPortee';
}

String choisirChargeEnum(double distance, {required TypeTir typeTir}) {
  final maxMap = _maxForEnum(typeTir);
  final ordre = _ordreForEnum(typeTir);
  final isOecl = (typeTir == TypeTir.eclairant);

  for (final ch in ordre) {
    final max = maxMap[ch];
    if (max == null) continue;
    final coeff = _coeffFor(ch, isOecl: isOecl);
    final seuil = coeff * max;
    if (distance < seuil) return ch;
  }
  return 'HorsPortee';
}

/// Sélection de charge CAESAR tenant compte de la famille FR / ALL.
String choisirChargeCaesar(
  double distance, {
  required TypeTir typeTir,
  required TypeChargeCaesar typeChargeCaesar,
}) {
  final maxMap = _maxForCaesar(
    typeTir: typeTir,
    typeChargeCaesar: typeChargeCaesar,
  );
  final ordre = _ordreForEnum(typeTir);

  for (final ch in ordre) {
    final max = maxMap[ch];
    if (max == null) continue;

    final coeff = _coeffForCaesar(
      charge: ch,
      typeTir: typeTir,
      typeChargeCaesar: typeChargeCaesar,
    );

    if (coeff <= 0) continue;

    final seuil = coeff * max;
    if (distance < seuil) return ch;
  }

  return 'HorsPortee';
}

double porteeMaxChargeCaesar(
  String charge, {
  required TypeTir typeTir,
  required TypeChargeCaesar typeChargeCaesar,
}) {
  final maxMap = _maxForCaesar(
    typeTir: typeTir,
    typeChargeCaesar: typeChargeCaesar,
  );

  return maxMap[charge.trim().toUpperCase()] ?? 0.0;
}

double coefficientSeuilChargeCaesar(
  String charge, {
  required TypeTir typeTir,
  required TypeChargeCaesar typeChargeCaesar,
}) {
  return _coeffForCaesar(
    charge: charge.trim().toUpperCase(),
    typeTir: typeTir,
    typeChargeCaesar: typeChargeCaesar,
  );
}

/// Calcule la portée utile maximale absolue (seuil * portée max)
/// pour la configuration CAESAR courante.
double getPorteeMaxAbsolueCaesar({
  required TypeTir typeTir,
  required TypeChargeCaesar typeChargeCaesar,
}) {
  final charges = chargesDisponiblesCaesar(
    typeTir: typeTir,
    typeChargeCaesar: typeChargeCaesar,
  );
  if (charges.isEmpty) return 0.0;

  final maxCharge = charges.last;
  final maxDist = porteeMaxChargeCaesar(
    maxCharge,
    typeTir: typeTir,
    typeChargeCaesar: typeChargeCaesar,
  );
  final coeff = coefficientSeuilChargeCaesar(
    maxCharge,
    typeTir: typeTir,
    typeChargeCaesar: typeChargeCaesar,
  );

  return maxDist * coeff;
}

double? v0ReferenceCaesar(
  String charge, {
  required TypeTir typeTir,
  required TypeChargeCaesar typeChargeCaesar,
}) {
  if (typeTir != TypeTir.appui ||
      typeChargeCaesar != TypeChargeCaesar.allemande) {
    return null;
  }

  return _appuiAllV0[charge.trim().toUpperCase()];
}

List<String> chargesDisponiblesCaesar({
  required TypeTir typeTir,
  required TypeChargeCaesar typeChargeCaesar,
}) {
  final maxMap = _maxForCaesar(
    typeTir: typeTir,
    typeChargeCaesar: typeChargeCaesar,
  );

  return List.unmodifiable(_ordreForEnum(typeTir).where(maxMap.containsKey));
}

/// Sélection de charge pour le MO-120 RTF1.
String choisirChargeMo120(double distance) {
  for (final ch in _ordreChargesMo120) {
    final max = _mo120AppuiMax[ch];
    if (max == null) continue;
    if (distance < _seuilMo120 * max) return ch;
  }
  return 'HorsPortee';
}

/// Portée max pour une charge MO-120.
double porteeMaxChargeMo120(String charge) =>
    _mo120AppuiMax[charge.toUpperCase()] ?? _mo120AppuiMax[charge] ?? 0.0;

/// Liste ordonnée des charges MO-120.
List<String> get ordreChargesMo120 => List.unmodifiable(_ordreChargesMo120);

// ==============
// Utilitaires
// ==============

double porteeMaxCharge(String charge, {String typeTir = 'Appui'}) {
  final maxMap = _maxForTypeLabel(typeTir);
  return maxMap[charge.toUpperCase()] ?? 0.0;
}

double porteeMaxChargeEnum(String charge, {required TypeTir typeTir}) {
  final maxMap = _maxForEnum(typeTir);
  return maxMap[charge.toUpperCase()] ?? 0.0;
}

double coefficientSeuilCharge(String charge, {String typeTir = 'Appui'}) {
  final isOecl = _isOeclLabel(typeTir);
  return _coeffFor(charge.toUpperCase(), isOecl: isOecl);
}

double porteeMinCharge(String charge, {String typeTir = 'Appui'}) {
  final ordre = _ordreForTypeLabel(typeTir);
  final idx = ordre.indexOf(charge.toUpperCase());
  if (idx <= 0) return 0.0;

  final prev = ordre[idx - 1];
  final prevMax = porteeMaxCharge(prev, typeTir: typeTir);
  if (prevMax <= 0) return 0.0;

  final prevCoeff = coefficientSeuilCharge(prev, typeTir: typeTir);
  return (prevCoeff * prevMax).floorToDouble() + 1.0;
}

String plagePorteeCharge(String charge, {String typeTir = 'Appui'}) {
  final max = porteeMaxCharge(charge, typeTir: typeTir);
  if (max == 0) return 'Charge inconnue';

  final min = porteeMinCharge(charge, typeTir: typeTir);
  final coeff = coefficientSeuilCharge(charge, typeTir: typeTir);
  final seuil = (coeff * max).floor();
  final pct = (coeff * 100).toStringAsFixed(0);

  return '${min.toStringAsFixed(0)} - ${seuil - 1} m (valide < $pct% de ${max.toStringAsFixed(0)} m)';
}
