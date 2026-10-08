import 'package:calculateur_etranger/domain/fire/models/tir_complet_input.dart';

/// Canonical conversion of the zonal overflow input.
///
/// [TirCompletInput.pourcentageDebordement] is expressed as a percentage in
/// the UI and transport layer. Doctrine engines consume a ratio. Keeping this
/// conversion here prevents zonal paths from silently substituting a different
/// fallback or from treating a percentage as a ratio.
abstract final class ZonalOverflowRatio {
  /// Historical default used only when no value was supplied by the input.
  static const double defaultRatio = 0.05;

  static double fromInput(TirCompletInput input) {
    return fromPercentage(input.pourcentageDebordement);
  }

  static double fromPercentage(num? percentage) {
    if (percentage == null) return defaultRatio;
    return percentage.toDouble() / 100.0;
  }
}
