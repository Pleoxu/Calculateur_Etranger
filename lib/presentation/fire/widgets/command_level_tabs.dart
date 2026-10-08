import 'package:flutter/material.dart';
import 'package:calculateur_etranger/domain/fire/models/fire_command_level.dart';

class CommandLevelTabs extends StatelessWidget {
  final FireCommandLevel selected;
  final ValueChanged<FireCommandLevel> onChanged;

  const CommandLevelTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isRgt = selected == FireCommandLevel.rgt;

    return TextButton(
      onPressed: () =>
          onChanged(isRgt ? FireCommandLevel.ue : FireCommandLevel.rgt),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: _App6Symbol(
        bars: isRgt ? 3 : 1,
        color: Colors.white.withValues(alpha: 0.92),
      ),
    );
  }
}

class _App6Symbol extends StatelessWidget {
  final int bars;
  final Color color;

  const _App6Symbol({required this.bars, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 30,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 11,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                bars,
                (_) => Container(
                  width: 2.5,
                  height: 11,
                  margin: const EdgeInsets.symmetric(horizontal: 1.6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 30,
            height: 16,
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 1.5),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}
