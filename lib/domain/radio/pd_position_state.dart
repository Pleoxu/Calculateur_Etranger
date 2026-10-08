enum PdPositionSource { manual, gpsAtlas, radioPct }

class PdPositionState {
  final PdPositionSource source;

  final double x;
  final double y;
  final double z;

  final DateTime? timestamp;
  final double? accuracy;

  const PdPositionState({
    required this.source,
    required this.x,
    required this.y,
    required this.z,
    this.timestamp,
    this.accuracy,
  });

  PdPositionState copyWith({
    PdPositionSource? source,
    double? x,
    double? y,
    double? z,
    DateTime? timestamp,
    double? accuracy,
  }) {
    return PdPositionState(
      source: source ?? this.source,
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      timestamp: timestamp ?? this.timestamp,
      accuracy: accuracy ?? this.accuracy,
    );
  }
}
