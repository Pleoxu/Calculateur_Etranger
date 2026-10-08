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

  /// FT 81-AR-2 charge 1. The raw D/E source spans 347–2060 m, but 450–1875 m
  /// is the continuous interval where both directions of every correction and
  /// Table E probable range error are published.
  static const m821M734Ch1 = M252Profile(
    id: 'M821_M734_CH1',
    label: 'M821A1/M734 · M821A2/M734A1 · CH1',
    chargeLabel: 'CH1',
    runtimeQualified: true,
    minimumRangeM: 450.0,
    maximumRangeM: 1875.0,
    munitions: <M252MunitionFamily>[
      M252MunitionFamily.m821a1,
      M252MunitionFamily.m821a2,
    ],
    tableFiles: <String, String>{
      'A': 'A.aebtl.gz',
      'B': 'B.bebtl.gz',
      'C': 'C_CH1.cebtl.gz',
      'D': 'D_CH1.debtl.gz',
      'E': 'E_CH1.eebtl.gz',
    },
  );

  /// FT 81-AR-2 charge 2. The source D/E tables span 1125–3400 m, but
  /// 1125–3125 m is the continuous interval where both directions of every
  /// Table-D correction and Table-E probable range error are published.
  static const m821M734Ch2 = M252Profile(
    id: 'M821_M734_CH2',
    label: 'M821A1/M734 · M821A2/M734A1 · CH2',
    chargeLabel: 'CH2',
    runtimeQualified: true,
    minimumRangeM: 1125.0,
    maximumRangeM: 3125.0,
    munitions: <M252MunitionFamily>[
      M252MunitionFamily.m821a1,
      M252MunitionFamily.m821a2,
    ],
    tableFiles: <String, String>{
      'A': 'A.aebtl.gz',
      'B': 'B.bebtl.gz',
      'C': 'C_CH2.cebtl.gz',
      'D': 'D_CH2.debtl.gz',
      'E': 'E_CH2.eebtl.gz',
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

  /// FT 81-AR-2 charge 4. The published D/E tables span 1825–5608 m, but
  /// 1825–5125 m is the continuous interval where all active Table-D
  /// corrections and the Table-E probable range error are published.
  static const m821M734Ch4 = M252Profile(
    id: 'M821_M734_CH4',
    label: 'M821A1/M734 · M821A2/M734A1 · CH4',
    chargeLabel: 'CH4',
    runtimeQualified: true,
    minimumRangeM: 1825.0,
    maximumRangeM: 5125.0,
    munitions: <M252MunitionFamily>[
      M252MunitionFamily.m821a1,
      M252MunitionFamily.m821a2,
    ],
    tableFiles: <String, String>{
      'A': 'A.aebtl.gz',
      'B': 'B.bebtl.gz',
      'C': 'C_CH4.cebtl.gz',
      'D': 'D_CH4.debtl.gz',
      'E': 'E_CH4.eebtl.gz',
    },
  );

  /// M819 / M772 Charge 1 profile.
  static const m819M772Ch1 = M252Profile(
    id: 'M819_M772_CH1',
    label: 'M819 · M772 · CH1',
    chargeLabel: 'CH1',
    runtimeQualified: true,
    minimumRangeM: 400.0,
    maximumRangeM: 1800.0,
    munitions: <M252MunitionFamily>[M252MunitionFamily.rpM819],
    tableFiles: <String, String>{
      'A': 'A.aebtl.gz',
      'B': 'B.bebtl.gz',
      'C': 'C_CH1.cebtl.gz',
      'D': 'D_CH1.debtl.gz',
      'E': 'E_CH1.eebtl.gz',
    },
  );

  /// M819 / M772 Charge 2 profile.
  /// Corrected domain according to actual Table D data: 1800.0..2850.0 m.
  static const m819M772Ch2 = M252Profile(
    id: 'M819_M772_CH2',
    label: 'M819 · M772 · CH2',
    chargeLabel: 'CH2',
    runtimeQualified: true,
    minimumRangeM: 1800.0,
    maximumRangeM: 2850.0,
    munitions: <M252MunitionFamily>[M252MunitionFamily.rpM819],
    tableFiles: <String, String>{
      'A': 'A.aebtl.gz',
      'B': 'B.bebtl.gz',
      'C': 'C_CH2.cebtl.gz',
      'D': 'D_CH2.debtl.gz',
      'E': 'E_CH2.eebtl.gz',
    },
  );

  /// Ordered profiles list including both M821 and M819 families.
  static const all = <M252Profile>[
    m821M734Ch0,
    m821M734Ch1,
    m821M734Ch2,
    m821M734Ch3,
    m821M734Ch4,
    m819M772Ch1,
    m819M772Ch2,
  ];

  /// All qualified charge profiles compatible with a selected cartridge/fuze.
  static List<M252Profile> profilesForMunition(
    M252MunitionFamily? family,
  ) =>
      <M252Profile>[
        for (final profile in all)
          if (profile.runtimeQualified && profile.supportsMunition(family))
            profile,
      ];

  /// Profiles that may calculate [distanceM] for one cartridge/fuze.
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
