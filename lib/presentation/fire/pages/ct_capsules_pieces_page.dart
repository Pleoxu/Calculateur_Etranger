// lib/presentation/fire/pages/ct_capsules_pieces_page.dart
import 'package:flutter/material.dart';

import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';
import 'package:calculateur_etranger/presentation/fire/pages/ct_capsule_qr_page.dart';
import 'package:calculateur_etranger/services/messages/ct_capsule_recipients_resolver.dart';
import 'package:calculateur_etranger/services/messages/ct_piece_capsule_builder.dart';
import 'package:calculateur_etranger/services/messages/ct_piece_fire_payload_builder.dart';

class CtCapsulesPiecesPage extends StatefulWidget {
  const CtCapsulesPiecesPage({
    super.key,
    required this.output,
    required this.dark,
  });

  final TirCompletOutput output;
  final bool dark;

  @override
  State<CtCapsulesPiecesPage> createState() => _CtCapsulesPiecesPageState();
}

class _CtCapsulesPiecesPageState extends State<CtCapsulesPiecesPage> {
  late final String _missionId;
  final Set<String> _acknowledgedRecipients = <String>{};
  static const _recipientsResolver = CtCapsuleRecipientsResolver();
  static const _firePayloadBuilder = CtPieceFirePayloadBuilder();

  @override
  void initState() {
    super.initState();
    _missionId = _buildMissionId(DateTime.now().toUtc());
  }

  String _buildMissionId(DateTime utc) {
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final hh = utc.hour.toString().padLeft(2, '0');
    final mm = utc.minute.toString().padLeft(2, '0');
    final ss = utc.second.toString().padLeft(2, '0');
    return 'CT-$y$m$d-$hh$mm$ss';
  }

  void _openQr(String recipientId) {
    final payload = _firePayloadBuilder.build(
      output: widget.output,
      recipientId: recipientId,
    );
    final sequenceNumber =
        _recipientsResolver.resolveOutput(widget.output).indexOf(recipientId) +
            1;

    final capsule = const CtPieceCapsuleBuilder().build(
      missionId: _missionId,
      recipientId: recipientId,
      sequenceNumber: sequenceNumber,
      displayPayload: payload,
      requiresAcknowledgement: true,
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CtCapsuleQrPage(capsule: capsule, dark: widget.dark),
      ),
    );
  }

  void _acknowledge(String recipientId) {
    setState(() {
      _acknowledgedRecipients.add(recipientId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final recipients = _recipientsResolver.resolveOutput(widget.output);

    final background =
        widget.dark ? const Color(0xFF0E1014) : const Color(0xFFF5F6F8);
    final appBarBackground =
        widget.dark ? const Color(0xFF111419) : const Color(0xFFF7F8FA);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Gun capsules'),
        centerTitle: true,
        backgroundColor: appBarBackground,
        foregroundColor: widget.dark ? const Color(0xFFE7E9EC) : Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: recipients.isEmpty
            ? _EmptyState(dark: widget.dark)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: recipients.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final recipientId = recipients[index];
                  final acknowledged = _acknowledgedRecipients.contains(
                    recipientId,
                  );

                  return _RecipientCard(
                    recipientId: recipientId,
                    dark: widget.dark,
                    acknowledged: acknowledged,
                    onShowQr: acknowledged ? null : () => _openQr(recipientId),
                    onAcknowledge:
                        acknowledged ? null : () => _acknowledge(recipientId),
                  );
                },
              ),
      ),
    );
  }
}

class _RecipientCard extends StatelessWidget {
  const _RecipientCard({
    required this.recipientId,
    required this.dark,
    required this.acknowledged,
    required this.onShowQr,
    required this.onAcknowledge,
  });

  final String recipientId;
  final bool dark;
  final bool acknowledged;
  final VoidCallback? onShowQr;
  final VoidCallback? onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final cardColor = acknowledged
        ? (dark ? const Color(0xFF121519) : const Color(0xFFE7E9EC))
        : (dark ? const Color(0xFF171B21) : const Color(0xFFF0F2F4));
    final borderColor =
        dark ? const Color(0xFF343A43) : Colors.black.withValues(alpha: 0.12);
    final textPrimary = acknowledged
        ? (dark ? const Color(0xFF777E87) : const Color(0xFF7A8087))
        : (dark ? const Color(0xFFE7E9EC) : const Color(0xFF17191C));
    final textSecondary = acknowledged
        ? (dark ? const Color(0xFF626871) : const Color(0xFF858B91))
        : (dark ? const Color(0xFF9EA5AE) : const Color(0xFF5F666F));
    final buttonBackground =
        dark ? const Color(0xFF245A4A) : const Color(0xFF1F6E57);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipientId,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  acknowledged
                      ? 'Capsule handed over and acknowledged'
                      : 'Recipient present in last calculation',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (acknowledged)
            const Icon(Icons.check_circle_outline, size: 28)
          else ...[
            OutlinedButton.icon(
              onPressed: onAcknowledge,
              icon: const Icon(Icons.check),
              label: const Text('Acquitter'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onShowQr,
              icon: const Icon(Icons.qr_code_2),
              label: const Text(
                'QR',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: buttonBackground,
                foregroundColor: Colors.white,
                minimumSize: const Size(112, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        dark ? const Color(0xFFE7E9EC) : const Color(0xFF17191C);
    final textSecondary =
        dark ? const Color(0xFF9EA5AE) : const Color(0xFF5F666F);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_2, size: 64, color: textSecondary),
            const SizedBox(height: 16),
            Text(
              'No recipient',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Perform a valid calculation first, then reopen the capsules.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
