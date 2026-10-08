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

  IconData get _icon {
    switch (selected) {
      case PdPositionSource.manual:
        return Icons.face;
      case PdPositionSource.gpsAtlas:
        return Icons.navigation;
      case PdPositionSource.radioPct:
        return Icons.bolt;
    }
  }

  String get _tooltip {
    switch (selected) {
      case PdPositionSource.manual:
        return 'PD manuelle';
      case PdPositionSource.gpsAtlas:
        return 'PD GPS / ATLAS';
      case PdPositionSource.radioPct:
        return 'PD radio PCT';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _tooltip,
      child: TextButton(
        onPressed: () => onChanged(_next(selected)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          backgroundColor: dark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFF0F1F3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Icon(
          _icon,
          size: 18,
          color: dark ? Colors.white.withValues(alpha: 0.92) : Colors.black87,
        ),
      ),
    );
  }
}
