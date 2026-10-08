
import 'package:flutter/material.dart';

enum VerificationStatus {
  invalid,
  pending,
  available,
  unavailable,
}

class VerificationStatusBanner extends StatelessWidget {
  const VerificationStatusBanner({
    super.key,
    required this.status,
    this.message,
  });

  final VerificationStatus status;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final (icon, color, defaultMessage) = switch (status) {
      VerificationStatus.invalid => (
          Icons.error_outline,
          Colors.orange,
          'Saisie invalide',
        ),
      VerificationStatus.pending => (
          Icons.hourglass_top,
          Colors.blue,
          'Vérification en cours',
        ),
      VerificationStatus.available => (
          Icons.info_outline,
          Colors.green,
          'Résultat disponible',
        ),
      VerificationStatus.unavailable => (
          Icons.warning_amber_rounded,
          Colors.orange,
          'Vérification indisponible',
        ),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: dark ? 0.16 : 0.09),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message ?? defaultMessage,
                style: TextStyle(
                  color: dark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
