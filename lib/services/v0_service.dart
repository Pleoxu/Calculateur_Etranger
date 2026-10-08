// lib/services/v0_service.dart
//
// Compatibility-only surfaces.
// No ballistic V0 lookup is reconstructed in this build.

class V0Service {
  const V0Service({Object? systeme});

  Future<double?> v0Ref({
    required String typeTirAssets,
    required String charge,
  }) async {
    throw UnsupportedError(
      'V0 lookup is unavailable in this compatibility build.',
    );
  }
}

class TableauV0Service {
  final String typeTir;
  final String charge;
  final bool verbose;

  const TableauV0Service({
    required this.typeTir,
    required this.charge,
    this.verbose = false,
  });

  Future<void> load() async {
    throw UnsupportedError(
      'V0 table loading is unavailable in this compatibility build.',
    );
  }

  Future<double> getV0Nominale() async {
    throw UnsupportedError(
      'V0 lookup is unavailable in this compatibility build.',
    );
  }
}
