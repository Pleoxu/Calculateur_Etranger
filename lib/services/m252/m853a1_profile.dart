import 'package:calculateur_etranger/models/calcul_data.dart';

/// Immutable identity and paths for one ILL M853A1 / M772 table set.
///
/// Each charge owns its six A–F tables. The tables are deliberately isolated
/// from both HE and RP M819: no cross-family fallback is permitted.
class M853A1Profile {
  const M853A1Profile({
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

abstract final class M853A1Profiles {
  static const m853a1M772Ch1 = M853A1Profile(
    id: 'M853A1_M772_CH1',
    chargeLabel: 'CH1',
    minimumRangeM: 300.0,
    maximumRangeM: 1425.0,
    tableFiles: <String, String>{
      'A': 'A.aebtl.gz',
      'B': 'B.bebtl.gz',
      'C': 'C_CH1.cebtl.gz',
      'D': 'D_CH1.m853d.gz',
      'E': 'E_CH1.m853e.gz',
      'F': 'F_CH1.m853f.gz',
    },
  );

  static const m853a1M772Ch2 = M853A1Profile(
    id: 'M853A1_M772_CH2',
    chargeLabel: 'CH2',
    minimumRangeM: 1050.0,
    maximumRangeM: 2900.0,
    tableFiles: <String, String>{
      'A': 'A.aebtl.gz',
      'B': 'B.bebtl.gz',
      'C': 'C_CH2.cebtl.gz',
      'D': 'D_CH2.m853d.gz',
      'E': 'E_CH2.m853e.gz',
      'F': 'F_CH2.m853f.gz',
    },
  );

  static const m853a1M772Ch3 = M853A1Profile(
    id: 'M853A1_M772_CH3',
    chargeLabel: 'CH3',
    minimumRangeM: 1350.0,
    maximumRangeM: 4100.0,
    tableFiles: <String, String>{
      'A': 'A.aebtl.gz',
      'B': 'B.bebtl.gz',
      'C': 'C_CH3.cebtl.gz',
      'D': 'D_CH3.m853d.gz',
      'E': 'E_CH3.m853e.gz',
      'F': 'F_CH3.m853f.gz',
    },
  );

  static const m853a1M772Ch4 = M853A1Profile(
    id: 'M853A1_M772_CH4',
    chargeLabel: 'CH4',
    minimumRangeM: 1675.0,
    maximumRangeM: 5050.0,
    tableFiles: <String, String>{
      'A': 'A.aebtl.gz',
      'B': 'B.bebtl.gz',
      'C': 'C_CH4.cebtl.gz',
      'D': 'D_CH4.m853d.gz',
      'E': 'E_CH4.m853e.gz',
      'F': 'F_CH4.m853f.gz',
    },
  );

  static const all = <M853A1Profile>[
    m853a1M772Ch1,
    m853a1M772Ch2,
    m853a1M772Ch3,
    m853a1M772Ch4,
  ];

  static bool supportsMunition(M252MunitionFamily? family) =>
      family == M252MunitionFamily.illM853a1;

  static List<M853A1Profile> candidatesFor({
    required M252MunitionFamily? munition,
    required double distanceM,
    String? charge,
  }) {
    if (!supportsMunition(munition)) return const <M853A1Profile>[];
    final forced = forCharge(charge);
    if (charge != null && charge.trim().isNotEmpty && forced == null) {
      return const <M853A1Profile>[];
    }
    return <M853A1Profile>[
      for (final profile in all)
        if ((forced == null || forced.id == profile.id) &&
            profile.supportsRange(distanceM))
          profile,
    ];
  }

  static M853A1Profile? forCharge(String? rawCharge) {
    final normalized = rawCharge
        ?.trim()
        .toUpperCase()
        .replaceAll('CHARGE.', '')
        .replaceAll('CH', '');
    if (normalized == null || normalized.isEmpty) return null;
    return switch (normalized) {
      '1' => m853a1M772Ch1,
      '2' => m853a1M772Ch2,
      '3' => m853a1M772Ch3,
      '4' => m853a1M772Ch4,
      _ => null,
    };
  }
}
