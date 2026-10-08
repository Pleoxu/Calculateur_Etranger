import 'package:calculateur_etranger/models/calcul_data.dart';

/// Immutable identity and paths for one complete M252 table set.
///
/// Every profile owns all five tables A–E. No M252 asset is stored directly
/// below `foreign/m252/A` through `E`; that former layout mixed unrelated
/// table sets and made it possible to load A/B from one profile with C/D/E
/// from another.
class M252Profile {
  const M252Profile({
    required this.id,
    required this.label,
    required this.chargeLabel,
    required this.runtimeQualified,
    required this.minimumRangeM,
    required this.maximumRangeM,
    required this.munitions,
    required this.tableFiles,
  });

  final String id;
  final String label;
  final String chargeLabel;
  final bool runtimeQualified;
  final double minimumRangeM;
  final double maximumRangeM;
  final List<M252MunitionFamily> munitions;
  final Map<String, String> tableFiles;

  static const _root = 'tableaux/foreign/m252/profiles';

  bool supportsMunition(M252MunitionFamily? family) =>
      family != null && munitions.contains(family);

  bool supportsRange(double distanceM) =>
      distanceM >= minimumRangeM && distanceM <= maximumRangeM;

  String clearPath(String tableId) =>
      '$_root/$id/$tableId/${_tableFile(tableId)}';

  String encryptedPath(String tableId) =>
      'assets/secure_enc/${clearPath(tableId)}.enc';

  String _tableFile(String tableId) {
    final value = tableFiles[tableId];
    if (value == null) {
      throw ArgumentError.value(tableId, 'tableId', 'Unknown M252 table.');
    }
    return value;
  }
}

abstract final class M252Profiles {
  /// M821/M734, M220 charge 0. The published D/E data are complete on the
  /// continuous 125–350 m domain and are therefore usable at 300 m.
  static const m821M734Ch0 = M252Profile(
    id: 'M821_M734_CH0',
    label: 'M821/M734 · CH0',
    chargeLabel: 'CH0',
    runtimeQualified: true,
    minimumRangeM: 125.0,
    maximumRangeM: 350.0,
    munitions: <M252MunitionFamily>[M252MunitionFamily.m821],
    tableFiles: <String, String>{
      'A': 'A.aebtl.gz',
      'B': 'B.bebtl.gz',
      'C': 'C_CH0.cebtl.gz',
      'D': 'D_CH0.debtl.gz',
      'E': 'E_CH0.eebtl.gz',
    },
  );

  /// M821A1/M734 and M821A2/M734A1, M220 charge 3.
  static const m821M734Ch3 = M252Profile(
    id: 'M821_M734_CH3',
    label: 'M821A1/M734 · M821A2/M734A1 · CH3',
    chargeLabel: 'CH3',
    runtimeQualified: true,
    minimumRangeM: 1525.0,
    maximumRangeM: 2300.0,
    munitions: <M252MunitionFamily>[
      M252MunitionFamily.m821a1,
      M252MunitionFamily.m821a2,
    ],
    tableFiles: <String, String>{
      'A': 'A.aebtl.gz',
      'B': 'B.bebtl.gz',
      'C': 'C_CH3.cebtl.gz',
      'D': 'D_CH3.debtl.gz',
      'E': 'E_CH3.eebtl.gz',
    },
  );

  /// Ordered by M220 charge. CH1, CH2 and CH4 are registered when imported.
  static const all = <M252Profile>[m821M734Ch0, m821M734Ch3];

  static M252Profile? forMunition(M252MunitionFamily? family) {
    for (final profile in all) {
      if (profile.runtimeQualified && profile.supportsMunition(family)) {
        return profile;
      }
    }
    return null;
  }

  static M252Profile? forCharge(String? rawCharge) {
    final normalized = rawCharge
        ?.trim()
        .toUpperCase()
        .replaceAll('CHARGE.', '')
        .replaceAll('CH', '');
    if (normalized == null || normalized.isEmpty) return null;
    for (final profile in all) {
      if (profile.chargeLabel == 'CH$normalized') return profile;
    }
    return null;
  }

  /// Resolves one source set without ever mixing a charge with another
  /// cartridge family. A forced charge is honoured only when it belongs to
  /// the selected family.
  static M252Profile? resolve({
    required M252MunitionFamily? munition,
    String? charge,
  }) {
    if (charge == null || charge.trim().isEmpty) {
      return forMunition(munition);
    }
    final forced = forCharge(charge);
    return forced != null && forced.supportsMunition(munition) ? forced : null;
  }
}
