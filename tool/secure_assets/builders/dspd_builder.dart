import 'dart:convert';
import 'dart:io';

import '../table_builder.dart';

class DspdBuilder implements TableBuilder {
  @override
  bool supports(File file) {
    final name = file.uri.pathSegments.last;

    if (!name.toUpperCase().startsWith('TABLEAU_DSPD_')) {
      return false;
    }

    if (!name.toUpperCase().endsWith('.JSON')) {
      return false;
    }

    return _parseName(name) != null;
  }

  @override
  Future<Map<String, dynamic>> build(File input, Directory outputDir) async {
    final name = input.uri.pathSegments.last;
    final parsed = _parseName(name);

    if (parsed == null) {
      throw ArgumentError(
        'Nom DSPD invalide : ${input.path}\n'
        'Attendu : Tableau_DSPD_<TYPE>_ARTxxx_CHn.json',
      );
    }

    final typeTir = parsed.typeTir;
    final article = parsed.article;
    final charge = parsed.charge;

    final tableId = 'DSPD_${typeTir}_ART${article}_CH$charge';
    final outputName = '$tableId.dspdtbl.gz';

    final decoded = jsonDecode(await input.readAsString());

    if (decoded is! List || decoded.isEmpty) {
      throw FormatException(
        '$tableId : la racine JSON doit être une liste non vide.',
      );
    }

    final normalized = <Map<String, dynamic>>[];

    for (var i = 0; i < decoded.length; i++) {
      final value = decoded[i];

      if (value is! Map) {
        throw FormatException('$tableId : ligne $i invalide.');
      }

      final row = Map<String, dynamic>.from(value);

      double number(String key) {
        final value = row[key];

        if (value is num) {
          return value.toDouble();
        }

        throw FormatException(
          '$tableId : ligne $i, champ "$key" invalide ou absent.',
        );
      }

      final tirMontagne = row['tirMontagne'];

      if (tirMontagne is! bool) {
        throw FormatException(
          '$tableId : ligne $i, champ "tirMontagne" invalide ou absent.',
        );
      }

      normalized.add(<String, dynamic>{
        'portee_m': number('portee_m'),
        'hausse_mil': number('hausse_mil'),
        'temps_depotage_s': number('temps_depotage_s'),
        'corr_hausse_+100m_mil': number('corr_hausse_+100m_mil'),
        'corr_temps_+100m_s': number('corr_temps_+100m_s'),
        'corr_hausse_-100m_mil': number('corr_hausse_-100m_mil'),
        'corr_temps_-100m_s': number('corr_temps_-100m_s'),
        'tirMontagne': tirMontagne,
      });
    }

    final encodedJson = utf8.encode(jsonEncode(normalized));

    final compressed = gzip.encode(encodedJson);

    final dspdDir = Directory('${outputDir.path}/DSPD');

    await dspdDir.create(recursive: true);

    final outputFile = File('${dspdDir.path}/$outputName');

    await outputFile.writeAsBytes(compressed, flush: true);

    print('----------------------------------------');
    print('Traitement : $name');
    print('ID : $tableId');
    print('Format : DSPDTBL_V1');
    print('Rows : ${normalized.length}');
    print('GZIP : ${compressed.length} bytes');

    return <String, dynamic>{
      'id': tableId,
      'format': 'DSPDTBL_V1',
      'rows': normalized.length,
      'file': 'tableaux/DSPD/$outputName',
    };
  }

  _DspdName? _parseName(String filename) {
    var name = filename;

    if (!name.toUpperCase().endsWith('.JSON')) {
      return null;
    }

    name = name.substring(0, name.length - 5);

    // Accepte aussi une éventuelle copie macOS du type "(1)".
    final copySuffix = RegExp(r'\([0-9]+\)$');
    name = name.replaceFirst(copySuffix, '');

    const prefix = 'Tableau_DSPD_';

    if (!name.toUpperCase().startsWith(prefix.toUpperCase())) {
      return null;
    }

    final payload = name.substring(prefix.length);

    final artMarker = payload.toUpperCase().lastIndexOf('_ART');

    if (artMarker <= 0) {
      return null;
    }

    final typeTir = payload.substring(0, artMarker);

    final afterArt = payload.substring(artMarker + 4);

    final chargeMarker = afterArt.toUpperCase().lastIndexOf('_CH');

    if (chargeMarker <= 0) {
      return null;
    }

    final article = afterArt.substring(0, chargeMarker);

    final charge = afterArt.substring(chargeMarker + 3);

    if (typeTir.isEmpty || article.isEmpty || charge.isEmpty) {
      return null;
    }

    if (int.tryParse(article) == null || int.tryParse(charge) == null) {
      return null;
    }

    return _DspdName(
      typeTir: typeTir.toUpperCase(),
      article: article,
      charge: charge,
    );
  }
}

class _DspdName {
  final String typeTir;
  final String article;
  final String charge;

  const _DspdName({
    required this.typeTir,
    required this.article,
    required this.charge,
  });
}
