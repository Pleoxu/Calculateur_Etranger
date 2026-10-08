// lib/services/tableau_i_service.dart

import 'package:flutter/foundation.dart';

import '../domain/fire/services/ballistic_asset_context.dart';
import 'secure_asset_resolver.dart';
import 'secure_table_service.dart';

class _ITableRow {
  final bool tirMontagne;
  final int latitude;
  final int azimut;
  final double distance;
  final double correction;

  const _ITableRow({
    required this.tirMontagne,
    required this.latitude,
    required this.azimut,
    required this.distance,
    required this.correction,
  });
}

class TableauIService {
  TableauIService({
    this.systeme = SystemeArme.caesar,
    this.typeTir = 'Appui',
    this.charge = 'CH2',
    this.tirMontagne = false,
    this.snapAzToStepMil,
    this.verbose = false,
  });

  final SystemeArme systeme;
  final String typeTir;
  final String charge;

  /// Conservé pour compatibilité avec les appels existants,
  /// mais ignoré par le Tableau I.
  bool tirMontagne;

  /// Conservé uniquement pour compatibilité avec les anciens appels.
  ///
  /// Il n'est volontairement plus utilisé : le Tableau I travaille désormais
  /// avec le gisement réel, sans arrondi préalable sur un pas angulaire.
  @Deprecated('Le Tableau I interpole désormais avec le gisement réel.')
  final int? snapAzToStepMil;

  bool verbose;

  bool _loaded = false;

  final SecureTableService _secureTable = const SecureTableService();

  final List<_ITableRow> _rows = [];

  late List<int> _latitudes;
  late List<int> _azimuts;
  late List<double> _distances;

  String _canonType(String s) => BallisticAssetContext.canonicalizeVariant(s);

  String _canonAssetType(String s) {
    return _canonType(s);
  }

  String get _assetPath {
    final t = _canonAssetType(typeTir);
    final ch = charge.trim().toUpperCase();

    // IMPORTANT :
    // Tableau I = ROTZ = correction rotation de la Terre.
    // Il ne dépend JAMAIS du tir montagne.
    return _secureTable.clearPath(
      systeme: systeme,
      famille: 'I',
      typeTir: t,
      charge: ch,
      extension: 'itbl',
    );
  }

  String get _encryptedPath {
    final t = _canonAssetType(typeTir);
    final ch = charge.trim().toUpperCase();

    return _secureTable.encryptedPath(
      systeme: systeme,
      famille: 'I',
      typeTir: t,
      charge: ch,
      extension: 'itbl',
    );
  }

  void _v(String msg) {
    if (verbose || kDebugMode) {
      debugPrint(msg);
    }
  }

  Future<void> load() async {
    if (_loaded) return;

    Uint8List bytes;

    try {
      bytes = await _secureTable.loadDecompressedFromPath(_encryptedPath);

      _v('[SECURE] TableauI AES natif OK $_encryptedPath systeme=$systeme');
    } catch (e) {
      throw StateError('[SECURE] AES ITBL decrypt failed $_encryptedPath : $e');
    }
    final data = ByteData.sublistView(bytes);

    var offset = 0;

    final magic = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    offset += 4;

    if (magic != 'ITBL') {
      throw StateError('[TableauI] Magic invalide: $magic');
    }

    final version = bytes[offset];
    offset += 1;

    if (version != 1) {
      throw StateError('[TableauI] Version non supportée: $version');
    }

    final rowCount = data.getUint32(offset, Endian.little);
    offset += 4;

    _rows.clear();

    for (var i = 0; i < rowCount; i++) {
      final rowTirMontagne = bytes[offset] == 1;
      offset += 1;

      final latitude = data.getInt16(offset, Endian.little);
      offset += 2;

      final azimut = data.getUint16(offset, Endian.little);
      offset += 2;

      final distance = data.getFloat32(offset, Endian.little);
      offset += 4;

      final correction = data.getFloat32(offset, Endian.little);
      offset += 4;

      _rows.add(
        _ITableRow(
          tirMontagne: rowTirMontagne,
          latitude: latitude,
          azimut: azimut,
          distance: distance,
          correction: correction,
        ),
      );
    }

    // Tableau I : on force toujours les lignes normales.
    // Les lignes tirMontagne=true sont ignorées.
    final source = _rows.where((r) => r.tirMontagne == false).toList();

    if (source.isEmpty) {
      throw StateError('[TableauI] Aucune donnée normale disponible');
    }

    _latitudes = source.map((e) => e.latitude).toSet().toList()..sort();
    _azimuts = source.map((e) => e.azimut).toSet().toList()..sort();
    _distances = source.map((e) => e.distance).toSet().toList()..sort();

    _loaded = true;

    _v(
      '[TableauI] OK rows=${_rows.length} '
      'rowsNormal=${source.length} '
      'lat=${_latitudes.length} '
      'az=${_azimuts.length} '
      'dist=${_distances.length} '
      'asset=$_assetPath',
    );
  }

