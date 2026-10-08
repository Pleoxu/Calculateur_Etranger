// lib/presentation/fire/dialogs/tir_similaire_dialog.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';

class TirSimilaireResult {
  final int carreaux;
  final TypeFusee fusee;
  final double? tPrev;
  final double? tAct;
  final double? v0Prev;

  const TirSimilaireResult({
    required this.carreaux,
    required this.fusee,
    this.tPrev,
    this.tAct,
    this.v0Prev,
  });
}

Future<TirSimilaireResult?> showTirSimilaireDialog({
  required BuildContext context,
  required bool dark,
  required int initialCarreaux,
  TypeFusee initialFusee = TypeFusee.frappe,
  List<TypeFusee> fuseesDisponibles = const <TypeFusee>[
    TypeFusee.frappe,
    TypeFusee.ralec,
  ],
  String? imposedFuzeLabel,
  double? initialTPrev,
  double? initialTAct,
  double? initialV0,
  int minCarreaux = 1,
  int maxCarreaux = 8,
}) async {
  // Conserve la valeur déjà enregistrée pour le tir similaire.
  // Le bornage garantit simplement qu'elle reste compatible avec
  // la plage du système actuellement sélectionné.
  int tempCar = initialCarreaux.clamp(minCarreaux, maxCarreaux);

  double? tPrev = initialTPrev;
  double? tAct = initialTAct;
  double? v0 = initialV0;

  final fusees = fuseesDisponibles.isEmpty
      ? const <TypeFusee>[TypeFusee.frappe, TypeFusee.ralec]
      : fuseesDisponibles;
  final imposedLabel = imposedFuzeLabel?.trim();
  final hasImposedFuze = imposedLabel != null && imposedLabel.isNotEmpty;

  TypeFusee tempFusee =
      fusees.contains(initialFusee) ? initialFusee : fusees.first;

  const mint = Color(0xFF2EE6A6);

  final bg = dark ? const Color(0xFF12141A) : Colors.white;
  final border = dark ? Colors.white.withValues(alpha: 0.12) : Colors.black12;

  final textPrimary =
      dark ? Colors.white.withValues(alpha: 0.92) : Colors.black87;
  final textSecondary = dark ? Colors.white70 : Colors.black54;

  final chipBg =
      dark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F1F3);
  final chipBd = dark
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.black.withValues(alpha: 0.10);

  final actionBg = dark ? const Color(0xFF0E0F12) : Colors.black;

  final tPrevCtrl = TextEditingController(text: initialTPrev?.toString() ?? '');
  final tActCtrl = TextEditingController(text: initialTAct?.toString() ?? '');
  final v0Ctrl = TextEditingController(text: initialV0?.toString() ?? '');

  double? parseNum(String s) {
    final v = s.trim().replaceAll(',', '.');
    if (v.isEmpty) return null;
    return double.tryParse(v);
  }

  InputDecoration deco(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: dark ? const Color(0xFF111318) : const Color(0xFFF7F8FA),
        labelStyle: TextStyle(color: textSecondary),
        floatingLabelStyle: TextStyle(color: textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dark ? Colors.white54 : Colors.black54),
        ),
      );

  Widget stepBtn(String s, VoidCallback? onTap) {
    return TextButton(
      onPressed: onTap,
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(chipBg),
        side: WidgetStatePropertyAll(BorderSide(color: chipBd)),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(22)),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      child: Text(
        s,
        style: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  ButtonStyle pillOutlined() => OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      );

  ButtonStyle pillPrimary() => TextButton.styleFrom(
        backgroundColor: actionBg,
        foregroundColor: mint,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      );

  final res = await showDialog<TirSimilaireResult>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: true,
    builder: (ctx) {
      final w = MediaQuery.of(ctx).size.width;
      final h = MediaQuery.of(ctx).size.height;
      final maxW = math.min(560.0, math.max(0.0, w - 24.0));
      final maxH = math.max(260.0, h * 0.85);

      return StatefulBuilder(
        builder: (ctx, setSD) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Text(
                            'Similar fire',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Square Weight: $tempCar',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            stepBtn(
                              '–',
                              tempCar <= minCarreaux
                                  ? null
                                  : () => setSD(() => tempCar--),
                            ),
                            const SizedBox(width: 18),
                            stepBtn(
                              '+',
                              tempCar >= maxCarreaux
                                  ? null
                                  : () => setSD(() => tempCar++),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(color: border, height: 18),
                        if (hasImposedFuze)
                          InputDecorator(
                            decoration: deco('Previous fire fuze'),
                            child: Text(
                              '$imposedLabel — defined by the M252 cartridge profile',
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          DropdownButtonFormField<TypeFusee>(
                            initialValue: tempFusee,
                            decoration: deco('Previous fire fuze'),
                            dropdownColor: bg,
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            items: fusees
                                .map(
                                  (fusee) => DropdownMenuItem<TypeFusee>(
                                    value: fusee,
                                    child: Text(fusee.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setSD(() => tempFusee = value);
                              }
                            },
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: tPrevCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          cursorColor: textPrimary,
                          decoration: deco('Previous temp. (°C)'),
                          onChanged: (v) {
                            tPrev = parseNum(v);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: tActCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          cursorColor: textPrimary,
                          decoration: deco('Current temp. (°C)'),
                          onChanged: (v) {
                            tAct = parseNum(v);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: v0Ctrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          cursorColor: textPrimary,
                          decoration: deco('Previous measured V0 (m/s)'),
                          onChanged: (v) {
                            v0 = parseNum(v);
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ex: 943,4 (comma accepted)',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: pillOutlined(),
                                onPressed: () {
                                  Navigator.of(ctx).pop(null);
                                },
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextButton(
                                style: pillPrimary(),
                                onPressed: () {
                                  Navigator.of(ctx).pop(
                                    TirSimilaireResult(
                                      carreaux: tempCar,
                                      fusee: tempFusee,
                                      tPrev: tPrev,
                                      tAct: tAct,
                                      v0Prev: v0,
                                    ),
                                  );
                                },
                                child: const Text('OK'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );

  return res;
}
