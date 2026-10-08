// lib/domain/fire/doctrine/mo81_llr_initial_conditions.dart
//
// Données initiales de référence MO81 LLR.
//
// La V0 dépend de la munition ET de la charge.
// La température de référence est 21 °C.
// Le calcul de l'effet température reste assuré par les tables T3.

import 'package:calculateur_etranger/models/calcul_data.dart';

class Mo81LlrInitialConditions {
  const Mo81LlrInitialConditions._();

  static const double temperatureReferenceC = 21.0;

  // OE 81 F1 — valeurs de référence disponibles.
  // Le raccordement à TypeMunition pourra être ajouté dès que le nom exact
  // de l'enum utilisé par le projet est confirmé.
  static const Map<String, double> v0ReferenceOe81F1Mps = <String, double>{
    'CH1': 100.0,
    'CH2': 131.5,
    'CH3': 157.0,
    'CH4': 192.0,
    'CH5': 222.5,
    'CH6': 249.5,
    'CH7': 273.5,
    'CH8': 296.0,
    'CH9': 320.0,
  };

  // OE 81 F2.
  static const Map<String, double> v0ReferenceOe81F2Mps = <String, double>{
    'CH1': 104.5,
    'CH2': 137.5,
    'CH3': 195.0,
    'CH4': 245.0,
    'CH5': 288.0,
    'CH6': 326.5,
  };

  // OECL 81 F1.
  static const Map<String, double> v0ReferenceOecl81F1Mps = <String, double>{
    'CH1': 117.5,
    'CH2': 144.0,
    'CH3': 170.5,
    'CH4': 191.0,
    'CH5': 212.0,
    'CH6': 232.5,
  };

  // OECL 81 F3.
  static const Map<String, double> v0ReferenceOecl81F3Mps = <String, double>{
    'CH1': 117.0,
    'CH2': 158.5,
    'CH3': 215.0,
    'CH4': 267.5,
    'CH5': 311.5,
  };

  // OECL IR 81 F2.
  static const Map<String, double> v0ReferenceOeclIr81F2Mps = <String, double>{
    'CH1': 124.0,
    'CH2': 137.5,
    'CH3': 195.0,
    'CH4': 245.0,
    'CH5': 288.0,
    'CH6': 326.5,
  };

  static const Map<String, Mo81LlrChargeComposition> compositions =
      <String, Mo81LlrChargeComposition>{
    'CH1': Mo81LlrChargeComposition(
      cartouche: 1,
      relaisBleu: 1,
      relaisIncolore: 0,
    ),
    'CH2': Mo81LlrChargeComposition(
      cartouche: 1,
      relaisBleu: 2,
      relaisIncolore: 0,
    ),
    'CH3': Mo81LlrChargeComposition(
      cartouche: 1,
      relaisBleu: 2,
      relaisIncolore: 1,
    ),
    'CH4': Mo81LlrChargeComposition(
      cartouche: 1,
      relaisBleu: 2,
      relaisIncolore: 2,
    ),
    'CH5': Mo81LlrChargeComposition(
      cartouche: 1,
      relaisBleu: 2,
      relaisIncolore: 3,
    ),
    'CH6': Mo81LlrChargeComposition(
      cartouche: 1,
      relaisBleu: 2,
      relaisIncolore: 4,
    ),
  };

  static String normalizeCharge(String charge) {
    final raw = charge.trim().toUpperCase().replaceAll(' ', '');
    if (raw.startsWith('CH')) return raw;
    return 'CH$raw';
  }

  static Map<String, double> v0TableForMunition(TypeMunition munition) {
    switch (munition) {
      case TypeMunition.oe81F2:
        return v0ReferenceOe81F2Mps;
      case TypeMunition.oecl81F1:
        return v0ReferenceOecl81F1Mps;
      case TypeMunition.oecl81F3:
        return v0ReferenceOecl81F3Mps;
      case TypeMunition.oeclIr81F2:
        return v0ReferenceOeclIr81F2Mps;
      default:
        throw StateError(
          'V0 MO81 LLR non configurée pour la munition $munition.',
        );
    }
  }

  static double v0ForMunitionAndCharge(TypeMunition munition, String charge) {
    final normalized = normalizeCharge(charge);
    final values = v0TableForMunition(munition);
    final value = values[normalized];

    if (value == null) {
      throw StateError(
        'V0 de référence MO81 LLR inconnue pour '
        '$munition / $normalized.',
      );
    }

    return value;
  }

  /// Compatibilité avec l'ancien code : cette méthode conserve le comportement
  /// historique OE 81 F2.
  static double v0ForCharge(String charge) {
    return v0ForMunitionAndCharge(TypeMunition.oe81F2, charge);
  }

  static Mo81LlrChargeComposition compositionForCharge(String charge) {
    final normalized = normalizeCharge(charge);
    final value = compositions[normalized];

    if (value == null) {
      throw StateError(
        'Composition MO81 LLR inconnue pour la charge $normalized.',
      );
    }

    return value;
  }
}

class Mo81LlrChargeComposition {
  final int cartouche;
  final int relaisBleu;
  final int relaisIncolore;

  const Mo81LlrChargeComposition({
    required this.cartouche,
    required this.relaisBleu,
    required this.relaisIncolore,
  });

  @override
  String toString() {
    final parts = <String>['cartouche $cartouche', 'relais bleu $relaisBleu'];

    if (relaisIncolore > 0) {
      parts.add('relais incolore $relaisIncolore');
    }

    return parts.join(' + ');
  }
}
