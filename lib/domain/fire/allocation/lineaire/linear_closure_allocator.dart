import 'dart:math' as math;

import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';

/// Allocateur linéaire doctrinal à fermeture, avec ordre des pièces
/// déterminé géométriquement par rapport à la PD sur l'axe du linéaire.
///
/// Idée :
/// - les impacts sont triés par offset doctrinal sur le linéaire
/// - les pièces sont triées par leur projection sur l'axe du linéaire
///   (référencée à la PD si elle existe, sinon à la pièce médiane)
/// - l'attribution se fait ensuite par couches, en conservant cet ordre
///
/// Cela évite d'utiliser un ordre canonique fixe PS7..PS4 pour l'affectation,
/// ce qui produisait des inversions quand la géométrie réelle autour de la PD
/// ne suivait pas cet ordre symbolique.
class LinearClosureAllocator {
  const LinearClosureAllocator();

  static const List<String> _doctrineOrder = [
    'PS7',
    'PS6',
    'PS5',
    'PD',
    'PS1',
    'PS2',
    'PS3',
    'PS4',
  ];

  static List<PieceAllocation> allocate({
    required List<PieceGeom> pieces,
    required double prX,
    required double prY,
    required double azimutLineaireMil,
    required List<OffsetWithCoords> offsetsWithCoords,
    Map<String, int> coupsParPieceById = const {},
    bool isPdNomade = false,
  }) {
    if (pieces.isEmpty || offsetsWithCoords.isEmpty) {
      return const [];
    }

    final pdList = pieces.where((p) => p.isPd).toList();
    if (pdList.length > 1) {
      throw ArgumentError('Multiple PD detected (isPd=true).');
    }

    final PieceGeom pd;
    if (pdList.isEmpty) {
      final tempOrdered = [...pieces]..sort((a, b) {
          final da = _doctrineRank(a.id);
          final db = _doctrineRank(b.id);
          if (da != db) return da.compareTo(db);
          return a.id.compareTo(b.id);
        });
      pd = tempOrdered[tempOrdered.length ~/ 2];
    } else {
      pd = pdList.first;
    }

    final targets = <OffsetTarget>[
      for (int i = 0; i < offsetsWithCoords.length; i++)
        OffsetTarget(
          index: i,
          offsetM: offsetsWithCoords[i].offsetM,
          x: offsetsWithCoords[i].x,
          y: offsetsWithCoords[i].y,
        ),
    ]..sort((a, b) => a.offsetM.compareTo(b.offsetM));

    final orderedPieces = _sortPiecesAlongLinearAxis(
      pieces: pieces,
      pd: pd,
      azimutLineaireMil: azimutLineaireMil,
    );

    final quotas = _computeQuotas(
      pieces: orderedPieces,
      totalTargets: targets.length,
      coupsParPieceById: coupsParPieceById,
      pdId: pd.id,
      isPdNomade: isPdNomade,
    );

    final allocation = <String, List<OffsetTarget>>{
      for (final p in orderedPieces) p.id: <OffsetTarget>[],
    };

    final remainingByPiece = <String, int>{
      for (final p in orderedPieces) p.id: math.max(0, quotas[p.id] ?? 0),
    };

    var remainingTargets = <OffsetTarget>[...targets];

    while (remainingTargets.isNotEmpty) {
      final activePieces = orderedPieces
          .where((p) => (remainingByPiece[p.id] ?? 0) > 0)
          .toList(growable: false);

      if (activePieces.isEmpty) {
        break;
      }

      final currentLayerCount = math.min(
        activePieces.length,
        remainingTargets.length,
      );

      final futureShots = activePieces.fold<int>(
        0,
        (sum, p) => sum + math.max(0, (remainingByPiece[p.id] ?? 0) - 1),
      );

      final split = _splitCurrentLayerTargets(
        remainingTargets: remainingTargets,
        currentLayerCount: currentLayerCount,
        futureShots: futureShots,
      );

      final layerTargets = split.layerTargets;
      remainingTargets = split.futureTargets;

      for (int i = 0; i < currentLayerCount; i++) {
        final piece = activePieces[i];
        allocation[piece.id]!.add(layerTargets[i]);
        remainingByPiece[piece.id] = (remainingByPiece[piece.id] ?? 0) - 1;
      }
    }

    while (remainingTargets.isNotEmpty) {
      allocation[pd.id]!.add(remainingTargets.removeAt(0));
    }

    return [
      for (final piece in pieces)
        PieceAllocation(
          piece: piece,
          targets: allocation[piece.id] ?? const <OffsetTarget>[],
        ),
    ];
  }

