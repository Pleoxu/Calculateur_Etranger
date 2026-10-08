import 'package:calculateur_etranger/domain/fire/services/ballistic_asset_context.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes caesarExport as the existing CAESAR ballistic family', () {
    expect(isCaesarSystemName('caesar'), isTrue);
    expect(isCaesarSystemName('caesarExport'), isTrue);
    expect(isCaesarSystemName('mo81M252'), isFalse);
  });

  test('preserves the selected CAESAR article asset variant', () {
    final context = BallisticAssetContext(
      systeme: Systeme.caesar,
      typeTir: TypeTir.appui,
      typeMunition: TypeMunition.oeF5Fr,
    );

    expect(context.isCaesar, isTrue);
    expect(context.variant, 'APPUI_ART390');
  });
}
