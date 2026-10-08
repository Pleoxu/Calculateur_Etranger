import 'package:calculateur_etranger/domain/fire/allocation/zonal/zonal_shot_assignment.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/zonal/hardcoded/zonal_hardcoded_doctrine_models.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/zonal/hardcoded/zonal_hardcoded_sequence_to_assignments.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/zonal/hardcoded/zonal_hardcoded_sequences.dart';

/// Service d'accès aux profils zonaux stabilisés "en dur".
///
/// Responsabilités :
/// - reconnaître les formats supportés (200x200, 200x300)
/// - sélectionner le mode doctrinal (OTAN / forcé)
/// - sélectionner la variante d'offsets
/// - convertir le profil en ZonalShotAssignment
///
/// Ce service ne généralise rien.
/// Il encapsule volontairement uniquement les cas stabilisés métier.
class ZonalHardcodedDoctrineService {
  const ZonalHardcodedDoctrineService();

  bool supports({
    required double width,
    required double height,
    required double debordementRatio,
  }) {
    return ZonalHardcodedSequences.isSupported(
      width: width,
      height: height,
      debordementRatio: debordementRatio,
    );
  }

  ZonalHardcodedSequence resolveSequence({
    required double width,
    required double height,
    required ZonalDoctrineMode mode,
    required double debordementRatio,
    ZonalOffsetVariant variant = ZonalOffsetVariant.reference,
  }) {
    return ZonalHardcodedSequences.resolve(
      width: width,
      height: height,
      mode: mode,
      debordementRatio: debordementRatio,
      variant: variant,
    );
  }

  List<ZonalShotAssignment> buildAssignments({
    required double width,
    required double height,
    required ZonalDoctrineMode mode,
    required Map<String, String> pieceCodeToId,
    required double debordementRatio,
    ZonalOffsetVariant variant = ZonalOffsetVariant.reference,
  }) {
    final sequence = resolveSequence(
      width: width,
      height: height,
      mode: mode,
      debordementRatio: debordementRatio,
      variant: variant,
    );

    return ZonalHardcodedSequenceToAssignments.convert(
      sequence: sequence,
      pieceCodeToId: pieceCodeToId,
    );
  }

  Map<int, List<ZonalShotAssignment>> buildAssignmentsBySalvo({
    required double width,
    required double height,
    required ZonalDoctrineMode mode,
    required Map<String, String> pieceCodeToId,
    required double debordementRatio,
    ZonalOffsetVariant variant = ZonalOffsetVariant.reference,
  }) {
    final sequence = resolveSequence(
      width: width,
      height: height,
      mode: mode,
      debordementRatio: debordementRatio,
      variant: variant,
    );

    return ZonalHardcodedSequenceToAssignments.groupBySalvo(
      sequence: sequence,
      pieceCodeToId: pieceCodeToId,
    );
  }

  /// Construit le mapping standard à partir des identifiants des pièces.
  ///
  /// Obligatoire pour les profils actuels :
  /// - PD
  /// - PS1..PS7
  Map<String, String> buildPieceCodeToId({
    required String pdId,
    required String ps1Id,
    required String ps2Id,
    required String ps3Id,
    required String ps4Id,
    required String ps5Id,
    required String ps6Id,
    required String ps7Id,
  }) {
    return <String, String>{
      'PD': pdId,
      'PS1': ps1Id,
      'PS2': ps2Id,
      'PS3': ps3Id,
      'PS4': ps4Id,
      'PS5': ps5Id,
      'PS6': ps6Id,
      'PS7': ps7Id,
    };
  }

  /// Version pratique : résout directement avec les IDs des pièces.
  List<ZonalShotAssignment> buildAssignmentsFromPieceIds({
    required double width,
    required double height,
    required ZonalDoctrineMode mode,
    required String pdId,
    required String ps1Id,
    required String ps2Id,
    required String ps3Id,
    required String ps4Id,
    required String ps5Id,
    required String ps6Id,
    required String ps7Id,
    required double debordementRatio,
    ZonalOffsetVariant variant = ZonalOffsetVariant.reference,
  }) {
    final pieceCodeToId = buildPieceCodeToId(
      pdId: pdId,
      ps1Id: ps1Id,
      ps2Id: ps2Id,
      ps3Id: ps3Id,
      ps4Id: ps4Id,
      ps5Id: ps5Id,
      ps6Id: ps6Id,
      ps7Id: ps7Id,
    );

    return buildAssignments(
      width: width,
      height: height,
      mode: mode,
      pieceCodeToId: pieceCodeToId,
      debordementRatio: debordementRatio,
      variant: variant,
    );
  }

  /// Variante pratique avec regroupement direct par salve.
  Map<int, List<ZonalShotAssignment>> buildAssignmentsBySalvoFromPieceIds({
    required double width,
    required double height,
    required ZonalDoctrineMode mode,
    required String pdId,
    required String ps1Id,
    required String ps2Id,
    required String ps3Id,
    required String ps4Id,
    required String ps5Id,
    required String ps6Id,
    required String ps7Id,
    required double debordementRatio,
    ZonalOffsetVariant variant = ZonalOffsetVariant.reference,
  }) {
    final pieceCodeToId = buildPieceCodeToId(
      pdId: pdId,
      ps1Id: ps1Id,
      ps2Id: ps2Id,
      ps3Id: ps3Id,
      ps4Id: ps4Id,
      ps5Id: ps5Id,
      ps6Id: ps6Id,
      ps7Id: ps7Id,
    );

    return buildAssignmentsBySalvo(
      width: width,
      height: height,
      mode: mode,
      pieceCodeToId: pieceCodeToId,
      debordementRatio: debordementRatio,
      variant: variant,
    );
  }
}