  Future<double?> rotZ({
    required double distance,
    required int azimutMil,
    required double latitudeDeg,
    bool? tirMontagne,
    bool absolute = false,
  }) async {
    try {
      // tirMontagne volontairement ignoré pour Tableau I.
      await load();

      final v = await calcRotz(
        latDeg: latitudeDeg,
        azMil: azimutMil,
        distanceM: distance,
      );

      return absolute ? v.abs() : v;
    } catch (e, st) {
      _v('[TableauI] ROTZ indisponible: $e\n$st');
      return 0.0;
    }
  }

  Future<double> calcRotz({
    required double latDeg,
    required int azMil,
    required double distanceM,
  }) async {
    await load();

    final latAbs = latDeg.abs();

    // Normalisation exacte du gisement sur [0, 6400[, puis exploitation
    // de la symétrie du Tableau I sur [0, 3200].
    //
    // Exemple :
    //   4825 mil -> 6400 - 4825 = 1575 mil
    //
    // Aucun arrondi vers 1600 n'est effectué : l'interpolation se fait
    // directement entre les colonnes 1200 et 1600.
    double azEff = (azMil % 6400).toDouble();

    if (azEff < 0) {
      azEff += 6400.0;
    }

    if (azEff > 3200.0) {
      azEff = 6400.0 - azEff;
    }

    // Latitude et gisement restent en double afin de conserver les vraies
    // valeurs d'entrée. Il n'y a plus de latAbs.round() ni de snap angulaire.
    final (lat1, lat2, uLat) = _boundsIntForDouble(_latitudes, latAbs);
    final (az1, az2, uAz) = _boundsIntForDouble(_azimuts, azEff);
    final (d1, d2, uD) = _boundsDouble(_distances, distanceM);

    final vLat1 = _interpAzDist(lat1, az1, az2, uAz, d1, d2, uD);
    final vLat2 = _interpAzDist(lat2, az1, az2, uAz, d1, d2, uD);

    double v = _lerp(vLat1, vLat2, uLat);

    if (latDeg < 0) {
      v = -v;
    }

    final rotzRight = -v;

    _v(
      '[TableauI] lat=$latDeg '
      'az=$azMil '
      'azEff=$azEff '
      'dist=$distanceM '
      'boundsLat=($lat1,$lat2,u=$uLat) '
      'boundsAz=($az1,$az2,u=$uAz) '
      'boundsD=($d1,$d2,u=$uD) '
      '=> ROTZ=$rotzRight',
    );

    return rotzRight;
  }

  double _interpAzDist(
    int lat,
    int az1,
    int az2,
    double uAz,
    double d1,
    double d2,
    double uD,
  ) {
    final c00 = _value(lat, az1, d1);
    final c10 = _value(lat, az2, d1);
    final c01 = _value(lat, az1, d2);
    final c11 = _value(lat, az2, d2);

    return _bilinear(c00, c10, c01, c11, uAz, uD);
  }

  double _value(int lat, int az, double dist) {
    final candidates = _rows.where(
      (r) =>
          r.tirMontagne == false &&
          r.latitude == lat &&
          r.azimut == az &&
          (r.distance - dist).abs() < 0.001,
    );

    if (candidates.isNotEmpty) {
      return candidates.first.correction;
    }

    throw StateError(
      '[TableauI] Valeur absente '
      'lat=$lat '
      'az=$az '
      'dist=$dist',
    );
  }

  static (int, int, double) _boundsIntForDouble(List<int> xs, double x) {
    if (xs.isEmpty) throw StateError('Liste vide');

    if (x <= xs.first) return (xs.first, xs.first, 0.0);
    if (x >= xs.last) return (xs.last, xs.last, 0.0);

    for (var i = 1; i < xs.length; i++) {
      final a = xs[i - 1];
      final b = xs[i];

      if (x <= b) {
        return (a, b, (x - a) / (b - a));
      }
    }

    return (xs.last, xs.last, 0.0);
  }

  static (double, double, double) _boundsDouble(List<double> xs, double x) {
    if (xs.isEmpty) throw StateError('Liste vide');

    if (x <= xs.first) return (xs.first, xs.first, 0.0);
    if (x >= xs.last) return (xs.last, xs.last, 0.0);

    for (var i = 1; i < xs.length; i++) {
      final a = xs[i - 1];
      final b = xs[i];

      if (x <= b) {
        return (a, b, (x - a) / (b - a));
      }
    }

    return (xs.last, xs.last, 0.0);
  }

  static double _lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  static double _bilinear(
    double c00,
    double c10,
    double c01,
    double c11,
    double u,
    double v,
  ) {
    return c00 +
        u * (c10 - c00) +
        v * (c01 - c00) +
        u * v * (c00 - c10 - c01 + c11);
  }

  List<int> get availableLatitudes => _latitudes;
  List<int> get availableAzCols => _azimuts;
  List<double> get availableDistances => _distances;
}
