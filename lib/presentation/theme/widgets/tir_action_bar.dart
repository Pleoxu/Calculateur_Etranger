import 'package:flutter/material.dart';

import '../tir_tokens.dart';

class TirActionBar extends StatelessWidget {
  const TirActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.busy = false,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.primaryIcon,
    this.secondaryIcon,
  });

  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final bool busy;

  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;

  final IconData? primaryIcon;
  final IconData? secondaryIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    final neutralBackground =
        dark ? TirColors.actionDark : TirColors.actionLight;

    final neutralBorder =
        dark ? TirColors.cardBorderDark : TirColors.cardBorderLight;

    final primary = SizedBox(
      width: double.infinity,
      height: TirSizes.actionHeight,
      child: FilledButton(
        onPressed: busy ? null : onPrimaryPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.disabled)) {
              return neutralBackground.withValues(alpha: 0.55);
            }

            if (states.contains(WidgetState.pressed)) {
              return dark ? const Color(0xFF353940) : const Color(0xFFD9DBDF);
            }

            if (states.contains(WidgetState.hovered)) {
              return dark ? const Color(0xFF30343A) : const Color(0xFFDFE1E5);
            }

            return neutralBackground;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.onSurface.withValues(alpha: 0.45);
            }
            return colors.onSurface;
          }),
          overlayColor: WidgetStatePropertyAll(
            colors.onSurface.withValues(alpha: 0.05),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: neutralBorder)),
          elevation: const WidgetStatePropertyAll(0),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(TirRadius.l)),
            ),
          ),
        ),
        child: busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.onSurfaceVariant,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (primaryIcon != null) ...[
                    Icon(primaryIcon, size: 18),
                    const SizedBox(width: TirSpacing.s),
                  ],
                  Text(primaryLabel),
                ],
              ),
      ),
    );

    final secondaryVisible =
        secondaryLabel != null && onSecondaryPressed != null;

    if (!secondaryVisible) {
      return primary;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        primary,
        const SizedBox(height: TirSpacing.s),
        SizedBox(
          height: TirSizes.actionHeight,
          child: OutlinedButton(
            onPressed: busy ? null : onSecondaryPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.onSurface,
              side: BorderSide(color: neutralBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (secondaryIcon != null) ...[
                  Icon(secondaryIcon, size: 18),
                  const SizedBox(width: TirSpacing.s),
                ],
                Text(secondaryLabel!),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
