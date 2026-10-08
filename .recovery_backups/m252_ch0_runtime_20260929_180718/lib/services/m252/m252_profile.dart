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
    required this.tableFiles,
  });

  final String id;
  final String label;
  final String chargeLabel;
  final bool runtimeQualified;
  final Map<String, String> tableFiles;

  static const _root = 'tableaux/foreign/m252/profiles';

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
  /// Imported M821/M734 charge-0 source set. Not yet exposed to calculations.
  static const m821M734Ch0 = M252Profile(
    id: 'M821_M734_CH0',
    label: 'M821/M734 · CH0',
    chargeLabel: 'CH0',
    runtimeQualified: false,
    tableFiles: <String, String>{
      'A': 'A.aebtl.gz',
      'B': 'B.bebtl.gz',
      'C': 'C_CH0.cebtl.gz',
      'D': 'D_CH0.debtl.gz',
      'E': 'E_CH0.eebtl.gz',
    },
  );

  /// Source: FT 81-AR-2 Part 6; shared by M821A1/M734 and M821A2/M734A1.
  static const m821M734Ch3 = M252Profile(
    id: 'M821_M734_CH3',
    label: 'M821A1/M734 · M821A2/M734A1 · CH3',
    chargeLabel: 'CH3',
    runtimeQualified: true,
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
}
