import 'dart:math' as math;

/// Résultat du calcul de réglage en observation unilatérale.
class ReglageResult {
  /// Angle entre l'axe d'observation OR et l'axe de tir PR (mil).
  final double angleObsMil;

  /// Distance d'observation d = OR (m).
  final double distObsM;

  /// Distance de tir D = PR (m).
  final double distTirM;

  /// Écart latéral observé, signé : + = droite observateur, - = gauche.
  final double ecartLateralObsMil;

  /// Écart en profondeur observé, signé : + = long/plus loin, - = court/plus près.
  final double ecartProfondeurObsM;

  /// Coefficient d'observation (Tableau I / Annexe 3.2), en m par mil observé.
  final double coeffObservation;

  /// Écart latéral observé converti en mètres, signé dans le repère observateur.
  final double ecartLateralObsM;

  /// Correction à appliquer dans le repère observateur, latérale : + droite, - gauche.
  final double correctionLateraleObsM;

  /// Correction à appliquer dans le repère observateur, profondeur : + allonger, - raccourcir.
  final double correctionProfondeurObsM;

  /// Correction en portée ramenée dans le repère de la pièce : + allonger, - raccourcir.
  final double correctionPorteePieceM;

  /// Correction latérale ramenée dans le repère de la pièce : + droite, - gauche.
  final double correctionLateralePieceM;

  /// Correction direction issue de correctionLateralePieceM / D : + droite, - gauche.
  final double correctionDirectionMil;

  /// Angle de hausse initial AE (Tableau F), si fourni par l'UI.
  final double? aeInitialMil;

  /// AQE initiale du calcul balistique, si disponible.
  final double? aqeInitialeMil;

  /// Angle de hausse corrigé AE relu dans le Tableau F à la portée corrigée.
  final double? aeCorrigeMil;

  /// Site total AS corrigé, recalculé à la portée corrigée.
  final double? siteTotalAsCorrigeMil;

  /// ACS corrigé depuis le Tableau G à la portée corrigée.
  final double? acsCorrigeMil;

  /// AQE corrigée = AE corrigé + AS corrigé + ACS corrigé.
  final double? aqeCorrigeeMil;

  /// Coefficient Δportée/Δhausse (m/mil) issu de la table F.
  final double? bondPorteeParMil;

  /// Correction hausse en millièmes = correctionPorteePieceM / bondPorteeParMil.
  final double? correctionHausseMil;

  /// Nouvelle portée/distance de tir corrigée.
  final double porteeCorrigeeM;

  /// Nouvelle direction/noire corrigée.
  final double noireCorrigeeMil;

  const ReglageResult({
    required this.angleObsMil,
    required this.distObsM,
    required this.distTirM,
    required this.ecartLateralObsMil,
    required this.ecartProfondeurObsM,
    required this.coeffObservation,
    required this.ecartLateralObsM,
    required this.correctionLateraleObsM,
    required this.correctionProfondeurObsM,
    required this.correctionPorteePieceM,
    required this.correctionLateralePieceM,
    required this.correctionDirectionMil,
    this.aeInitialMil,
    this.aqeInitialeMil,
    this.aeCorrigeMil,
    this.siteTotalAsCorrigeMil,
    this.acsCorrigeMil,
    this.aqeCorrigeeMil,
    this.bondPorteeParMil,
    this.correctionHausseMil,
    required this.porteeCorrigeeM,
    required this.noireCorrigeeMil,
  });
}

/// Moteur de réglage.
///
/// Principe :
/// 1. on convertit l'écart observé (droite/gauche en mil + court/long en m)
///    en vecteur dans le repère observateur ;
/// 2. on inverse ce vecteur pour obtenir la correction à appliquer ;
/// 3. on projette cette correction dans le repère de la pièce ;
/// 4. on recalcule les éléments initiaux : portée et direction/noire.
class ReglageEngine {
  static double _milToRad(double mil) => mil * 2.0 * math.pi / 6400.0;

  static double _normMil(double mil) {
    var v = mil % 6400.0;
    if (v < 0) v += 6400.0;
    return v;
  }

