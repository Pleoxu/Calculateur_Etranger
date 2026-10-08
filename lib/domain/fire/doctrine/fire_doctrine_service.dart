import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:calculateur_etranger/domain/fire/allocation/zonal/zonal_shot_assignment.dart';
import 'package:calculateur_etranger/models/calcul_data.dart' show ZonalMode;
import 'package:calculateur_etranger/domain/fire/doctrine/zonal/hardcoded/zonal_hardcoded_doctrine_models.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/zonal/hardcoded/zonal_hardcoded_doctrine_service.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/zonal/zonal_doctrine_engine.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';

class FireDoctrineService {
  const FireDoctrineService();

  static const ZonalHardcodedDoctrineService _hardcoded =
      ZonalHardcodedDoctrineService();

  List<int>? linearSequence(int nbCoups) {
    switch (nbCoups) {
      case 11:
        return const [1, 1, 1, 2, 1, 2, 1, 2, 1, 1, 1];
      case 12:
        return const [1, 1, 1, 2, 1, 2, 2, 1, 2, 1, 1, 1];
      case 13:
        return const [1, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 1];
      case 14:
        return const [1, 1, 2, 1, 2, 1, 2, 2, 1, 2, 1, 2, 1, 1];
      case 15:
        return const [1, 1, 2, 1, 2, 1, 2, 2, 2, 1, 2, 1, 2, 1, 1];
      case 16:
        return const [1, 2, 1, 2, 1, 2, 1, 2, 2, 1, 2, 1, 2, 1, 2, 1];
      default:
        return null;
    }
  }

  /// Retourne true pour tout zonal couvert par le moteur paramétrique :
  ///   - Rectangles : 3 colonnes × 2-5 rangées, jusqu'aux limites OTAN 267×445 m
  ///   - Carrés 4×4 : 268-352m (couvre 300×300m à 350×350m, nRows=4)
  ///   - Rectangles 4×5 : L:268-380m, P:353-420m
  ///   - Carrés/rect 5×5 : L:353-420m, P:353-420m
  bool isSmallDoctrinalZonal({
    required double largeurM,
    required double profondeurM,
  }) {
    const double lMaxRect = 267.0;
    const double pMax = 445.0;
    const double lMin = 100.0;
    const double pMin = 100.0;

    final isRect = largeurM >= lMin &&
        largeurM <= lMaxRect &&
        profondeurM >= pMin &&
        profondeurM <= pMax;

    final isSquare4x4 = isSquare4x4Compatible(
      largeurM: largeurM,
      profondeurM: profondeurM,
    );

    final is4x5 = largeurM >= 268.0 &&
        largeurM <= 380.0 &&
        profondeurM >= 353.0 &&
        profondeurM <= 420.0 &&
        !isSquare4x4;

    final is5x5 = largeurM >= 353.0 &&
        largeurM <= 420.0 &&
        profondeurM >= 353.0 &&
        profondeurM <= 420.0 &&
        !isSquare4x4;

    return isRect || isSquare4x4 || is4x5 || is5x5;
  }

  bool isSquare4x4Compatible({
    required double largeurM,
    required double profondeurM,
  }) {
    const square4x4Min = 268.0;
    const square4x4Max = 352.0;
    const squareTolerance = 15.0;

    final isSquare = (largeurM - profondeurM).abs() <= squareTolerance;
    return isSquare &&
        largeurM >= square4x4Min &&
        largeurM <= square4x4Max &&
        profondeurM >= square4x4Min &&
        profondeurM <= square4x4Max;
  }

  bool isSquare3x3Compatible({
    required double largeurM,
    required double profondeurM,
  }) {
    const square3x3Min = 160.0;
    const square3x3Max = 230.0;
    const squareTolerance = 10.0;

    final isSquare = (largeurM - profondeurM).abs() <= squareTolerance;
    return isSquare &&
        largeurM >= square3x3Min &&
        largeurM <= square3x3Max &&
        profondeurM >= square3x3Min &&
        profondeurM <= square3x3Max;
  }

  bool isSpecial200x200Doctrine({
    required bool isZonal,
    required bool salvesOn,
    required double largeurM,
    required double profondeurM,
    required int piecesCount,
  }) {
    return isZonal &&
        salvesOn &&
        piecesCount == 8 &&
        isSquare3x3Compatible(largeurM: largeurM, profondeurM: profondeurM);
  }

