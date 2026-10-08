// lib/services/tableau_dspd_service.dart
//
// Lecteur DSPD BONUS ART389.
// Étape actuelle : validation du calcul AQE à partir des JSON source.
// Le loader tente d'abord un asset Flutter sous assets/data/DSPD/, puis
// un fichier de maintenance local pour les essais desktop.
//
// Une fois le calcul validé, le chargement pourra être remplacé par la
// version binaire/chiffrée sans changer l'API publique du service.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class DspdRow {
  final double porteeM;
  final double hausseMil;
  final double tempsDepotageS;
  final double corrHaussePlus100mMil;
  final double corrTempsPlus100mS;
  final double corrHausseMoins100mMil;
  final double corrTempsMoins100mS;
  final bool tirMontagne;

  const DspdRow({
    required this.porteeM,
    required this.hausseMil,
    required this.tempsDepotageS,
    required this.corrHaussePlus100mMil,
    required this.corrTempsPlus100mS,
    required this.corrHausseMoins100mMil,
    required this.corrTempsMoins100mS,
    required this.tirMontagne,
  });

  factory DspdRow.fromJson(Map<String, dynamic> json) {
    double n(String key) {
      final value = json[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed == null) {
        throw FormatException('[DSPD] champ numérique invalide: $key=$value');
      }
      return parsed;
    }

    return DspdRow(
      porteeM: n('portee_m'),
      hausseMil: n('hausse_mil'),
      tempsDepotageS: n('temps_depotage_s'),
      corrHaussePlus100mMil: n('corr_hausse_+100m_mil'),
      corrTempsPlus100mS: n('corr_temps_+100m_s'),
      corrHausseMoins100mMil: n('corr_hausse_-100m_mil'),
      corrTempsMoins100mS: n('corr_temps_-100m_s'),
      tirMontagne: json['tirMontagne'] == true,
    );
  }
}

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
  String? _usedPath;
  List<DspdRow> _rows = const [];

  String get _type => typeTir.trim().toUpperCase();
  String get _charge => charge.trim().toUpperCase();

  String get _fileName => 'Tableau_DSPD_${_type}_$_charge.json';

  Future<void> load() async {
    if (_loaded) return;

    final assetPath = 'assets/data/DSPD/$_fileName';

    String? raw;

    // 1) Asset Flutter : voie préférée pour les essais si le JSON est copié
    //    sous assets/data/DSPD/ et que assets/data/ est déjà déclaré.
    try {
      raw = await rootBundle.loadString(assetPath);
      _usedPath = assetPath;
    } catch (_) {
      // 2) Fallback DEV desktop : recherche du JSON dans maintenance/.
      //    Cette voie permet de valider immédiatement les calculs sans
      //    modifier le pipeline sécurisé.
      raw = await _loadFromMaintenance();
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw FormatException(
        '[DSPD] racine JSON invalide dans $_usedPath : List attendue',
      );
    }

    final parsed = <DspdRow>[];
    for (final item in decoded) {
      if (item is! Map) {
        throw FormatException('[DSPD] ligne invalide dans $_usedPath');
      }
      parsed.add(DspdRow.fromJson(Map<String, dynamic>.from(item)));
    }

    if (parsed.isEmpty) {
      throw StateError('[DSPD] aucune ligne dans $_usedPath');
    }

    parsed.sort((a, b) {
      final tm = a.tirMontagne == b.tirMontagne ? 0 : (a.tirMontagne ? 1 : -1);
      if (tm != 0) return tm;
      return a.porteeM.compareTo(b.porteeM);
    });

    _rows = parsed;
    _loaded = true;

    if (verbose || kDebugMode) {
      final normal = _rows.where((r) => !r.tirMontagne).length;
      final montagne = _rows.where((r) => r.tirMontagne).length;
      debugPrint(
        '[DSPD] OK path=$_usedPath rows=${_rows.length} '
        'normal=$normal montagne=$montagne',
      );
    }
  }

  Future<String> _loadFromMaintenance() async {
    final relative = 'maintenance/Tableaux_JSON/CAESAR/DSPD/$_fileName';

    final candidates = <String>{};

    var dir = Directory.current.absolute;
    for (var i = 0; i < 8; i++) {
      candidates.add('${dir.path}/$relative');
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    for (final path in candidates) {
      final file = File(path);
      if (await file.exists()) {
        _usedPath = path;
        if (verbose || kDebugMode) {
          debugPrint('[DSPD:DEV] lecture JSON maintenance: $path');
        }
        return file.readAsString();
      }
    }

    throw StateError(
      '[DSPD] table introuvable. '
      'Copier $_fileName dans assets/data/DSPD/ '
      'ou lancer depuis un arbre contenant $relative',
    );
  }

  List<DspdRow> _branch(bool tirMontagne) {
    final rows = _rows.where((r) => r.tirMontagne == tirMontagne).toList()
      ..sort((a, b) => a.porteeM.compareTo(b.porteeM));

    if (rows.isEmpty) {
      throw StateError(
        '[DSPD] aucune branche tirMontagne=$tirMontagne '
        'pour $_type/$_charge',
      );
    }
    return rows;
  }

  Future<double> correctionHaussePar100mMil({
    required double distance,
    required bool tirMontagne,
    required bool deniveleePositive,
  }) async {
    await load();

    final value = _interp(
      rows: _branch(tirMontagne),
      distance: distance,
      getter: deniveleePositive
          ? (r) => r.corrHaussePlus100mMil
          : (r) => r.corrHausseMoins100mMil,
    );

    if (verbose || kDebugMode) {
      debugPrint(
        '[DSPD:AQE] type=$_type charge=$_charge '
        'distance=$distance TM=$tirMontagne '
        'sens=${deniveleePositive ? "+100m" : "-100m"} '
        'corr100=$value',
      );
    }

    return value;
  }

  Future<double> correctionTempsPar100mS({
    required double distance,
    required bool tirMontagne,
    required bool deniveleePositive,
  }) async {
    await load();

    return _interp(
      rows: _branch(tirMontagne),
      distance: distance,
      getter: deniveleePositive
          ? (r) => r.corrTempsPlus100mS
          : (r) => r.corrTempsMoins100mS,
    );
  }

  Future<double> tempsDepotageS({
    required double distance,
    required bool tirMontagne,
  }) async {
    await load();

    return _interp(
      rows: _branch(tirMontagne),
      distance: distance,
      getter: (r) => r.tempsDepotageS,
    );
  }

  Future<double> hausseMil({
    required double distance,
    required bool tirMontagne,
  }) async {
    await load();

    return _interp(
      rows: _branch(tirMontagne),
      distance: distance,
      getter: (r) => r.hausseMil,
    );
  }

  double _interp({
    required List<DspdRow> rows,
    required double distance,
    required double Function(DspdRow row) getter,
  }) {
    if (!distance.isFinite) {
      throw ArgumentError.value(distance, 'distance', 'distance non finie');
    }

    if (distance < rows.first.porteeM || distance > rows.last.porteeM) {
      throw RangeError(
        '[DSPD] distance $distance hors domaine '
        '[${rows.first.porteeM}..${rows.last.porteeM}] '
        'pour $_type/$_charge',
      );
    }

    if (distance == rows.first.porteeM) return getter(rows.first);
    if (distance == rows.last.porteeM) return getter(rows.last);

    var lo = 0;
    var hi = rows.length - 1;

    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (rows[mid].porteeM <= distance) {
        lo = mid;
      } else {
        hi = mid;
      }
    }

    final a = rows[lo];
    final b = rows[hi];

    if (distance == a.porteeM) return getter(a);
    if (distance == b.porteeM) return getter(b);

    final span = b.porteeM - a.porteeM;
    if (span == 0.0) return getter(a);

    final u = (distance - a.porteeM) / span;
    final va = getter(a);
    final vb = getter(b);

    final value = va + (vb - va) * u;

    if (verbose || kDebugMode) {
      debugPrint(
        '[DSPD:INTERP] d=$distance '
        'd0=${a.porteeM} v0=$va '
        'd1=${b.porteeM} v1=$vb '
        'u=$u -> $value',
      );
    }

    return value;
  }
}
