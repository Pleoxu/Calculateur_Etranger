// lib/services/messages/ct_message_capsule.dart
//
// Transport-only CTMSG v1 envelope.
// The payload is intentionally opaque to this module.

import 'dart:convert';
import 'dart:typed_data';

class CtMessageCapsule {
  CtMessageCapsule({
    required this.missionId,
    required this.recipientId,
    required this.createdAtUtc,
    required this.sequenceNumber,
    required Uint8List payload,
    this.requiresAcknowledgement = true,
  })  : payload = Uint8List.fromList(payload),
        checksum = _crc32Hex(payload);

  CtMessageCapsule._({
    required this.missionId,
    required this.recipientId,
    required this.createdAtUtc,
    required this.sequenceNumber,
    required Uint8List payload,
    required this.requiresAcknowledgement,
    required this.checksum,
  }) : payload = Uint8List.fromList(payload);

  static const int formatVersion = 1;
  static const String wirePrefix = 'CTMSG1:';

  final String missionId;
  final String recipientId;
  final DateTime createdAtUtc;
  final int sequenceNumber;
  final Uint8List payload;
  final bool requiresAcknowledgement;
  final String checksum;

  Map<String, Object> toJson() {
    return <String, Object>{
      'v': formatVersion,
      'missionId': missionId,
      'recipientId': recipientId,
      'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
      'sequenceNumber': sequenceNumber,
      'requiresAck': requiresAcknowledgement,
      'payloadB64': base64UrlEncode(payload),
      'checksum': checksum,
    };
  }

  String toCompactString() {
    final jsonBytes = utf8.encode(jsonEncode(toJson()));
    return '$wirePrefix${base64UrlEncode(jsonBytes)}';
  }

  Uint8List toFileBytes() => Uint8List.fromList(utf8.encode(toCompactString()));

  bool get isIntegrityValid => checksum == _crc32Hex(payload);

  static CtMessageCapsule fromCompactString(String source) {
    final value = source.trim();

    if (!value.startsWith(wirePrefix)) {
      throw const FormatException('Invalid CTMSG format.');
    }

    final encoded = value.substring(wirePrefix.length);

    late final Map<String, dynamic> json;
    try {
      final decoded = utf8.decode(base64Url.decode(encoded));
      final parsed = jsonDecode(decoded);
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('Invalid CTMSG content.');
      }
      json = parsed;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid CTMSG encoding.');
    }

    if (json['v'] != formatVersion) {
      throw FormatException('Unsupported CTMSG version: ${json['v']}');
    }

    final missionId = _requiredString(json, 'missionId');
    final recipientId = _requiredString(json, 'recipientId');

    final createdAtRaw = _requiredString(json, 'createdAtUtc');
    final createdAt = DateTime.tryParse(createdAtRaw)?.toUtc();
    if (createdAt == null) {
      throw const FormatException('Invalid CTMSG timestamp.');
    }

    final sequenceNumber = json['sequenceNumber'];
    if (sequenceNumber is! int || sequenceNumber < 0) {
      throw const FormatException('Invalid CTMSG sequence number.');
    }

    final requiresAck = json['requiresAck'];
    if (requiresAck is! bool) {
      throw const FormatException('Invalid requiresAck field.');
    }

    final payloadEncoded = _requiredString(json, 'payloadB64');
    late final Uint8List payload;
    try {
      payload = Uint8List.fromList(base64Url.decode(payloadEncoded));
    } catch (_) {
      throw const FormatException('Invalid CTMSG payload.');
    }

    final checksum = _requiredString(json, 'checksum').toLowerCase();

    final capsule = CtMessageCapsule._(
      missionId: missionId,
      recipientId: recipientId,
      createdAtUtc: createdAt,
      sequenceNumber: sequenceNumber,
      payload: payload,
      requiresAcknowledgement: requiresAck,
      checksum: checksum,
    );

    if (!capsule.isIntegrityValid) {
      throw const FormatException('Invalid CTMSG integrity check.');
    }

    return capsule;
  }

  static CtMessageCapsule fromFileBytes(List<int> bytes) {
    try {
      return fromCompactString(utf8.decode(bytes));
    } catch (error) {
      if (error is FormatException) rethrow;
      throw const FormatException('Invalid CTMSG file.');
    }
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing or invalid CTMSG field: $key');
    }
    return value;
  }

  static String _crc32Hex(List<int> bytes) {
    var crc = 0xffffffff;

    for (final byte in bytes) {
      crc ^= byte & 0xff;
      for (var bit = 0; bit < 8; bit++) {
        final mask = -(crc & 1);
        crc = (crc >> 1) ^ (0xedb88320 & mask);
      }
    }

    final value = (crc ^ 0xffffffff) & 0xffffffff;
    return value.toRadixString(16).padLeft(8, '0');
  }
}
