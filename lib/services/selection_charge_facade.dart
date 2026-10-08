// lib/services/selection_charge_facade.dart
//
// Compatibility-only facade.
// Automatic charge selection is intentionally unavailable in this build.

class SelectionChargeFacade {
  const SelectionChargeFacade._();

  static Future<dynamic> selectCaesar({
    required String typeTirAssets,
    required double distanceM,
    required bool tirMontagne,
    List<String> chargesAdmissibles = const <String>[],
    double hausseMinMil = 0.0,
    double hausseMaxMil = 0.0,
    bool verbose = false,
  }) async {
    throw UnsupportedError(
      'Automatic charge selection is unavailable in this compatibility build.',
    );
  }

  static Future<dynamic> selectBestCharge({
    Object? systeme,
    required String typeTirAssets,
    required double distanceM,
    required bool tirMontagne,
    Iterable<String> chargesUtilisables = const <String>[],
    double hausseMinMil = 0.0,
    double hausseMaxMil = 0.0,
    bool verbose = false,
  }) async {
    throw UnsupportedError(
      'Automatic charge selection is unavailable in this compatibility build.',
    );
  }

  static void clearCache() {}
}
