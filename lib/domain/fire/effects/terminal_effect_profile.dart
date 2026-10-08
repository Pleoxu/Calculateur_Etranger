class TerminalEffectProfile {
  const TerminalEffectProfile({
    required this.id,
    required this.munitionKey,
    required this.validated,
    this.forwardFactor = 1.0,
    this.rearFactor = 1.0,
    this.lateralFactor = 1.0,
    this.maxElongationFactor = 4.0,
  });

  final String id;
  final String munitionKey;
  final bool validated;

  final double forwardFactor;
  final double rearFactor;
  final double lateralFactor;
  final double maxElongationFactor;
}
