// lib/presentation/fire/pages/ct_capsule_qr_page.dart
import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import 'package:calculateur_etranger/services/messages/ct_message_capsule.dart';

class CtCapsuleQrPage extends StatelessWidget {
  const CtCapsuleQrPage({super.key, required this.capsule, required this.dark});

  final CtMessageCapsule capsule;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final compact = capsule.toCompactString();

    final background = dark ? const Color(0xFF0E1014) : const Color(0xFFF5F6F8);
    final panel = dark ? const Color(0xFF171B21) : Colors.white;
    final border =
        dark ? const Color(0xFF343A43) : Colors.black.withValues(alpha: 0.12);
    final textPrimary =
        dark ? const Color(0xFFE7E9EC) : const Color(0xFF17191C);
    final textSecondary =
        dark ? const Color(0xFF9EA5AE) : const Color(0xFF5F666F);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text('QR ${capsule.recipientId}'),
        centerTitle: true,
        backgroundColor:
            dark ? const Color(0xFF111419) : const Color(0xFFF7F8FA),
        foregroundColor: textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      capsule.recipientId,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'CTMSG capsule • integrity ${capsule.isIntegrityValid ? "OK" : "INVALID"}',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 320,
                          maxHeight: 320,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: CustomPaint(painter: _CtQrPainter(compact)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Mission ${capsule.missionId}  •  sequence ${capsule.sequenceNumber}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CtQrPainter extends CustomPainter {
  _CtQrPainter(String data)
      : image = QrImage(
          QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
        );

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final modules = image.moduleCount;
    const quietZoneModules = 4;
    final totalModules = modules + quietZoneModules * 2;
    final cell = size.shortestSide / totalModules;

    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    for (var row = 0; row < modules; row++) {
      for (var col = 0; col < modules; col++) {
        if (!image.isDark(row, col)) continue;

        canvas.drawRect(
          Rect.fromLTWH(
            (col + quietZoneModules) * cell,
            (row + quietZoneModules) * cell,
            cell.ceilToDouble(),
            cell.ceilToDouble(),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CtQrPainter oldDelegate) => false;
}