  List<ZonalShotAssignment> computeAssignments({
    required List<PieceGeom> pieces,
    required double largeurM,
    required double profondeurM,
    required int coups,
    required double prX,
    required double prY,
    required double azimutLargeurMil,
    required double azimutTirMil,
    required double debordementRatio,
    required double recouvrementMini,
    required double diametreEfficaceM,
    ZonalMode zonalMode = ZonalMode.otan,
    bool isZonalPreset = false,
  }) {
    if (isZonalPreset) {
      final assignments = _buildPresetBatteryAssignments(
        pieces: pieces,
        largeurM: largeurM,
        profondeurM: profondeurM,
        debordementRatio: debordementRatio,
        diametreEfficaceM: diametreEfficaceM,
      );
      final normalized = _forceSingleBatterySalve8(
        assignments: assignments,
        pieces: pieces,
        coups: coups,
      );
      debugPrint(
        '[ZONAL] preset battery assignments count=${normalized.length}',
      );
      return normalized;
    }

    if (_hardcoded.supports(
      width: largeurM,
      height: profondeurM,
      debordementRatio: debordementRatio,
    )) {
      final mode = zonalMode == ZonalMode.otan
          ? ZonalDoctrineMode.otan
          : ZonalDoctrineMode.force;

      final mapping = <String, String>{
        for (final piece in pieces) piece.id: piece.id,
      };

      final assignments = _hardcoded.buildAssignments(
        width: largeurM,
        height: profondeurM,
        mode: mode,
        pieceCodeToId: mapping,
        debordementRatio: debordementRatio,
      )..sort((a, b) {
          final bySalve = a.salve.compareTo(b.salve);
          if (bySalve != 0) return bySalve;
          return a.ordre.compareTo(b.ordre);
        });

      final limitedAssignments =
          assignments.take(coups).toList(growable: false);
      final normalized = _forceSingleBatterySalve8(
        assignments: limitedAssignments,
        pieces: pieces,
        coups: coups,
      );

      debugPrint(
        '[ZONAL] hardcoded assignments count=${assignments.length} limited=${normalized.length} rounds=$coups mode=$mode',
      );
      for (final a in normalized) {
        debugPrint(
          '[ZONAL] hardcoded gun=${a.pieceId} salvo=${a.salve} order=${a.ordre} local=${a.position}',
        );
      }

      return normalized;
    }

    final mode = zonalMode == ZonalMode.otan
        ? ZonalDoctrineMode.otan
        : ZonalDoctrineMode.force;

    final assignments = ZonalDoctrineEngine.computeAssignments(
      largeur: largeurM,
      profondeur: profondeurM,
      pieces: pieces,
      coups: coups,
      prX: prX,
      prY: prY,
      azimutLargeurMil: azimutLargeurMil,
      azimutTirMil: azimutTirMil,
      debordementRatio: debordementRatio,
      recouvrementMini: recouvrementMini,
      diametreEfficaceM: diametreEfficaceM,
      mode: mode,
    )..sort((a, b) {
        final bySalve = a.salve.compareTo(b.salve);
        if (bySalve != 0) return bySalve;
        return a.ordre.compareTo(b.ordre);
      });

    final normalized = _forceSingleBatterySalve8(
      assignments: assignments,
      pieces: pieces,
      coups: coups,
    );

    debugPrint('[ZONAL] doctrine assignments count=${normalized.length}');
    for (final a in normalized) {
      debugPrint(
        '[ZONAL] doctrine gun=${a.pieceId} salvo=${a.salve} order=${a.ordre} local=${a.position}',
      );
    }

    return normalized;
  }

  List<ZonalShotAssignment> _forceSingleBatterySalve8({
    required List<ZonalShotAssignment> assignments,
    required List<PieceGeom> pieces,
    required int coups,
  }) {
    if (coups != 8 || assignments.length != 8) return assignments;

    const roles = <String>[
      'PD',
      'PS1',
      'PS2',
      'PS3',
      'PS4',
      'PS5',
      'PS6',
      'PS7',
    ];

    final pieceIdByRole = <String, String>{
      for (final p in pieces) p.id.trim().toUpperCase(): p.id,
    };

    if (!roles.every(pieceIdByRole.containsKey)) return assignments;

    final present =
        assignments.map((a) => a.pieceId.trim().toUpperCase()).toList();
    final missing = roles.where((r) => !present.contains(r)).toList();

    final seen = <String>{};
    var missingIdx = 0;

    return [
      for (var i = 0; i < assignments.length; i++)
        (() {
          final a = assignments[i];
          final currentRole = a.pieceId.trim().toUpperCase();

          var pieceId = a.pieceId;
          if (!roles.contains(currentRole) || seen.contains(currentRole)) {
            if (missingIdx < missing.length) {
              pieceId = pieceIdByRole[missing[missingIdx]]!;
              missingIdx++;
            }
          }

          seen.add(pieceId.trim().toUpperCase());

          return ZonalShotAssignment(
            pieceId: pieceId,
            salve: 1,
            ordre: i + 1,
            position: a.position,
            point: a.point,
          );
        })(),
    ];
  }

