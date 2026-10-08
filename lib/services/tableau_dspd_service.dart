// lib/services/tableau_dspd_service.dart

import 'package:flutter/foundation.dart';

class TableauDspdService {
  final String typeTir;
  final String charge;
  final bool verbose;

  TableauDspdService({
    required this.typeTir,
    required this.charge,
    this.verbose = false,
  });

  bool _loaded = false;
  Map<String, dynamic> _dspdData = {};

  void _v(String message) {
    if (verbose || kDebugMode) {
      debugPrint(message);
    }
  }

  Future<void> load() async {
    throw UnsupportedError(
      'TableauDspdService.load is unavailable in this compatibility build.',
    );
  }

  Future<Map<String, dynamic>> getData() async {
    await load();
    return _dspdData;
  }

  Future<double> correctionHaussePar100mMil({
    required double distance,
    bool tirMontagne = false,
  }) async =>
      throw UnsupportedError(
        'TableauDspdService.correctionHaussePar100mMil is unavailable in this compatibility build.',
      );

  Future<double> tempsDepotageS({
    required double distance,
    bool tirMontagne = false,
  }) async =>
      throw UnsupportedError(
        'TableauDspdService.tempsDepotageS is unavailable in this compatibility build.',
      );

  Future<double> correctionTempsPar100mS({
    required double distance,
    bool tirMontagne = false,
    required bool deniveleePositive,
  }) async =>
      throw UnsupportedError(
        'TableauDspdService.correctionTempsPar100mS is unavailable in this compatibility build.',
      );
}