  static List<PieceGeom> _sortPiecesAlongLinearAxis({
    required List<PieceGeom> pieces,
    required PieceGeom pd,
    required double azimutLineaireMil,
  }) {
    final azRad = azimutLineaireMil * 2.0 * math.pi / 6400.0;

    final ux = math.sin(azRad);
    final uy = math.cos(azRad);

    final annotated = pieces.map((piece) {
      final dx = piece.x - pd.x;
      final dy = piece.y - pd.y;
      final along = dx * ux + dy * uy;
      return _PieceAlong(piece: piece, along: along);
    }).toList();

    annotated.sort((a, b) {
      final cmpAlong = a.along.compareTo(b.along);
      if (cmpAlong != 0) return cmpAlong;

      final da = _doctrineRank(a.piece.id);
      final db = _doctrineRank(b.piece.id);
      if (da != db) return da.compareTo(db);
      return a.piece.id.compareTo(b.piece.id);
    });

    return annotated.map((e) => e.piece).toList(growable: false);
  }

  static int _doctrineRank(String id) {
    final index = _doctrineOrder.indexOf(id);
    return index >= 0 ? index : 999;
  }

  static Map<String, int> _computeQuotas({
    required List<PieceGeom> pieces,
    required int totalTargets,
    required Map<String, int> coupsParPieceById,
    required String pdId,
    bool isPdNomade = false,
  }) {
    final quotas = <String, int>{for (final piece in pieces) piece.id: 0};

    if (totalTargets <= 0) {
      return quotas;
    }

    if (coupsParPieceById.isNotEmpty) {
      for (final piece in pieces) {
        quotas[piece.id] = math.max(0, coupsParPieceById[piece.id] ?? 0);
      }

      final sum = quotas.values.fold<int>(0, (a, b) => a + b);

      if (sum < totalTargets) {
        quotas[pdId] = (quotas[pdId] ?? 0) + (totalTargets - sum);
      } else if (sum > totalTargets) {
        var extra = sum - totalTargets;

        for (final piece in pieces.reversed) {
          if (extra <= 0) break;
          if (piece.id == pdId) continue;

          final cur = quotas[piece.id] ?? 0;
          final take = math.min(cur, extra);
          quotas[piece.id] = cur - take;
          extra -= take;
        }

        if (extra > 0) {
          final cur = quotas[pdId] ?? 0;
          final take = math.min(cur, extra);
          quotas[pdId] = cur - take;
        }
      }

      return quotas;
    }

    if (isPdNomade) {
      final psOnly = pieces.where((p) => p.id != pdId).toList();
      final psCount = psOnly.length;

      if (psCount == 0) {
        quotas[pdId] = totalTargets;
        return quotas;
      }

      final base = totalTargets ~/ psCount;
      final rem = totalTargets % psCount;

      for (int i = 0; i < psOnly.length; i++) {
        quotas[psOnly[i].id] = base + (i < rem ? 1 : 0);
      }
      quotas[pdId] = 0;
      return quotas;
    }

    final n = pieces.length;
    final base = totalTargets ~/ n;
    final rem = totalTargets % n;

    for (int i = 0; i < n; i++) {
      quotas[pieces[i].id] = base + (i < rem ? 1 : 0);
    }

    return quotas;
  }

  static _LayerSplit _splitCurrentLayerTargets({
    required List<OffsetTarget> remainingTargets,
    required int currentLayerCount,
    required int futureShots,
  }) {
    if (currentLayerCount <= 0 || remainingTargets.isEmpty) {
      return const _LayerSplit(
        layerTargets: <OffsetTarget>[],
        futureTargets: <OffsetTarget>[],
      );
    }

    final total = remainingTargets.length;
    final reserve = math.max(
      0,
      math.min(total - currentLayerCount, futureShots),
    );
    final availableForLayer = total - reserve;
    final count = math.min(currentLayerCount, availableForLayer);

    if (count <= 0) {
      return _LayerSplit(
        layerTargets:
            remainingTargets.take(currentLayerCount).toList(growable: false),
        futureTargets:
            remainingTargets.skip(currentLayerCount).toList(growable: false),
      );
    }

    final leftCount = count ~/ 2;
    final rightCount = count - leftCount;

    final layerTargets = <OffsetTarget>[];
    layerTargets.addAll(remainingTargets.take(leftCount));
    layerTargets.addAll(remainingTargets.skip(total - rightCount));
    layerTargets.sort((a, b) => a.offsetM.compareTo(b.offsetM));

    final futureTargets = <OffsetTarget>[];
    futureTargets.addAll(
      remainingTargets.skip(leftCount).take(total - leftCount - rightCount),
    );

    return _LayerSplit(
      layerTargets: List.unmodifiable(layerTargets),
      futureTargets: List.unmodifiable(futureTargets),
    );
  }
}

class _LayerSplit {
  final List<OffsetTarget> layerTargets;
  final List<OffsetTarget> futureTargets;

  const _LayerSplit({required this.layerTargets, required this.futureTargets});
}

class _PieceAlong {
  final PieceGeom piece;
  final double along;

  const _PieceAlong({required this.piece, required this.along});
}
