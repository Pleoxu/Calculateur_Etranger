// lib/presentation/fire/dialogs/masse_et_charge_dialogs.dart
//
// Dialogues liés à la masse obus (carreaux) et à la charge forcée.

import 'package:flutter/material.dart';

/// Ouvre un dialogue pour choisir le nombre de carreaux.
/// [minCarreaux] et [maxCarreaux] définissent la plage (Caesar: 1-8, MO-120/MEPAC: 1-3).
/// Retourne la nouvelle valeur ou null si annulé.
Future<int?> showCarreauxDialog({
  required BuildContext context,
  required bool dark,
  required int initialCarreaux,
  int minCarreaux = 1,
  int maxCarreaux = 8,
}) async {
  int temp = initialCarreaux.clamp(minCarreaux, maxCarreaux);

  final btnBg = dark ? const Color(0xFF3A3B3E) : Colors.grey.shade300;
  final iconColor = dark ? Colors.white : Colors.black87;
  final dialogBg = dark ? const Color(0xFF232427) : Colors.white;
  final textColor =
      dark ? Colors.white.withValues(alpha: 0.92) : Colors.black87;
  final subText = dark ? Colors.white70 : Colors.black54;
  const paleGreen = Color(0xFFBDECC1);

  final picked = await showDialog<int>(
    context: context,
    useRootNavigator: false,
    builder: (_) => StatefulBuilder(
      builder: (_, setStateDialog) => AlertDialog(
        backgroundColor: dialogBg,
        surfaceTintColor: Colors
            .transparent, // important en Material3 pour éviter le "tint" clair
        title: Text('Shell mass', style: TextStyle(color: textColor)),
        content: SizedBox(
          width: 320,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Material(
                color: btnBg,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    if (temp > minCarreaux) {
                      temp--;
                      setStateDialog(() {});
                    }
                  },
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.remove, color: iconColor),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Carreaux: $temp',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$minCarreaux to $maxCarreaux',
                    style: TextStyle(color: subText, fontSize: 12.5),
                  ),
                ],
              ),
              Material(
                color: btnBg,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    if (temp < maxCarreaux) {
                      temp++;
                      setStateDialog(() {});
                    }
                  },
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.add, color: iconColor),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            style: TextButton.styleFrom(foregroundColor: paleGreen),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, temp),
            style: TextButton.styleFrom(foregroundColor: paleGreen),
            child: const Text('OK'),
          ),
        ],
      ),
    ),
  );

  return picked;
}

/// Ouvre un dialogue pour forcer la charge MO-120 (CH0 à CH10).
/// Retourne la charge choisie sous forme de String (ex. 'CH0', 'CH1/2', 'CH10')
/// ou null si annulé.
Future<String?> showChargeMo120Dialog({
  required BuildContext context,
  required bool dark,
  String? initialCharge,
}) async {
  const List<String> charges = [
    'CH0',
    'CH1/2',
    'CH1',
    'CH1½',
    'CH2',
    'CH2½',
    'CH3',
    'CH4',
    'CH5',
    'CH6',
    'CH7',
    'CH8',
    'CH9',
    'CH10',
  ];

  String tmp = (initialCharge != null && charges.contains(initialCharge))
      ? initialCharge
      : 'CH3';

  final dialogBg = dark ? const Color(0xFF232427) : Colors.white;
  final textColor =
      dark ? Colors.white.withValues(alpha: 0.92) : Colors.black87;
  final borderColor = dark ? Colors.white24 : Colors.black26;
  final fieldBg = dark ? const Color(0xFF111318) : const Color(0xFFF2F3F5);
  final iconColor = dark ? Colors.white70 : Colors.black54;
  const mint = Color(0xFF2EE6A6);

  final picked = await showDialog<String>(
    context: context,
    useRootNavigator: false,
    builder: (_) {
      return AlertDialog(
        backgroundColor: dialogBg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Force MO-120 charge',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
        ),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Container(
              padding: const EdgeInsets.only(top: 4),
              width: 340,
              child: InputDecorator(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: fieldBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: dark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: tmp,
                    isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down, color: iconColor),
                    dropdownColor: dialogBg,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    items: charges
                        .map(
                          (ch) => DropdownMenuItem<String>(
                            value: ch,
                            child: Text(ch),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        tmp = v;
                        setStateDialog(() {});
                      }
                    },
                  ),
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            style: TextButton.styleFrom(
              foregroundColor: dark ? Colors.white70 : Colors.black54,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, tmp),
            style: TextButton.styleFrom(foregroundColor: mint),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );

  return picked;
}

/// Ouvre un dialogue pour forcer la charge (CH1..CH6).
/// Retourne la charge choisie (1..6) ou null si annulé.
Future<int?> showChargeDialog({
  required BuildContext context,
  required bool dark,
  int? initialCharge,
}) async {
  int tmp = (initialCharge ?? 4).clamp(1, 6);

  final dialogBg = dark ? const Color(0xFF232427) : Colors.white;
  final textColor =
      dark ? Colors.white.withValues(alpha: 0.92) : Colors.black87;
  final borderColor = dark ? Colors.white24 : Colors.black26;
  final fieldBg = dark ? const Color(0xFF111318) : const Color(0xFFF2F3F5);
  final iconColor = dark ? Colors.white70 : Colors.black54;

  // Vert “mint” cohérent avec ton UI
  const mint = Color(0xFF2EE6A6);

  final picked = await showDialog<int>(
    context: context,
    useRootNavigator: false, // ✅ important: rester dans le Theme local
    builder: (_) {
      return AlertDialog(
        backgroundColor: dialogBg,
        surfaceTintColor: Colors.transparent, // ✅ évite le tint clair Material3
        title: Text(
          'Force charge',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
        ),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Container(
              padding: const EdgeInsets.only(top: 4),
              width: 340,
              child: InputDecorator(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: fieldBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: dark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: tmp,
                    isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down, color: iconColor),
                    dropdownColor: dialogBg, // ✅ menu en dark
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    items: List.generate(6, (i) => i + 1)
                        .map(
                          (ch) => DropdownMenuItem<int>(
                            value: ch,
                            child: Text('CH$ch'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        tmp = v;
                        setStateDialog(() {});
                      }
                    },
                  ),
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            style: TextButton.styleFrom(
              foregroundColor: dark ? Colors.white70 : Colors.black54,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, tmp),
            style: TextButton.styleFrom(foregroundColor: mint),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );

  return picked;
}
