import 'package:calculateur_etranger/domain/fire/doctrine/zonal/hardcoded/zonal_hardcoded_doctrine_models.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/zonal/hardcoded/zonal_hardcoded_sequences.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/zonal/zonal_overflow_ratio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ZonalOverflowRatio', () {
    test('converts the UI percentage to the doctrine ratio', () {
      expect(ZonalOverflowRatio.fromPercentage(10), 0.10);
      expect(ZonalOverflowRatio.fromPercentage(10.0), 0.10);
    });

    test('preserves the historical default only for absent input', () {
      expect(
        ZonalOverflowRatio.fromPercentage(null),
        ZonalOverflowRatio.defaultRatio,
      );
    });
  });

  test('the 200×200 hardcoded OTAN profile receives the requested ratio', () {
    const ratio = 0.10;

    expect(
      ZonalHardcodedSequences.isSupported(
        width: 200,
        height: 200,
        debordementRatio: ratio,
      ),
      isTrue,
    );

    final sequence = ZonalHardcodedSequences.resolve(
      width: 200,
      height: 200,
      mode: ZonalDoctrineMode.otan,
      debordementRatio: ratio,
    );

    expect(sequence.totalPerRow, const [3, 2, 3]);
    expect(sequence.shots, hasLength(8));
  });
}
