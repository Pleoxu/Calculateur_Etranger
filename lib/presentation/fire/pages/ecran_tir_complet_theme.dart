import 'package:flutter/material.dart';

import 'package:calculateur_etranger/presentation/theme/app_theme.dart';
import 'package:calculateur_etranger/presentation/theme/tir_tokens.dart';

/// Thème de compatibilité temporaire pour EcranTirComplet.
///
/// Le mode clair/sombre est encore piloté par `header.dark`.
/// Les anciens paramètres sont conservés temporairement pour ne pas
/// casser les appels existants pendant le refactor.
ThemeData buildLocalTheme({
  required BuildContext context,
  required bool dark,
  required Color card,
  required Color border,
  required Color textPrimary,
  required Color textSecondary,
}) {
  // IMPORTANT :
  // on utilise le même mode clair/sombre que EcranTirComplet.
  //
  // Ainsi TirCard, TirActionBar et les futurs composants qui utilisent
  // Theme.of(context).colorScheme restent cohérents avec l'écran.
  final base = dark ? AppTheme.dark : AppTheme.light;
  final colors = base.colorScheme;

  return base.copyWith(
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(TirRadius.xl)),
      ),
    ),
    dividerTheme: DividerThemeData(color: colors.outlineVariant, thickness: 1),
    iconTheme: IconThemeData(color: colors.onSurfaceVariant),
    inputDecorationTheme: base.inputDecorationTheme,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.primary,
      selectionColor: colors.primary.withValues(alpha: 0.22),
      selectionHandleColor: colors.primary,
    ),
  );
}
