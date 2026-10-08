import 'package:flutter/material.dart';

class ZonalIndexedPoint {
  final int row;
  final int col;
  final double offsetM;
  final double x;
  final double y;

  const ZonalIndexedPoint({
    required this.row,
    required this.col,
    required this.offsetM,
    required this.x,
    required this.y,
  });

  ZonalIndexedPoint copyWith({
    int? row,
    int? col,
    double? offsetM,
    double? x,
    double? y,
  }) {
    return ZonalIndexedPoint(
      row: row ?? this.row,
      col: col ?? this.col,
      offsetM: offsetM ?? this.offsetM,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  @override
  String toString() {
    return 'ZonalIndexedPoint(row: $row, col: $col, offsetM: $offsetM, x: $x, y: $y)';
  }
}

class ZonalShotAssignment {
  final String pieceId;
  final int salve;
  final int ordre;

  /// Position locale utilisée par le moteur spécial 200x200
  final Offset position;

  /// Point doctrinal/grille utilisé par le usecase principal
  final ZonalIndexedPoint point;

  const ZonalShotAssignment({
    required this.pieceId,
    required this.salve,
    required this.ordre,
    required this.position,
    required this.point,
  });

  ZonalShotAssignment copyWith({
    String? pieceId,
    int? salve,
    int? ordre,
    Offset? position,
    ZonalIndexedPoint? point,
  }) {
    return ZonalShotAssignment(
      pieceId: pieceId ?? this.pieceId,
      salve: salve ?? this.salve,
      ordre: ordre ?? this.ordre,
      position: position ?? this.position,
      point: point ?? this.point,
    );
  }

  @override
  String toString() {
    return 'ZonalShotAssignment('
        'pieceId: $pieceId, '
        'salve: $salve, '
        'ordre: $ordre, '
        'position: $position, '
        'point: $point'
        ')';
  }
}
