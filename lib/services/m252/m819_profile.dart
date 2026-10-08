import 'package:calculateur_etranger/models/calcul_data.dart';

/// Immutable identity and paths for one RP M819 / M772 table set.
///
/// The smoke-round profiles intentionally remain distinct from the M821/M734
/// profiles: Table D carries M772 nominal data, while Table F carries the M772
/// correction factors. Those columns must never be mixed into an HE profile.
class M819Profile {
  const M819Profile({
    required this.id,
    required this.chargeLabel,
    required this.minimumRangeM,
    required this.maximumRangeM,
    required this.tableFiles,
  });

  static const _root = 'tableaux/foreign/m252/profiles';

  final String id;
  final String chargeLabel;
  final double minimumRangeM;
  final double maximumRangeM;
  final Map<String, String> tableFiles;

  bool supportsRange(double distanceM) =>
      distanceM >= minimumRangeM && distanceM <= maximumRangeM;

  String clearPath(String tableId) =>
      '$_root/$id/$tableId/${tableFiles[tableId]!}';

  String encryptedPath(String tableId) =>
      'assets/secure_enc/${clearPath(tableId)}.enc';
}

abstract final class M819Profiles {
  static const m819M772Ch1 = M819Profile(
    id: 'M819_M772_CH1',
    chargeLabel: 'CH1',
    minimumRangeM: 300.0,
    maximumRangeM: 1575.0,
    tableFiles: <String, String>{
      'A': 'A.aebtl.gz',
      'B': 'B.bebtl.gz',
      'C': 'C_CH1.cebtl.gz',
      'D': 'D_CH1.m819d.gz',
      'E': 'E_CH1.m819e.gz',
      'F': 'F_CH1.m819f.gz',
    },
  );

  static const m819M772Ch2 = M819Profile(
    id: 'M819_M772_CH2',
    chargeLabel: 'CH2',
    minimumRangeM: 975.0,
    maximumRangeM: 2850.0,
    tableFiles: <String, String>{
      'A': 'A.aebtl.gz',
      'B': 'B.bebtl.gz',
      'C': 'C_CH2.cebtl.gz',
      'D': 'D_CH2.m819d.gz',
      'E': 'E_CH2.m819e.gz',
      'F': 'F_CH2.m819f.gz',
    },
  );

  static const m819M772Ch3 = M819Profile(
    id: 'M819_M772_CH3',
    chargeLabel: 'CH3',
    minimumRangeM: 1325.0,
    maximumRangeM: 3975.0,
    tableFiles: <String, String>{
      'A': 'A.aebtl.gz',
      'B': 'B.bebtl.gz',
      'C': 'C_CH3.cebtl.gz',
      'D': 'D_CH3.m819d.gz',
      'E': 'E_CH3.m819e.gz',
      'F': 'F_CH3.m819f.gz',
    },
  );

  static const m819M772Ch4 = M819Profile(
    id: 'M819_M772_CH4',
    chargeLabel: 'CH4',
    minimumRangeM: 1625.0,
    maximumRangeM: 4950.0,
    tableFiles: <String, String>{
      'A': 'A.aebtl.gz',
      'B': 'B.bebtl.gz',
      'C': 'C_CH4.cebtl.gz',
      'D': 'D_CH4.m819d.gz',
      'E': 'E_CH4.m819e.gz',
      'F': 'F_CH4.m819f.gz',
    },
  );

  static const all = <M819Profile>[
    m819M772Ch1,
    m819M772Ch2,
    m819M772Ch3,
    m819M772Ch4,
  ];

  static bool supportsMunition(M252MunitionFamily? family) =>
      family == M252MunitionFamily.rpM819;

  static List<M819Profile> candidatesFor({
    required M252MunitionFamily? munition,
    required double distanceM,
    String? charge,
  }) {
    if (!supportsMunition(munition)) return const <M819Profile>[];
    final forced = forCharge(charge);
    if (charge != null && charge.trim().isNotEmpty && forced == null) {
      return const <M819Profile>[];
    }
    return <M819Profile>[
      for (final profile in all)
        if ((forced == null || forced.id == profile.id) &&
            profile.supportsRange(distanceM))
          profile,
    ];
  }

  static M819Profile? forCharge(String? rawCharge) {
    final normalized = rawCharge
        ?.trim()
        .toUpperCase()
        .replaceAll('CHARGE.', '')
        .replaceAll('CH', '');
    if (normalized == null || normalized.isEmpty) return null;
    return switch (normalized) {
      '1' => m819M772Ch1,
      '2' => m819M772Ch2,
      '3' => m819M772Ch3,
      '4' => m819M772Ch4,
      _ => null,
    };
  }
}
