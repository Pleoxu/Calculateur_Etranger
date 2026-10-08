import 'dart:math' as math;

import 'package:calculateur_etranger/domain/fire/models/tir_complet_input.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';

class FirePlanPiecesResolver {
  const FirePlanPiecesResolver();

  int effectiveLinearPieceCount(TirCompletInput input) {
    final selected = _sanitizeSelectedRoles(input.selectedLinearRoles);
    if (selected.isNotEmpty) return selected.length;

    final supportIds = input.piecesSoutien
        .map((ps) => ps.nom.trim().toUpperCase())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (input.linearFiringMode == LinearFiringMode.sectionWithoutPd) {
      return supportIds.isEmpty ? 1 : supportIds.length;
    }

    return 1 + supportIds.length;
  }

  List<PieceGeom> resolveLinearPieces({
    required TirCompletInput input,
    required double pdX,
    required double pdY,
  }) {
    final support = <String, PieceGeom>{
      for (final ps in input.piecesSoutien)
        ps.nom.toUpperCase(): _psToPieceGeom(ps, pdX: pdX, pdY: pdY),
    };

    List<String> selected = _sanitizeSelectedRoles(input.selectedLinearRoles);

    if (selected.isEmpty) {
      final supportIds = support.keys.toList()..sort();

      selected = input.linearFiringMode == LinearFiringMode.sectionWithoutPd
          ? supportIds
          : <String>['PD', ...supportIds];
    }

    final pieces = <PieceGeom>[];
    for (final id in selected) {
      if (id == 'PD') {
        pieces.add(
          PieceGeom(
            id: 'PD',
            x: pdX,
            y: pdY,
            z: input.zPiece ?? input.altPiece ?? 0.0,
            isPd: true,
          ),
        );
      } else {
        final ps = support[id];
        if (ps != null) pieces.add(ps);
      }
    }

    if (pieces.isEmpty) {
      pieces.add(
        PieceGeom(
          id: 'PD',
          x: pdX,
          y: pdY,
          z: input.zPiece ?? input.altPiece ?? 0.0,
          isPd: true,
        ),
      );
    }

    return pieces;
  }

  List<PieceGeom> resolveZonalPieces({
    required TirCompletInput input,
    required double pdX,
    required double pdY,
  }) {
    final support = <String, PieceGeom>{
      for (final ps in input.piecesSoutien)
        ps.nom.trim().toUpperCase(): _psToPieceGeom(ps, pdX: pdX, pdY: pdY),
    };

    // La sélection zonale est actuellement transportée par le même champ que
    // la sélection linéaire. L'interface et le mapper utilisent déjà
    // `selectedLinearRoles`; on le traite donc comme la sélection commune des
    // pièces tireuses, sans introduire un second état concurrent.
    var selected = _sanitizeSelectedRoles(input.selectedLinearRoles);

    if (selected.isEmpty) {
      // Repli compatible avec les anciens dossiers ne contenant pas encore
      // de sélection explicite : on ne retient que les pièces réellement
      // configurées. Aucun preset ne doit créer implicitement des pièces.
      final supportIds = support.keys.toList()..sort();
      selected = input.autrePieces
          ? <String>['PD', ...supportIds]
          : const <String>['PD'];
    }

    final pieces = <PieceGeom>[];

    for (final id in selected) {
      if (id == 'PD') {
        pieces.add(
          PieceGeom(
            id: 'PD',
            x: pdX,
            y: pdY,
            z: input.zPiece ?? input.altPiece ?? 0.0,
            isPd: true,
          ),
        );
        continue;
      }

      final supportPiece = support[id];
      if (supportPiece != null) {
        pieces.add(supportPiece);
      }
    }

    if (pieces.isEmpty) {
      pieces.add(
        PieceGeom(
          id: 'PD',
          x: pdX,
          y: pdY,
          z: input.zPiece ?? input.altPiece ?? 0.0,
          isPd: true,
        ),
      );
    }

    return pieces;
  }

  List<String> _sanitizeSelectedRoles(List<String> raw) {
    const allowed = {'PD', 'PS1', 'PS2', 'PS3', 'PS4', 'PS5', 'PS6', 'PS7'};
    final out = <String>[];

    for (final r in raw) {
      final id = r.trim().toUpperCase();
      if (!allowed.contains(id)) continue;
      if (!out.contains(id)) out.add(id);
    }

    return out;
  }

  PieceGeom _psToPieceGeom(
    PieceSoutienInput ps, {
    required double pdX,
    required double pdY,
  }) {
    final aRad = ps.azimutMil * 2.0 * math.pi / 6400.0;

    return PieceGeom(
      id: ps.nom,
      x: pdX + ps.distanceM * math.sin(aRad),
      y: pdY + ps.distanceM * math.cos(aRad),
      z: ps.zPS,
      isPd: false,
    );
  }
}
