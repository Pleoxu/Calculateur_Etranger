import 'package:calculateur_etranger/domain/fire/models/tir_complet_input.dart'
    as tc;
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/presentation/fire/models/piece_soutien.dart';
import 'package:calculateur_etranger/presentation/fire/helpers/coups_repartition_helper.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/coups_repartition_dialog.dart';

const List<String> allLinearRoles = [
  'PD',
  'PS1',
  'PS2',
  'PS3',
  'PS4',
  'PS5',
  'PS6',
  'PS7',
];

List<String> sortRolesForStorage(Iterable<String> roles) {
  final unique = roles.toSet();
  return allLinearRoles.where(unique.contains).toList();
}

Map<String, int> equitableDistribution({
  required List<String> orderedPieces,
  required int totalCoups,
}) {
  if (orderedPieces.isEmpty || totalCoups <= 0) return <String, int>{};

  return doctrinalRepartition(
    totalCoups: totalCoups,
    piecesOrdered: orderedPieces,
    minPerPiece: CoupsRepartitionDialog.minCoupsParPiece,
    maxPerPiece: CoupsRepartitionDialog.maxCoupsParPiece,
  );
}

Map<String, int> normalizeSafely({
  required Map<String, int> current,
  required List<String> orderedPieces,
  required int totalCoups,
}) {
  if (orderedPieces.isEmpty || totalCoups <= 0) return <String, int>{};

  final input = {for (final p in orderedPieces) p: (current[p] ?? 0)};

  final sum = input.values.fold<int>(0, (a, b) => a + b);

  // Une répartition héritée peut avoir la bonne somme tout en étant devenue
  // obsolète après changement de sélection (ex. PD:2 puis ajout de PS1 => PS1:0).
  // Dans un tir multi-pièces, si au moins une pièce sélectionnée n'a encore
  // aucune part alors que le nombre total de coups permet d'en attribuer au
  // moins un par pièce, on réamorce la répartition doctrinale.
  final canGiveAtLeastOnePerPiece = totalCoups >= orderedPieces.length;
  final hasUnassignedSelectedPiece =
      orderedPieces.length > 1 && input.values.any((v) => v == 0);

  final isValid = input.length == orderedPieces.length &&
      sum == totalCoups &&
      !input.values.any((v) => v < 0) &&
      !(canGiveAtLeastOnePerPiece && hasUnassignedSelectedPiece);

  if (!isValid) {
    return equitableDistribution(
      orderedPieces: orderedPieces,
      totalCoups: totalCoups,
    );
  }

  return normalizeToTotal(
    input: input,
    totalCoups: totalCoups,
    piecesOrdered: orderedPieces,
  );
}

Set<String> defaultLinearRoles({
  required tc.LinearFiringMode mode,
  required int totalCoupsNature,
  required List<PieceSoutien> existing,
  required List<String> previousSelected,
}) {
  final prev = sortRolesForStorage(previousSelected);
  if (prev.isNotEmpty) return prev.toSet();

  final existingRoles = sortRolesForStorage([
    'PD',
    ...existing.map((e) => e.nom.trim().toUpperCase()),
  ]);

  if (mode == tc.LinearFiringMode.sectionWithoutPd) {
    final supports = existingRoles.where((e) => e != 'PD').toSet();
    return supports.isEmpty ? <String>{} : supports;
  }

  // Aucun mode ne doit inventer des rôles absents. Par défaut, on conserve
  // uniquement les pièces réellement connues ; à défaut, la PD reste seule.
  return existingRoles.isEmpty ? <String>{'PD'} : existingRoles.toSet();
}

Set<String> normalizeLinearRoles({
  required tc.LinearFiringMode mode,
  required Set<String> selected,
}) {
  final roles = sortRolesForStorage(selected).toSet();

  switch (mode) {
    case tc.LinearFiringMode.sectionWithoutPd:
      return roles.where((r) => r != 'PD').toSet();

    case tc.LinearFiringMode.sectionWithPd:
    case tc.LinearFiringMode.batteryWithPd:
      // Ces modes imposent seulement la présence de la PD. Le nombre de
      // pièces disponibles est désormais fourni par la configuration/UI.
      return <String>{'PD', ...roles.where((r) => r != 'PD')};

    case tc.LinearFiringMode.libre:
      return roles;
  }
}

List<String> orderedSelectedRolesForRepartition({
  required Iterable<String> roles,
}) {
  const doctrinalFireOrder = [
    'PS7',
    'PS6',
    'PS5',
    'PD',
    'PS1',
    'PS2',
    'PS3',
    'PS4',
  ];

  final set = roles.toSet();
  return doctrinalFireOrder.where(set.contains).toList();
}

List<PieceSoutien> buildPiecesFromRoles({
  required Iterable<String> roles,
  required List<PieceSoutien> existing,
}) {
  final byName = {for (final ps in existing) ps.nom.trim().toUpperCase(): ps};

  final out = <PieceSoutien>[];

  for (final role in sortRolesForStorage(roles)) {
    if (role == 'PD') continue;

    final piece = byName[role];
    if (piece == null) {
      // Une pièce sélectionnée mais non positionnée ne doit jamais recevoir
      // silencieusement une géométrie fictive. Elle sera ajoutée uniquement
      // lorsqu'une position réelle aura été fournie par l'utilisateur.
      continue;
    }

    out.add(piece.copyWith(nom: role));
  }

  return out;
}

bool isZonalSquare3x3(NatureTirSelection sel) {
  const double minM = 160.0;
  const double maxM = 230.0;
  const double tolerance = 10.0;

  final l = sel.longueurZonaleM;
  final p = sel.profondeurM;

  if (l <= 0 || p <= 0) return false;

  final isSquare = (l - p).abs() <= tolerance;
  return isSquare && l >= minM && l <= maxM && p >= minM && p <= maxM;
}

bool isZonalPreset(NatureTirSelection? sel) {
  if (sel == null) return false;
  if (sel.nature != NatureTirType.zonal) return false;
  if (sel.zonalMode != ZonalMode.force) return false;
  if (sel.nbCoups != 8) return false;

  final l = sel.longueurZonaleM;
  final p = sel.profondeurM;

  if (l <= 0 || p <= 0) return false;

  final isSquare = (l - p).abs() <= 1.0;
  const presetSizes = [100.0, 150.0, 200.0];

  return isSquare && presetSizes.any((s) => (l - s).abs() <= 1.0);
}
