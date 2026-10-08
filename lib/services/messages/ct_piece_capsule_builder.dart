// lib/services/messages/ct_piece_capsule_builder.dart
//
// Builds a CTMSG envelope from a generic display payload.
// This module is transport-only and does not interpret domain content.

import 'ct_message_capsule.dart';
import 'ct_piece_display_payload.dart';

class CtPieceCapsuleBuilder {
  const CtPieceCapsuleBuilder();

  CtMessageCapsule build({
    required String missionId,
    required String recipientId,
    required int sequenceNumber,
    required CtPieceDisplayPayload displayPayload,
    DateTime? createdAtUtc,
    bool requiresAcknowledgement = true,
  }) {
    final normalizedMissionId = missionId.trim();
    final normalizedRecipientId = recipientId.trim();

    if (normalizedMissionId.isEmpty) {
      throw ArgumentError('missionId must not be empty.');
    }

    if (normalizedRecipientId.isEmpty) {
      throw ArgumentError('recipientId must not be empty.');
    }

    if (sequenceNumber < 0) {
      throw ArgumentError('sequenceNumber must be non-negative.');
    }

    return CtMessageCapsule(
      missionId: normalizedMissionId,
      recipientId: normalizedRecipientId,
      createdAtUtc: (createdAtUtc ?? DateTime.now().toUtc()).toUtc(),
      sequenceNumber: sequenceNumber,
      payload: displayPayload.toBytes(),
      requiresAcknowledgement: requiresAcknowledgement,
    );
  }
}
