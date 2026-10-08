import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:calculateur_etranger/domain/fire/allocation/zonal/zonal_shot_assignment.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/zonal/hardcoded/zonal_hardcoded_doctrine_models.dart';

/// Convertit une séquence zonale "métier" figée en
/// liste de ZonalShotAssignment exploitable par le moteur.
///
/// Hypothèses :
/// - pieceCode du profil = identifiant métier lisible ("PD", "PS1", ..., "PS7")
/// - pieceCodeToId permet de faire la correspondance vers les vrais pieceId du domaine
/// - le repère local des offsets est déjà correct dans la séquence source
///
/// Ce fichier ne décide PAS de la doctrine.
/// Il ne fait qu'adapter une séquence validée vers les types attendus par le calculateur.
class ZonalHardcodedSequenceToAssignments {
  const ZonalHardcodedSequenceToAssignments._();

  static List<ZonalShotAssignment> convert({
    required ZonalHardcodedSequence sequence,
    required Map<String, String> pieceCodeToId,
  }) {
    _validatePieceMapping(sequence: sequence, pieceCodeToId: pieceCodeToId);

    return List<ZonalShotAssignment>.generate(sequence.shots.length, (index) {
      final shot = sequence.shots[index];
      final pieceId = pieceCodeToId[shot.pieceCode]!;

      return ZonalShotAssignment(
        pieceId: pieceId,
        ordre: index + 1,
        salve: shot.salvo,
        position: Offset(shot.x, shot.y),
        point: ZonalIndexedPoint(
          row: shot.row,
          col: shot.slot,
          x: shot.x,
          y: shot.y,
          offsetM: _distanceFromCenter(shot.x, shot.y),
        ),
      );
    });
  }

  static Map<int, List<ZonalShotAssignment>> groupBySalvo({
    required ZonalHardcodedSequence sequence,
    required Map<String, String> pieceCodeToId,
  }) {
    final assignments = convert(
      sequence: sequence,
      pieceCodeToId: pieceCodeToId,
    );

    final result = <int, List<ZonalShotAssignment>>{};
    for (final assignment in assignments) {
      result.putIfAbsent(assignment.salve, () => <ZonalShotAssignment>[]);
      result[assignment.salve]!.add(assignment);
    }
    return result;
  }

  static List<ZonalShotAssignment> convert200x200Otan({
    required ZonalHardcodedSequence sequence,
    required Map<String, String> pieceCodeToId,
  }) {
    _assertSequenceCode(sequence.code, 'ZONAL_200x200_OTAN');
    return convert(sequence: sequence, pieceCodeToId: pieceCodeToId);
  }

  static List<ZonalShotAssignment> convert200x200Force({
    required ZonalHardcodedSequence sequence,
    required Map<String, String> pieceCodeToId,
  }) {
    _assertSequenceCode(sequence.code, 'ZONAL_200x200_FORCE');
    return convert(sequence: sequence, pieceCodeToId: pieceCodeToId);
  }

  static List<ZonalShotAssignment> convert200x300Otan({
    required ZonalHardcodedSequence sequence,
    required Map<String, String> pieceCodeToId,
  }) {
    _assertSequenceCode(sequence.code, 'ZONAL_200x300_OTAN');
    return convert(sequence: sequence, pieceCodeToId: pieceCodeToId);
  }

  static List<ZonalShotAssignment> convert200x300Force({
    required ZonalHardcodedSequence sequence,
    required Map<String, String> pieceCodeToId,
  }) {
    _assertSequenceCode(sequence.code, 'ZONAL_200x300_FORCE');
    return convert(sequence: sequence, pieceCodeToId: pieceCodeToId);
  }

  static void _validatePieceMapping({
    required ZonalHardcodedSequence sequence,
    required Map<String, String> pieceCodeToId,
  }) {
    final usedCodes = sequence.shots.map((shot) => shot.pieceCode).toSet();

    final missing = usedCodes
        .where((code) => !pieceCodeToId.containsKey(code))
        .toList(growable: false);

    if (missing.isNotEmpty) {
      throw ArgumentError(
        'pieceCodeToId mapping incomplete. Missing: ${missing.join(', ')}',
      );
    }
  }

  static void _assertSequenceCode(String actual, String expected) {
    if (actual != expected) {
      throw StateError(
        'Invalid sequence. Expected: $expected, received: $actual',
      );
    }
  }

  static double _distanceFromCenter(double x, double y) {
    return math.sqrt((x * x) + (y * y));
  }
}
