import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import 'package:calculateur_etranger/domain/fire/allocation/zonal/zonal_shot_assignment.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/zonal/hardcoded/zonal_hardcoded_doctrine_models.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';

class ZonalDoctrineEngine {
  const ZonalDoctrineEngine._();

  static List<ZonalShotAssignment> computeAssignments({
    required double largeur,
    required double profondeur,
    required List<PieceGeom> pieces,
    required int coups,
    required double prX,
    required double prY,
    required double azimutLargeurMil,
    required double azimutTirMil,
    required double debordementRatio,
    required double recouvrementMini,
    required double diametreEfficaceM,
    required ZonalDoctrineMode mode,
  }) {
    if (pieces.isEmpty || coups <= 0 || largeur <= 0 || profondeur <= 0) {
      return const <ZonalShotAssignment>[];
    }

    final geo = ZonalGeometry.compute(
      largeur: largeur,
      profondeur: profondeur,
      debordementRatio: debordementRatio,
      recouvrementMini: recouvrementMini,
      diametreEfficaceM: diametreEfficaceM,
    );

    final doctrinalSlots = _buildSlots(geo: geo, mode: mode);
    final slots = doctrinalSlots.take(coups).toList(growable: false);

    debugPrint(
      '[ZONAL-SLOTS] '
      'is5x6=${geo.is5x6} '
      'is3x6=${geo.is3x6} '
      'mode=$mode '
      'doctrinal=${doctrinalSlots.length} '
      'rounds=$coups '
      'slots=${slots.length}',
    );

    if (slots.isEmpty) {
      return const <ZonalShotAssignment>[];
    }

    final uLargeur = _unitFromAzMil(azimutLargeurMil);
    final uTir = _unitFromAzMil(azimutTirMil);

    final slotsWithUtm = slots.map((s) {
      final utmE = prX + s.position.dx * uLargeur.dx + s.position.dy * uTir.dx;
      final utmN = prY + s.position.dx * uLargeur.dy + s.position.dy * uTir.dy;
      return _SlotWithUtm(slot: s, utmE: utmE, utmN: utmN);
    }).toList();

    final pieceIds = geo.is3x6
        ? _assignUniquePerSalve(
            pieces: pieces,
            slotsWithUtm: slotsWithUtm,
            prX: prX,
            prY: prY,
          )
        : _assignMonge(
            pieces: pieces,
            slotsWithUtm: slotsWithUtm,
            prX: prX,
            prY: prY,
          );

    return [
      for (var i = 0; i < slots.length; i++)
        ZonalShotAssignment(
          pieceId: pieceIds[i],
          ordre: slots[i].ordre,
          salve: slots[i].salve,
          position: slots[i].position,
          point: ZonalIndexedPoint(
            row: slots[i].row,
            col: slots[i].col,
            offsetM: math.sqrt(
              slots[i].position.dx * slots[i].position.dx +
                  slots[i].position.dy * slots[i].position.dy,
            ),
            x: slots[i].position.dx,
            y: slots[i].position.dy,
          ),
        ),
    ];
  }

  static List<_DoctrineSlot> _buildSlots({
    required ZonalGeometry geo,
    required ZonalDoctrineMode mode,
  }) {
    // Doctrine ÉCLAIRANT :
    // le diamètre efficace vaut 600 m (rayon 300 m). Dans ce cas, on ne doit
    // pas appliquer l'économie OTAN HE, sinon le plan peut demander 8 coups
    // tout en ne générant que 7 offsets. On force donc la grille complète.
    final isEclairant = geo.diametreEfficaceM >= 600.0;

    if (geo.is3x6) {
      return (!isEclairant && mode == ZonalDoctrineMode.otan)
          ? _build3x6OtanSlots(geo: geo)
          : _build3x8ForcedSlots(geo: geo);
    }

    if (geo.is5x6) {
      return (!isEclairant && mode == ZonalDoctrineMode.otan)
          ? _build5x6OtanSlots(geo: geo)
          : _build5x6ForcedSlots(geo: geo);
    }

    if (geo.is5x5) {
      return (!isEclairant && mode == ZonalDoctrineMode.otan)
          ? _build5x5OtanSlots(geo: geo)
          : _build5x5ForcedSlots(geo: geo);
    }

    if (geo.is4x5) {
      return (!isEclairant && mode == ZonalDoctrineMode.otan)
          ? _build4x5OtanSlots(geo: geo)
          : _build4x5ForcedSlots(geo: geo);
    }

    if (geo.isSquare4x4) {
      return (!isEclairant && mode == ZonalDoctrineMode.otan)
          ? _buildSquare4x4OtanSlots(geo: geo)
          : _buildSquare4x4ForcedSlots(geo: geo);
    }

    if (geo.nCols == 3) {
      if (!isEclairant &&
          mode == ZonalDoctrineMode.otan &&
          geo.otanApplicable) {
        return _buildOtanSlots(geo: geo);
      }

      return _buildForcedSlots(geo: geo);
    }

    // Repli générique pour une grille ne correspondant à aucun preset :
    // matrice complète, sans économie OTAN implicite.
    return _buildGenericMatrixSlots(geo: geo);
  }

  static List<_DoctrineSlot> _buildGenericMatrixSlots({
    required ZonalGeometry geo,
  }) {
    final xs = _axisCenters(
      first: geo.xLeft,
      last: geo.xRight,
      count: geo.nCols,
    );
    final ys = geo.ys;

    final out = <_DoctrineSlot>[];
    var ordre = 1;

    for (var row = 0; row < ys.length; row++) {
      for (var col = 0; col < xs.length; col++) {
        final currentOrdre = ordre++;
        out.add(
          _DoctrineSlot(
            row: row,
            col: col,
            ordre: currentOrdre,
            salve: ((currentOrdre - 1) ~/ 8) + 1,
            position: Offset(xs[col], ys[row]),
          ),
        );
      }
    }

    return out;
  }

  static List<double> _axisCenters({
    required double first,
    required double last,
    required int count,
  }) {
    if (count <= 1) return const <double>[0.0];

    final step = (last - first) / (count - 1);
    return <double>[for (var i = 0; i < count; i++) first + i * step];
  }

