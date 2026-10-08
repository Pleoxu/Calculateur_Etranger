import 'package:calculateur_etranger/models/calcul_data.dart';

/// Déclare les référentiels momentanément retirés du calcul pour une
/// combinaison système / munition donnée.
///
/// Une mise en maintenance doit bloquer le calcul avant tout chargement
/// d'asset. L'interface reste cependant navigable afin que les réglages et les
/// munitions puissent être préparés et vérifiés.
class BallisticTableMaintenance {
  const BallisticTableMaintenance._();

  /// Référentiels à revalider avant le raccordement du tir éclairant MO81 L16.
  static const List<String> mo81L16IlluminatingTables = <String>[
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
  ];

  static bool appliesToSelection({
    required Systeme systeme,
    required TypeTir typeTir,
  }) {
    return systeme == Systeme.mo81M252 && typeTir == TypeTir.eclairant;
  }

  static bool appliesTo(CalculInput input) {
    return appliesToSelection(systeme: input.systeme, typeTir: input.typeTir);
  }

  /// Arrête explicitement le calcul avant qu'il ne puisse utiliser les tables
  static void ensureCalculationAvailable(CalculInput input) {
    if (appliesTo(input)) {
      throw const Mo81L16IlluminatingTablesUnderMaintenance();
    }
  }
}

/// Erreur de domaine affichable dans l'interface, volontairement distincte
/// d'une table absente ou d'une erreur de décodage d'asset.
class Mo81L16IlluminatingTablesUnderMaintenance implements Exception {
  const Mo81L16IlluminatingTablesUnderMaintenance();

  List<String> get tables =>
      BallisticTableMaintenance.mo81L16IlluminatingTables;

  String get userMessage => 'MO81 L16 illumination is under maintenance: '
      'Tables ${tables.join(', ')} are unavailable.';

  @override
  String toString() =>
      'Mo81L16IlluminatingTablesUnderMaintenance: $userMessage';
}
