import 'dart:math' as math;

import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';

class FirePlanCrossingResolver {
  const FirePlanCrossingResolver();

  ({List<PieceAllocation> allocs, bool hasCrossings}) resolve({
    required List<PieceAllocation> allocs,
    required bool isLineaire,
    required bool isZonal,
    required double azimutLineaireMil,
  }) {
    if (isZonal) {
      return _resolveZonalCrossings(allocs: allocs);
    }

    if (!isLineaire || allocs.length < 2) {
      return (allocs: allocs, hasCrossings: false);
    }

    final sortedPieces = _sortPiecesAlongLinearAxis(
      pieces: allocs.map((a) => a.piece).toList(growable: false),
      azimutLineaireMil: azimutLineaireMil,
    );
    final sortedIds = sortedPieces.map((p) => p.id).toList(growable: false);

    final indexed = <_LinearTargetRef>[];
    for (final alloc in allocs) {
      final pieceRank = sortedIds.indexOf(alloc.piece.id);
      for (final target in alloc.targets) {
        indexed.add(
          _LinearTargetRef(
            pieceId: alloc.piece.id,
            pieceRank: pieceRank,
            target: target,
          ),
        );
      }
    }

    if (indexed.isEmpty) {
      return (allocs: allocs, hasCrossings: false);
    }

    indexed.sort((a, b) {
      final cmp = a.target.offsetM.compareTo(b.target.offsetM);
      if (cmp != 0) return cmp;
      return a.pieceRank.compareTo(b.pieceRank);
    });

    var hasCrossings = false;
    for (var i = 1; i < indexed.length; i++) {
      if (indexed[i - 1].pieceRank > indexed[i].pieceRank) {
        hasCrossings = true;
        break;
      }
    }

    if (!hasCrossings) {
      return (allocs: allocs, hasCrossings: false);
    }

    final countsByPiece = <String, int>{
      for (final alloc in allocs) alloc.piece.id: alloc.targets.length,
    };

    final rebuiltTargets = <String, List<OffsetTarget>>{
      for (final alloc in allocs) alloc.piece.id: <OffsetTarget>[],
    };

    var cursor = 0;
    for (final piece in sortedPieces) {
      final count = countsByPiece[piece.id] ?? 0;
      for (var i = 0; i < count && cursor < indexed.length; i++) {
        rebuiltTargets[piece.id]!.add(indexed[cursor].target);
        cursor++;
      }
    }

    final fixed = [
      for (final alloc in allocs)
        PieceAllocation(
          piece: alloc.piece,
          targets: List.unmodifiable(
            rebuiltTargets[alloc.piece.id] ?? const [],
          ),
        ),
    ];

    return (allocs: fixed, hasCrossings: true);
  }

  ({List<PieceAllocation> allocs, bool hasCrossings}) _resolveZonalCrossings({
    required List<PieceAllocation> allocs,
  }) {
    if (allocs.length < 2) return (allocs: allocs, hasCrossings: false);

    final pieceX = <double>[for (final a in allocs) a.piece.x];
    final pieceY = <double>[for (final a in allocs) a.piece.y];
    final targets = <List<OffsetTarget>>[
      for (final a in allocs) [...a.targets],
    ];
    final n = allocs.length;

    bool hadAnyCrossing = false;
    bool improved = true;
    var pass = 0;

    while (improved && pass < 20) {
      improved = false;
      pass++;
      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          for (var ti = 0; ti < targets[i].length; ti++) {
            for (var tj = 0; tj < targets[j].length; tj++) {
              final ax = pieceX[i], ay = pieceY[i];
              final bx = targets[i][ti].x, by = targets[i][ti].y;
              final cx = pieceX[j], cy = pieceY[j];
              final dx = targets[j][tj].x, dy = targets[j][tj].y;
              if (_segmentsIntersect(ax, ay, bx, by, cx, cy, dx, dy)) {
                hadAnyCrossing = true;
                final stillCrossesAfterSwap = _segmentsIntersect(
                  ax,
                  ay,
                  dx,
                  dy,
                  cx,
                  cy,
                  bx,
                  by,
                );
                if (!stillCrossesAfterSwap) {
                  final tmp = targets[i][ti];
                  targets[i][ti] = targets[j][tj];
                  targets[j][tj] = tmp;
                  improved = true;
                }
              }
            }
          }
        }
      }
    }

    final fixed = [
      for (var i = 0; i < n; i++)
        PieceAllocation(
          piece: allocs[i].piece,
          targets: List.unmodifiable(targets[i]),
        ),
    ];
    return (allocs: fixed, hasCrossings: hadAnyCrossing);
  }

  List<PieceGeom> _sortPiecesAlongLinearAxis({
    required List<PieceGeom> pieces,
    required double azimutLineaireMil,
  }) {
    final pdList = pieces.where((p) => p.isPd).toList();
    final ref = pdList.isNotEmpty ? pdList.first : pieces[pieces.length ~/ 2];

    final azRad = azimutLineaireMil * 2.0 * math.pi / 6400.0;
    final ux = math.sin(azRad);
    final uy = math.cos(azRad);

    final annotated = pieces.map((piece) {
      final dx = piece.x - ref.x;
      final dy = piece.y - ref.y;
      final along = dx * ux + dy * uy;
      return (piece: piece, along: along);
    }).toList();

    annotated.sort((a, b) {
      final cmp = a.along.compareTo(b.along);
      if (cmp != 0) return cmp;
      return a.piece.id.compareTo(b.piece.id);
    });

    return annotated.map((e) => e.piece).toList(growable: false);
  }

  bool _segmentsIntersect(
    double ax,
    double ay,
    double bx,
    double by,
    double cx,
    double cy,
    double dx,
    double dy,
  ) {
    double cross(
      double ox,
      double oy,
      double px,
      double py,
      double qx,
      double qy,
    ) {
      return (px - ox) * (qy - oy) - (py - oy) * (qx - ox);
    }

    final d1 = cross(cx, cy, dx, dy, ax, ay);
    final d2 = cross(cx, cy, dx, dy, bx, by);
    final d3 = cross(ax, ay, bx, by, cx, cy);
    final d4 = cross(ax, ay, bx, by, dx, dy);
    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }
    return false;
  }
}

class _LinearTargetRef {
  final String pieceId;
  final int pieceRank;
  final OffsetTarget target;

  const _LinearTargetRef({
    required this.pieceId,
    required this.pieceRank,
    required this.target,
  });
}
