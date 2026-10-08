import 'package:flutter/material.dart';

class NatureTirSwitchDoctrine extends StatelessWidget {
  const NatureTirSwitchDoctrine({
    super.key,
    required this.value,
    required this.onChanged,
    required this.activeThumbColor,
    required this.inactiveThumbColor,
    required this.inactiveTrackColor,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeThumbColor;
  final Color inactiveThumbColor;
  final Color inactiveTrackColor;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.8,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: activeThumbColor,
        inactiveThumbColor: inactiveThumbColor,
        inactiveTrackColor: inactiveTrackColor,
      ),
    );
  }
}
