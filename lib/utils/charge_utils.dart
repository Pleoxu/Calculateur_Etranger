// lib/utils/charge_utils.dart
//
// Sélection de charge encadrée par distances.
// Règles :
// - Appui : règles progressives (80% / 85% / 90%) conservées
// - OECL (Éclairant) : règle UNIQUE à 95%
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
    case TypeTir.appuiRtc:
      throw UnsupportedError(
        'RTC charge selection is not connected in this compatibility build.',
      );
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
  if (max == 0) return 'Unknown charge';

  final min = porteeMinCharge(charge, typeTir: typeTir);
  final coeff = coefficientSeuilCharge(charge, typeTir: typeTir);
  final seuil = (coeff * max).floor();
  final pct = (coeff * 100).toStringAsFixed(0);

  return '${min.toStringAsFixed(0)} - ${seuil - 1} m (valid < $pct% of ${max.toStringAsFixed(0)} m)';
}
