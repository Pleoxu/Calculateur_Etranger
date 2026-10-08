import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calculateur_etranger/presentation/theme/tir_tokens.dart';

import '../helpers/coups_repartition_helper.dart';
import '../state/coups_par_piece_provider.dart';
import 'dialog_shell.dart';

class CoupsRepartitionResult {
  final bool confirmed;
  final Map<String, int> coupsParPiece;

  const CoupsRepartitionResult({
    required this.confirmed,
    required this.coupsParPiece,
  });
}

class CoupsRepartitionDialog extends ConsumerStatefulWidget {
  final int totalCoups;
  final List<String> piecesOrdered;
  final bool dark;

  const CoupsRepartitionDialog({
    super.key,
    required this.totalCoups,
    required this.piecesOrdered,
    required this.dark,
  });

  static const int minCoupsParPiece = 0;
  static const int maxCoupsParPiece = 40;

  @override
  ConsumerState<CoupsRepartitionDialog> createState() =>
      _CoupsRepartitionDialogState();
}

class _CoupsRepartitionDialogState
    extends ConsumerState<CoupsRepartitionDialog> {
  late final List<String> _pieces;

  static const Color _borderDark = Color(0xFF3A4048);

  @override
  void initState() {
    super.initState();

    _pieces = _sanitizePieces(widget.piecesOrdered);

    Future.microtask(() {
      final notifier = ref.read(coupsParPieceByPieceProvider.notifier);
      final currentMap = ref.read(coupsParPieceByPieceProvider);

      final newMap = <String, int>{};
      for (final p in _pieces) {
        newMap[p] = currentMap[p] ?? 0;
      }

      // Cas hérité fréquent lors du passage à un tir multi-pièces :
      // tout le total est encore porté par la PD et les PS sont à zéro.
      //
      // Si plusieurs pièces sont effectivement sélectionnées, on propose
      // automatiquement une répartition équitable dès l'ouverture du dialogue.
      // Les répartitions déjà multi-pièces restent, elles, inchangées.
      if (_shouldSuggestEquitable(newMap)) {
        notifier.setAll(
          equitableRepartition(
            totalCoups: widget.totalCoups,
            piecesOrdered: _pieces,
            minPerPiece: CoupsRepartitionDialog.minCoupsParPiece,
            maxPerPiece: CoupsRepartitionDialog.maxCoupsParPiece,
          ),
        );
      } else {
        notifier.setAll(newMap);
      }
    });
  }

  bool _shouldSuggestEquitable(Map<String, int> current) {
    if (_pieces.length <= 1 || widget.totalCoups <= 1) return false;

    final pdValue = current['PD'] ?? 0;
    if (pdValue != widget.totalCoups) return false;

    for (final piece in _pieces) {
      if (piece == 'PD') continue;
      if ((current[piece] ?? 0) != 0) return false;
    }

    return true;
  }

  List<String> _sanitizePieces(List<String> source) {
    final out = <String>[];
    final seen = <String>{};

    for (final raw in source) {
      final piece = raw.trim().toUpperCase();
      if (piece.isEmpty) continue;
      if (seen.add(piece)) {
        out.add(piece);
      }
    }

    return out;
  }

  CoupsRepartitionResult _buildResult({required bool confirmed}) {
    final map = ref.read(coupsParPieceByPieceProvider);

    final filtered = <String, int>{};
    for (final p in _pieces) {
      filtered[p] = map[p] ?? 0;
    }

    return CoupsRepartitionResult(
      confirmed: confirmed,
      coupsParPiece: filtered,
    );
  }

  void _closeAsConfirmed() {
    Navigator.of(context).pop(_buildResult(confirmed: true));
  }

  void _closeAsCancelled() {
    Navigator.of(context).pop(_buildResult(confirmed: false));
  }

  @override
  Widget build(BuildContext context) {
    final map = ref.watch(coupsParPieceByPieceProvider);
    final notifier = ref.read(coupsParPieceByPieceProvider.notifier);

    final sum = _pieces.fold<int>(0, (a, p) => a + (map[p] ?? 0));
    final delta = widget.totalCoups - sum;

    final bg = widget.dark ? const Color(0xFF12141A) : Colors.white;
    final border = widget.dark ? _borderDark : Colors.black12;
    final textColor =
        widget.dark ? Colors.white.withValues(alpha: 0.92) : Colors.black87;
    final subColor = widget.dark ? Colors.white70 : Colors.black54;

    final statusColor = delta == 0 ? subColor : Colors.orange;
    final actionGrey = widget.dark ? Colors.white70 : Colors.black54;

    void repartirEquitable() {
      final eq = equitableRepartition(
        totalCoups: widget.totalCoups,
        piecesOrdered: _pieces,
        minPerPiece: CoupsRepartitionDialog.minCoupsParPiece,
        maxPerPiece: CoupsRepartitionDialog.maxCoupsParPiece,
      );
      notifier.setAll(eq);
    }

    void normaliserAuTotal() {
      final normalized = normalizeToTotal(
        input: map,
        totalCoups: widget.totalCoups,
        piecesOrdered: _pieces,
        minPerPiece: CoupsRepartitionDialog.minCoupsParPiece,
        maxPerPiece: CoupsRepartitionDialog.maxCoupsParPiece,
      );
      notifier.setAll(normalized);
    }

    final content = DefaultTextStyle(
      style: TextStyle(color: textColor),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              'Répartition des coups',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Total: ${widget.totalCoups}   •   Attribués: $sum   •   '
            '${delta == 0 ? "OK" : (delta > 0 ? "Reste: $delta" : "Dépasse: ${-delta}")}',
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Divider(color: border, height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            alignment: WrapAlignment.start,
            children: [
              TextButton(
                onPressed: repartirEquitable,
                style: TextButton.styleFrom(
                  foregroundColor: actionGrey,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: const Text('Répartir équitable'),
              ),
              TextButton(
                onPressed: normaliserAuTotal,
                style: TextButton.styleFrom(
                  foregroundColor: actionGrey,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: const Text('Normaliser au total'),
              ),
            ],
          ),
          const SizedBox(height: TirSpacing.s),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _pieces.length,
              itemBuilder: (_, i) {
                final p = _pieces[i];
                return _PieceStepperRow(
                  piece: p,
                  value: map[p] ?? 0,
                  dark: widget.dark,
                  min: CoupsRepartitionDialog.minCoupsParPiece,
                  max: CoupsRepartitionDialog.maxCoupsParPiece,
                  onChanged: (v) => notifier.set(p, v),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          _ActionBar(
            border: border,
            onCancel: _closeAsCancelled,
            onOk: _closeAsConfirmed,
          ),
        ],
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _closeAsConfirmed();
      },
      child: DialogShell(
        dark: widget.dark,
        surface: bg,
        border: border,
        maxWidth: 640,
        child: content,
      ),
    );
  }
}

class _PieceStepperRow extends StatelessWidget {
  final String piece;
  final int value;
  final bool dark;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _PieceStepperRow({
    required this.piece,
    required this.value,
    required this.dark,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        dark ? Colors.white.withValues(alpha: 0.92) : Colors.black87;
    final hintColor = dark ? Colors.white54 : Colors.black45;

    final canMinus = value > min;
    final canPlus = value < max;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              piece,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            onPressed: canMinus ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            onPressed: canPlus ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 10),
          Text('($min-$max)', style: TextStyle(color: hintColor)),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final Color border;
  final VoidCallback onCancel;
  final VoidCallback onOk;

  const _ActionBar({
    required this.border,
    required this.onCancel,
    required this.onOk,
  });

  static const Color _okBg = Color(0xFF0B0D11);
  static const Color _okTextGreen = Color(0xFF4FAF7A);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onCancel,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: border),
              ),
              child: const Center(
                child: Text(
                  'Annuler',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: GestureDetector(
            onTap: onOk,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: _okBg,
              ),
              child: const Center(
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: _okTextGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
