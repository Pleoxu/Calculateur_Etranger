enum TypeChargeCaesar { fr, allemande }

extension TypeChargeCaesarX on TypeChargeCaesar {
  String get code => switch (this) {
        TypeChargeCaesar.fr => 'FR',
        TypeChargeCaesar.allemande => 'ALL',
      };

  String get label => switch (this) {
        TypeChargeCaesar.fr => 'Charges FR',
        TypeChargeCaesar.allemande => 'Charges ALL',
      };
}

/// Référence officielle d'un jeu de tables de tir CAESAR.
///
/// Étape 1 de la migration : l'enum est déclaré, mais les services continuent
/// d'utiliser les variantes historiques APPUI, APPUIRTC et OECL.
enum ArtTable { art386, art387, art388, art390, art391, art392 }

extension ArtTableX on ArtTable {
  String get code => switch (this) {
        ArtTable.art386 => 'ART386',
        ArtTable.art387 => 'ART387',
        ArtTable.art388 => 'ART388',
        ArtTable.art390 => 'ART390',
        ArtTable.art391 => 'ART391',
        ArtTable.art392 => 'ART392',
      };

  int get number => switch (this) {
        ArtTable.art386 => 386,
        ArtTable.art387 => 387,
        ArtTable.art388 => 388,
        ArtTable.art390 => 390,
        ArtTable.art391 => 391,
        ArtTable.art392 => 392,
      };

  static ArtTable? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }

    final value = raw.trim().toUpperCase().replaceAll(' ', '');

    return switch (value) {
      '386' || 'ART386' => ArtTable.art386,
      '387' || 'ART387' => ArtTable.art387,
      '388' || 'ART388' => ArtTable.art388,
      '390' || 'ART390' => ArtTable.art390,
      '391' || 'ART391' => ArtTable.art391,
      '392' || 'ART392' => ArtTable.art392,
      _ => null,
    };
  }
}
