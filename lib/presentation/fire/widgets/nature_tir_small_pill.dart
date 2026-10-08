import 'package:flutter/material.dart';
import 'package:calculateur_etranger/presentation/theme/tir_tokens.dart';

class NatureTirSmallPill extends StatelessWidget {
  const NatureTirSmallPill({
    super.key,
    required this.label,
    required this.isOn,
    required this.onTap,
    required this.activeColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  final String label;
  final bool isOn;
  final VoidCallback onTap;
  final Color activeColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final bg = isOn ? activeColor.withValues(alpha: 0.25) : backgroundColor;
    final bd = isOn ? activeColor : borderColor;
    final fg = isOn ? activeColor : textColor;

    return InkWell(
      borderRadius: BorderRadius.circular(TirRadius.m),
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(TirRadius.m),
          border: Border.all(color: bd),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: isOn ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}
