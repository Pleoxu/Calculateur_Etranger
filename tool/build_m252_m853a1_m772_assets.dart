// Builds the six isolated, clear ILL M853A1 / M772 profile assets (A–F).
// Run merge_encrypt_m252_assets.dart afterwards to AES-GCM encrypt and merge
// the generated profile-scoped manifest fragment.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const _profiles = <int, _ProfileSpec>{
  1: _ProfileSpec('M853A1_M772_CH1'),
  2: _ProfileSpec('M853A1_M772_CH2'),
  3: _ProfileSpec('M853A1_M772_CH3'),
  4: _ProfileSpec('M853A1_M772_CH4'),
};

class _ProfileSpec {
  const _ProfileSpec(this.id);
  final String id;
}

Future<void> main(List<String> arguments) async {
  var project = Directory.current;
  var clean = false;
  for (var index = 0; index < arguments.length; index++) {
    switch (arguments[index]) {
      case '--project':
        if (index + 1 >= arguments.length) {
          throw ArgumentError('--project requires a directory path.');
        }
        project = Directory(arguments[++index]);
      case '--clean':
        clean = true;
      case '--help':
      case '-h':
        stdout.writeln(
          'Usage: dart run tool/build_m252_m853a1_m772_assets.dart '
          '[--project PATH] [--clean]',
        );
        return;
      default:
        throw ArgumentError('Unknown argument: ${arguments[index]}');
    }
  }
  project = Directory(project.absolute.path);
  if (!File('${project.path}/pubspec.yaml').existsSync()) {
    throw StateError('Not a Flutter project root: ${project.path}');
  }

  final clearRoot = Directory('${project.path}/assets/secure');
  final assetRoot = Directory(
    '${clearRoot.path}/tableaux/foreign/m252/profiles',
  );
  await assetRoot.create(recursive: true);
  if (clean) {
    for (final profile in _profiles.values) {
      final directory = Directory('${assetRoot.path}/${profile.id}');
      if (directory.existsSync()) await directory.delete(recursive: true);
    }
  }

  final entries = <Map<String, dynamic>>[];
  for (final item in _profiles.entries) {
    final charge = item.key;
    final profile = item.value;
    final raw = Directory(
      '${project.path}/maintenance/M252/PROFILES/${profile.id}/raw',
    );
    await _verifyHashes(raw);
    final files = <String, File>{
      for (final table in const <String>['A', 'B', 'C', 'D', 'E', 'F'])
        table: File(
          '${raw.path}/M252_M853A1_M772_CH${charge}_TABLE_$table.json',
        ),
    };
    final payloads = <String, Uint8List>{
      'A': _encodeA(
        _object(await files['A']!.readAsString(), files['A']!.path),
      ),
      'B': _encodeB(_list(await files['B']!.readAsString(), files['B']!.path)),
      'C': _encodeC(
        _object(await files['C']!.readAsString(), files['C']!.path),
      ),
      'D': _encodeD(_list(await files['D']!.readAsString(), files['D']!.path)),
      'E': _encodeE(_list(await files['E']!.readAsString(), files['E']!.path)),
      'F': _encodeF(_list(await files['F']!.readAsString(), files['F']!.path)),
    };
    final names = <String, String>{
      'A': 'A.aebtl.gz',
      'B': 'B.bebtl.gz',
      'C': 'C_CH$charge.cebtl.gz',
      'D': 'D_CH$charge.m853d.gz',
      'E': 'E_CH$charge.m853e.gz',
      'F': 'F_CH$charge.m853f.gz',
    };
    final formats = <String, String>{
      'A': 'AEBTL_V1',
      'B': 'BEBTL_V1',
      'C': 'CEBTL_V1',
      'D': 'M853A1DTBL_V2',
      'E': 'M853A1ETBL_V1',
      'F': 'M853A1FTBL_V1',
    };
    for (final table in names.keys) {
      final relative =
          'tableaux/foreign/m252/profiles/${profile.id}/$table/${names[table]}';
      final output = File('${clearRoot.path}/$relative');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(gzip.encode(payloads[table]!), flush: true);
      entries.add(<String, dynamic>{
        'id': 'foreign.m252.profile.${profile.id}.$table',
        'profile': profile.id,
        'tableId': table,
        'family': 'foreign',
        'platform': 'M252',
        'munition': 'ILL_M853A1',
        'fuze': 'M772',
        'charge': charge,
        'format': formats[table],
        'file': relative,
        'keyVersion': 0,
      });
    }
    stdout.writeln('Built ${profile.id}: A–F (source hashes verified).');
  }
  entries.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
  final fragment = File(
    '${clearRoot.path}/manifest_foreign_m252_m853a1_m772.json',
  );
  await fragment.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(entries)}\n',
    flush: true,
  );
  stdout.writeln('Manifest fragment: ${fragment.path}');
  stdout.writeln(
    'Run merge_encrypt_m252_assets.dart --fragment ${fragment.uri.pathSegments.last}.',
  );
}

