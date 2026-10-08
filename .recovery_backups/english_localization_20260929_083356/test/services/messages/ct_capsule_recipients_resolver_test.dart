// test/services/messages/ct_capsule_recipients_resolver_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:calculateur_etranger/services/messages/ct_capsule_recipients_resolver.dart';

void main() {
  const resolver = CtCapsuleRecipientsResolver();

  group('CtCapsuleRecipientsResolver', () {
    test('PD seule', () {
      expect(
        resolver.resolvePieceIds(<String>['PD']),
        <String>['PD'],
      );
    });

    test('ponctuel ou linéaire: pièces réellement présentes seulement', () {
      expect(
        resolver.resolvePieceIds(
          <String>['PS2', 'PD', 'PS1'],
        ),
        <String>['PD', 'PS1', 'PS2'],
      );
    });

    test('zonal: déduplique les pièces présentes dans plusieurs salves', () {
      expect(
        resolver.resolvePieceIds(
          <String>[
            'PS5',
            'PD',
            'PS1',
            'PS2',
            'PS3',
            'PS4',
            'PD',
            'PS1',
            'PS3',
            'PS4',
          ],
        ),
        <String>['PD', 'PS1', 'PS2', 'PS3', 'PS4', 'PS5'],
      );
    });

    test('normalise casse et espaces', () {
      expect(
        resolver.resolvePieceIds(
          <String>[' ps2 ', 'pd', 'PS1', '', '  '],
        ),
        <String>['PD', 'PS1', 'PS2'],
      );
    });

    test('trie correctement PS2 avant PS10', () {
      expect(
        resolver.resolvePieceIds(
          <String>['PS10', 'PS2', 'PD', 'PS1'],
        ),
        <String>['PD', 'PS1', 'PS2', 'PS10'],
      );
    });
  });
}
