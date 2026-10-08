import 'package:flutter/material.dart';
import 'package:calculateur_etranger/presentation/theme/tir_tokens.dart';

class NatureTirIntPicker extends StatelessWidget {
  const NatureTirIntPicker({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _iconButton(
              icon: Icons.remove,
              onPressed: () => onChanged((value - 1).clamp(min, max)),
            ),
            const SizedBox(width: TirSpacing.s),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 20),
              child: Text(
                value.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: TirSpacing.s),
            _iconButton(
              icon: Icons.add,
              onPressed: () => onChanged((value + 1).clamp(min, max)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(TirRadius.m),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(TirRadius.m),
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, color: textColor, size: 18),
      ),
    );
  }
}
