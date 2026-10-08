// lib/domain/fire/target_generation/lineaire/linear_fire_assignment.dart
//
// Doctrine linéaire :
//
// - Longueur nominale L
// - Débordement deb% => longueur étendue Le = L*(1+deb)
// - Rayon R = d/2 (d = diamètre d’efficacité)
// - Centres possibles : on doit rester dans la zone utile
//
// Conventions PR :
// - depuisExtremite=true : PR = origine de la LIGNE ÉTENDUE
//   => bornes étendues = [0, Le]
//   => centres ∈ [R, Le-R]
//
// - depuisExtremite=false : PR au centre de la ligne étendue
//   => bornes étendues = [-Le/2, +Le/2]
//   => centres ∈ [-Le/2+R, +Le/2-R]
//
// Doctrine spécifique ÉCLAIRANT :
// - Le diamètre d’efficacité représente déjà la couverture utile.
// - On ne calcule PAS avec le recouvrement doctrinal HE.
// - Nombre de coups = ceil(Le / d)
//
// Doctrine HE / RTC :
// - Pas maxi entre centres = step = d*(1-recouv)
// - Nombre de positions doctrinal = ceil(Le / step)

import 'dart:math' as math;

/// Nombre de positions doctrinales sur un linéaire.
int computeNbCoupsLineaire({
  required double longueurM,
  required double diametreEfficaciteM,
  required double recouvrementPourcent,
  required double debordementPourcent,
}) {
  final L = longueurM.isFinite ? longueurM : 0.0;

  if (L <= 0) {
    return 1;
  }

  final d = diametreEfficaciteM.isFinite ? diametreEfficaciteM : 0.0;
  final dd = d <= 0 ? 100.0 : d;

  final rec = (recouvrementPourcent.isFinite ? recouvrementPourcent : 0.0)
      .clamp(0.0, 95.0);

  final deb = (debordementPourcent.isFinite ? debordementPourcent : 0.0).clamp(
    0.0,
    80.0,
  );

  final Le = L * (1.0 + deb / 100.0);

  // Doctrine ÉCLAIRANT.
  // Exemple : L=1000, deb=5%, Le=1050, d=600 => ceil(1050/600)=2.
  final isEclairant = dd >= 600.0;

  if (isEclairant) {
    return math.max(1, (Le / dd).ceil());
  }

  // Doctrine HE / RTC.
  final rawStep = dd * (1.0 - rec / 100.0);
  final step = math.max(dd * 0.2, rawStep);

  return math.max(1, (Le / step).ceil());
}

/// Offsets doctrinaux (centres) en mètres dans l’axe du linéaire.
List<double> computeOffsetsLineaire({
  required int nbCoups,
  required double longueurM,
  required double diametreEfficaciteM,
  required double recouvrementPourcent,
  required double debordementPourcent,
  required bool depuisExtremite,
}) {
  final n = nbCoups <= 0 ? 1 : nbCoups;

  final L = longueurM.isFinite ? longueurM : 0.0;
  final d = diametreEfficaciteM.isFinite ? diametreEfficaciteM : 0.0;
  final dd = d <= 0 ? 100.0 : d;

  final deb = (debordementPourcent.isFinite ? debordementPourcent : 0.0).clamp(
    0.0,
    80.0,
  );

  final Le = (L <= 0 ? 1.0 : L) * (1.0 + deb / 100.0);

  final double extStart;
  final double extEnd;

  if (depuisExtremite) {
    extStart = 0.0;
    extEnd = Le;
  } else {
    extStart = -Le / 2.0;
    extEnd = Le / 2.0;
  }

  final R = dd / 2.0;
  final innerStart = extStart + R;
  final innerEnd = extEnd - R;

  if (innerEnd <= innerStart + 1e-9) {
    return <double>[(extStart + extEnd) / 2.0];
  }

  if (n == 1) {
    return <double>[(innerStart + innerEnd) / 2.0];
  }

  final step = (innerEnd - innerStart) / (n - 1);

  return List<double>.generate(
    n,
    (i) => innerStart + step * i,
    growable: false,
  );
}