  static List<_DoctrineSlot> _build3x6OtanSlots({required ZonalGeometry geo}) {
    final out = <_DoctrineSlot>[];

    // Doctrine OTAN 300×500.
    //
    // Règle métier figée : EXTÉRIEUR -> INTÉRIEUR.
    // Ce cas est volontairement matriciel : on ne le génère PAS par balayage.
    //
    // Grille virtuelle OTAN 7 colonnes × 6 rangées :
    //   R1 : C1 C3 C5 C7 -> S1
    //   R2 : C2 C4 C6    -> S2 S3 S2
    //   R3 : C2 C4 C6    -> S2 S3 S2
    //   R4 : C2 C4 C6    -> S2 S3 S2
    //   R5 : C2 C4 C6    -> S2 S3 S2
    //   R6 : C1 C3 C5 C7 -> S1
    //
    // Total : 8 + 8 + 4 = 20 coups.
    // Important : les colonnes sont réparties sur le zonal étendu.
    // Les rangs R1/R6 ne doivent pas former une chaîne de tangences,
    // et les rangs R2/R5 ne prennent qu'un seul centre C4.
    final xs = _sevenColumns300x500Otan(geo);
    final ys = _sixRows300x500(geo);
    var ordre = 1;

    void add({required int row, required int col, required int salve}) {
      if (row < 0 || row >= ys.length) return;
      if (col < 0 || col >= xs.length) return;

      out.add(
        _DoctrineSlot(
          row: row,
          col: col,
          ordre: ordre++,
          salve: salve,
          position: Offset(xs[col], ys[row]),
        ),
      );
    }

    // S1 — fermeture extérieure horizontale : R1 + R6.
    for (final col in [0, 2, 4, 6]) {
      add(row: 0, col: col, salve: 1);
    }
    for (final col in [0, 2, 4, 6]) {
      add(row: 5, col: col, salve: 1);
    }

    // S2 — fermeture extérieure verticale : C2 + C6 sur R2 à R5.
    for (final row in [1, 2, 3, 4]) {
      add(row: row, col: 1, salve: 2);
      add(row: row, col: 5, salve: 2);
    }

    // S3 — remplissage intérieur OTAN : colonne centrale C4 sur R2 à R5.
    for (final row in [1, 2, 3, 4]) {
      add(row: row, col: 3, salve: 3);
    }

    out.sort((a, b) {
      final bySalve = a.salve.compareTo(b.salve);
      if (bySalve != 0) return bySalve;
      return a.ordre.compareTo(b.ordre);
    });

    return out;
  }

  static List<_DoctrineSlot> _build3x8ForcedSlots({
    required ZonalGeometry geo,
  }) {
    final out = <_DoctrineSlot>[];

    // Doctrine forcée 300×500 / 24 coups.
    //
    // Grille complète 4 × 6, toujours en logique EXTÉRIEUR -> INTÉRIEUR :
    //   S1 : R1 et R6 complets = 8 coups.
    //   S2 : colonnes extérieures R2 à R5 = 8 coups.
    //   S3 : colonnes intérieures R2 à R5 = 8 coups.
    //
    // Total : 8 + 8 + 8 = 24 coups.
    final xs = _fourColumns300x500(geo);
    final ys = _sixRows300x500(geo);
    var ordre = 1;

    void add({required int row, required int col, required int salve}) {
      if (row < 0 || row >= ys.length) return;
      if (col < 0 || col >= xs.length) return;

      out.add(
        _DoctrineSlot(
          row: row,
          col: col * 2,
          ordre: ordre++,
          salve: salve,
          position: Offset(xs[col], ys[row]),
        ),
      );
    }

    // S1 — fermeture extérieure horizontale : R1 + R6.
    for (final col in [0, 1, 2, 3]) {
      add(row: 0, col: col, salve: 1);
    }
    for (final col in [0, 1, 2, 3]) {
      add(row: 5, col: col, salve: 1);
    }

    // S2 — fermeture extérieure verticale : C1 + C4 sur R2 à R5.
    for (final row in [1, 2, 3, 4]) {
      add(row: row, col: 0, salve: 2);
      add(row: row, col: 3, salve: 2);
    }

    // S3 — remplissage intérieur forcé : C2 + C3 sur R2 à R5.
    for (final row in [1, 2, 3, 4]) {
      add(row: row, col: 1, salve: 3);
      add(row: row, col: 2, salve: 3);
    }

    out.sort((a, b) {
      final bySalve = a.salve.compareTo(b.salve);
      if (bySalve != 0) return bySalve;
      return a.ordre.compareTo(b.ordre);
    });

    return out;
  }

  static List<double> _sevenColumns300x500Otan(ZonalGeometry geo) {
    // 300×500 OTAN.
    // R1/R6 utilisent C1 C3 C5 C7 sur le zonal étendu.
    // R2→R5 utilisent C2 C4 C6, avec tangence horizontale.
    //
    // Avec D=100m, r=50m :
    // C2/C4/C6 doivent être à -100 / 0 / +100
    // pour que les 3 coups soient tangents et couvrent les 300m.

    final r = geo.diametreEfficaceM / 2.0;

    return <double>[
      geo.xLeft, // C1
      -2.0 * r, // C2
      geo.xLeft / 3, // C3 intermédiaire extérieur haut/bas
      0.0, // C4
      geo.xRight / 3, // C5 intermédiaire extérieur haut/bas
      2.0 * r, // C6
      geo.xRight, // C7
    ];
  }

  static List<double> _fourColumns300x500(ZonalGeometry geo) {
    // Mode forcé 300×500 : 4 colonnes réparties sur le zonal étendu.
    final step = (geo.xRight - geo.xLeft) / 3.0;
    return <double>[geo.xLeft, geo.xLeft + step, geo.xRight - step, geo.xRight];
  }

  static List<double> _sixRows300x500(ZonalGeometry geo) {
    // Doctrine 300×500 :
    // - R1/R6 conservent les extrêmes.
    // - R2→R5 sont répartis régulièrement sur la profondeur.
    // - La tangence doctrinale se fait sur la rangée, pas entre rangées.

    final top = geo.ys.isNotEmpty ? geo.ys.first : -250.0;
    final bottom = geo.ys.isNotEmpty ? geo.ys.last : 250.0;
    final span = bottom - top;

    return <double>[
      top, // R1
      top + span * 0.20, // R2
      top + span * 0.40, // R3
      top + span * 0.60, // R4
      top + span * 0.80, // R5
      bottom, // R6
    ];
  }

