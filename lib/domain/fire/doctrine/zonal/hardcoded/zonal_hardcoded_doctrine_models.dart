enum ZonalDoctrineMode { otan, force }

enum ZonalOffsetVariant { reference, alternate }

class ZonalHardcodedShot {
  final String pieceCode;
  final int salvo;
  final int row;
  final int slot;
  final double x;
  final double y;
  final String label;

  const ZonalHardcodedShot({
    required this.pieceCode,
    required this.salvo,
    required this.row,
    required this.slot,
    required this.x,
    required this.y,
    required this.label,
  });

  ZonalHardcodedShot copyWith({
    String? pieceCode,
    int? salvo,
    int? row,
    int? slot,
    double? x,
    double? y,
    String? label,
  }) {
    return ZonalHardcodedShot(
      pieceCode: pieceCode ?? this.pieceCode,
      salvo: salvo ?? this.salvo,
      row: row ?? this.row,
      slot: slot ?? this.slot,
      x: x ?? this.x,
      y: y ?? this.y,
      label: label ?? this.label,
    );
  }
}

class ZonalHardcodedSequence {
  final String code;
  final double width;
  final double height;
  final ZonalDoctrineMode mode;
  final ZonalOffsetVariant variant;
  final List<int> totalPerRow;
  final List<int> salvo1PerRow;
  final List<int> salvo2PerRow;
  final List<ZonalHardcodedShot> shots;

  const ZonalHardcodedSequence({
    required this.code,
    required this.width,
    required this.height,
    required this.mode,
    required this.variant,
    required this.totalPerRow,
    required this.salvo1PerRow,
    required this.salvo2PerRow,
    required this.shots,
  });

  int get totalShots => shots.length;

  List<ZonalHardcodedShot> get salvo1 =>
      shots.where((shot) => shot.salvo == 1).toList(growable: false);

  List<ZonalHardcodedShot> get salvo2 =>
      shots.where((shot) => shot.salvo == 2).toList(growable: false);
}
