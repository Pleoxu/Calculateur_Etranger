// test/services/messages/ct_piece_display_payload_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:calculateur_etranger/services/messages/ct_piece_display_payload.dart';

void main() {
  test('round-trip generic piece display payload', () {
    const original = CtPieceDisplayPayload(
      title: 'PS1',
      sections: <CtPieceDisplaySection>[
        CtPieceDisplaySection(
          title: 'Identification',
          fields: <CtPieceDisplayField>[
            CtPieceDisplayField(label: 'Gun', value: 'PS1'),
            CtPieceDisplayField(label: 'Statut', value: 'Prepared'),
          ],
        ),
        CtPieceDisplaySection(
          title: 'Informations',
          fields: <CtPieceDisplayField>[
            CtPieceDisplayField(label: 'Element A', value: 'Test value'),
            CtPieceDisplayField(label: 'Element B', value: '123'),
          ],
        ),
      ],
    );

    final decoded = CtPieceDisplayPayload.fromBytes(original.toBytes());

    expect(decoded.title, 'PS1');
    expect(decoded.sections.length, 2);
    expect(decoded.sections.first.fields.first.value, 'PS1');
    expect(decoded.sections.last.fields.last.value, '123');
  });
}