  static List<_DoctrineSlot> _build5x6ForcedSlots({
    required ZonalGeometry geo,
  }) {
    final out = <_DoctrineSlot>[];
    var ordre = 1;

    // Mode forcé 400×500 : grille complète 5 × 6 = 30 coups.
    // L'ordre est doctrinal : il couvre d'abord le périmètre et les oppositions,
    // puis complète l'intérieur. Cela évite les salves rangée-par-rangée qui
    // concentraient les coups sur une seule partie du zonal.
    final xs = _fiveClassicColumns(geo);
    final ys = _sixRows(geo);

    void add({required int row, required int col, required int salve}) {
      out.add(
        _DoctrineSlot(
          row: row,
          col: col * 2,
          ordre: ordre++,
          salve: salve,
          position: Offset(xs[col], ys[row]),
        ),
      );
    }

    // S1 : ouverture largeur R1/R6 + opposition profondeur.
    for (final cell in [
      [0, 0],
      [0, 2],
      [0, 4],
      [5, 0],
      [5, 2],
      [5, 4],
      [2, 0],
      [3, 4],
    ]) {
      add(row: cell[0], col: cell[1], salve: 1);
    }

    // S2 : fermeture des rangées R2/R5 + opposition inverse.
    for (final cell in [
      [1, 0],
      [1, 2],
      [1, 4],
      [4, 0],
      [4, 2],
      [4, 4],
      [2, 4],
      [3, 0],
    ]) {
      add(row: cell[0], col: cell[1], salve: 2);
    }

    // S3 : complément des rangées extérieures et intérieur latéral.
    for (final cell in [
      [0, 1],
      [0, 3],
      [5, 1],
      [5, 3],
      [2, 1],
      [2, 3],
      [3, 1],
      [3, 3],
    ]) {
      add(row: cell[0], col: cell[1], salve: 3);
    }

    // S4 : six coups centraux restants.
    for (final cell in [
      [1, 1],
      [1, 3],
      [4, 1],
      [4, 3],
      [2, 2],
      [3, 2],
    ]) {
      add(row: cell[0], col: cell[1], salve: 4);
    }

    out.sort((a, b) {
      final bySalve = a.salve.compareTo(b.salve);
      if (bySalve != 0) return bySalve;
      return a.ordre.compareTo(b.ordre);
    });

    return out;
  }

  static List<_DoctrineSlot> _build5x6OtanSlots({required ZonalGeometry geo}) {
    final out = <_DoctrineSlot>[];

    final ys = _sixRows(geo);

    double xForCell(int row, int col) {
      // Doctrine 400×500 / 5×6 : géométrie hybride volontaire.
      //
      // R1 et R6 restent sur la doctrine de recouvrement minimum avec
      // débordement : les centres extérieurs sont à r du périmètre théorique
      // du zonal étendu. Avec L=400, débord=5%, D=100 :
      // x = -160, -80, 0, +80, +160.
      //
      // R2 à R5 n'ont PAS de débordement latéral : les 4 cercles doivent
      // s'inscrire dans les 400 m nominaux et être tangents :
      // x = -150, -50, +50, +150.
      if (geo.is5x6) {
        final isOuterRow = row == 0 || row == 5;
        if (isOuterRow) {
          final classic = _fiveClassicColumns(geo);
          switch (col) {
            case 0:
              return classic[0];
            case 2:
              return classic[1];
            case 4:
              return classic[2];
            case 6:
              return classic[3];
            case 8:
              return classic[4];
          }
        } else {
          final step = geo.largeurM / 4.0;
          switch (col) {
            case 1:
              return -1.5 * step;
            case 3:
              return -0.5 * step;
            case 5:
              return 0.5 * step;
            case 7:
              return 1.5 * step;
          }
        }
      }

      // Fallback générique : grille virtuelle 9 colonnes.
      final xs = _nineTangentColumns(geo);
      return xs[col.clamp(0, xs.length - 1)];
    }

    void add({
      required int row,
      required int col,
      required int salve,
      required int ordre,
    }) {
      if (row < 0 || row >= ys.length) return;
      if (col < 0 || col > 8) return;

      out.add(
        _DoctrineSlot(
          row: row,
          col: col,
          ordre: ordre,
          salve: salve,
          position: Offset(xForCell(row, col), ys[row]),
        ),
      );
    }

    // Doctrine OTAN 400×500 / 26 coups.
    //
    // Grille virtuelle :
    // - R1/R6 : C1 C3 C5 C7 C9 sur le zonal étendu.
    // - R2 à R5 : C2 C4 C6 C8 tangents dans les 400 m nominaux.
    //
    // Salve 1 : validée.
    // Salve 2 : fermeture du zonal par les côtés en profondeur
    //            (6 coups sur C2/C8) + opposition R1/R6.
    // Salve 3 : complément R1/R6 en opposition et remplissage du centre.
    // Salve 4 : deux offsets centraux restants.

    // S1 — 8 coups.
    add(row: 0, col: 0, salve: 1, ordre: 1); // R1 C1
    add(row: 0, col: 4, salve: 1, ordre: 2); // R1 C5
    add(row: 0, col: 8, salve: 1, ordre: 3); // R1 C9
    add(row: 2, col: 1, salve: 1, ordre: 4); // R3 C2
    add(row: 3, col: 7, salve: 1, ordre: 5); // R4 C8
    add(row: 5, col: 0, salve: 1, ordre: 6); // R6 C1
    add(row: 5, col: 4, salve: 1, ordre: 7); // R6 C5
    add(row: 5, col: 8, salve: 1, ordre: 8); // R6 C9

    // S2 — 8 coups.
    add(row: 0, col: 2, salve: 2, ordre: 9); // R1 C3
    add(row: 1, col: 1, salve: 2, ordre: 10); // R2 C2
    add(row: 1, col: 7, salve: 2, ordre: 11); // R2 C8
    add(row: 2, col: 7, salve: 2, ordre: 12); // R3 C8
    add(row: 3, col: 1, salve: 2, ordre: 13); // R4 C2
    add(row: 4, col: 1, salve: 2, ordre: 14); // R5 C2
    add(row: 4, col: 7, salve: 2, ordre: 15); // R5 C8
    add(row: 5, col: 6, salve: 2, ordre: 16); // R6 C7

    // S3 — 8 coups.
    add(row: 0, col: 6, salve: 3, ordre: 17); // R1 C7
    add(row: 1, col: 3, salve: 3, ordre: 18); // R2 C4
    add(row: 1, col: 5, salve: 3, ordre: 19); // R2 C6
    add(row: 2, col: 3, salve: 3, ordre: 20); // R3 C4
    add(row: 3, col: 5, salve: 3, ordre: 21); // R4 C6
    add(row: 4, col: 3, salve: 3, ordre: 22); // R5 C4
    add(row: 4, col: 5, salve: 3, ordre: 23); // R5 C6
    add(row: 5, col: 2, salve: 3, ordre: 24); // R6 C3

    // S4 — 2 coups.
    add(row: 2, col: 5, salve: 4, ordre: 25); // R3 C6
    add(row: 3, col: 3, salve: 4, ordre: 26); // R4 C4

    out.sort((a, b) {
      final bySalve = a.salve.compareTo(b.salve);
      if (bySalve != 0) return bySalve;
      return a.ordre.compareTo(b.ordre);
    });

    return out;
  }

