import 'package:flutter/material.dart';

class TirRepartitionLegend extends StatelessWidget {
  const TirRepartitionLegend({
    super.key,
    required this.orderedIds,
    required this.pieceColors,
    required this.textColor,
  });

  final List<String> orderedIds;
  final Map<String, Color> pieceColors;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    if (pieceColors.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          for (final id in orderedIds)
            if (pieceColors.containsKey(id))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: pieceColors[id]!,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    id,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}
