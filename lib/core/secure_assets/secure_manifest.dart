class SecureManifestEntry {
  const SecureManifestEntry({
    required this.id,
    required this.family,
    required this.variant,
    required this.charge,
    required this.format,
    required this.rows,
    required this.file,
    required this.keyVersion,
  });

  final String id;
  final String family;
  final String variant;
  final int charge;
  final String format;
  final int? rows;
  final String file;
  final int keyVersion;

  factory SecureManifestEntry.fromJson(Map<String, dynamic> json) {
    final id = _string(json, 'id');
    final file = _string(json, 'file', fallbackKey: 'path');

    return SecureManifestEntry(
      id: id,
      family: _optionalString(json, 'family') ?? _familyFromId(id),
      variant: _optionalString(json, 'variant') ?? '',
      charge: _optionalInt(json, 'charge') ?? _chargeFromId(id),
      format: _string(json, 'format'),
      rows: _optionalRows(json),
      file: file,
      keyVersion: _optionalInt(json, 'keyVersion') ?? 0,
    );
  }

  static String _string(
    Map<String, dynamic> json,
    String key, {
    String? fallbackKey,
  }) {
    final value = json[key] ?? (fallbackKey == null ? null : json[fallbackKey]);

    if (value is String && value.isNotEmpty) {
      return value;
    }

    throw FormatException('Invalid manifest: "$key" missing/invalid.');
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) return value;
    throw FormatException('Invalid manifest: "$key" must be a string.');
  }

  static int? _optionalRows(Map<String, dynamic> json) {
    final value = json['rows'];

    if (value == null) return null;

    if (value is int && value >= 0) {
      return value;
    }

    throw const FormatException(
      'Invalid manifest: "rows" must be a non-negative integer when present.',
    );
  }

  static int? _optionalInt(Map<String, dynamic> json, String key) {
    final value = json[key];

    if (value == null) return null;

    if (value is int) {
      return value;
    }

    // Compatibilité avec les charges textuelles des tables MO :
    // CH1, CH1_5, CH2_5, etc.
    if (value is String) {
      final normalized = value.trim().toUpperCase();

      final match = RegExp(r'^CH(\d+)(?:_5)?$').firstMatch(normalized);
      if (match != null) {
        return int.parse(match.group(1)!);
      }

      final parsed = int.tryParse(normalized);
      if (parsed != null) {
        return parsed;
      }
    }

    throw FormatException(
      'Invalid manifest: "$key" must be an integer '
      'or a charge in the format CHx/CHx_5.',
    );
  }

  static String _familyFromId(String id) {
    if (id.startsWith('JBIS_')) return 'JBIS';
    return id.split('_').first;
  }

  static int _chargeFromId(String id) {
    // Compatible avec CH1, CH1_5, CH2_5, etc.
    final match = RegExp(r'_CH(\d+)(?:_5)?$').firstMatch(id.toUpperCase());
    if (match == null) return 0;
    return int.parse(match.group(1)!);
  }
}