  static List<double> _fiveClassicColumns(ZonalGeometry geo) {
    final step = (geo.xRight - geo.xLeft) / 4.0;

    return <double>[
      geo.xLeft,
      geo.xLeft + step,
      geo.xCenter,
      geo.xRight - step,
      geo.xRight,
    ];
  }

  static List<double> _nineTangentColumns(ZonalGeometry geo) {
    final classic = _fiveClassicColumns(geo);

    return <double>[
      classic[0],
      (classic[0] + classic[1]) / 2.0,
      classic[1],
      (classic[1] + classic[2]) / 2.0,
      classic[2],
      (classic[2] + classic[3]) / 2.0,
      classic[3],
      (classic[3] + classic[4]) / 2.0,
      classic[4],
    ];
  }

  static List<double> _sixRows(ZonalGeometry geo) {
    if (geo.ys.length == 6) {
      return geo.ys;
    }

    final top = geo.ys.isNotEmpty ? geo.ys.first : -250.0;
    final bottom = geo.ys.isNotEmpty ? geo.ys.last : 250.0;
    final step = (bottom - top) / 5.0;

    return <double>[for (var i = 0; i < 6; i++) top + i * step];
  }

  static List<_DoctrineSlot> _build5x5ForcedSlots({
    required ZonalGeometry geo,
  }) {
    final out = <_DoctrineSlot>[];
    var ordre = 1;

    final pas5 = (geo.xRight - geo.xLeft) / 4.0;
    final c1 = geo.xLeft;
    final c2 = geo.xLeft + pas5;
    final c3 = 0.0;
    final c4 = geo.xRight - pas5;
    final c5 = geo.xRight;

    final r1 = geo.ys[0];
    final r2 = geo.ys[1];
    final r3 = geo.ys[2];
    final r4 = geo.ys[3];
    final r5 = geo.ys[4];

    for (final pos in [
      Offset(c1, r1),
      Offset(c3, r1),
      Offset(c5, r1),
      Offset(c1, r3),
      Offset(c5, r3),
      Offset(c1, r5),
      Offset(c3, r5),
      Offset(c5, r5),
    ]) {
      out.add(
        _DoctrineSlot(row: 0, col: 0, ordre: ordre++, salve: 1, position: pos),
      );
    }

    for (final pos in [
      Offset(c2, r1),
      Offset(c4, r1),
      Offset(c1, r2),
      Offset(c5, r2),
      Offset(c1, r4),
      Offset(c5, r4),
      Offset(c2, r5),
      Offset(c4, r5),
    ]) {
      out.add(
        _DoctrineSlot(row: 0, col: 0, ordre: ordre++, salve: 2, position: pos),
      );
    }

    for (final pos in [
      Offset(c2, r2),
      Offset(c3, r2),
      Offset(c4, r2),
      Offset(c2, r3),
      Offset(c4, r3),
      Offset(c2, r4),
      Offset(c3, r4),
      Offset(c4, r4),
    ]) {
      out.add(
        _DoctrineSlot(row: 0, col: 0, ordre: ordre++, salve: 3, position: pos),
      );
    }

    out.add(
      _DoctrineSlot(
        row: 0,
        col: 0,
        ordre: ordre++,
        salve: 4,
        position: Offset(c3, r3),
      ),
    );

    return out;
  }

  static List<_DoctrineSlot> _build5x5OtanSlots({required ZonalGeometry geo}) {
    final out = <_DoctrineSlot>[];
    var ordre = 1;
    final r = geo.diametreEfficaceM / 2.0;

    final pas5 = (geo.xRight - geo.xLeft) / 4.0;
    final c1 = geo.xLeft;
    final c2 = geo.xLeft + pas5;
    final c3 = 0.0;
    final c4 = geo.xRight - pas5;
    final c5 = geo.xRight;

    final coExt = math.min(3.0 * r, geo.xRight);
    final co1 = -coExt;
    final co2 = -r;
    final co3 = r;
    final co4 = coExt;

    final r1 = geo.ys[0];
    final r2 = geo.ys[1];
    final r3 = geo.ys[2];
    final r4 = geo.ys[3];
    final r5 = geo.ys[4];

    for (final pos in [
      Offset(c1, r1),
      Offset(c3, r1),
      Offset(c5, r1),
      Offset(c1, r3),
      Offset(c5, r3),
      Offset(c1, r5),
      Offset(c3, r5),
      Offset(c5, r5),
    ]) {
      out.add(
        _DoctrineSlot(row: 0, col: 0, ordre: ordre++, salve: 1, position: pos),
      );
    }

    for (final pos in [
      Offset(c2, r1),
      Offset(c4, r1),
      Offset(co1, r2),
      Offset(co4, r2),
      Offset(co1, r4),
      Offset(co4, r4),
      Offset(c2, r5),
      Offset(c4, r5),
    ]) {
      out.add(
        _DoctrineSlot(row: 0, col: 0, ordre: ordre++, salve: 2, position: pos),
      );
    }

    for (final pos in [
      Offset(co2, r2),
      Offset(co3, r2),
      Offset(c2, r3),
      Offset(c3, r3),
      Offset(c4, r3),
      Offset(co2, r4),
      Offset(co3, r4),
    ]) {
      out.add(
        _DoctrineSlot(row: 0, col: 0, ordre: ordre++, salve: 3, position: pos),
      );
    }

    return out;
  }

  static List<_DoctrineSlot> _build4x5ForcedSlots({
    required ZonalGeometry geo,
  }) {
    final out = <_DoctrineSlot>[];
    var ordre = 1;

    final pas4 = (geo.xRight - geo.xLeft) / 3.0;
    final cols = [
      geo.xLeft,
      geo.xLeft + pas4,
      geo.xLeft + 2.0 * pas4,
      geo.xRight,
    ];

    final r1 = geo.ys[0];
    final r2 = geo.ys[1];
    final r3 = geo.ys[2];
    final r4 = geo.ys[3];
    final r5 = geo.ys[4];

    for (final x in cols) {
      out.add(
        _DoctrineSlot(
          row: 0,
          col: 0,
          ordre: ordre++,
          salve: 1,
          position: Offset(x, r1),
        ),
      );
    }
    for (final x in cols) {
      out.add(
        _DoctrineSlot(
          row: 0,
          col: 0,
          ordre: ordre++,
          salve: 1,
          position: Offset(x, r5),
        ),
      );
    }

    for (final x in cols) {
      out.add(
        _DoctrineSlot(
          row: 0,
          col: 0,
          ordre: ordre++,
          salve: 2,
          position: Offset(x, r2),
        ),
      );
    }
    for (final x in cols) {
      out.add(
        _DoctrineSlot(
          row: 0,
          col: 0,
          ordre: ordre++,
          salve: 2,
          position: Offset(x, r4),
        ),
      );
    }

    for (final x in cols) {
      out.add(
        _DoctrineSlot(
          row: 0,
          col: 0,
          ordre: ordre++,
          salve: 3,
          position: Offset(x, r3),
        ),
      );
    }

    return out;
  }

