import 'package:flutter/material.dart';
import 'package:calculateur_etranger/presentation/theme/tir_tokens.dart';

class NatureTirRow extends StatelessWidget {
  const NatureTirRow({
    super.key,
    required this.label,
    required this.child,
    required this.labelColor,
  });

  final String label;
  final Widget child;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 260) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: labelColor, fontSize: 12.5)),
              const SizedBox(height: TirSpacing.s),
              SizedBox(width: double.infinity, child: child),
            ],
          );
        }

        return Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: TextStyle(color: labelColor, fontSize: 12.5),
              ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
