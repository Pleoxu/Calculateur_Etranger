import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/presentation/fire/models/piece_soutien.dart';
import 'package:calculateur_etranger/presentation/fire/state/tir_complet_state.dart';
import 'package:calculateur_etranger/presentation/fire/state/coups_par_piece_provider.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/nature_tir_card.dart'
    as nt;
import 'package:calculateur_etranger/presentation/fire/widgets/positions_pieces_dialog.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/coups_repartition_dialog.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/linear_fire_config_card.dart'
    as linear_cfg;
import 'package:calculateur_etranger/presentation/fire/widgets/zonal_fire_config_card.dart'
    as zonal_cfg;
import 'package:calculateur_etranger/presentation/theme/tir_tokens.dart';

import 'ecran_tir_complet_roles.dart';

/// Rôles que l'opérateur peut sélectionner avant de renseigner leur position.
/// La liste canonique sert ici de catalogue d'interface, pas de composition
/// automatique : seules les pièces effectivement choisies seront positionnées.
List<String> _selectableFireRoles(List<PieceSoutien> pieces) {
  final roles = <String>{
    ...allLinearRoles,
    ...pieces.map((e) => e.nom.trim().toUpperCase()).where((e) => e.isNotEmpty),
  };
  return sortRolesForStorage(roles);
}

/// Filtre la liste des pièces existantes selon les rôles sélectionnés.
/// Les rôles sans position réelle sont simplement ignorés.
List<PieceSoutien> _existingPiecesFromRoles({
  required Iterable<String> roles,
  required List<PieceSoutien> existing,
}) {
  final wanted = roles
      .map((e) => e.trim().toUpperCase())
      .where((e) => e != 'PD' && e.isNotEmpty)
      .toSet();

  return [
    for (final piece in existing)
      if (wanted.contains(piece.nom.trim().toUpperCase())) piece,
  ];
}

List<PiecePositionDraft> _positionDraftsFromRoles({
  required Iterable<String> roles,
  required List<PieceSoutien> existing,
  required bool preserveExistingValues,
}) {
  // Les positions PS ne sont jamais préremplies à l'ouverture.
  // L'opérateur renseigne explicitement Distance / Azimut / ΔZ.
  const byName = <String, PieceSoutien>{};

  return [
    for (final role in sortRolesForStorage(roles))
      if (role != 'PD')
        PiecePositionDraft(
          nom: role,
          // Première sélection d'une PS : aucun préremplissage géométrique.
          // En réédition d'une configuration déjà validée, on conserve les
          // valeurs effectivement saisies par l'opérateur.
          distanceM: byName[role]?.distanceM,
          azimutMil: byName[role]?.azimutMil,
          deltaZPd: byName[role]?.deltaZPd,
          zPS: byName[role]?.zPS,
        ),
  ];
}

double dialogWidth(BuildContext context, {double max = 640}) {
  final w = MediaQuery.of(context).size.width;
  final available = math.max(0.0, w - 24.0);
  return math.min(max, available);
}

Widget responsiveDialogShell({
  required BuildContext ctx,
  required Color surface,
  required Color border,
  required Widget child,
  double maxWidth = 640,
}) {
  final width = dialogWidth(ctx, max: maxWidth);
  final h = MediaQuery.of(ctx).size.height;
  final maxH = math.max(260.0, h * 0.85);

  return Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(
      horizontal: TirSpacing.m,
      vertical: TirSpacing.m,
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width, maxHeight: maxH),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(TirRadius.xl),
          border: Border.all(color: border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TirRadius.xl),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              TirSpacing.l,
              TirSpacing.m,
              TirSpacing.l,
              TirSpacing.m,
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

Future<void> openNatureDialog({
  required BuildContext context,
  required bool dark,
  required NatureTirSelection? initial,
  required ValueChanged<NatureTirSelection> onValidated,
  required double diametreEfficaciteM,
}) async {
  final Color surface = dark ? TirColors.cardDark : TirColors.cardLight;
  final Color border =
      dark ? TirColors.cardBorderDark : TirColors.cardBorderLight;

  final res = await showDialog<NatureTirSelection>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: true,
    builder: (ctx) {
      return responsiveDialogShell(
        ctx: ctx,
        surface: surface,
        border: border,
        maxWidth: 640,
        child: nt.NatureTirCard(
          dark: dark,
          initialSelection: initial,
          onChanged: (_) {},
          onValidate: (s) => Navigator.of(ctx).pop(s),
          onCancel: () => Navigator.of(ctx).pop(null),
          diametreEfficaciteM: diametreEfficaciteM,
        ),
      );
    },
  );

  if (res != null) {
    onValidated(res);
  }
}

