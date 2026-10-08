class CoverageEllipse {
  final double centerX;
  final double centerY;

  final double azimutMil;

  final double semiMajorAxis;
  final double semiMinorAxis;

  final double lethalRadius;
  final double angleChuteDeg;

  final double burstHeightM;

  /// Demi-grand axe du mode optionnel de distribution spatiale visuelle.
  ///
  /// Le rendu réel par défaut conserve semiMajorAxis/semiMinorAxis.
  /// Ces axes ne sont utilisés que si le switch de distribution spatiale est actif.
  final double visualSemiMajorAxis;
  final double visualSemiMinorAxis;

  /// Paramètres du modèle visuel abstrait de densité d'effet.
  ///
  /// Ce modèle sert uniquement à la représentation graphique :
  /// il ne modélise pas la létalité réelle ni les effets terminaux.
  final double visualLambda;
  final double visualForwardAlpha;
  final double visualRearBeta;

  /// Seuil de zone avant active, exprimé en fraction du demi-grand axe.
  /// 0.0 => x' > 0 ; 0.25 => x' > 0.25a.
  final double frontActiveThreshold;

  /// Intensité directionnelle historique de la couverture.
  /// Conservé pour compatibilité avec les anciens appels.
  final double directionalAlpha;

  /// Ratio visuel avant/arrière historique.
  /// Conservé pour compatibilité avec les anciens appels.
  final double forwardBackwardRatio;

  const CoverageEllipse({
    required this.centerX,
    required this.centerY,
    required this.azimutMil,
    required this.semiMajorAxis,
    required this.semiMinorAxis,
    required this.lethalRadius,
    required this.angleChuteDeg,
    required this.burstHeightM,
    double? visualSemiMajorAxis,
    double? visualSemiMinorAxis,
    this.visualLambda = 2.0,
    this.visualForwardAlpha = 1.0,
    this.visualRearBeta = 0.5,
    this.frontActiveThreshold = 0.0,
    this.directionalAlpha = 0.0,
    this.forwardBackwardRatio = 1.0,
  })  : visualSemiMajorAxis = visualSemiMajorAxis ?? semiMajorAxis,
        visualSemiMinorAxis = visualSemiMinorAxis ?? semiMinorAxis;
}
