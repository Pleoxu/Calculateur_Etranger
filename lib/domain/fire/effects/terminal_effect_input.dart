class TerminalEffectInput {
  const TerminalEffectInput({
    required this.centerX,
    required this.centerY,
    required this.azimutMil,
    required this.angleChuteDeg,
    required this.effectiveDiameterM,
    this.cotangenteAngleChute,
    this.ecartProbablePorteeM,
    this.ecartProbableDirectionM,
    this.residualVelocityMps,
    this.referenceVelocityMps,
    this.burstHeightM = 0.0,
  });

  final double centerX;
  final double centerY;

  final double azimutMil;
  final double angleChuteDeg;
  final double? cotangenteAngleChute;

  final double effectiveDiameterM;

  final double? ecartProbablePorteeM;
  final double? ecartProbableDirectionM;

  final double? residualVelocityMps;
  final double? referenceVelocityMps;

  final double burstHeightM;
}
