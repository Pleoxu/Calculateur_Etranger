import 'package:flutter/material.dart';

abstract final class TirSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class TirRadius {
  static const double s = 6;
  static const double m = 10;
  static const double l = 14;
  static const double xl = 18;

  static const BorderRadius card = BorderRadius.all(Radius.circular(l));

  static const BorderRadius field = BorderRadius.all(Radius.circular(m));
}

abstract final class TirBreakpoints {
  /// Téléphone / petite fenêtre.
  static const double compact = 600;

  /// Tablette / fenêtre intermédiaire.
  static const double medium = 840;

  /// Grande tablette / desktop.
  static const double expanded = 1200;
}

abstract final class TirSizes {
  static const double maxContentWidth = 1180;

  static const double fieldHeight = 48;
  static const double actionHeight = 48;

  /// Certains dialogues historiques utilisent une action plus compacte.
  /// Conservé pour éviter un changement visuel implicite 46 -> 48.
  static const double compactActionHeight = 46;

  static const double iconButtonSize = 40;
}

abstract final class TirColors {
  // Surfaces neutres — alignées sur les cartouches historiques validés.
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF12141A);

  static const Color cardBorderLight = Color(0x1A000000);
  static const Color cardBorderDark = Color(0x1AFFFFFF);

  // Bordure secondaire plus présente, utilisée dans les configurations.
  static const Color secondaryBorderDark = Color(0xFF3A4048);

  // Actions neutres.
  static const Color actionLight = Color(0xFFE7E8EC);
  static const Color actionDark = Color(0xFF2A2E35);

  // Champs.
  static const Color fieldLight = Color(0xFFF4F5F7);
  static const Color fieldDark = Color(0xFF1B1E24);

  static const Color fieldBorderLight = Color(0xFFD9DCE1);
  static const Color fieldBorderDark = Color(0xFF353941);

  // Fond général.
  static const Color backgroundLight = Color(0xFFF4F5F7);
  static const Color backgroundDark = Color(0xFF0E0F12);

  // États actifs.
  /// Le vert est réservé aux états actifs / validations.
  static const Color activeLight = Color(0xFF1A9E72);
  static const Color activeDark = Color(0xFF2EE6A6);

  // États de mode historiques des cartes linéaire / zonale.
  static const Color modeIdle = Color(0xFF1A1F26);
  static const Color modeActive = Color(0xFF2F6F55);

  // Action de confirmation historique des dialogues de configuration.
  static const Color confirmBackground = Color(0xFF0B0D11);
  static const Color confirmForeground = Color(0xFF4FAF7A);
  static const Color actionMuted = Color(0xFF7E8791);

  // Avertissements.
  static const Color warningLight = Color(0xFFB05E00);
  static const Color warningDark = Color(0xFFFFBD59);

  /// Bordure orange forte utilisée pour les avertissements de saisie.
  static const Color warningBorder = Color(0xFFFF9500);

  // Erreurs.
  static const Color errorLight = Color(0xFFBA1A1A);
  static const Color errorDark = Color(0xFFFFB4AB);
}