  static List<_DoctrineSlot> _build4x5OtanSlots({required ZonalGeometry geo}) {
    final out = <_DoctrineSlot>[];
    var ordre = 1;

    // Doctrine OTAN 300×400 : 18 coups = 8 / 8 / 2.
    // Répartition rangs : 4 / 3 / 4 / 3 / 4.
    // S1 ouvre les rangées extrêmes R1/R5.
    // S2 ferme les extérieurs : R2/R4 en 3 coups + les deux bords de R3.
    // S3 traite les deux intérieurs restants de R3.
    final pas4 = (geo.xRight - geo.xLeft) / 3.0;
    final cols4 = [
      geo.xLeft,
      geo.xLeft + pas4,
      geo.xLeft + 2.0 * pas4,
      geo.xRight,
    ];

    final cols3 = [geo.xLeft, (geo.xLeft + geo.xRight) / 2.0, geo.xRight];

    final r1 = geo.ys[0];
    final r2 = geo.ys[1];
    final r3 = geo.ys[2];
    final r4 = geo.ys[3];
    final r5 = geo.ys[4];

    void add({required double x, required double y, required int salve}) {
      out.add(
        _DoctrineSlot(
          row: 0,
          col: 0,
          ordre: ordre++,
          salve: salve,
          position: Offset(x, y),
        ),
      );
    }

    // S1 : R1 + R5 complets, 4 + 4 = 8.
    for (final x in cols4) {
      add(x: x, y: r1, salve: 1);
    }
    for (final x in cols4) {
      add(x: x, y: r5, salve: 1);
    }

    // S2 : fermeture extérieure, 3 + 3 + 2 = 8.
    for (final x in cols3) {
      add(x: x, y: r2, salve: 2);
    }
    for (final x in cols3) {
      add(x: x, y: r4, salve: 2);
    }
    add(x: cols4.first, y: r3, salve: 2);
    add(x: cols4.last, y: r3, salve: 2);

    // S3 : les deux coups intérieurs restants de R3, 2 coups.
    add(x: cols4[1], y: r3, salve: 3);
    add(x: cols4[2], y: r3, salve: 3);

    return out;
  }

  static List<_DoctrineSlot> _buildSquare4x4ForcedSlots({
    required ZonalGeometry geo,
  }) {
    final out = <_DoctrineSlot>[];
    var ordre = 1;
    final cols = [geo.xLeft, geo.xLeftInner4, geo.xRightInner4, geo.xRight];

    for (final rIdx in [0, 3]) {
      final y = geo.ys[rIdx];
      for (var c = 0; c < 4; c++) {
        out.add(
          _DoctrineSlot(
            row: rIdx,
            col: c,
            ordre: ordre++,
            salve: 1,
            position: Offset(cols[c], y),
          ),
        );
      }
    }

    for (final rIdx in [1, 2]) {
      final y = geo.ys[rIdx];
      for (var c = 0; c < 4; c++) {
        out.add(
          _DoctrineSlot(
            row: rIdx,
            col: c,
            ordre: ordre++,
            salve: 2,
            position: Offset(cols[c], y),
          ),
        );
      }
    }

    return out;
  }

  static List<_DoctrineSlot> _buildSquare4x4OtanSlots({
    required ZonalGeometry geo,
  }) {
    final out = <_DoctrineSlot>[];
    var ordre = 1;
    final cols = [geo.xLeft, geo.xLeftInner4, geo.xRightInner4, geo.xRight];
    final r = geo.diametreEfficaceM / 2.0;
    final otanS2Cols = [-2.0 * r, 0.0, 2.0 * r];

    for (final rIdx in [0, 3]) {
      final y = geo.ys[rIdx];
      for (var c = 0; c < 4; c++) {
        out.add(
          _DoctrineSlot(
            row: rIdx,
            col: c,
            ordre: ordre++,
            salve: 1,
            position: Offset(cols[c], y),
          ),
        );
      }
    }

    for (final rIdx in [1, 2]) {
      final y = geo.ys[rIdx];
      for (var c = 0; c < 3; c++) {
        out.add(
          _DoctrineSlot(
            row: rIdx,
            col: c + 1,
            ordre: ordre++,
            salve: 2,
            position: Offset(otanS2Cols[c], y),
          ),
        );
      }
    }

    return out;
  }

  static List<_DoctrineSlot> _buildOtanSlots({required ZonalGeometry geo}) {
    final out = <_DoctrineSlot>[];
    var ordre = 1;

    final nRows = geo.nRows;
    final midRow = nRows ~/ 2;

    if (nRows == 5) {
      out.add(
        _DoctrineSlot(
          row: 0,
          col: 0,
          ordre: ordre++,
          salve: 1,
          position: Offset(geo.xLeft, geo.ys[0]),
        ),
      );
      out.add(
        _DoctrineSlot(
          row: 0,
          col: 2,
          ordre: ordre++,
          salve: 1,
          position: Offset(geo.xCenter, geo.ys[0]),
        ),
      );
      out.add(
        _DoctrineSlot(
          row: 0,
          col: 4,
          ordre: ordre++,
          salve: 1,
          position: Offset(geo.xRight, geo.ys[0]),
        ),
      );
      out.add(
        _DoctrineSlot(
          row: midRow,
          col: 0,
          ordre: ordre++,
          salve: 1,
          position: Offset(geo.xLeft, geo.ys[midRow]),
        ),
      );
      out.add(
        _DoctrineSlot(
          row: midRow,
          col: 4,
          ordre: ordre++,
          salve: 1,
          position: Offset(geo.xRight, geo.ys[midRow]),
        ),
      );
      out.add(
        _DoctrineSlot(
          row: 4,
          col: 0,
          ordre: ordre++,
          salve: 1,
          position: Offset(geo.xLeft, geo.ys[4]),
        ),
      );
      out.add(
        _DoctrineSlot(
          row: 4,
          col: 2,
          ordre: ordre++,
          salve: 1,
          position: Offset(geo.xCenter, geo.ys[4]),
        ),
      );
      out.add(
        _DoctrineSlot(
          row: 4,
          col: 4,
          ordre: ordre++,
          salve: 1,
          position: Offset(geo.xRight, geo.ys[4]),
        ),
      );

      out.add(
        _DoctrineSlot(
          row: 1,
          col: 1,
          ordre: ordre++,
          salve: 2,
          position: Offset(geo.xLeftInner, geo.ys[1]),
        ),
      );
      out.add(
        _DoctrineSlot(
          row: 1,
          col: 3,
          ordre: ordre++,
          salve: 2,
          position: Offset(geo.xRightInner, geo.ys[1]),
        ),
      );
      out.add(
        _DoctrineSlot(
          row: midRow,
          col: 2,
          ordre: ordre++,
          salve: 2,
          position: Offset(geo.xCenter, geo.ys[midRow]),
        ),
      );
      out.add(
        _DoctrineSlot(
          row: 3,
          col: 1,
          ordre: ordre++,
          salve: 2,
          position: Offset(geo.xLeftInner, geo.ys[3]),
        ),
      );
      out.add(
        _DoctrineSlot(
          row: 3,
          col: 3,
          ordre: ordre++,
          salve: 2,
          position: Offset(geo.xRightInner, geo.ys[3]),
        ),
      );

      return out;
    }

    for (var row = 0; row < nRows; row++) {
      final y = geo.ys[row];
      final isFirst = row == 0;
      final isLast = row == nRows - 1;

      if (isFirst || isLast) {
        out.add(
          _DoctrineSlot(
            row: row,
            col: 0,
            ordre: ordre++,
            salve: 1,
            position: Offset(geo.xLeft, y),
          ),
        );
        out.add(
          _DoctrineSlot(
            row: row,
            col: 4,
            ordre: ordre++,
            salve: 1,
            position: Offset(geo.xRight, y),
          ),
        );
      } else {
        out.add(
          _DoctrineSlot(
            row: row,
            col: 1,
            ordre: ordre++,
            salve: 1,
            position: Offset(geo.xLeftInner, y),
          ),
        );
        out.add(
          _DoctrineSlot(
            row: row,
            col: 3,
            ordre: ordre++,
            salve: 1,
            position: Offset(geo.xRightInner, y),
          ),
        );
      }
    }

    if (nRows >= 1) {
      out.add(
        _DoctrineSlot(
          row: 0,
          col: 2,
          ordre: ordre++,
          salve: 2,
          position: Offset(geo.xCenter, geo.ys[0]),
        ),
      );
    }

    if (nRows >= 2) {
      out.add(
        _DoctrineSlot(
          row: nRows - 1,
          col: 2,
          ordre: ordre++,
          salve: 2,
          position: Offset(geo.xCenter, geo.ys[nRows - 1]),
        ),
      );
    }

    return out;
  }

