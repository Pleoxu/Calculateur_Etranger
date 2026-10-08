import 'dart:typed_data';

void writeMagic(Uint8List bytes, List<int> magic) {
  if (magic.length != 4 || bytes.length < 4) {
    throw ArgumentError(
      'A four-byte magic and a writable header are required.',
    );
  }
  bytes.setRange(0, 4, magic);
}

void checkRange(String field, num value, num minimum, num maximum) {
  if (value < minimum || value > maximum) {
    throw FormatException(
      '$field out of range: $value (expected $minimum..$maximum).',
    );
  }
}

num _number(Map<String, dynamic> row, String field) {
  final value = row[field];
  if (value is! num || !value.isFinite) {
    throw FormatException('Invalid numeric field "$field": $value');
  }
  return value;
}

int _scaled(Map<String, dynamic> row, String field, num scale) {
  final scaled = (_number(row, field) * scale).round();
  return scaled;
}

int readScaled1(Map<String, dynamic> row, String field) =>
    _scaled(row, field, 1);

int readScaled10(Map<String, dynamic> row, String field) =>
    _scaled(row, field, 10);

int readScaled100(Map<String, dynamic> row, String field) =>
    _scaled(row, field, 100);
