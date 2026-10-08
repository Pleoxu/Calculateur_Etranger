// lib/presentation/fire/widgets/pd_source_tap.dart

import 'package:flutter/material.dart';

import 'package:calculateur_etranger/domain/radio/pd_position_state.dart';

class PdSourceTap extends StatelessWidget {
  final PdPositionSource selected;
  final ValueChanged<PdPositionSource> onChanged;
  final bool dark;

  const PdSourceTap({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.dark,
  });

  PdPositionSource _next(PdPositionSource source) {
    switch (source) {
      case PdPositionSource.manual:
        return PdPositionSource.gpsAtlas;
      case PdPositionSource.gpsAtlas:
        return PdPositionSource.radioPct;
      case PdPositionSource.radioPct:
        return PdPositionSource.manual;
    }
  }

  String get _tooltip {
    switch (selected) {
      case PdPositionSource.manual:
        return 'PD manuelle';
      case PdPositionSource.gpsAtlas:
        return 'PD OPS / GPS-ATLAS';
      case PdPositionSource.radioPct:
        return 'PD radio PCT';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg =
        dark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F1F3);

    final fg = dark ? Colors.white.withValues(alpha: 0.92) : Colors.black87;

    return Tooltip(
      message: _tooltip,
      child: TextButton(
        onPressed: () => onChanged(_next(selected)),
        style: TextButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: bg,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: _PdSourceIcon(source: selected, color: fg),
      ),
    );
  }
}

class _PdSourceIcon extends StatelessWidget {
  final PdPositionSource source;
  final Color color;

  const _PdSourceIcon({required this.source, required this.color});

  @override
  Widget build(BuildContext context) {
    switch (source) {
      case PdPositionSource.manual:
        return CustomPaint(
          size: const Size(34, 34),
          painter: _ManualOperatorPainter(color),
        );

      case PdPositionSource.gpsAtlas:
        return Icon(Icons.navigation_rounded, size: 34, color: color);

      case PdPositionSource.radioPct:
        return Icon(Icons.bolt_rounded, size: 36, color: color);
    }
  }
}

class _ManualOperatorPainter extends CustomPainter {
  final Color color;

  const _ManualOperatorPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // Tête (décalée vers le bas pour aligner la base avec les icônes UE/Rgt)
    canvas.drawCircle(Offset(w * 0.5, h * 0.40), w * 0.16, paint);

    // Buste arrondi
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.28, h * 0.58, w * 0.44, h * 0.34),
      Radius.circular(w * 0.10),
    );
    canvas.drawRRect(body, paint);

    // Bras verticaux internes
    final armPaint = Paint()
      ..color = const Color(0xFF12141A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawLine(
      Offset(w * 0.36, h * 0.72),
      Offset(w * 0.36, h * 1.00),
      armPaint,
    );

    canvas.drawLine(
      Offset(w * 0.64, h * 0.72),
      Offset(w * 0.64, h * 1.00),
      armPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ManualOperatorPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