  static List<_DoctrineSlot> _buildForcedSlots({required ZonalGeometry geo}) {
    final out = <_DoctrineSlot>[];
    var ordre = 1;

    if (geo.nRows == 5) {
      return _buildForced5Slots(geo: geo);
    }

    for (var row = 0; row < geo.nRows; row++) {
      final y = geo.ys[row];
      out.add(
        _DoctrineSlot(
          row: row,
          col: 0,
          ordre: ordre++,
          salve: 1,
          position: Offset(geo.xLeft, y),
        ),
      );
      out.add(
        _DoctrineSlot(
          row: row,
          col: 4,
          ordre: ordre++,
          salve: 1,
          position: Offset(geo.xRight, y),
        ),
      );
    }

    for (var row = 0; row < geo.nRows; row++) {
      out.add(
        _DoctrineSlot(
          row: row,
          col: 2,
          ordre: ordre++,
          salve: 2,
          position: Offset(geo.xCenter, geo.ys[row]),
        ),
      );
    }

    return out;
  }

  static List<_DoctrineSlot> _buildForced5Slots({required ZonalGeometry geo}) {
    final out = <_DoctrineSlot>[];
    var ordre = 1;

    final s1Rows = [0, 2, 4];
    final s1FullRows = [0, 4];

    for (final row in s1Rows) {
      final y = geo.ys[row];
      out.add(
        _DoctrineSlot(
          row: row,
          col: 0,
          ordre: ordre++,
          salve: 1,
          position: Offset(geo.xLeft, y),
        ),
      );

      if (s1FullRows.contains(row)) {
        out.add(
          _DoctrineSlot(
            row: row,
            col: 1,
            ordre: ordre++,
            salve: 1,
            position: Offset(geo.xLeftInner, y),
          ),
        );
      }

      out.add(
        _DoctrineSlot(
          row: row,
          col: 2,
          ordre: ordre++,
          salve: 1,
          position: Offset(geo.xRight, y),
        ),
      );
    }

    for (final row in [1, 3]) {
      final y = geo.ys[row];
      out.add(
        _DoctrineSlot(
          row: row,
          col: 0,
          ordre: ordre++,
          salve: 2,
          position: Offset(geo.xLeft, y),
        ),
      );
      out.add(
        _DoctrineSlot(
          row: row,
          col: 1,
          ordre: ordre++,
          salve: 2,
          position: Offset(geo.xLeftInner, y),
        ),
      );
      out.add(
        _DoctrineSlot(
          row: row,
          col: 2,
          ordre: ordre++,
          salve: 2,
          position: Offset(geo.xRight, y),
        ),
      );
    }

    out.add(
      _DoctrineSlot(
        row: 2,
        col: 1,
        ordre: ordre++,
        salve: 2,
        position: Offset(geo.xLeftInner, geo.ys[2]),
      ),
    );

    return out;
  }

  static List<String> _assignUniquePerSalve({
    required List<PieceGeom> pieces,
    required List<_SlotWithUtm> slotsWithUtm,
    required double prX,
    required double prY,
  }) {
    final result = List<String>.filled(
      slotsWithUtm.length,
      '',
      growable: false,
    );
    if (pieces.isEmpty || slotsWithUtm.isEmpty) return result;

    final battE = pieces.fold(0.0, (s, p) => s + p.x) / pieces.length;
    final battN = pieces.fold(0.0, (s, p) => s + p.y) / pieces.length;

    final dx = prX - battE;
    final dy = prY - battN;
    final dist = math.sqrt(dx * dx + dy * dy);
    final ux = dist > 1e-3 ? dx / dist : 1.0;
    final uy = dist > 1e-3 ? dy / dist : 0.0;

    final perpX = -uy;
    final perpY = ux;

    double projPiece(PieceGeom p) =>
        (p.x - battE) * perpX + (p.y - battN) * perpY;

    double projSlot(_SlotWithUtm s) =>
        (s.utmE - prX) * perpX + (s.utmN - prY) * perpY;

    final piecesSorted = List<PieceGeom>.from(pieces)
      ..sort((a, b) => projPiece(a).compareTo(projPiece(b)));

    final entriesBySalve = <int, List<MapEntry<int, _SlotWithUtm>>>{};
    for (final entry in slotsWithUtm.asMap().entries) {
      entriesBySalve.putIfAbsent(entry.value.slot.salve, () => []).add(entry);
    }

    final salves = entriesBySalve.keys.toList()..sort();

    for (final salve in salves) {
      final entries = entriesBySalve[salve]!
        ..sort((a, b) => projSlot(a.value).compareTo(projSlot(b.value)));

      final selectedPieces = _selectUniquePiecesForSalve(
        piecesSorted: piecesSorted,
        take: entries.length,
      );

      for (var i = 0; i < entries.length; i++) {
        result[entries[i].key] = selectedPieces[i].id;
      }
    }

    return result;
  }

