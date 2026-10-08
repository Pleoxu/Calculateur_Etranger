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
  /// FT 81-AR-2 Part 6 M220 charge 0. The published D/E data are complete on
  /// the continuous 125–350 m domain and are therefore usable at 300 m.
  ///
  /// A profile identifies a charge, not a different projectile family: the
  /// Part 6 source applies the same charge tables to M821A1/M734 and
  /// M821A2/M734A1.
  static const m821M734Ch0 = M252Profile(
    id: 'M821_M734_CH0',
    label: 'M821A1/M734 · M821A2/M734A1 · CH0',
    chargeLabel: 'CH0',
    runtimeQualified: true,
    minimumRangeM: 125.0,
    maximumRangeM: 350.0,
    munitions: <M252MunitionFamily>[
      M252MunitionFamily.m821a1,
      M252MunitionFamily.m821a2,
    ],
    tableFiles: <String, String>{
      'A': 'A.aebtl.gz',
      'B': 'B.bebtl.gz',
      'C': 'C_CH0.cebtl.gz',
      'D': 'D_CH0.debtl.gz',
      'E': 'E_CH0.eebtl.gz',
    },
  );

  /// FT 81-AR-2 Part 6 M220 charge 3.
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

  /// All qualified charge profiles compatible with a selected cartridge/fuze.
  ///
  /// A munition is intentionally allowed to appear in more than one profile:
  /// the charge is resolved from the target distance, not fixed by the UI chip.
  static List<M252Profile> profilesForMunition(M252MunitionFamily? family) =>
      <M252Profile>[
        for (final profile in all)
          if (profile.runtimeQualified && profile.supportsMunition(family))
            profile,
      ];

  /// Profiles that may calculate [distanceM] for one cartridge/fuze.
  ///
  /// A non-empty [charge] remains an explicit caller constraint. Without it,
  /// all distance-qualified candidates are returned so the ballistic service
  /// can choose the one with the lowest published Table E probable range error.
  static List<M252Profile> candidatesFor({
    required M252MunitionFamily? munition,
    required double distanceM,
    String? charge,
  }) {
    final requestedCharge = forCharge(charge);
    if (charge != null && charge.trim().isNotEmpty && requestedCharge == null) {
      return const <M252Profile>[];
    }

    return <M252Profile>[
      for (final profile in profilesForMunition(munition))
        if ((requestedCharge == null || requestedCharge.id == profile.id) &&
            profile.supportsRange(distanceM))
          profile,
    ];
  }

  /// Returns a profile only when the profile/range relationship is unambiguous.
  /// Overlapping future charges are deliberately left to the Table-E selector.
  static M252Profile? profileForMunitionAtDistance({
    required M252MunitionFamily? munition,
    required double distanceM,
    String? charge,
  }) {
    final candidates = candidatesFor(
      munition: munition,
      distanceM: distanceM,
      charge: charge,
    );
    return candidates.length == 1 ? candidates.single : null;
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
}
