import 'package:flutter/material.dart';
import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';

class ElementsTirCard extends StatelessWidget {
  final TirCompletOutput output;
  final String title;

  const ElementsTirCard({super.key, required this.output, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color cardBg = theme.dialogTheme.backgroundColor ?? theme.cardColor;

    final Color border = (theme.dividerTheme.color ?? theme.dividerColor)
        .withValues(alpha: 0.35);

    final Color textPrimary = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final Color textSecondary =
        (theme.textTheme.bodyMedium?.color ?? Colors.white70).withValues(
      alpha: 0.9,
    );

    final titleStyle = theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ) ??
        TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        );

    final pieceTitleStyle = theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ) ??
        TextStyle(fontWeight: FontWeight.w800, color: textPrimary);

    final salveTitleStyle = pieceTitleStyle.copyWith(
      fontSize: 15,
      color: textPrimary.withValues(alpha: 0.95),
    );

    final secondaryStyle = theme.textTheme.bodyMedium?.copyWith(
          color: textSecondary,
          height: 1.25,
        ) ??
        TextStyle(color: textSecondary, height: 1.25);

    final groupedShots =
        output.hasShots ? _groupShots(output.shots) : const <TirLineaireShot>[];

    final shotsSorted = groupedShots.isNotEmpty
        ? _sortShotsForFiring(groupedShots)
        : const <TirLineaireShot>[];

    final shotsBySalve = shotsSorted.isNotEmpty
        ? _groupShotsBySalve(shotsSorted)
        : const <int, List<TirLineaireShot>>{};

    final salves = shotsBySalve.keys.toList()..sort();

    return Card(
      color: cardBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: titleStyle),
            const SizedBox(height: 6),
            if (output.hasShots)
              Text(
                'Total rounds: ${output.totalShotsCount}',
                style: secondaryStyle,
              ),
            const SizedBox(height: 10),
            if (output.hasShots) ...[
              for (final salve in salves) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(
                    'Salvo $salve — ${_totalShotsInSalve(shotsBySalve[salve]!)} rounds',
                    style: salveTitleStyle,
                  ),
                ),
                for (final shot in shotsBySalve[salve]!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _shotRowGrouped(
                      nomPiece: shot.nomPiece,
                      offsetM: shot.offsetM,
                      r: shot.resultat,
                      objX: shot.objX,
                      objY: shot.objY,
                      count: shot.count,
                      titleStyle: pieceTitleStyle,
                      secondaryStyle: secondaryStyle,
                      textPrimary: textPrimary,
                    ),
                  ),
                if (salve != salves.last) ...[
                  const SizedBox(height: 2),
                  Divider(color: border),
                  const SizedBox(height: 4),
                ],
              ],
            ] else ...[
              _pieceRow(
                title: 'PD (assigned target)',
                offsetM: output.pdOffsetM,
                r: output.resultatPdAffecte,
                objX: output.pdObjX,
                objY: output.pdObjY,
                titleStyle: pieceTitleStyle,
                secondaryStyle: secondaryStyle,
              ),
              const SizedBox(height: 10),
              Divider(color: border),
              const SizedBox(height: 10),
              for (final ps
                  in output.resultatsPS.toList()
                    ..sort((a, b) => a.offsetM.compareTo(b.offsetM)))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _pieceRow(
                    title: ps.nom,
                    offsetM: ps.offsetM,
                    r: ps.resultat,
                    objX: ps.objX,
                    objY: ps.objY,
                    titleStyle: pieceTitleStyle,
                    secondaryStyle: secondaryStyle,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Map<int, List<TirLineaireShot>> _groupShotsBySalve(
    List<TirLineaireShot> shots,
  ) {
    final grouped = <int, List<TirLineaireShot>>{};

    for (final shot in shots) {
      final salve = shot.numeroSalve ?? 1;
      grouped.putIfAbsent(salve, () => []).add(shot);
    }

    return grouped;
  }

  int _totalShotsInSalve(List<TirLineaireShot> shots) {
    return shots.fold<int>(
      0,
      (sum, shot) => sum + (shot.count <= 0 ? 1 : shot.count),
    );
  }

  List<TirLineaireShot> _groupShots(List<TirLineaireShot> shots) {
    final Map<String, TirLineaireShot> acc = {};

    String keyOf(TirLineaireShot s) {
      final salve = s.numeroSalve ?? 1;
      final off = s.offsetM.toStringAsFixed(6);
      final x = s.objX.toStringAsFixed(6);
      final y = s.objY.toStringAsFixed(6);
      return '$salve|${s.nomPiece}|$off|$x|$y';
    }

    for (final s in shots) {
      final k = keyOf(s);
      final existing = acc[k];
      if (existing == null) {
        acc[k] = TirLineaireShot(
          nomPiece: s.nomPiece,
          offsetM: s.offsetM,
          objX: s.objX,
          objY: s.objY,
          resultat: s.resultat,
          count: (s.count <= 0 ? 1 : s.count),
          numeroSalve: s.numeroSalve,
        );
      } else {
        acc[k] = TirLineaireShot(
          nomPiece: existing.nomPiece,
          offsetM: existing.offsetM,
          objX: existing.objX,
          objY: existing.objY,
          resultat: existing.resultat,
          count: existing.count + (s.count <= 0 ? 1 : s.count),
          numeroSalve: existing.numeroSalve ?? s.numeroSalve,
        );
      }
    }

    return acc.values.toList();
  }

  List<TirLineaireShot> _sortShotsForFiring(List<TirLineaireShot> shots) {
    final Map<double, List<TirLineaireShot>> grouped = {};
    for (final shot in shots) {
      final absOffset = shot.offsetM.abs();
      grouped.putIfAbsent(absOffset, () => []).add(shot);
    }

    final sortedAbsOffsets = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final result = <TirLineaireShot>[];
    for (final absOffset in sortedAbsOffsets) {
      final group = grouped[absOffset]!;
      group.sort((a, b) => a.offsetM.compareTo(b.offsetM));
      result.addAll(group);
    }
    return result;
  }

  String _f2(num? v) => v == null ? '-' : v.toStringAsFixed(2);
  String _f1(num? v) => v == null ? '-' : v.toStringAsFixed(1);

  Widget _shotRowGrouped({
    required String nomPiece,
    required double offsetM,
    required dynamic r,
    required double objX,
    required double objY,
    required int count,
    required TextStyle titleStyle,
    required TextStyle secondaryStyle,
    required Color textPrimary,
  }) {
    final num? noire = (r == null) ? null : r.noireMil;
    final num? aqe = (r == null) ? null : r.aqeMil;
    final num? tv = (r == null) ? null : r.tempsVolS;
    final String tempsLabel = (r == null) ? 'Time of flight' : r.tempsLabel;

    final String mult = count > 1 ? ' (×$count rounds)' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$nomPiece • Offset ${_f1(offsetM)} m$mult',
          style: titleStyle.copyWith(color: textPrimary),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 6),
        Text('Obj : X=${_f1(objX)}  Y=${_f1(objY)}', style: secondaryStyle),
        const SizedBox(height: 2),
        Text(
          'Firing bearing: ${_f2(noire)} mil    AQE: ${_f2(aqe)} mil    $tempsLabel: ${_f2(tv)} s',
          style: secondaryStyle,
        ),
      ],
    );
  }

  Widget _pieceRow({
    required String title,
    required double offsetM,
    required dynamic r,
    required double objX,
    required double objY,
    required TextStyle titleStyle,
    required TextStyle secondaryStyle,
  }) {
    final num? noire = (r == null) ? null : r.noireMil;
    final num? aqe = (r == null) ? null : r.aqeMil;
    final num? tv = (r == null) ? null : r.tempsVolS;
    final String tempsLabel = (r == null) ? 'Time of flight' : r.tempsLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        const SizedBox(height: 6),
        Text(
          'Offset : ${_f1(offsetM)} m    Obj : X=${_f1(objX)}  Y=${_f1(objY)}',
          style: secondaryStyle,
        ),
        const SizedBox(height: 2),
        Text(
          'Firing bearing: ${_f2(noire)} mil    AQE: ${_f2(aqe)} mil    $tempsLabel: ${_f2(tv)} s',
          style: secondaryStyle,
        ),
      ],
    );
  }
}
