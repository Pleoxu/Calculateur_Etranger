// lib/services/tableau_b_mo81_llr_service.dart
//
// Lecteur dédié T1 MO81 LLR.
// Charge directement l'asset AES MO81_LLR sans passer par le manifeste
// historique de SecureAssetLoader.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:calculateur_etranger/security/native_secure_assets.dart';

enum Mo81LlrT1Status {
  ok,
  tableVide,
  horsDomaineDistance,
  horsDomaineDenivelee,
  celluleVide,
}

class Mo81LlrT1Row {
  final double correctionSiteMil;
  final int niveauMeteo;
  final bool interpolation;
  final bool valid;
  final Mo81LlrT1Status status;
  final String? warning;

  const Mo81LlrT1Row({
    required this.correctionSiteMil,
    required this.niveauMeteo,
    this.interpolation = false,
    this.valid = true,
    this.status = Mo81LlrT1Status.ok,
    this.warning,
  });
}

class _T1Point {
  final double distance;
  final double denivelee;
  final double correctionSite;
  final int niveauMeteo;
  final bool tirMontagne;

  const _T1Point({
    required this.distance,
    required this.denivelee,
    required this.correctionSite,
    required this.niveauMeteo,
    required this.tirMontagne,
  });
}

class TableauBMo81LlrService {
  final bool tirMontagne;
  final bool verbose;
  final String encryptedPath;

  TableauBMo81LlrService({
    required this.tirMontagne,
    this.verbose = false,
    this.encryptedPath =
        'assets/secure_enc/tableaux/MO81_LLR/T1/MO81_LLR_OE_81_F2_T1_CH3.btbl.gz.enc',
  });

  bool _loaded = false;
  final List<_T1Point> _points = <_T1Point>[];

  Future<void> load() async {
    if (_loaded) return;

    final compressed = await NativeSecureAssets.decryptAsset(encryptedPath);
    final raw = Uint8List.fromList(gzip.decode(compressed));

    _decode(raw);
    _loaded = true;

    if (verbose || kDebugMode) {
      debugPrint('[MO81 LLR T1] OK path=$encryptedPath rows=${_points.length}');
    }
  }

  void _decode(Uint8List bytes) {
    const headerSize = 9;
    const rowSize = 8;

    if (bytes.length < headerSize) {
      throw FormatException('[MO81 LLR T1] BTBL trop court.');
    }

    final data = ByteData.sublistView(bytes);
    final magic = String.fromCharCodes(bytes.sublist(0, 4));
    if (magic != 'BTBL') {
      throw FormatException('[MO81 LLR T1] Magic invalide: $magic');
    }

    final version = data.getUint8(4);
    if (version != 1) {
      throw FormatException(
        '[MO81 LLR T1] Version BTBL non supportée: $version',
      );
    }

    final rowCount = data.getUint32(5, Endian.little);
    final expectedSize = headerSize + rowCount * rowSize;

    if (bytes.length != expectedSize) {
      throw FormatException(
        '[MO81 LLR T1] Taille invalide: '
        '${bytes.length}, attendue=$expectedSize',
      );
    }

    _points.clear();

    var offset = headerSize;
    for (var i = 0; i < rowCount; i++) {
      final distance = data.getUint16(offset, Endian.little);
      offset += 2;

      final denivelee = data.getInt16(offset, Endian.little);
      offset += 2;

      final correctionSite = data.getInt16(offset, Endian.little);
      offset += 2;

      final niveauMeteo = data.getUint8(offset);
      offset += 1;

      final flags = data.getUint8(offset);
      offset += 1;

      if ((flags & 0xFE) != 0) {
        throw FormatException(
          '[MO81 LLR T1] Flags réservés utilisés ligne $i: $flags',
        );
      }

      _points.add(
        _T1Point(
          distance: distance.toDouble(),
          denivelee: denivelee.toDouble(),
          correctionSite: correctionSite.toDouble(),
          niveauMeteo: niveauMeteo,
          tirMontagne: (flags & 0x01) != 0,
        ),
      );
    }
  }