  static List<PieceGeom> _selectUniquePiecesForSalve({
    required List<PieceGeom> piecesSorted,
    required int take,
  }) {
    if (piecesSorted.isEmpty || take <= 0) return const <PieceGeom>[];
    if (take >= piecesSorted.length) return List<PieceGeom>.from(piecesSorted);

    final pdIndex = piecesSorted.indexWhere((p) => p.isPd);
    if (pdIndex < 0) {
      return piecesSorted.take(take).toList(growable: false);
    }

    var start = pdIndex - ((take - 1) ~/ 2);
    var end = start + take;

    if (start < 0) {
      end -= start;
      start = 0;
    }

    if (end > piecesSorted.length) {
      start -= end - piecesSorted.length;
      end = piecesSorted.length;
    }

    if (start < 0) start = 0;
    end = math.min(end, piecesSorted.length);

    return piecesSorted.sublist(start, end);
  }

  static List<String> _assignMonge({
    required List<PieceGeom> pieces,
    required List<_SlotWithUtm> slotsWithUtm,
    required double prX,
    required double prY,
  }) {
    final result = List<String>.filled(
      slotsWithUtm.length,
      '',
      growable: false,
    );
    if (pieces.isEmpty || slotsWithUtm.isEmpty) return result;

    final battE = pieces.fold(0.0, (s, p) => s + p.x) / pieces.length;
    final battN = pieces.fold(0.0, (s, p) => s + p.y) / pieces.length;

    final dx = prX - battE;
    final dy = prY - battN;
    final dist = math.sqrt(dx * dx + dy * dy);
    final ux = dist > 1e-3 ? dx / dist : 1.0;
    final uy = dist > 1e-3 ? dy / dist : 0.0;

    final perpX = -uy;
    final perpY = ux;

    double projPiece(PieceGeom p) =>
        (p.x - battE) * perpX + (p.y - battN) * perpY;

    double projSlot(_SlotWithUtm s) =>
        (s.utmE - prX) * perpX + (s.utmN - prY) * perpY;

    final piecesSorted = List<PieceGeom>.from(pieces)
      ..sort((a, b) => projPiece(a).compareTo(projPiece(b)));

    final assignedCount = <String, int>{for (final p in piecesSorted) p.id: 0};

    final entriesBySalve = <int, List<MapEntry<int, _SlotWithUtm>>>{};
    for (final entry in slotsWithUtm.asMap().entries) {
      entriesBySalve.putIfAbsent(entry.value.slot.salve, () => []).add(entry);
    }

    final salves = entriesBySalve.keys.toList()..sort();

    for (final salve in salves) {
      final entries = entriesBySalve[salve]!
        ..sort((a, b) => projSlot(a.value).compareTo(projSlot(b.value)));

      final usedThisSalve = <String>{};

      for (var k = 0; k < entries.length; k++) {
        // Rang latéral théorique de la pièce à utiliser pour conserver l'effet
        // Monge : les slots à gauche restent affectés aux pièces à gauche,
        // les slots à droite restent affectés aux pièces à droite.
        final targetRank = entries.length <= 1 || piecesSorted.length <= 1
            ? 0.0
            : k * (piecesSorted.length - 1) / (entries.length - 1);

        PieceGeom? best;
        double bestScore = double.infinity;

        for (var pIdx = 0; pIdx < piecesSorted.length; pIdx++) {
          final p = piecesSorted[pIdx];
          final alreadyUsed = usedThisSalve.contains(p.id);

          // Tant qu'il reste des pièces non utilisées dans cette salve, on évite
          // de donner deux coups de la même salve à la même pièce. Si la salve
          // contient plus de slots que de pièces, les doublons deviennent admis.
          if (alreadyUsed && usedThisSalve.length < piecesSorted.length) {
            continue;
          }

          final lateralScore = (pIdx - targetRank).abs() * 1000.0;
          final balanceScore = (assignedCount[p.id] ?? 0) * 100.0;
          final reusePenalty = alreadyUsed ? 10.0 : 0.0;
          final score = lateralScore + balanceScore + reusePenalty;

          if (score < bestScore) {
            bestScore = score;
            best = p;
          }
        }

        // Sécurité : ne jamais laisser un slot sans pièce, sinon il est filtré
        // plus loin et on retombe sur le bug 26 demandés / 18 dessinés.
        best ??= piecesSorted[k % piecesSorted.length];

        result[entries[k].key] = best.id;
        assignedCount[best.id] = (assignedCount[best.id] ?? 0) + 1;
        usedThisSalve.add(best.id);
      }
    }

    return result;
  }

  static Offset _unitFromAzMil(double azMil) {
    final azRad = azMil * 2.0 * math.pi / 6400.0;
    return Offset(math.sin(azRad), math.cos(azRad));
  }
}

class _SlotWithUtm {
  final _DoctrineSlot slot;
  final double utmE;
  final double utmN;

  const _SlotWithUtm({
    required this.slot,
    required this.utmE,
    required this.utmN,
  });
}

class ZonalGeometry {
  final double largeurM;
  final double profondeurM;
  final int nRows;
  final int nCols;
  final double xLeft;
  final double xCenter;
  final double xRight;
  final double xLeftInner;
  final double xRightInner;
  final double xLeftInner4;
  final double xRightInner4;
  final double diametreEfficaceM;
  final List<double> ys;
  final double recouvrementVertical;
  final double recouvrementLateral;
  final bool otanApplicable;
  final bool isSquare4x4;
  final bool is4x5;
  final bool is5x5;
  final bool is5x6;
  final bool is3x6;

  int get coupsOtan {
    // Doctrine ÉCLAIRANT : pas d'économie OTAN.
    if (diametreEfficaceM >= 600.0) {
      return coupsForce;
    }

    if (is5x6) return 26;
    if (is3x6) return 20;
    if (is5x5) return 23;
    if (is4x5) return 18;
    if (isSquare4x4) return 14;

    // Géométrie générique validée pour une grille 3x5 :
    // 15 coups en forcé, 13 coups en OTAN.
    if (nCols == 3 && nRows == 5) return 13;

    // Doctrine générique historique pour les autres grilles à 3 colonnes :
    // deux positions par rangée, plus deux centres de fermeture.
    if (nCols == 3) return math.min(coupsForce, 2 * nRows + 2);

    // Sans doctrine validée, aucune économie automatique.
    return coupsForce;
  }

