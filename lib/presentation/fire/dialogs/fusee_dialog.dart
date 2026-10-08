// lib/presentation/fire/dialogs/fusee_dialog.dart

import 'package:flutter/material.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';

/// Ouvre le sélecteur avec les seules fusées autorisées par la munition active.
///
/// La politique métier est résolue avant l'ouverture par [OptionsTirList]. Le
/// dialogue reste toutefois défensif : une valeur initiale non compatible est
/// remplacée par la première valeur autorisée et aucun autre choix n'est rendu.
Future<TypeFusee?> showFuseeDialog({
  required BuildContext context,
  required bool dark,
  required TypeFusee initial,
  required List<TypeFusee> fuseesAutorisees,
}) async {
  assert(fuseesAutorisees.isNotEmpty);

  final choix = List<TypeFusee>.unmodifiable(fuseesAutorisees);
  TypeFusee tmp = choix.contains(initial) ? initial : choix.first;

  const Color mint = Color(0xFF2A6B57);
  const Color mintSoft = Color(0xFFBFF5D9);

  final picked = await showDialog<TypeFusee?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      Widget pill({
        required TypeFusee fusee,
        required bool selected,
        required VoidCallback onTap,
      }) {
        return SizedBox(
          width: 190,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 44,
              decoration: BoxDecoration(
                color:
                    selected ? mint : (dark ? Colors.white10 : Colors.black12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? mint
                      : (dark ? Colors.white24 : Colors.black26),
                ),
              ),
              child: Center(
                child: Text(
                  fusee.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? mintSoft
                        : (dark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: dark ? const Color(0xFF111417) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: dark ? Colors.white12 : Colors.black12),
            ),
            title: Text(
              'Fuze selection',
              style: TextStyle(
                color: dark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final fusee in choix)
                        pill(
                          fusee: fusee,
                          selected: tmp == fusee,
                          onTap: () => setState(() => tmp = fusee),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: Text(
                  'Abandonner',
                  style: TextStyle(
                    color: dark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: mint,
                  foregroundColor: mintSoft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(tmp),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    },
  );

  return picked;
}