Future<List<PieceSoutien>?> openPositionsPiecesDialog({
  required BuildContext context,
  required bool dark,
  required Iterable<String> selectedRoles,
  required List<PieceSoutien> existingPieces,
  required Color surface,
  required Color border,
  required Color textPrimary,
  required Color textSecondary,
  bool preserveExistingValues = true,
}) async {
  final Color mint = dark ? TirColors.activeDark : TirColors.activeLight;

  final initial = _positionDraftsFromRoles(
    roles: selectedRoles,
    existing: existingPieces,
    preserveExistingValues: preserveExistingValues,
  );

  final res = await PositionsPiecesDialog.show(
    context,
    dark: dark,
    surface: surface,
    border: border,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    mint: mint,
    initial: initial,
  );

  if (res == null) return null;

  final existingByName = <String, PieceSoutien>{
    for (final ps in existingPieces) ps.nom.trim().toUpperCase(): ps,
  };

  return [
    for (final d in res)
      (existingByName[d.nom.trim().toUpperCase()] ?? PieceSoutien(nom: d.nom))
          .copyWith(
        nom: d.nom,
        distanceM: d.distanceM!,
        azimutMil: d.azimutMil!,
        deltaZPd: d.deltaZPd ?? 0.0,
        zPS: d.zPS,
      ),
  ];
}