  /// Calcule l'angle au point R entre l'axe pièce→repère et l'axe observateur→repère.
  static double computeAngleObsMil(
    double pX,
    double pY,
    double rX,
    double rY,
    double oX,
    double oY,
  ) {
    final rpX = pX - rX;
    final rpY = pY - rY;
    final roX = oX - rX;
    final roY = oY - rY;

    final modRP = math.sqrt(rpX * rpX + rpY * rpY);
    final modRO = math.sqrt(roX * roX + roY * roY);

    if (modRP < 1e-6 || modRO < 1e-6) return 0.0;

    final cosAngle = ((rpX * roX + rpY * roY) / (modRP * modRO)).clamp(
      -1.0,
      1.0,
    );
    final angleRad = math.acos(cosAngle);
    return angleRad * 6400.0 / (2.0 * math.pi);
  }

  /// [ecartLateralObsMil] : + si M est à droite de R vu de O, - si à gauche.
  /// [ecartProfondeurObsM] : + si M est long/plus loin que R dans l'axe O→R,
  /// - si M est court/plus près.
  /// [noireInitialeMil] : direction/noire avant réglage.
  static ReglageResult compute({
    required double pX,
    required double pY,
    required double rX,
    required double rY,
    required double oX,
    required double oY,
    required double ecartLateralObsMil,
    required double ecartProfondeurObsM,
    required double distTirM,
    required double noireInitialeMil,
    double? bondPorteeParMil,
    double? aeInitialMil,
    double? aqeInitialeMil,
    double? aeCorrigeMil,
    double? siteTotalAsCorrigeMil,
    double? acsCorrigeMil,
    double? aqeCorrigeeMil,
  }) {
    final dObsM = math.sqrt((oX - rX) * (oX - rX) + (oY - rY) * (oY - rY));
    final dObsKm = dObsM / 1000.0;

    final iMil = computeAngleObsMil(pX, pY, rX, rY, oX, oY);
    final iRad = _milToRad(iMil.clamp(10.0, 3190.0));
    final double sinI = math.sin(iRad).abs().clamp(1e-9, double.infinity);

    // Tableau I : m par mil observé.
    final coeff = dObsKm / sinI;
    final ecartLatObsM = ecartLateralObsMil * coeff;

    // Bases unitaires.
    final obsUx = (rX - oX) / dObsM;
    final obsUy = (rY - oY) / dObsM;
    final obsRightX = obsUy; // rotation horaire : droite de l'observateur
    final obsRightY = -obsUx;

    final tirUx = (rX - pX) / distTirM;
    final tirUy = (rY - pY) / distTirM;
    final tirRightX = tirUy; // droite de la pièce
    final tirRightY = -tirUx;

    // Erreur M-R vue par l'observateur.
    final errX = ecartProfondeurObsM * obsUx + ecartLatObsM * obsRightX;
    final errY = ecartProfondeurObsM * obsUy + ecartLatObsM * obsRightY;

    // Correction à appliquer = R-M.
    final corrX = -errX;
    final corrY = -errY;

    final corrProfObsM = -ecartProfondeurObsM;
    final corrLatObsM = -ecartLatObsM;

    // Projection dans le repère pièce.
    final corrPorteePieceM = corrX * tirUx + corrY * tirUy;
    final corrLateralePieceM = corrX * tirRightX + corrY * tirRightY;

    // Conversion latéral -> direction en mil, approximation d/D.
    final corrDirectionMil = (corrLateralePieceM / distTirM) * 1000.0;

    final corrHausseMil = (bondPorteeParMil != null && bondPorteeParMil > 1e-9)
        ? corrPorteePieceM / bondPorteeParMil
        : null;

    return ReglageResult(
      angleObsMil: iMil,
      distObsM: dObsM,
      distTirM: distTirM,
      ecartLateralObsMil: ecartLateralObsMil,
      ecartProfondeurObsM: ecartProfondeurObsM,
      coeffObservation: coeff,
      ecartLateralObsM: ecartLatObsM,
      correctionLateraleObsM: corrLatObsM,
      correctionProfondeurObsM: corrProfObsM,
      correctionPorteePieceM: corrPorteePieceM,
      correctionLateralePieceM: corrLateralePieceM,
      correctionDirectionMil: corrDirectionMil,
      aeInitialMil: aeInitialMil,
      aqeInitialeMil: aqeInitialeMil,
      aeCorrigeMil: aeCorrigeMil,
      siteTotalAsCorrigeMil: siteTotalAsCorrigeMil,
      acsCorrigeMil: acsCorrigeMil,
      aqeCorrigeeMil: aqeCorrigeeMil,
      bondPorteeParMil: bondPorteeParMil,
      correctionHausseMil: corrHausseMil,
      porteeCorrigeeM: distTirM + corrPorteePieceM,
      noireCorrigeeMil: _normMil(noireInitialeMil + corrDirectionMil),
    );
  }
}