Future<void> _verifyHashes(Directory raw) async {
  final manifest = File('${raw.path}/SOURCES.sha256');
  if (!manifest.existsSync()) throw StateError('Missing ${manifest.path}');
  for (final line in await manifest.readAsLines()) {
    if (line.trim().isEmpty) {
      continue;
    }
    final match = RegExp(r'^([0-9a-f]{64})\s+(.+)$').firstMatch(line.trim());
    if (match == null) throw FormatException('Invalid source hash: $line');
    final source = File('${raw.path}/${match.group(2)!}');
    if (!source.existsSync()) {
      throw StateError('Missing source: ${source.path}');
    }
    final actual = await _sha256(source);
    if (actual != match.group(1)) {
      throw StateError('SHA-256 mismatch for ${source.path}: $actual');
    }
  }
}

Future<String> _sha256(File source) async {
  final mac = await Process.run('shasum', ['-a', '256', source.path]);
  if (mac.exitCode == 0) {
    return mac.stdout.toString().trim().split(RegExp(r'\s+')).first;
  }
  final linux = await Process.run('sha256sum', [source.path]);
  if (linux.exitCode == 0) {
    return linux.stdout.toString().trim().split(RegExp(r'\s+')).first;
  }
  throw StateError('No SHA-256 command is available.');
}

Map<String, dynamic> _object(String source, String path) {
  final decoded = jsonDecode(source);
  if (decoded is! Map) throw FormatException('$path must be a JSON object.');
  return Map<String, dynamic>.from(decoded);
}

List<Map<String, dynamic>> _list(String source, String path) {
  final decoded = jsonDecode(source);
  if (decoded is! List) throw FormatException('$path must be a JSON list.');
  return <Map<String, dynamic>>[
    for (final item in decoded)
      if (item is Map)
        Map<String, dynamic>.from(item)
      else
        throw FormatException('$path has a non-object row.'),
  ];
}

Uint8List _header(String magic, int rowCount, int rowSize) {
  final bytes = Uint8List(9 + rowCount * rowSize);
  final data = ByteData.sublistView(bytes);
  bytes.setAll(0, ascii.encode(magic));
  data.setUint8(4, 1);
  data.setUint32(5, rowCount, Endian.little);
  return bytes;
}

Uint8List _encodeA(Map<String, dynamic> source) {
  final values = source.entries.toList()
    ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
  final bytes = _header('AEBT', values.length, 6);
  final data = ByteData.sublistView(bytes);
  var offset = 9;
  var previous = -1;
  for (final entry in values) {
    final angle = int.parse(entry.key);
    final row = Map<String, dynamic>.from(entry.value as Map);
    if (angle <= previous || angle < 0 || angle > 6400 || angle % 100 != 0) {
      throw FormatException('Invalid Table A angle: $angle');
    }
    previous = angle;
    data.setUint16(offset, angle, Endian.little);
    data.setUint16(offset + 2, (_num(row, 'Wz') * 100).round(), Endian.little);
    data.setUint16(offset + 4, (_num(row, 'Wx') * 100).round(), Endian.little);
    offset += 6;
  }
  if (values.first.key != '0' || values.last.key != '6400') {
    throw const FormatException('Table A must cover 0..6400 mil.');
  }
  return bytes;
}

