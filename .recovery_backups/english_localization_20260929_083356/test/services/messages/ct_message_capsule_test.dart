// test/services/messages/ct_message_capsule_test.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:calculateur_etranger/services/messages/ct_message_capsule.dart';

void main() {
  group('CtMessageCapsule', () {
    test('round-trip conserve les métadonnées et le payload', () {
      final original = CtMessageCapsule(
        missionId: 'MISSION-042',
        recipientId: 'PS1',
        createdAtUtc: DateTime.utc(2026, 9, 11, 13, 45),
        sequenceNumber: 7,
        payload: Uint8List.fromList(utf8.encode('payload-test')),
      );

      final encoded = original.toCompactString();
      final decoded = CtMessageCapsule.fromCompactString(encoded);

      expect(decoded.missionId, original.missionId);
      expect(decoded.recipientId, original.recipientId);
      expect(decoded.createdAtUtc, original.createdAtUtc);
      expect(decoded.sequenceNumber, original.sequenceNumber);
      expect(decoded.requiresAcknowledgement, isTrue);
      expect(decoded.payload, original.payload);
      expect(decoded.checksum, original.checksum);
      expect(decoded.isIntegrityValid, isTrue);
    });

    test('le format fichier utilise la même capsule', () {
      final original = CtMessageCapsule(
        missionId: 'MISSION-100',
        recipientId: 'PS2',
        createdAtUtc: DateTime.utc(2026, 9, 11, 14),
        sequenceNumber: 1,
        payload: Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
        requiresAcknowledgement: false,
      );

      final decoded = CtMessageCapsule.fromFileBytes(original.toFileBytes());

      expect(decoded.recipientId, 'PS2');
      expect(decoded.requiresAcknowledgement, isFalse);
      expect(decoded.payload, <int>[1, 2, 3, 4, 5]);
    });

    test('rejette une capsule dont le payload a été altéré', () {
      final original = CtMessageCapsule(
        missionId: 'MISSION-200',
        recipientId: 'PS3',
        createdAtUtc: DateTime.utc(2026, 9, 11, 15),
        sequenceNumber: 2,
        payload: Uint8List.fromList(utf8.encode('ABC')),
      );

      final compact = original.toCompactString();
      final encodedJson = compact.substring(CtMessageCapsule.wirePrefix.length);
      final jsonMap = jsonDecode(
        utf8.decode(base64Url.decode(encodedJson)),
      ) as Map<String, dynamic>;

      jsonMap['payloadB64'] = base64UrlEncode(utf8.encode('XYZ'));

      final tampered = CtMessageCapsule.wirePrefix +
          base64UrlEncode(utf8.encode(jsonEncode(jsonMap)));

      expect(
        () => CtMessageCapsule.fromCompactString(tampered),
        throwsFormatException,
      );
    });

    test('rejette un préfixe inconnu', () {
      expect(
        () => CtMessageCapsule.fromCompactString('BAD:abcdef'),
        throwsFormatException,
      );
    });

    test('permet au lecteur de détecter un mauvais destinataire', () {
      final capsule = CtMessageCapsule(
        missionId: 'MISSION-300',
        recipientId: 'PS4',
        createdAtUtc: DateTime.utc(2026, 9, 11, 16),
        sequenceNumber: 3,
        payload: Uint8List.fromList(<int>[9, 9, 9]),
      );

      final decoded =
          CtMessageCapsule.fromCompactString(capsule.toCompactString());

      const localRecipientId = 'PS1';
      expect(decoded.recipientId == localRecipientId, isFalse);
    });
  });
}
