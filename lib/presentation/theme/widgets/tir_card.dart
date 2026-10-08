import 'package:flutter/material.dart';

import '../tir_tokens.dart';

enum TirCardVariant { standard, highlight, warning }

class TirCard extends StatelessWidget {
  const TirCard({
    super.key,
    required this.child,
    this.variant = TirCardVariant.standard,
    this.padding = const EdgeInsets.all(TirSpacing.l),
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final TirCardVariant variant;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    late final Color background;
    late final Color border;

    switch (variant) {
      case TirCardVariant.standard:
        // Surface volontairement neutre :
        // aucune teinte verte issue du ColorScheme Material.
        background = dark ? TirColors.cardDark : TirColors.cardLight;

        border = dark ? TirColors.cardBorderDark : TirColors.cardBorderLight;
        break;

      case TirCardVariant.highlight:
        // Le vert n'est utilisé que lorsqu'une carte doit réellement
        // signaler un état particulier.
        background = dark
            ? TirColors.activeDark.withValues(alpha: 0.08)
            : TirColors.activeLight.withValues(alpha: 0.07);

        border = dark
            ? TirColors.activeDark.withValues(alpha: 0.45)
            : TirColors.activeLight.withValues(alpha: 0.35);
        break;

      case TirCardVariant.warning:
        background = dark
            ? TirColors.warningDark.withValues(alpha: 0.08)
            : TirColors.warningLight.withValues(alpha: 0.07);

        border = dark
            ? TirColors.warningDark.withValues(alpha: 0.55)
            : TirColors.warningLight.withValues(alpha: 0.45);
        break;
    }

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: TirRadius.card,
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}
