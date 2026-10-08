// lib/presentation/fire/widgets/meteo_validity_dialog.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:calculateur_etranger/domain/meteo/meteo_validity.dart';
import 'package:calculateur_etranger/domain/meteo/meteo_parse_result.dart';

class MeteoValidityDialog {
  static const Color mint = Color(0xFF2EE6A6);

  static Future<bool> show(
    BuildContext context,
    MeteoValidityResult result,
    MeteoTemporalInfo? temporalInfo, {
    required bool dark,
  }) async {
    final title = result.getAlertTitle();
    final message = result.getAlertMessage();

    final blocks = message.split('\n\n');
    final firstBlock = blocks.isNotEmpty ? blocks.first : message;
    final restMessage = blocks.length > 1 ? blocks.sublist(1).join('\n\n') : '';

    final isBlocking = result.status == MeteoValidityStatus.expired;

    final bg = dark ? const Color(0xFF12141A) : Colors.white;
    final border = dark ? Colors.white.withValues(alpha: 0.12) : Colors.black12;

    final textPrimary =
        dark ? Colors.white.withValues(alpha: 0.92) : Colors.black87;
    final textSecondary = dark ? Colors.white70 : Colors.black54;

    final actionBg = dark ? const Color(0xFF0E0F12) : Colors.black;
    final actionFg = dark ? mint : Colors.white;

    ButtonStyle pillOutlined() => OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        );

    ButtonStyle pillPrimary() => TextButton.styleFrom(
          backgroundColor: actionBg,
          foregroundColor: actionFg,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        );

    final response = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: !isBlocking,
      builder: (ctx) {
        final w = MediaQuery.of(ctx).size.width;
        final h = MediaQuery.of(ctx).size.height;

        final maxW = math.min(460.0, w * 0.92);
        final maxH = math.min(h * 0.85, h - 24);

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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                firstBlock,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 15,
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (restMessage.isNotEmpty) ...[
                                const SizedBox(height: 18),
                                Text(
                                  restMessage,
                                  textAlign: TextAlign.justify,
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 15,
                                    height: 1.25,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (isBlocking)
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            style: pillPrimary(),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Continue anyway'),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: pillOutlined(),
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextButton(
                                style: pillPrimary(),
                                onPressed: () => Navigator.of(ctx).pop(true),
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

    return response ?? false;
  }
}
