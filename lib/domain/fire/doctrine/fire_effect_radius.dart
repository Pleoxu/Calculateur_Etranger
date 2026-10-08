/// Retourne le diamètre d'efficacité doctrinal de la munition sélectionnée.
///
/// Le système d'arme et la munition étant déjà choisis en amont, cette fonction
///
/// La valeur transmise doit être le diamètre d'efficacité porté par la
/// définition de la munition sélectionnée, par exemple :
/// - CAESAR Appui : 100 m
/// - CAESAR Éclairant : 600 m
double doctrineDiametreEfficaceM({required double diametreMunitionM}) {
  if (!diametreMunitionM.isFinite || diametreMunitionM <= 0) {
    throw ArgumentError.value(
      diametreMunitionM,
      'diametreMunitionM',
      'The effective diameter must be a finite value '
          'strictement positive.',
    );
  }

  return diametreMunitionM;
}
