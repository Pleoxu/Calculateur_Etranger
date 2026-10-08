import 'dart:typed_data';

void writeMagic(Uint8List bytes, List<int> magic) {
  if (magic.length != 4) {
    throw ArgumentError('Magic doit faire 4 bytes');
  }

  for (var i = 0; i < 4; i++) {
    bytes[i] = magic[i];
  }
}

int readInt(Map<String, dynamic> row, String key) {
  final value = row[key];

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.round();
  }

  throw FormatException('Champ entier invalide "$key" : $value');
}

int readScaled1(Map<String, dynamic> row, String key) {
  final value = row[key];

  if (value is num) {
    return value.round();
  }

  throw FormatException('Champ numérique invalide "$key" : $value');
}

int readScaled10(Map<String, dynamic> row, String key) {
  final value = row[key];

  if (value is num) {
    return (value * 10).round();
  }

  throw FormatException('Champ numérique invalide "$key" : $value');
}

int readScaled100(Map<String, dynamic> row, String key) {
  final value = row[key];

  if (value is num) {
    return (value * 100).round();
  }

  throw FormatException('Champ numérique invalide "$key" : $value');
}

bool readBool(Map<String, dynamic> row, String key) {
  final value = row[key];

  if (value is bool) {
    return value;
  }

  if (value is int) {
    return value != 0;
  }

  if (value is String) {
    final normalized = value.toLowerCase().trim();

    return normalized == 'true' || normalized == '1' || normalized == 'oui';
  }

  return false;
}

void checkRange(String name, int value, int min, int max) {
  if (value < min || value > max) {
    throw RangeError('$name hors limites : $value attendu [$min,$max]');
  }
}