Uint8List _encodeB(List<Map<String, dynamic>> rows) {
  rows.sort((a, b) => _num(a, 'delta_alt_m').compareTo(_num(b, 'delta_alt_m')));
  final bytes = _header('BEBT', rows.length, 6);
  final data = ByteData.sublistView(bytes);
  var offset = 9;
  var previous = -double.infinity;
  for (final row in rows) {
    final altitude = _num(row, 'delta_alt_m');
    if (altitude <= previous || altitude % 10 != 0) {
      throw FormatException('Invalid Table B altitude: $altitude');
    }
    previous = altitude;
    data.setInt16(offset, altitude.round(), Endian.little);
    data.setInt16(
      offset + 2,
      (_num(row, 'dc_tb_pct') * 10).round(),
      Endian.little,
    );
    data.setInt16(
      offset + 4,
      (_num(row, 'dc_pb_pct') * 10).round(),
      Endian.little,
    );
    offset += 6;
  }
  return bytes;
}

Uint8List _encodeC(Map<String, dynamic> source) {
  final dataRows = source['data'];
  if (dataRows is! List) {
    throw const FormatException('Table C data[] is required.');
  }
  final rows = <Map<String, dynamic>>[
    for (final item in dataRows)
      if (item is Map)
        Map<String, dynamic>.from(item)
      else
        throw const FormatException('Invalid Table C row.'),
  ]..sort((a, b) => _num(a, 'tempPoudreF').compareTo(_num(b, 'tempPoudreF')));
  final bytes = _header('CEBT', rows.length, 4);
  final output = ByteData.sublistView(bytes);
  var offset = 9;
  var previous = -double.infinity;
  for (final row in rows) {
    final f = _num(row, 'tempPoudreF');
    if (f <= previous || f % 5 != 0) {
      throw FormatException('Invalid Table C temperature: $f');
    }
    previous = f;
    output.setInt16(offset, f.round(), Endian.little);
    output.setInt16(
      offset + 2,
      (_num(row, 'deltaVo_temp') * 10).round(),
      Endian.little,
    );
    offset += 4;
  }
  return bytes;
}

Uint8List _encodeD(List<Map<String, dynamic>> rows) {
  rows.sort((a, b) => _num(a, 'distance').compareTo(_num(b, 'distance')));
  // V2 preserves Table D columns 12–19. These range factors are required
  // for the meteorological elevation calculation; Table F remains the M772
  // setting correction table.
  final bytes = _header('M8D2', rows.length, 68);
  final data = ByteData.sublistView(bytes);
  var offset = 9;
  var previous = -double.infinity;
  const correctionFields = <String>[
    'correctionWz',
    'correctionV0Dec',
    'correctionV0Inc',
    'correctionVentFace',
    'correctionVentArriere',
    'correctionTempAirDec',
    'correctionTempAirInc',
    'correctionDensiteAirDec',
    'correctionDensiteAirInc',
  ];
  for (final row in rows) {
    final distance = _num(row, 'distance');
    if (distance <= previous) {
      throw FormatException('Table D distances must increase.');
    }
    previous = distance;
    final values = <double>[
      distance,
      _num(row, 'hausse'),
      _num(row, 'reglageFusee'),
      _num(row, 'ecartProbableHauteurEclatement'),
      _num(row, 'ecartProbableDelaiEclatement'),
      _num(row, 'ecartProbablePorteeEclatement'),
      _num(row, 'tempsVolS'),
    ];
    for (var index = 0; index < values.length; index++) {
      data.setFloat32(offset + index * 4, values[index], Endian.little);
    }
    var validMask = 0;
    for (var index = 0; index < correctionFields.length; index++) {
      final value = _optionalNum(row, correctionFields[index]);
      if (value == null) continue;
      validMask |= 1 << index;
      data.setFloat32(offset + (7 + index) * 4, value, Endian.little);
    }
    final line = _num(row, 'numeroLigne').round();
    if (line < 0 || line > 15) {
      throw FormatException('Invalid Table D LINE NO.: $line');
    }
    data.setUint8(offset + 64, line);
    data.setUint16(offset + 65, validMask, Endian.little);
    data.setUint8(offset + 67, 0);
    offset += 68;
  }
  return bytes;
}