  int get coupsForce {
    if (is5x6) return 30;
    if (is3x6) return 24;
    if (is5x5) return 25;
    if (is4x5) return 20;
    if (isSquare4x4) return 16;
    return nCols * nRows;
  }

  bool get isSquare4x4Otan => isSquare4x4;

  const ZonalGeometry._({
    required this.largeurM,
    required this.profondeurM,
    required this.nRows,
    required this.nCols,
    required this.xLeft,
    required this.xCenter,
    required this.xRight,
    required this.xLeftInner,
    required this.xRightInner,
    required this.xLeftInner4,
    required this.xRightInner4,
    required this.diametreEfficaceM,
    required this.ys,
    required this.recouvrementVertical,
    required this.recouvrementLateral,
    required this.otanApplicable,
    required this.isSquare4x4,
    required this.is4x5,
    required this.is5x5,
    required this.is5x6,
    required this.is3x6,
  });

  factory ZonalGeometry.compute({
    required double largeur,
    required double profondeur,
    required double debordementRatio,
    required double recouvrementMini,
    required double diametreEfficaceM,
  }) {
    final r = diametreEfficaceM / 2.0;

    final largeurExt = largeur * (1.0 + debordementRatio);
    final profondeurExt = profondeur * (1.0 + debordementRatio);

    final isSquare = (largeur - profondeur).abs() < _ZonalMath.eps * 1e6 ||
        (largeur - profondeur).abs() / math.max(largeur, profondeur) < 0.05;

    final isSquare4x4 = isSquare &&
        largeurExt >= 6.0 * r - _ZonalMath.eps &&
        largeurExt <= 8.0 * r + _ZonalMath.eps;

    const l5x5Min = 353.0;
    const l5x5Max = 420.0;
    final is5x5 = !isSquare4x4 &&
        largeur >= l5x5Min &&
        largeur <= l5x5Max &&
        profondeur >= l5x5Min &&
        profondeur <= l5x5Max;

    const l4x5Min = 268.0;
    const l4x5Max = 380.0;
    const p4x5Min = 353.0;
    const p4x5Max = 480.0;
    final is4x5 = !isSquare4x4 &&
        !is5x5 &&
        largeur >= l4x5Min &&
        largeur <= l4x5Max &&
        profondeur >= p4x5Min &&
        profondeur <= p4x5Max;

    const l5x6Min = 380.0;
    const l5x6Max = 450.0;
    const p5x6Min = 480.0;
    const p5x6Max = 560.0;
    final is5x6 = !isSquare4x4 &&
        !is5x5 &&
        !is4x5 &&
        largeur >= l5x6Min &&
        largeur <= l5x6Max &&
        profondeur >= p5x6Min &&
        profondeur <= p5x6Max;

    const l3x6Min = 280.0;
    const l3x6Max = 340.0;
    const p3x6Min = 480.0;
    const p3x6Max = 560.0;
    final is3x6 = !isSquare4x4 &&
        !is5x5 &&
        !is4x5 &&
        !is5x6 &&
        largeur >= l3x6Min &&
        largeur <= l3x6Max &&
        profondeur >= p3x6Min &&
        profondeur <= p3x6Max;

    final otanApplicable = !isSquare4x4 &&
        !is4x5 &&
        !is5x5 &&
        !is5x6 &&
        !is3x6 &&
        largeurExt <= 6.0 * r + _ZonalMath.eps &&
        largeurExt >= 4.0 * r - _ZonalMath.eps;

    // Pas doctrinal maximal entre deux centres.
    //
    // Le nombre de centres est calculé directement sur la dimension étendue :
    //   count = ceil(dimensionEtendue / pas)
    //
    // Cette règle est indépendante du système d'arme. Elle permet notamment :
    // - CAESAR, D=100 m, zone 150x160 avec 5 % : grille générique 2x2 ;
    //   3 colonnes x 5 rangées.
    final maxStep = diametreEfficaceM * (1.0 - recouvrementMini);

    int axisCount(double extendedDimension) {
      if (extendedDimension <= _ZonalMath.eps) return 1;
      if (maxStep <= _ZonalMath.eps) return 1;
      return math.max(1, (extendedDimension / maxStep).ceil());
    }

    var nRows = axisCount(profondeurExt);

    if (is5x6 || is3x6) {
      nRows = 6;
    }

    final ys = <double>[];
    if (nRows == 1) {
      ys.add(0.0);
    } else {
      final top = -(profondeurExt / 2.0 - r);
      final bottom = -top;
      final step = (bottom - top) / (nRows - 1);
      for (var i = 0; i < nRows; i++) {
        ys.add(top + i * step);
      }
    }

    final xLeft = -(largeurExt / 2.0 - r);
    final xRight = largeurExt / 2.0 - r;
    const xCenter = 0.0;

    final xLeftInner = -r;
    final xRightInner = r;

    final xLeftInner4 = isSquare4x4 ? xLeft + (xRight - xLeft) / 3.0 : -r;
    final xRightInner4 = isSquare4x4 ? xRight - (xRight - xLeft) / 3.0 : r;

    final recouvrementVertical =
        ys.length <= 1 ? 1.0 : 1.0 - ((ys[0] - ys[1]).abs() / (2.0 * r));

    final recouvrementLateral = 1.0 - ((xCenter - xLeft).abs() / (2.0 * r));

    final genericCols = axisCount(largeurExt);

    return ZonalGeometry._(
      largeurM: largeur,
      profondeurM: profondeur,
      nRows: nRows,
      nCols: is5x6
          ? 9
          : (is3x6
              ? 7
              : (isSquare4x4
                  ? 4
                  : (is4x5 ? 4 : (is5x5 ? 5 : math.max(1, genericCols))))),
      xLeft: xLeft,
      xCenter: xCenter,
      xRight: xRight,
      xLeftInner: xLeftInner,
      xRightInner: xRightInner,
      xLeftInner4: xLeftInner4,
      xRightInner4: xRightInner4,
      diametreEfficaceM: diametreEfficaceM,
      ys: ys,
      recouvrementVertical: recouvrementVertical,
      recouvrementLateral: recouvrementLateral,
      otanApplicable: otanApplicable,
      isSquare4x4: isSquare4x4,
      is4x5: is4x5,
      is5x5: is5x5,
      is5x6: is5x6,
      is3x6: is3x6,
    );
  }
}

class _DoctrineSlot {
  final int row;
  final int col;
  final int ordre;
  final int salve;
  final Offset position;

  const _DoctrineSlot({
    required this.row,
    required this.col,
    required this.ordre,
    required this.salve,
    required this.position,
  });
}

class _ZonalMath {
  static const double eps = 1e-9;
}
