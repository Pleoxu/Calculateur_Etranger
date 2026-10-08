import 'package:flutter/material.dart';

class FirePieceSelector extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const FirePieceSelector({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const Color _bgInactive = Color(0xFF1A1F26);
  static const Color _bgActive = Color(0xFF2F6F55);
  static const Color _border = Color(0xFF3A4048);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? _bgActive : _bgInactive,
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 16, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w600, // ✅ plus lisible
              ),
            ),
          ],
        ),
      ),
    );
  }
}
