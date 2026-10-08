import 'package:flutter/material.dart';
import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/elements_ponctuel_card.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/elements_zonal_card.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/elements_lineaire_card.dart';

/// Tile pliable qui encapsule les cards de résultats
/// (ponctuel multi-pièces, linéaire ou zonal).
class ElementsResultTile extends StatefulWidget {
  final TirCompletOutput output;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  const ElementsResultTile({
    super.key,
    required this.output,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  State<ElementsResultTile> createState() => _ElementsResultTileState();
}

class _ElementsResultTileState extends State<ElementsResultTile> {
  bool _expanded = false;

  String get _title {
    final kind = widget.output.firePlan.kind;
    if (kind.isPonctuel) {
      final n = widget.output.firePlan.pieces.length;
      return n > 1 ? 'Éléments ponctuels multi-pièces' : 'Éléments ponctuels';
    }
    if (kind.isZonal) return 'Éléments zonal';
    return 'Éléments linéaire';
  }

  String get _summary {
    final fp = widget.output.firePlan;
    final n = fp.pieces.length;
    final coups = fp.nbCoupsTotal;
    final piecesStr = n > 0 ? '$n pièce${n > 1 ? 's' : ''}' : '';
    final coupsStr = coups > 0 ? '$coups coups' : '';
    final parts = [piecesStr, coupsStr].where((s) => s.isNotEmpty).toList();
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            initiallyExpanded: _expanded,
            onExpansionChanged: (v) => setState(() => _expanded = v),
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            childrenPadding: EdgeInsets.zero,
            title: Row(
              children: [
                Text(
                  _title,
                  style: TextStyle(
                    color: widget.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                if (!_expanded)
                  Expanded(
                    child: Text(
                      _summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            iconColor: widget.textPrimary,
            collapsedIconColor: widget.textPrimary,
            children: [_buildContent()],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final kind = widget.output.firePlan.kind;
    if (kind.isPonctuel) return ElementsPonctuelCard(output: widget.output);
    if (kind.isZonal) return ElementsZonalCard(output: widget.output);
    return ElementsLineaireCard(output: widget.output);
  }
}
