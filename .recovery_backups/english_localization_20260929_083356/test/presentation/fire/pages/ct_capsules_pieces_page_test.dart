// test/presentation/fire/pages/ct_capsules_pieces_page_test.dart
//
// Test volontairement limité au résolveur déjà utilisé par l'écran.
// L'écran lui-même reçoit un TirCompletOutput réel dans l'application.

import 'package:flutter_test/flutter_test.dart';

import 'package:calculateur_etranger/services/messages/ct_capsule_recipients_resolver.dart';

void main() {
  test('ordre affiché attendu pour plusieurs destinataires', () {
    const resolver = CtCapsuleRecipientsResolver();

    final recipients = resolver.resolvePieceIds(
      <String>['PS3', 'PS1', 'PD', 'PS2', 'PS1'],
    );

    expect(
      recipients,
      <String>['PD', 'PS1', 'PS2', 'PS3'],
    );
  });
}
