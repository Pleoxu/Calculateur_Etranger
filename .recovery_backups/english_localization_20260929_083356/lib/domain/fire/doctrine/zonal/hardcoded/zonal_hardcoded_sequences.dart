import 'package:calculateur_etranger/domain/fire/doctrine/zonal/zonal_doctrine_engine.dart';

import 'zonal_hardcoded_doctrine_models.dart';

/// Profils zonaux stabilisés.
class ZonalHardcodedSequences {
  const ZonalHardcodedSequences._();

  // Paramètres doctrinaux de référence
  static const double _diametreEfficaceM = 100.0;
  static const double _debordementRatio = 0.05;
  static const double _recouvrementMini = 0.10;

  /// Retourne vrai si le format [width]×[height] est couvert par un profil
  /// hardcodé (nCols=3, nRows=3 ou nRows=4).
  static bool isSupported({
    required double width,
    required double height,
    double debordementRatio = _debordementRatio,
  }) {
    final geo = ZonalGeometry.compute(
      largeur: width,
      profondeur: height,
      debordementRatio: debordementRatio,
      recouvrementMini: _recouvrementMini,
      diametreEfficaceM: _diametreEfficaceM,
    );

    return geo.nCols == 3 && (geo.nRows == 3 || geo.nRows == 4);
  }

  static ZonalHardcodedSequence resolve({
    required double width,
    required double height,
    required ZonalDoctrineMode mode,
    ZonalOffsetVariant variant = ZonalOffsetVariant.reference,
    double debordementRatio = _debordementRatio,
  }) {
    final geo = ZonalGeometry.compute(
      largeur: width,
      profondeur: height,
      debordementRatio: debordementRatio,
      recouvrementMini: _recouvrementMini,
      diametreEfficaceM: _diametreEfficaceM,
    );

    if (geo.nCols == 3 && geo.nRows == 3) {
      return mode == ZonalDoctrineMode.otan
          ? _buildGrid3x3Otan(geo: geo, width: width, height: height)
          : _buildGrid3x3Force(geo: geo, width: width, height: height);
    }

    if (geo.nCols == 3 && geo.nRows == 4) {
      return mode == ZonalDoctrineMode.otan
          ? _buildGrid3x4Otan(geo: geo, width: width, height: height)
          : _buildGrid3x4Force(geo: geo, width: width, height: height);
    }

    throw UnsupportedError(
      'Aucun profil zonal stabilisé pour ${width}x$height '
      '(grille ${geo.nCols}×${geo.nRows}) en mode $mode.',
    );
  }

  static ZonalHardcodedSequence _buildGrid3x3Otan({
    required ZonalGeometry geo,
    required double width,
    required double height,
  }) {
    final r1y = geo.ys[0];
    final r2y = geo.ys[1];
    final r3y = geo.ys[2];

    return ZonalHardcodedSequence(
      code: 'ZONAL_${width.toInt()}x${height.toInt()}_OTAN',
      width: width,
      height: height,
      mode: ZonalDoctrineMode.otan,
      variant: ZonalOffsetVariant.reference,
      totalPerRow: const [3, 2, 3],
      salvo1PerRow: const [3, 2, 3],
      salvo2PerRow: const [0, 0, 0],
      shots: <ZonalHardcodedShot>[
        ZonalHardcodedShot(
          pieceCode: 'PS7',
          salvo: 1,
          row: 1,
          slot: 1,
          x: geo.xLeft,
          y: r1y,
          label: 'R1C1',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS6',
          salvo: 1,
          row: 1,
          slot: 2,
          x: geo.xCenter,
          y: r1y,
          label: 'R1C2',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS5',
          salvo: 1,
          row: 1,
          slot: 3,
          x: geo.xRight,
          y: r1y,
          label: 'R1C3',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PD',
          salvo: 1,
          row: 2,
          slot: 1,
          x: geo.xLeft,
          y: r2y,
          label: 'R2I1',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS1',
          salvo: 1,
          row: 2,
          slot: 2,
          x: geo.xRight,
          y: r2y,
          label: 'R2I2',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS2',
          salvo: 1,
          row: 3,
          slot: 1,
          x: geo.xLeft,
          y: r3y,
          label: 'R3C1',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS3',
          salvo: 1,
          row: 3,
          slot: 2,
          x: geo.xCenter,
          y: r3y,
          label: 'R3C2',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS4',
          salvo: 1,
          row: 3,
          slot: 3,
          x: geo.xRight,
          y: r3y,
          label: 'R3C3',
        ),
      ],
    );
  }

