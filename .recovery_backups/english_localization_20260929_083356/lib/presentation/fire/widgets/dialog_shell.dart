import 'dart:math' as math;
import 'package:flutter/material.dart';

class DialogShell extends StatefulWidget {
  final bool dark;
  final Color surface;
  final Color border;

  final Widget child;

  /// maxWidth desktop/tablette, mais responsive sur mobile
  final double maxWidth;

  /// fraction de hauteur max (évite overflow clavier/petit écran)
  final double maxHeightFactor;

  const DialogShell({
    super.key,
    required this.dark,
    required this.surface,
    required this.border,
    required this.child,
    this.maxWidth = 640,
    this.maxHeightFactor = 0.85,
  });

  @override
  State<DialogShell> createState() => _DialogShellState();
}

class _DialogShellState extends State<DialogShell> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _dialogWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    // 12 + 12 d'insetPadding => on retire 24
    final available = math.max(0.0, w - 24.0);
    return math.min(widget.maxWidth, available);
  }

  @override
  Widget build(BuildContext context) {
    final width = _dialogWidth(context);

    final h = MediaQuery.of(context).size.height;
    final maxH = math.max(260.0, h * widget.maxHeightFactor);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width, maxHeight: maxH),
          child: Container(
            width: width,
            decoration: BoxDecoration(
              color: widget.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: widget.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: LayoutBuilder(
                builder: (context, c) {
                  // ✅ Fix robuste :
                  // Ne PAS fournir controller au Scrollbar (sinon assert si pas encore attaché).
                  // On garde le controller uniquement sur le SingleChildScrollView.
                  return Scrollbar(
                    thumbVisibility: false,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: ConstrainedBox(
                        // ✅ évite certains overflows/contraintes bizarres
                        constraints: BoxConstraints(minWidth: c.maxWidth),
                        child: widget.child,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barre de boutons façon “Nature du tir”
class DialogActionBar extends StatelessWidget {
  final Color border;
  final Color textPrimary;

  final Color mint;
  final VoidCallback onCancel;
  final VoidCallback onOk;
  final String cancelLabel;
  final String okLabel;

  const DialogActionBar({
    super.key,
    required this.border,
    required this.textPrimary,
    required this.mint,
    required this.onCancel,
    required this.onOk,
    this.cancelLabel = 'Annuler',
    this.okLabel = 'OK',
  });

  static const Color _okBgDark = Color(0xFF2A2E35);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: textPrimary,
              side: BorderSide(color: border),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              minimumSize: const Size.fromHeight(46),
            ),
            onPressed: onCancel,
            child: Text(cancelLabel),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            // ✅ OK : fond gris foncé + texte mint
            style: ElevatedButton.styleFrom(
              backgroundColor: _okBgDark,
              foregroundColor: const Color(0xFF69B886),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              minimumSize: const Size.fromHeight(46),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            onPressed: onOk,
            child: Text(okLabel),
          ),
        ),
      ],
    );
  }
}

/// Helper : petits boutons “texte mint” (Répartir / Normaliser, etc.)
TextButton mintTextButton({
  required Color mint,
  required VoidCallback? onPressed,
  required String label,
}) {
  return TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(foregroundColor: mint),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
  );
}

/// Helper : petits boutons “texte gris” (actions secondaires : Répartir coups, etc.)
TextButton greyTextButton({
  required bool dark,
  required VoidCallback? onPressed,
  required String label,
}) {
  final c = dark ? Colors.white70 : Colors.black54;
  return TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(foregroundColor: c),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
  );
}
