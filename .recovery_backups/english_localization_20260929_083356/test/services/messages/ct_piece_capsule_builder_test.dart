// test/services/messages/ct_piece_capsule_builder_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:calculateur_etranger/services/messages/ct_message_capsule.dart';
import 'package:calculateur_etranger/services/messages/ct_piece_capsule_builder.dart';
import 'package:calculateur_etranger/services/messages/ct_piece_display_payload.dart';

void main() {
  group('CtPieceCapsuleBuilder', () {
    test('construit une capsule PS1 lisible de bout en bout', () {
      const payload = CtPieceDisplayPayload(
        title: 'PS1',
        sections: <CtPieceDisplaySection>[
          CtPieceDisplaySection(
            title: 'Identification',
            fields: <CtPieceDisplayField>[
              CtPieceDisplayField(label: 'Pièce', value: 'PS1'),
              CtPieceDisplayField(label: 'Statut', value: 'Prête'),
            ],
          ),
          CtPieceDisplaySection(
            title: 'Informations',
            fields: <CtPieceDisplayField>[
              CtPieceDisplayField(label: 'Élément A', value: 'Valeur test'),
              CtPieceDisplayField(label: 'Élément B', value: '123'),
            ],
          ),
        ],
      );

      final capsule = const CtPieceCapsuleBuilder().build(
        missionId: 'MISSION-PS1-001',
        recipientId: 'PS1',
        sequenceNumber: 1,
        createdAtUtc: DateTime.utc(2026, 9, 11, 16, 0),
        displayPayload: payload,
      );

      final encoded = capsule.toCompactString();
      final decodedCapsule = CtMessageCapsule.fromCompactString(encoded);
      final decodedPayload =
          CtPieceDisplayPayload.fromBytes(decodedCapsule.payload);

      expect(decodedCapsule.missionId, 'MISSION-PS1-001');
      expect(decodedCapsule.recipientId, 'PS1');
      expect(decodedCapsule.sequenceNumber, 1);
      expect(decodedCapsule.isIntegrityValid, isTrue);
      expect(decodedPayload.title, 'PS1');
      expect(decodedPayload.sections.length, 2);
      expect(decodedPayload.sections.first.fields.first.value, 'PS1');
    });

    test('rejette un destinataire vide', () {
      const payload = CtPieceDisplayPayload(
        title: 'PS1',
        sections: <CtPieceDisplaySection>[],
      );

      expect(
        () => const CtPieceCapsuleBuilder().build(
          missionId: 'MISSION-1',
          recipientId: '   ',
          sequenceNumber: 0,
          displayPayload: payload,
        ),
        throwsArgumentError,
      );
    });
  });
}