  static ZonalHardcodedSequence _buildGrid3x3Force({
    required ZonalGeometry geo,
    required double width,
    required double height,
  }) {
    final r1y = geo.ys[0];
    final r2y = geo.ys[1];
    final r3y = geo.ys[2];

    return ZonalHardcodedSequence(
      code: 'ZONAL_${width.toInt()}x${height.toInt()}_FORCE',
      width: width,
      height: height,
      mode: ZonalDoctrineMode.force,
      variant: ZonalOffsetVariant.reference,
      totalPerRow: const [3, 3, 3],
      salvo1PerRow: const [3, 2, 3],
      salvo2PerRow: const [0, 1, 0],
      shots: <ZonalHardcodedShot>[
        ZonalHardcodedShot(
          pieceCode: 'PS7',
          salvo: 1,
          row: 1,
          slot: 1,
          x: geo.xLeft,
          y: r1y,
          label: 'R1C1',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS6',
          salvo: 1,
          row: 1,
          slot: 2,
          x: geo.xCenter,
          y: r1y,
          label: 'R1C2',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS5',
          salvo: 1,
          row: 1,
          slot: 3,
          x: geo.xRight,
          y: r1y,
          label: 'R1C3',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PD',
          salvo: 1,
          row: 2,
          slot: 1,
          x: geo.xLeft,
          y: r2y,
          label: 'R2I1',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS1',
          salvo: 1,
          row: 2,
          slot: 2,
          x: geo.xRight,
          y: r2y,
          label: 'R2I2',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS2',
          salvo: 1,
          row: 3,
          slot: 1,
          x: geo.xLeft,
          y: r3y,
          label: 'R3C1',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS3',
          salvo: 1,
          row: 3,
          slot: 2,
          x: geo.xCenter,
          y: r3y,
          label: 'R3C2',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS4',
          salvo: 1,
          row: 3,
          slot: 3,
          x: geo.xRight,
          y: r3y,
          label: 'R3C3',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PD',
          salvo: 2,
          row: 2,
          slot: 3,
          x: geo.xCenter,
          y: r2y,
          label: 'R2C2',
        ),
      ],
    );
  }