Future<void> openAutresPiecesDialogLineaire({
  required BuildContext context,
  required WidgetRef ref,
  required bool dark,
  required TirCompletState st,
  required TirCompletNotifier stN,
}) async {
  final Color surface = dark ? TirColors.cardDark : TirColors.cardLight;
  final Color border =
      dark ? TirColors.cardBorderDark : TirColors.cardBorderLight;

  final totalCoupsNature = st.nbCoupsTotalFromNatureSelection <= 0
      ? (st.natureSelection?.nbCoups ?? 3)
      : st.nbCoupsTotalFromNatureSelection;

  var mode = st.linearFiringMode;
  final availableRoles = _selectableFireRoles(st.piecesSoutien);

  // À chaque ouverture : PD seule est présélectionnée.
  // Les PS sont choisies explicitement par l'opérateur.
  var selectedRoles = <String>{'PD'};

  List<PieceSoutien> currentPiecesSoutien = _existingPiecesFromRoles(
    roles: selectedRoles,
    existing: st.autrePieces ? st.piecesSoutien : const <PieceSoutien>[],
  );

  Map<String, int> coups = Map<String, int>.from(st.coupsParPieceByPiece);

  List<String> orderedNow() =>
      orderedSelectedRolesForRepartition(roles: selectedRoles);

  Map<String, int> normalizeNow() => normalizeSafely(
        current: coups,
        orderedPieces: orderedNow(),
        totalCoups: totalCoupsNature,
      );

  coups = normalizeNow();

  Future<void> openRepartitionDialog(StateSetter setLocal) async {
    final ordered = orderedNow();
    if (ordered.isEmpty) return;

    final notifier = ref.read(coupsParPieceByPieceProvider.notifier);
    notifier.setAll(coups);

    final result = await showDialog<CoupsRepartitionResult>(
      context: context,
      useRootNavigator: false,
      builder: (_) => CoupsRepartitionDialog(
        totalCoups: totalCoupsNature,
        piecesOrdered: ordered,
        dark: dark,
      ),
    );

    if (result == null) return;

    final normalized = normalizeSafely(
      current: result.coupsParPiece,
      orderedPieces: orderedNow(),
      totalCoups: totalCoupsNature,
    );

    notifier.setAll(normalized);
    setLocal(() {
      coups = normalized;
    });
  }

  bool validated = false;

  await showDialog<void>(
    context: context,
    useRootNavigator: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return responsiveDialogShell(
            ctx: ctx,
            surface: surface,
            border: border,
            maxWidth: 760,
            child: linear_cfg.LinearFireConfigCard(
              dark: dark,
              totalCoups: totalCoupsNature,
              allPieces: availableRoles,
              sectionSize: availableRoles.length,
              sectionLabel: 'Sous-ensemble',
              formationLabel: 'Formation',
              initialMode: mode,
              initialSelectedRoles: sortRolesForStorage(selectedRoles),
              coupsParPiece: coups,
              onChanged: (result) {
                setLocal(() {
                  mode = result.mode;
                  selectedRoles = result.selectedRoles
                      .where(availableRoles.contains)
                      .toSet();
                  currentPiecesSoutien = _existingPiecesFromRoles(
                    roles: selectedRoles,
                    existing: st.autrePieces
                        ? st.piecesSoutien
                        : const <PieceSoutien>[],
                  );
                  coups = normalizeNow();
                });
              },
              onOpenRepartition: () async {
                await openRepartitionDialog(setLocal);
              },
              onCancel: () => Navigator.of(ctx).pop(),
              onValidate: (result) {
                mode = result.mode;
                selectedRoles =
                    result.selectedRoles.where(availableRoles.contains).toSet();
                currentPiecesSoutien = _existingPiecesFromRoles(
                  roles: selectedRoles,
                  existing: currentPiecesSoutien,
                );
                coups = normalizeNow();
                validated = true;
                Navigator.of(ctx).pop();
              },
            ),
          );
        },
      );
    },
  );

  if (!context.mounted) return;
  if (!validated) return;

  selectedRoles = selectedRoles.where(availableRoles.contains).toSet();
  currentPiecesSoutien = _existingPiecesFromRoles(
    roles: selectedRoles,
    existing: currentPiecesSoutien,
  );
  final normalized = normalizeSafely(
    current: coups,
    orderedPieces: orderedNow(),
    totalCoups: totalCoupsNature,
  );

  stN.setLinearFiringMode(mode);
  stN.setSelectedLinearRoles(sortRolesForStorage(selectedRoles));
  stN.setCoupsParPieceByPiece(Map<String, int>.from(normalized));

  if (selectedRoles.where((r) => r != 'PD').isEmpty) {
    stN.setAutrePiecesEnabled(false);
    stN.setPiecesSoutien(const <PieceSoutien>[]);
    return;
  }
  if (!context.mounted) return;

  final positioned = await openPositionsPiecesDialog(
    context: context,
    dark: dark,
    selectedRoles: selectedRoles,
    existingPieces: st.autrePieces ? st.piecesSoutien : const <PieceSoutien>[],
    surface: surface,
    border: border,
    textPrimary: dark ? Colors.white.withValues(alpha: 0.92) : Colors.black87,
    textSecondary: dark ? Colors.white70 : Colors.black54,
    preserveExistingValues: false,
  );

  if (!context.mounted) return;
  if (positioned == null) return;
  stN.setAutrePiecesEnabled(positioned.isNotEmpty);
  stN.setPiecesSoutien(positioned);
}

