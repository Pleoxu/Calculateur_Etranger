import 'package:flutter/material.dart';

import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/presentation/fire/models/repartition_view_mode.dart';
import 'package:calculateur_etranger/presentation/fire/painters/tir_painter_utils.dart';

const Color cPD = Color(0xFF2EE6A6);
const Color cPS1 = Color(0xFFFF4D4D);
const Color cPS2 = Color(0xFF3B82F6);
const Color cPS3 = Color(0xFFFFD43B);
const Color cPS4 = Color(0xFF8C6B3B);
const Color cPS5 = Color(0xFFFF9F1C);
const Color cPS6 = Color(0xFF22C55E);
const Color cPS7 = Color(0xFFFF5CC8);

const List<Color> fallbackPalette = [
  cPD,
  cPS1,
  cPS2,
  cPS3,
  cPS4,
  cPS5,
  cPS6,
  cPS7,
];

const List<String> doctrineLegendOrderFullBattery = [
  'PS7',
  'PS6',
  'PS5',
  'PD',
  'PS1',
  'PS2',
  'PS3',
  'PS4',
];

class PainterData {
  const PainterData({required this.orderedIds, required this.pieceIndex});

  final List<String> orderedIds;
  final Map<String, int> pieceIndex;
}

List<int> buildSalveOptions(TirCompletOutput output) {
  final salves = output.shots
      .map((s) => s.numeroSalve)
      .whereType<int>()
      .toSet()
      .toList()
    ..sort();

  return salves;
}

List<TirLineaireShot> filterShotsBySalve(
  List<TirLineaireShot> shots,
  int? selectedSalve,
) {
  if (selectedSalve == null) return shots;
  return shots.where((s) => s.numeroSalve == selectedSalve).toList();
}

Color? fixedColorForPiece(String id) {
  switch (id) {
    case 'PD':
      return cPD;
    case 'PS1':
      return cPS1;
    case 'PS2':
      return cPS2;
    case 'PS3':
      return cPS3;
    case 'PS4':
      return cPS4;
    case 'PS5':
      return cPS5;
    case 'PS6':
      return cPS6;
    case 'PS7':
      return cPS7;
  }

  return null;
}

Map<String, Color> buildPieceColors(List<TirLineaireShot> shots) {
  final ids = <String>{};

  for (final s in shots) {
    ids.add(s.nomPiece);
  }

  final sorted = ids.toList()..sort();
  final map = <String, Color>{};

  int fb = 0;

  for (final id in sorted) {
    final fixed = fixedColorForPiece(id);

    if (fixed != null) {
      map[id] = fixed;
    } else {
      map[id] = fallbackPalette[fb % fallbackPalette.length];
      fb++;
    }
  }

  return map;
}

PainterData buildPainterData({
  required TirCompletOutput output,
  required Map<String, Color> pieceColors,
  required bool isZonal,
  required double? azimutLargeurMil,
  required double? azimutLineaireMil,
  required double azimutTirMil,
}) {
  final orderedIds = isZonal
      ? buildZonalLegendOrder(
          output: output,
          presentIds: pieceColors.keys,
          axisAzMil: azimutLargeurMil ?? ((azimutTirMil + 1600.0) % 6400.0),
        )
      : buildUniqueLeftToRightPieceOrder(
          output: output,
          presentIds: pieceColors.keys,
          axisAzMil: azimutLineaireMil ?? output.firePlan.azimutMilOut,
        );

  final pieceIndex = <String, int>{
    for (int i = 0; i < orderedIds.length; i++) orderedIds[i]: i,
  };

  return PainterData(orderedIds: orderedIds, pieceIndex: pieceIndex);
}

List<String> buildUniqueLeftToRightPieceOrder({
  required TirCompletOutput output,
  required Iterable<String> presentIds,
  required double axisAzMil,
}) {
  final ids = presentIds.toSet();

  final ordered = doctrineLegendOrderFullBattery.where(ids.contains).toList();
  final missing = ids.difference(ordered.toSet()).toList()..sort();

  return [...ordered, ...missing];
}

int fallbackGeoRank(String id) {
  const order = ['PS7', 'PS6', 'PS5', 'PD', 'PS1', 'PS2', 'PS3', 'PS4'];

  final idx = order.indexOf(id);
  if (idx >= 0) return idx;

  return 1000;
}

List<String> buildZonalLegendOrder({
  required TirCompletOutput output,
  required Iterable<String> presentIds,
  required double axisAzMil,
}) {
  final ids = presentIds.toSet();
  final u = unitFromAzMil(axisAzMil);

  final pieceById = <String, PieceGeom>{
    for (final p in output.firePlan.pieces) p.id: p,
    for (final a in output.firePlan.allocs) a.piece.id: a.piece,
  };

  final withPos = <({String id, double pos, int doctrineRank})>[];
  final missing = <String>[];

  for (final id in ids) {
    final piece = pieceById[id];

    if (piece == null) {
      missing.add(id);
      continue;
    }

    final dx = piece.x - output.prX;
    final dy = piece.y - output.prY;
    final pos = dx * u.ux + dy * u.uy;

    withPos.add((id: id, pos: pos, doctrineRank: fallbackGeoRank(id)));
  }

  withPos.sort((a, b) {
    final c = a.pos.compareTo(b.pos);
    if (c != 0) return c;
    return a.doctrineRank.compareTo(b.doctrineRank);
  });

  missing.sort();

  return [...withPos.map((e) => e.id), ...missing];
}

int salveCount(TirCompletOutput output) {
  final salves =
      output.shots.map((s) => s.numeroSalve).whereType<int>().toSet();

  if (salves.isNotEmpty) return salves.length;

  return 1;
}

String? specialZonalLabel({
  required double longueurM,
  required double profondeurM,
  required int salves,
}) {
  final isSquare = (longueurM - profondeurM).abs() <= 1.0;
  if (!isSquare) return null;

  String? type;

  if ((longueurM - 200.0).abs() <= 1.0) {
    type = 'Neutralisation';
  } else if ((longueurM - 150.0).abs() <= 1.0) {
    type = 'Interdiction';
  } else if ((longueurM - 100.0).abs() <= 1.0) {
    type = 'Destruction';
  }

  if (type == null) return null;

  final ennemi = salves <= 1
      ? 'Infanterie'
      : salves == 2
          ? 'Armored vehicles'
          : 'Char';

  return '$type • $ennemi';
}

String paLineaireLabel(PointApplicationLineaire? pa) {
  switch (pa) {
    case PointApplicationLineaire.gauche:
      return 'Left';
    case PointApplicationLineaire.droite:
      return 'Right';
    case PointApplicationLineaire.extremite:
      return 'End';
    case PointApplicationLineaire.centre:
    default:
      return 'Center';
  }
}

String viewModeLabel(RepartitionViewMode mode) => mode.label;

String salveLabel(int? salve) {
  if (salve == null) return 'Tout';
  return 'Salvo $salve';
}