Uint8List _encodeE(List<Map<String, dynamic>> rows) {
  rows.sort((a, b) => _num(a, 'distance').compareTo(_num(b, 'distance')));
  final bytes = _header('M8E1', rows.length, 44);
  final data = ByteData.sublistView(bytes);
  var offset = 9;
  var previous = -double.infinity;
  const fields = <String>[
    'distance',
    'hausse',
    'elevationPourHausseEclatement50mTours',
    'elevationPourHausseEclatement50mMil',
    'variationReglageFuseePour50m',
    'elevationPourAllongementPorteeEclatement100mTours',
    'elevationPourAllongementPorteeEclatement100mMil',
    'variationReglageFuseePour100m',
    'fleche',
    'distanceImpact',
  ];
  for (final row in rows) {
    final distance = _num(row, 'distance');
    if (distance <= previous) {
      throw FormatException('Table E distances must increase.');
    }
    previous = distance;
    var validMask = 0;
    for (var index = 0; index < fields.length; index++) {
      final value = index == 0
          ? _num(row, fields[index])
          : _optionalNum(row, fields[index]);
      if (value != null) {
        if (index > 0) validMask |= 1 << (index - 1);
        data.setFloat32(offset + index * 4, value, Endian.little);
      }
    }
    data.setUint16(offset + 40, validMask, Endian.little);
    data.setUint16(offset + 42, 0, Endian.little);
    offset += 44;
  }
  return bytes;
}

Uint8List _encodeF(List<Map<String, dynamic>> rows) {
  rows.sort(
    (a, b) => _num(a, 'reglageFusee').compareTo(_num(b, 'reglageFusee')),
  );
  final bytes = _header('M8F2', rows.length, 40);
  final data = ByteData.sublistView(bytes);
  var offset = 9;
  var previous = -double.infinity;
  const fields = <String>[
    'reglageFusee',
    'correctionV0Dec',
    'correctionV0Inc',
    'correctionVentFace',
    'correctionVentArriere',
    'correctionTempAirDec',
    'correctionTempAirInc',
    'correctionDensiteAirDec',
    'correctionDensiteAirInc',
  ];
  for (final row in rows) {
    final setting = _num(row, 'reglageFusee');
    if (setting <= previous) {
      throw FormatException('Table F settings must increase.');
    }
    previous = setting;
    data.setFloat32(offset, setting, Endian.little);
    var validMask = 0;
    for (var index = 1; index < fields.length; index++) {
      final value = _optionalNum(row, fields[index]);
      if (value == null) continue;
      validMask |= 1 << (index - 1);
      data.setFloat32(offset + index * 4, value, Endian.little);
    }
    data.setUint16(offset + 36, validMask, Endian.little);
    data.setUint16(offset + 38, 0, Endian.little);
    offset += 40;
  }
  return bytes;
}

double _num(Map<String, dynamic> row, String field) {
  final value = row[field];
  if (value is! num || !value.isFinite) {
    throw FormatException(
      'Required numeric value $field is missing or invalid.',
    );
  }
  return value.toDouble();
}

double? _optionalNum(Map<String, dynamic> row, String field) {
  final value = row[field];
  if (value == null) return null;
  if (value is! num || !value.isFinite) {
    throw FormatException('Optional numeric value $field is invalid.');
  }
  return value.toDouble();
}