Future<void> openAutresPiecesDialog({
  required BuildContext context,
  required WidgetRef ref,
  required bool dark,
  required TirCompletState st,
  required TirCompletNotifier stN,
}) async {
  if (st.natureEnabled &&
      st.natureSelection?.nature == NatureTirType.lineaire) {
    await openAutresPiecesDialogLineaire(
      context: context,
      ref: ref,
      dark: dark,
      st: st,
      stN: stN,
    );
    return;
  }

  // Ponctuel sans autres pièces :
  // répartition propre sur PD uniquement.
  // Évite de conserver les anciennes PS/offsets après un passage linéaire/zonal.
  if (st.natureEnabled &&
      st.natureSelection?.nature == NatureTirType.ponctuel &&
      !st.autrePieces) {
    final int baseCoups = (st.natureSelection?.nbCoups ?? 1).clamp(1, 400);

    stN.setAutrePiecesEnabled(false);
    stN.setSelectedLinearRoles(const <String>[]);
    stN.setCoupsParPieceByPiece(<String, int>{'PD': baseCoups});
    return;
  }

  final Color surface = dark ? TirColors.cardDark : TirColors.cardLight;
  final Color border =
      dark ? TirColors.cardBorderDark : TirColors.cardBorderLight;
  final Color textPrimary =
      dark ? Colors.white.withValues(alpha: 0.92) : Colors.black87;
  final Color textSecondary = dark ? Colors.white70 : Colors.black54;

  final selZ = st.natureSelection;

  final bool isZonal200x200Force = selZ != null &&
      selZ.nature == NatureTirType.zonal &&
      selZ.zonalMode == ZonalMode.force &&
      isZonalSquare3x3(selZ);

  int computeTotalCoupsForRoles(Set<String> roles) {
    final int baseCoups = (st.natureSelection?.nbCoups ?? 1).clamp(1, 400);

    final bool isPonctuel = selZ?.nature == NatureTirType.ponctuel;
    if (isPonctuel) {
      final cleanedRoles = roles
          .map((e) => e.trim().toUpperCase())
          .where((e) => e.isNotEmpty)
          .toSet();

      if (!st.autrePieces || cleanedRoles.length <= 1) {
        return baseCoups;
      }

      final int piecesCount = cleanedRoles.length.clamp(
        1,
        allLinearRoles.length,
      );
      return (baseCoups * piecesCount).clamp(1, 9999);
    }

    if (isZonal200x200Force) return 9;

    final bool isZonal = selZ?.nature == NatureTirType.zonal;
    if (isZonal) return baseCoups;

    final int piecesCount = roles.length.clamp(1, allLinearRoles.length);
    return (baseCoups * piecesCount).clamp(1, 9999);
  }

  // À chaque ouverture zonale : aucune ancienne PS n'est reprise.
  // Le catalogue reste complet, mais seule la PD est présélectionnée.
  List<PieceSoutien> currentPiecesSoutien = const <PieceSoutien>[];
  Set<String> selectedRoles = <String>{'PD'};

  final availableZonalRoles = _selectableFireRoles(st.piecesSoutien);

  List<String> zonalDoctrinalOrderFromRoles(Set<String> roles) {
    const docOrder = ['PS7', 'PS6', 'PS5', 'PD', 'PS1', 'PS2', 'PS3', 'PS4'];
    return docOrder.where(roles.contains).toList();
  }

  List<String> orderedNow() => zonalDoctrinalOrderFromRoles(selectedRoles);

  Map<String, int> coups = Map<String, int>.from(st.coupsParPieceByPiece);

  Map<String, int> normalizeNow() => normalizeSafely(
        current: coups,
        orderedPieces: orderedNow(),
        totalCoups: computeTotalCoupsForRoles(selectedRoles),
      );

  coups = normalizeNow();

  Future<void> openRepartitionDialog(StateSetter setLocal) async {
    final ordered = orderedNow();
    if (ordered.isEmpty) return;

    final notifier = ref.read(coupsParPieceByPieceProvider.notifier);
    notifier.setAll(coups);

    final result = await showDialog<CoupsRepartitionResult>(
      context: context,
      useRootNavigator: false,
      builder: (_) => CoupsRepartitionDialog(
        totalCoups: computeTotalCoupsForRoles(selectedRoles),
        piecesOrdered: ordered,
        dark: dark,
      ),
    );

    if (result == null) return;

    final normalized = normalizeSafely(
      current: result.coupsParPiece,
      orderedPieces: orderedNow(),
      totalCoups: computeTotalCoupsForRoles(selectedRoles),
    );

    notifier.setAll(normalized);
    setLocal(() {
      coups = normalized;
    });
  }

  bool validated = false;
  bool nomadeExterne = false;

  await showDialog<void>(
    context: context,
    useRootNavigator: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return responsiveDialogShell(
            ctx: ctx,
            surface: surface,
            border: border,
            maxWidth: 760,
            child: zonal_cfg.ZonalFireConfigCard(
              allPieces: availableZonalRoles,
              sectionSize: availableZonalRoles.length,
              sectionLabel: 'Sous-ensemble',
              formationLabel: 'Formation',
              initialSelection: sortRolesForStorage(selectedRoles),
              initialNomade: nomadeExterne,
              dark: dark,
              totalCoups: computeTotalCoupsForRoles(selectedRoles),
              coupsParPiece: coups,
              onOpenRepartition: () async {
                await openRepartitionDialog(setLocal);
              },
              onChanged: (result) {
                setLocal(() {
                  selectedRoles = sortRolesForStorage(
                    result.selectedRoles,
                  ).where(availableZonalRoles.contains).toSet();
                  nomadeExterne = result.nomadeExterne;
                  currentPiecesSoutien = _existingPiecesFromRoles(
                    roles: selectedRoles,
                    existing: st.autrePieces
                        ? st.piecesSoutien
                        : const <PieceSoutien>[],
                  );
                  coups = normalizeNow();
                });
              },
              onCancel: () => Navigator.of(ctx).pop(),
              onValidate: (result) {
                setLocal(() {
                  selectedRoles = sortRolesForStorage(
                    result.selectedRoles,
                  ).where(availableZonalRoles.contains).toSet();
                  nomadeExterne = result.nomadeExterne;
                  currentPiecesSoutien = _existingPiecesFromRoles(
                    roles: selectedRoles,
                    existing: st.autrePieces
                        ? st.piecesSoutien
                        : const <PieceSoutien>[],
                  );
                  coups = normalizeNow();
                });
                validated = true;
                Navigator.of(ctx).pop();
              },
            ),
          );
        },
      );
    },
  );

  if (!context.mounted) return;
  if (!validated) return;

  final normalized = normalizeSafely(
    current: coups,
    orderedPieces: orderedNow(),
    totalCoups: computeTotalCoupsForRoles(selectedRoles),
  );

  final selectedSupports = selectedRoles
      .map((e) => e.trim().toUpperCase())
      .where((e) => e != 'PD' && e.isNotEmpty)
      .toSet();

  if (selectedSupports.isEmpty) {
    stN.setAutrePiecesEnabled(false);
    stN.setPiecesSoutien(const <PieceSoutien>[]);
    stN.setCoupsParPieceByPiece(<String, int>{
      'PD': computeTotalCoupsForRoles({'PD'}),
    });
    return;
  }

  stN.setCoupsParPieceByPiece(Map<String, int>.from(normalized));

  if (!context.mounted) return;

  final positioned = await openPositionsPiecesDialog(
    context: context,
    dark: dark,
    selectedRoles: selectedRoles,
    existingPieces: st.autrePieces ? st.piecesSoutien : const <PieceSoutien>[],
    surface: surface,
    border: border,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    preserveExistingValues: false,
  );

  if (!context.mounted) return;
  if (positioned == null) return;
  stN.setAutrePiecesEnabled(positioned.isNotEmpty);
  stN.setPiecesSoutien(positioned);
}
