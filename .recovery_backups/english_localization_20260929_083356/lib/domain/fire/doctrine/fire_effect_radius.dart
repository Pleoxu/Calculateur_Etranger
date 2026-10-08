/// Retourne le diamètre d'efficacité doctrinal de la munition sélectionnée.
///
/// Le système d'arme et la munition étant déjà choisis en amont, cette fonction
/// ne déduit plus la valeur à partir du type de tir ou d'un booléen `isMo120`.
///
/// La valeur transmise doit être le diamètre d'efficacité porté par la
/// définition de la munition sélectionnée, par exemple :
/// - MO120 Appui : 50 m
/// - MO120 OECL : 400 m
/// - CAESAR Appui : 100 m
/// - CAESAR Éclairant : 600 m
double doctrineDiametreEfficaceM({required double diametreMunitionM}) {
  if (!diametreMunitionM.isFinite || diametreMunitionM <= 0) {
    throw ArgumentError.value(
      diametreMunitionM,
      'diametreMunitionM',
      'Le diamètre d’efficacité doit être une valeur finie '
          'strictement positive.',
    );
  }

  return diametreMunitionM;
}
