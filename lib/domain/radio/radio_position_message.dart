enum RadioNodeType { pd, ps }

class RadioPositionMessage {
  final String id;
  final RadioNodeType type;

  final double x;
  final double y;
  final double z;

  final DateTime timestamp;

  final double? accuracy;

  const RadioPositionMessage({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
    this.accuracy,
  });
}