  Future<Mo81LlrT1Row> chercher({
    required double distanceTopoM,
    required double deniveleeM,
  }) async {
    await load();

    final points = _points.where((p) => p.tirMontagne == tirMontagne).toList();

    if (points.isEmpty) {
      return const Mo81LlrT1Row(
        correctionSiteMil: 0,
        niveauMeteo: 0,
        valid: false,
        status: Mo81LlrT1Status.tableVide,
        warning: 'Aucune donnée T1 MO81 LLR exploitable.',
      );
    }

    final distances = points.map((p) => p.distance).toSet().toList()..sort();
    final dBounds = _boundsStrict(distances, distanceTopoM);

    if (dBounds == null) {
      return Mo81LlrT1Row(
        correctionSiteMil: 0,
        niveauMeteo: 0,
        valid: false,
        status: Mo81LlrT1Status.horsDomaineDistance,
        warning:
            'Distance hors domaine T1 MO81 LLR: ${distanceTopoM.toStringAsFixed(1)} m.',
      );
    }

    final d1 = dBounds.$1;
    final d2 = dBounds.$2;
    final uD = dBounds.$3;

    final h1 = _boundsDenivelee(points, d1, deniveleeM);
    if (h1 == null) {
      return _horsDomaineDenivelee(d1, deniveleeM);
    }

    final h2 = _boundsDenivelee(points, d2, deniveleeM);
    if (h2 == null) {
      return _horsDomaineDenivelee(d2, deniveleeM);
    }

    final p11 = _point(points, d1, h1.$1);
    final p12 = _point(points, d1, h1.$2);
    final p21 = _point(points, d2, h2.$1);
    final p22 = _point(points, d2, h2.$2);

    if (p11 == null || p12 == null || p21 == null || p22 == null) {
      return const Mo81LlrT1Row(
        correctionSiteMil: 0,
        niveauMeteo: 0,
        valid: false,
        status: Mo81LlrT1Status.celluleVide,
        warning: 'Cellule vide T1 MO81 LLR : interpolation impossible.',
      );
    }

    final vD1 = _lerp(p11.correctionSite, p12.correctionSite, h1.$3);
    final vD2 = _lerp(p21.correctionSite, p22.correctionSite, h2.$3);
    final correction = _lerp(vD1, vD2, uD);

    final niveau = _nearestLevel(
      [p11, p12, p21, p22],
      distanceTopoM: distanceTopoM,
      deniveleeM: deniveleeM,
    );

    final interpolation = d1 != d2 || h1.$1 != h1.$2 || h2.$1 != h2.$2;

    if (verbose || kDebugMode) {
      debugPrint(
        '[MO81 LLR T1] D=$distanceTopoM dZ=$deniveleeM '
        'corrSite=${correction.toStringAsFixed(2)} LN=$niveau '
        'interp=$interpolation',
      );
    }

    return Mo81LlrT1Row(
      correctionSiteMil: correction,
      niveauMeteo: niveau,
      interpolation: interpolation,
    );
  }

  Mo81LlrT1Row _horsDomaineDenivelee(double distance, double denivelee) {
    final hs = _points
        .where(
          (p) =>
              p.tirMontagne == tirMontagne &&
              (p.distance - distance).abs() < 0.001,
        )
        .map((p) => p.denivelee)
        .toSet()
        .toList()
      ..sort();

    return Mo81LlrT1Row(
      correctionSiteMil: 0,
      niveauMeteo: 0,
      valid: false,
      status: Mo81LlrT1Status.horsDomaineDenivelee,
      warning: hs.isEmpty
          ? 'Aucune ligne T1 MO81 LLR pour D=$distance m.'
          : 'Dénivelée hors domaine T1 à D=$distance m: '
              '${denivelee.toStringAsFixed(1)} m '
              '(min=${hs.first}, max=${hs.last}).',
    );
  }

  static (double, double, double)? _boundsStrict(List<double> xs, double x) {
    if (xs.isEmpty) return null;
    const eps = 0.0001;

    if (x < xs.first - eps || x > xs.last + eps) return null;

    if ((x - xs.first).abs() <= eps) return (xs.first, xs.first, 0);
    if ((x - xs.last).abs() <= eps) return (xs.last, xs.last, 0);

    for (var i = 0; i < xs.length - 1; i++) {
      final a = xs[i];
      final b = xs[i + 1];

      if (x >= a - eps && x <= b + eps) {
        if ((x - a).abs() <= eps) return (a, a, 0);
        if ((x - b).abs() <= eps) return (b, b, 0);
        return (a, b, (x - a) / (b - a));
      }
    }

    return null;
  }

  static (double, double, double)? _boundsDenivelee(
    List<_T1Point> points,
    double distance,
    double denivelee,
  ) {
    final hs = points
        .where((p) => (p.distance - distance).abs() < 0.001)
        .map((p) => p.denivelee)
        .toSet()
        .toList()
      ..sort();

    return _boundsStrict(hs, denivelee);
  }

  static _T1Point? _point(
    List<_T1Point> points,
    double distance,
    double denivelee,
  ) {
    for (final p in points) {
      if ((p.distance - distance).abs() < 0.001 &&
          (p.denivelee - denivelee).abs() < 0.001) {
        return p;
      }
    }
    return null;
  }

  static int _nearestLevel(
    List<_T1Point> candidates, {
    required double distanceTopoM,
    required double deniveleeM,
  }) {
    var best = candidates.first;
    var bestScore = double.infinity;

    for (final p in candidates) {
      final score =
          (p.distance - distanceTopoM).abs() + (p.denivelee - deniveleeM).abs();

      if (score < bestScore) {
        best = p;
        bestScore = score;
      }
    }

    return best.niveauMeteo;
  }

  static double _lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }
}
