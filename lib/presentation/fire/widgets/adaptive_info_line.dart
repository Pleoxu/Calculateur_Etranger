import 'package:flutter/material.dart';

class AdaptiveInfoLine extends StatelessWidget {
  const AdaptiveInfoLine({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}