  List<ZonalShotAssignment> _buildPresetBatteryAssignments({
    required List<PieceGeom> pieces,
    required double largeurM,
    required double profondeurM,
    required double debordementRatio,
    required double diametreEfficaceM,
  }) {
    if (pieces.isEmpty) return const <ZonalShotAssignment>[];

    final points = _buildPresetCoveragePoints(
      largeurM: largeurM,
      profondeurM: profondeurM,
    );

    final pieceIds = <String>[for (final p in pieces) p.id];
    while (pieceIds.length < 8) {
      pieceIds.add(pieceIds[pieceIds.length % pieces.length]);
    }

    return [
      for (var i = 0; i < 8; i++)
        ZonalShotAssignment(
          pieceId: pieceIds[i],
          salve: 1,
          ordre: i + 1,
          position: points[i],
          point: ZonalIndexedPoint(
            row: _presetRow(index: i),
            col: _presetCol(index: i),
            offsetM: math.sqrt(
              points[i].dx * points[i].dx + points[i].dy * points[i].dy,
            ),
            x: points[i].dx,
            y: points[i].dy,
          ),
        ),
    ];
  }

  List<Offset> _buildPresetCoveragePoints({
    required double largeurM,
    required double profondeurM,
  }) {
    if (_isPresetDimension(largeurM, profondeurM, 100.0)) {
      return _destruction100x100Points();
    }
    if (_isPresetDimension(largeurM, profondeurM, 150.0)) {
      return _interdiction150x150Points();
    }
    return _neutralisation200x200Points();
  }

  bool _isPresetDimension(double largeurM, double profondeurM, double value) {
    const tolerance = 0.75;
    return (largeurM - value).abs() <= tolerance &&
        (profondeurM - value).abs() <= tolerance;
  }

  /// Destruction 100×100, avec zonal étendu 110×110.
  ///
  /// Pattern 8 coups :
  /// - 4 coups diagonaux à ±35 m pour traiter fortement les coins ;
  /// - 4 coups complémentaires à ±30 m sur les axes pour fermer les côtés.
  /// Destruction 100x100, avec zonal etendu 110x110.
  ///
  /// Geometrie retenue : cercles rayon 50 m contraints par le zonal etendu.
  /// - demi-cote etendu h = 55 m ;
  /// - centres diagonaux tangents aux coins : d = h - 50 / sqrt(2) ~= 19.64 m ;
  /// - centres axiaux tangents aux cotes : s = h - 50 = 5 m.
  ///
  /// Cela limite le debordement visible tout en gardant 8 coups :
  /// 4 pour les diagonales/coins, 4 pour fermer les cotes/axes.
  List<Offset> _destruction100x100Points() {
    const d = 19.64;
    const s = 5.0;

    return const <Offset>[
      Offset(d, d),
      Offset(-d, d),
      Offset(-d, -d),
      Offset(d, -d),
      Offset(s, 0.0),
      Offset(-s, 0.0),
      Offset(0.0, s),
      Offset(0.0, -s),
    ];
  }

  /// Interdiction 150x150, avec zonal etendu 165x165.
  ///
  /// h = 82.5 m ; d = h - 50 / sqrt(2) ~= 47.14 m ; s = h - 50 = 32.5 m.
  List<Offset> _interdiction150x150Points() {
    const d = 47.14;
    const s = 32.5;

    return const <Offset>[
      Offset(d, d),
      Offset(-d, d),
      Offset(-d, -d),
      Offset(d, -d),
      Offset(s, 0.0),
      Offset(-s, 0.0),
      Offset(0.0, s),
      Offset(0.0, -s),
    ];
  }

  /// Neutralisation 200x200, avec zonal etendu 220x220.
  ///
  /// h = 110 m ; d = h - 50 / sqrt(2) ~= 74.64 m ; s = h - 50 = 60 m.
  List<Offset> _neutralisation200x200Points() {
    const d = 74.64;
    const s = 60.0;

    return const <Offset>[
      Offset(d, d),
      Offset(-d, d),
      Offset(-d, -d),
      Offset(d, -d),
      Offset(s, 0.0),
      Offset(-s, 0.0),
      Offset(0.0, s),
      Offset(0.0, -s),
    ];
  }

  int _presetRow({required int index}) {
    const rows = <int>[0, 0, 2, 2, 1, 1, 2, 0];
    return rows[
        index < 0 ? 0 : (index >= rows.length ? rows.length - 1 : index)];
  }

  int _presetCol({required int index}) {
    const cols = <int>[2, 0, 0, 2, 2, 0, 1, 1];
    return cols[
        index < 0 ? 0 : (index >= cols.length ? cols.length - 1 : index)];
  }
}
