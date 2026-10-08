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
    return SizedBox(
      width: 60,
      height: 48,
      child: Center(
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: activeThumbColor,
          inactiveThumbColor: inactiveThumbColor,
          inactiveTrackColor: inactiveTrackColor,
        ),
      ),
    );
  }
}
