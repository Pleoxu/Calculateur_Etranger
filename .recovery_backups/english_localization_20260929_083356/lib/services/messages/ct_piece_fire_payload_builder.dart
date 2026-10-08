// lib/services/messages/ct_piece_fire_payload_builder.dart
//
// Projects the results already calculated for one recipient into the generic
// ct-piece-display payload. This adapter is read-only: it never recalculates
// ballistics and does not modify the firing plan or the output.

import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';

import 'ct_piece_display_payload.dart';

class CtPieceFirePayloadBuilder {
  const CtPieceFirePayloadBuilder();

  /// Builds the complete, display-ready payload for one engaged piece.
  ///
  /// A capsule contains every calculated shot assigned to its recipient. A
  /// single-shot mission therefore has one "Éléments de tir" section, whereas
  /// a linear, zonal, or salvo mission has one section per calculated shot.
  CtPieceDisplayPayload build({
    required TirCompletOutput output,
    required String recipientId,
    List<CtPieceDisplaySection> extraSections = const <CtPieceDisplaySection>[],
  }) {
    final recipient = _normalisePieceId(recipientId);
    if (recipient.isEmpty) {
      throw ArgumentError.value(
        recipientId,
        'recipientId',
        'Le destinataire ne doit pas être vide.',
      );
    }

    final shots = output.shots
        .where((shot) => _normalisePieceId(shot.nomPiece) == recipient)
        .toList(growable: false);
    if (shots.isEmpty) {
      throw StateError(
        'Aucun tir calculé pour la pièce $recipient.',
      );
    }

    final piece = _findPiece(output.firePlan.pieces, recipient);
    if (piece == null) {
      throw StateError(
        'Coordonnées de la pièce $recipient indisponibles dans le plan de tir.',
      );
    }

    return CtPieceDisplayPayload(
      title: 'Capsule $recipient',
      sections: <CtPieceDisplaySection>[
        CtPieceDisplaySection(
          title: 'Pièce',
          fields: <CtPieceDisplayField>[
            CtPieceDisplayField(label: 'Pièce', value: recipient),
            CtPieceDisplayField(
              label: 'Coordonnées pièce (UTM)',
              value: _formatPieceCoordinates(piece),
            ),
          ],
        ),
        for (var index = 0; index < shots.length; index++)
          _buildShotSection(
            shot: shots[index],
            index: index,
            total: shots.length,
          ),
        ...extraSections,
      ],
    );
  }

  CtPieceDisplaySection _buildShotSection({
    required TirLineaireShot shot,
    required int index,
    required int total,
  }) {
    final result = shot.resultat;
    final timeLabel = result.isOECL ? 'Tempage' : 'Temps de vol';

    return CtPieceDisplaySection(
      title: _shotTitle(shot: shot, index: index, total: total),
      fields: <CtPieceDisplayField>[
        CtPieceDisplayField(
          label: 'Noire',
          value: '${result.noireMil.toStringAsFixed(1)} mil',
        ),
        CtPieceDisplayField(
          label: 'AQE',
          value: '${result.aqeMil.toStringAsFixed(1)} mil',
        ),
        CtPieceDisplayField(
          label: timeLabel,
          value: '${result.tempsVolS.toStringAsFixed(2)} s',
        ),
        CtPieceDisplayField(label: 'Charge', value: result.charge),
        CtPieceDisplayField(
          label: 'EPP',
          value: _formatMeters(result.ecartProbablePorteeM),
        ),
        CtPieceDisplayField(
          label: 'EPD',
          value: _formatMeters(result.ecartProbableDirectionM),
        ),
      ],
    );
  }

  String _formatMeters(num? value) {
    return value == null ? '—' : '${value.toStringAsFixed(1)} m';
  }

  String _shotTitle({
    required TirLineaireShot shot,
    required int index,
    required int total,
  }) {
    final salve = shot.numeroSalve;

    if (total == 1) {
      return salve == null
          ? 'Éléments de tir'
          : 'Éléments de tir • salve $salve';
    }

    return salve == null
        ? 'Tir ${index + 1}'
        : 'Tir ${index + 1} • salve $salve';
  }

  PieceGeom? _findPiece(Iterable<PieceGeom> pieces, String recipient) {
    for (final piece in pieces) {
      if (_normalisePieceId(piece.id) == recipient) {
        return piece;
      }
    }
    return null;
  }

  String _formatPieceCoordinates(PieceGeom piece) {
    final altitude =
        piece.z == null ? '' : '  Z=${piece.z!.toStringAsFixed(1)} m';
    return 'X=${piece.x.toStringAsFixed(1)}  Y=${piece.y.toStringAsFixed(1)}$altitude';
  }

  String _normalisePieceId(String value) => value.trim().toUpperCase();
}
