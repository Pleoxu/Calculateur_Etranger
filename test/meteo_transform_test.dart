import 'package:flutter_test/flutter_test.dart';
import 'package:calculateur_etranger/domain/meteo/metcm_to_metb_transformer.dart';

void main() {
  test('METCM → METB: returns expected first METB line for a simple case', () {
    // On construit uniquement les couches nécessaires :
    // METCM 01 (0-200), METCM 02 (200-500) etc. La ligne 00 est volontairement exclue par l’algo.
    final layers = <MetcmLayer>[
      MetcmLayer(
        lineNumber: 1,
        altitudeBas: 0,
        altitudeHaut: 200,
        directionDeg: 0,
        directionMils: 0,
        vitesse: 0,
        temperature: 287.5,
        pression: 1001,
      ),
      MetcmLayer(
        lineNumber: 2,
        altitudeBas: 200,
        altitudeHaut: 500,
        directionDeg: 0,
        directionMils: 0,
        vitesse: 0,
        temperature: 285.9,
        pression: 972,
      ),
      MetcmLayer(
        lineNumber: 3,
        altitudeBas: 500,
        altitudeHaut: 1000,
        directionDeg: 0,
        directionMils: 0,
        vitesse: 0,
        temperature: 283.3,
        pression: 926,
      ),
    ];

    final metb = MeteoTransformer.transform(layers, verbose: false);

    // On vérifie juste que ça sort bien la ligne 00 (et qu’elle est cohérente)
    // (Selon ta logique : METB 00 se base sur METCM 01)
    final l00 = metb.firstWhere((e) => e.lineNumber == 0);
    expect(l00.vitesse, 0);
    expect(l00.directionMils, 0);

    // Temp/Press permil doivent être proches de 1000 (ISA near sea level).
    expect(l00.densiteTemp, inInclusiveRange(990, 1010));
    expect(l00.densitePression, inInclusiveRange(970, 1030));
  });
}