  static ZonalHardcodedSequence _buildGrid3x4Otan({
    required ZonalGeometry geo,
    required double width,
    required double height,
  }) {
    const double yMid = 0.0;

    return ZonalHardcodedSequence(
      code: 'ZONAL_${width.toInt()}x${height.toInt()}_OTAN',
      width: width,
      height: height,
      mode: ZonalDoctrineMode.otan,
      variant: ZonalOffsetVariant.reference,
      totalPerRow: const [2, 2, 2, 2],
      salvo1PerRow: const [2, 2, 2, 2],
      salvo2PerRow: const [0, 1, 1, 0],
      shots: <ZonalHardcodedShot>[
        ZonalHardcodedShot(
          pieceCode: 'PD',
          salvo: 1,
          row: 1,
          slot: 1,
          x: geo.xLeft,
          y: geo.ys[0],
          label: 'C1R1',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS5',
          salvo: 1,
          row: 2,
          slot: 1,
          x: geo.xLeftInner,
          y: geo.ys[1],
          label: 'C1R2',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS6',
          salvo: 1,
          row: 3,
          slot: 1,
          x: geo.xLeftInner,
          y: geo.ys[2],
          label: 'C1R3',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS7',
          salvo: 1,
          row: 4,
          slot: 1,
          x: geo.xLeft,
          y: geo.ys[3],
          label: 'C1R4',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS1',
          salvo: 1,
          row: 1,
          slot: 3,
          x: geo.xRight,
          y: geo.ys[0],
          label: 'C3R1',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS2',
          salvo: 1,
          row: 2,
          slot: 3,
          x: geo.xRightInner,
          y: geo.ys[1],
          label: 'C3R2',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS3',
          salvo: 1,
          row: 3,
          slot: 3,
          x: geo.xRightInner,
          y: geo.ys[2],
          label: 'C3R3',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS4',
          salvo: 1,
          row: 4,
          slot: 3,
          x: geo.xRight,
          y: geo.ys[3],
          label: 'C3R4',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PD',
          salvo: 2,
          row: 2,
          slot: 2,
          x: geo.xLeftInner,
          y: yMid,
          label: 'MIDL',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS1',
          salvo: 2,
          row: 3,
          slot: 2,
          x: geo.xRightInner,
          y: yMid,
          label: 'MIDR',
        ),
      ],
    );
  }

  static ZonalHardcodedSequence _buildGrid3x4Force({
    required ZonalGeometry geo,
    required double width,
    required double height,
  }) {
    return ZonalHardcodedSequence(
      code: 'ZONAL_${width.toInt()}x${height.toInt()}_FORCE',
      width: width,
      height: height,
      mode: ZonalDoctrineMode.force,
      variant: ZonalOffsetVariant.reference,
      totalPerRow: const [3, 3, 3, 3],
      salvo1PerRow: const [2, 2, 2, 2],
      salvo2PerRow: const [1, 1, 1, 1],
      shots: <ZonalHardcodedShot>[
        ZonalHardcodedShot(
          pieceCode: 'PD',
          salvo: 1,
          row: 1,
          slot: 1,
          x: geo.xLeft,
          y: geo.ys[0],
          label: 'C1R1',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS5',
          salvo: 1,
          row: 2,
          slot: 1,
          x: geo.xLeft,
          y: geo.ys[1],
          label: 'C1R2',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS6',
          salvo: 1,
          row: 3,
          slot: 1,
          x: geo.xLeft,
          y: geo.ys[2],
          label: 'C1R3',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS7',
          salvo: 1,
          row: 4,
          slot: 1,
          x: geo.xLeft,
          y: geo.ys[3],
          label: 'C1R4',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS1',
          salvo: 1,
          row: 1,
          slot: 3,
          x: geo.xRight,
          y: geo.ys[0],
          label: 'C3R1',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS2',
          salvo: 1,
          row: 2,
          slot: 3,
          x: geo.xRight,
          y: geo.ys[1],
          label: 'C3R2',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS3',
          salvo: 1,
          row: 3,
          slot: 3,
          x: geo.xRight,
          y: geo.ys[2],
          label: 'C3R3',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS4',
          salvo: 1,
          row: 4,
          slot: 3,
          x: geo.xRight,
          y: geo.ys[3],
          label: 'C3R4',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PD',
          salvo: 2,
          row: 1,
          slot: 2,
          x: geo.xCenter,
          y: geo.ys[0],
          label: 'C2R1',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS5',
          salvo: 2,
          row: 2,
          slot: 2,
          x: geo.xCenter,
          y: geo.ys[1],
          label: 'C2R2',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS1',
          salvo: 2,
          row: 3,
          slot: 2,
          x: geo.xCenter,
          y: geo.ys[2],
          label: 'C2R3',
        ),
        ZonalHardcodedShot(
          pieceCode: 'PS2',
          salvo: 2,
          row: 4,
          slot: 2,
          x: geo.xCenter,
          y: geo.ys[3],
          label: 'C2R4',
        ),
      ],
    );
  }
}
