import 'package:flutter/material.dart';

import 'tir_tokens.dart';

abstract final class AppTheme {
  static const Color _seed = Color(0xFF315C49);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );

    return _build(scheme: scheme, brightness: Brightness.light);
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );

    return _build(scheme: scheme, brightness: Brightness.dark);
  }

  static ThemeData _build({
    required ColorScheme scheme,
    required Brightness brightness,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );

    final fieldBorder = OutlineInputBorder(
      borderRadius: TirRadius.field,
      borderSide: BorderSide(color: scheme.outlineVariant),
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: TirRadius.card,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TirSpacing.m,
          vertical: TirSpacing.m,
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: TirRadius.field,
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: TirRadius.field,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: TirRadius.field,
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, TirSizes.actionHeight),
          shape: RoundedRectangleBorder(
            borderRadius: TirRadius.l == 0
                ? BorderRadius.zero
                : const BorderRadius.all(Radius.circular(TirRadius.l)),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, TirSizes.actionHeight),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(TirRadius.l)),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
    );
  }
}
