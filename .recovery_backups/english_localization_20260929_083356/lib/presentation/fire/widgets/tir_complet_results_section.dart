// lib/presentation/fire/widgets/tir_complet_results_section.dart

import 'package:flutter/material.dart';

import 'package:calculateur_etranger/domain/fire/models/tir_complet_input.dart'
    as tc;
import 'package:calculateur_etranger/domain/report/message_pd_data.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/presentation/fire/pages/ct_capsules_pieces_page.dart';
import 'package:calculateur_etranger/presentation/fire/pages/red_page.dart';
import 'package:calculateur_etranger/presentation/fire/state/tir_complet_state.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/elements_result_tile.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/reglage_card.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/tir_details_decomposition.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/tir_results_card.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/message_pd_preview_card.dart';
import 'package:calculateur_etranger/presentation/fire/services/message_pd_report_capture.dart';
import 'package:calculateur_etranger/services/report/message_pd_collector.dart';
import 'package:calculateur_etranger/services/report/message_pd_local_store.dart';

class TirCompletResultsSection extends StatelessWidget {
  const TirCompletResultsSection({
    super.key,
    required this.st,
    required this.result,
    required this.zoneCtrl,
    required this.obsXCtrl,
    required this.obsYCtrl,
    required this.obsZCtrl,
    required this.obsAltObjCtrl,
    required this.obsZObjCtrl,
    required this.diametreEfficaciteM,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.dark,
  });

  final TirCompletState st;
  final CalculResult result;

  final TextEditingController zoneCtrl;
  final TextEditingController obsXCtrl;
  final TextEditingController obsYCtrl;
  final TextEditingController obsZCtrl;
  final TextEditingController obsAltObjCtrl;
  final TextEditingController obsZObjCtrl;

  final double diametreEfficaciteM;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final bool dark;

  bool _outputMatchesCurrentNature() {
    final out = st.lastOutput;
    if (out == null) return false;

    final sel = st.natureSelection;
    final nature = sel?.nature;

    if (!st.natureEnabled || nature == null) return true;

    if (nature == NatureTirType.ponctuel) {
      if (out.shots.length != 1) return false;
      final shot = out.shots.first;
      final piece = shot.nomPiece.trim().toUpperCase();
      return piece == 'PD' &&
          out.firePlan.zoneLargeurM.abs() <= 0.001 &&
          out.firePlan.zoneProfondeurM.abs() <= 0.001;
    }

    if (nature == NatureTirType.zonal) return out.firePlan.kind.isZonal;
    if (nature == NatureTirType.lineaire) return !out.firePlan.kind.isZonal;
    return true;
  }

  double? _parse(String raw) {
    final value = raw.trim().replaceAll(',', '.');
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  Widget _reglageSection() {
    if (!st.observateurEnabled || st.lastOutput == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([
        obsXCtrl,
        obsYCtrl,
        obsZCtrl,
        obsAltObjCtrl,
        obsZObjCtrl,
      ]),
      builder: (context, _) {
        final out = st.lastOutput!;
        final oX = _parse(obsXCtrl.text);
        final oY = _parse(obsYCtrl.text);
        final res = out.resultatPdAffecte ?? out.resultatPrincipal;

        if (oX == null || oY == null || res == null) {
          return Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Réglage disponible après calcul avec coordonnées observateur (UTM)',
                    style: TextStyle(color: textSecondary, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          );
        }

        final obsZ = _parse(obsZCtrl.text);
        final altObj = st.observateurObjMode == tc.ObservateurObjMode.daz
            ? _parse(obsAltObjCtrl.text)
            : _parse(obsZObjCtrl.text);

        if (obsZ != null && altObj != null && obsZ <= altObj) {
          final orangeBorder = dark
              ? const Color(0xFFFF9500).withValues(alpha: 0.85)
              : const Color(0xFFFF9500);
          final orangeFill = dark
              ? const Color(0xFFFF9500).withValues(alpha: 0.07)
              : const Color(0xFFFF9500).withValues(alpha: 0.06);
          final orangeText =
              dark ? const Color(0xFFFFBD59) : const Color(0xFFB05E00);

          return Container(
            decoration: BoxDecoration(
              color: orangeFill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: orangeBorder, width: 1.5),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: orangeText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Réglage impossible : l'observateur doit être plus haut que l'objectif",
                    style: TextStyle(
                      color: orangeText,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return ReglageCard(
          output: out,
          pdX: out.pdObjX,
          pdY: out.pdObjY,
          obsX: oX,
          obsY: oY,
          distTirM: res.portee,
          noireMil: res.noireMil,
          typeAssets: res.typeAssets,
          charge: res.charge,
          tirMontagne: st.tirVertical,
          card: card,
          border: border,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          dark: dark,
        );
      },
    );
  }

  void _openRepartition(BuildContext context) {
    final out = st.lastOutput!;
    final sel = st.natureSelection;
    final currentNature = sel?.nature;

    final observateurX = _parse(obsXCtrl.text);
    final observateurY = _parse(obsYCtrl.text);
    final observateurZ = _parse(obsZCtrl.text);
    final showObservateur =
        st.observateurEnabled && observateurX != null && observateurY != null;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RedPage(
          output: out,
          dark: dark,
          azimutTirMil: out.firePlan.azimutMilOut,
          utmZone: zoneCtrl.text.trim(),
          fusee: st.fusee,
          typeTir: st.typeTir,
          natureType: currentNature ??
              (out.firePlan.kind.isZonal
                  ? NatureTirType.zonal
                  : (out.firePlan.zoneLargeurM.abs() > 0.001
                      ? NatureTirType.lineaire
                      : NatureTirType.ponctuel)),
          longueurM: out.firePlan.zoneLargeurM,
          profondeurM: out.firePlan.zoneProfondeurM,
          debordPct: out.debordPct,
          diametreEfficaciteM: diametreEfficaciteM,
          azimutLineaireMil: sel?.azimutMil,
          azimutLargeurMil: sel?.azimutLargeurMil,
          azimutProfondeurMil: sel?.azimutProfondeurMil,
          observateurX: observateurX,
          observateurY: observateurY,
          observateurZ: observateurZ,
          showObservateur: showObservateur,
        ),
      ),
    );
  }

  Future<void> _saveMessageLocally(
    BuildContext sheetContext,
    MessagePdData data,
    MessagePdReportCapture reportCapture,
  ) async {
    var pdfStage = 'initialisation';
    try {
      pdfStage = 'capture des cartes';
      debugPrint('[PDF DIAG] 1/3 début capture cartes');

      final maps = await reportCapture.captureAll();

      debugPrint(
        '[PDF DIAG] 2/3 capture OK '
        'battery=${maps.battery?.length ?? 0} '
        'global=${maps.global?.length ?? 0} '
        'impact=${maps.impact?.length ?? 0} '
        'red=${maps.red?.length ?? 0}',
      );

      pdfStage = 'génération / écriture du PDF';
      debugPrint('[PDF DIAG] 3/3 début génération/écriture PDF');

      final file = await const MessagePdLocalStore().savePdf(
        data,
        batteryMapPng: maps.battery,
        globalMapPng: maps.global,
        impactMapPng: maps.impact,
        redMapPng: maps.red,
      );

      if (!sheetContext.mounted) return;

      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(
          content: Text(
            'Compte rendu PDF enregistré : ${file.path.split('/').last}',
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('[PDF_SAVE][ERROR] $e');
      debugPrint('$st');

      if (!sheetContext.mounted) return;

      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: Text(
            'Impossible d’enregistrer le compte rendu PDF '
            '[$pdfStage] : $e',
          ),
        ),
      );
    }
  }

  void _openMessageBuilder(BuildContext context) {
    final request = st.lastRequest;
    final output = st.lastOutput;

    if (output == null) {
      return;
    }

    if (request == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Snapshot du dernier calcul indisponible'),
        ),
      );
      return;
    }

    final data = const MessagePdCollector().collect(
      request: request,
      output: output,
      utmZoneFallback: zoneCtrl.text.trim(),
      diametreEfficaciteM: diametreEfficaciteM,
    );
    final reportCapture = MessagePdReportCapture();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 12,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.86,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF111419) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: border),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Créer le message',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      MessagePdPreviewCard(
                        data: data,
                        card: card,
                        border: border,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        dark: dark,
                        reportCapture: reportCapture,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _saveMessageLocally(
                                  sheetContext, data, reportCapture),
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Créer / enregistrer'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                backgroundColor: dark
                                    ? const Color(0xFF2B2F35)
                                    : const Color(0xFFE1E4E8),
                                foregroundColor:
                                    dark ? Colors.white : Colors.black87,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Fermer'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                foregroundColor:
                                    dark ? Colors.white : Colors.black87,
                                side: BorderSide(color: border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
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
  }

  void _openCapsulesPieces(BuildContext context) {
    final output = st.lastOutput;

    if (output == null || output.shots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucune capsule disponible : effectuer d’abord un calcul valide.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CtCapsulesPiecesPage(
          output: output,
          dark: dark,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showPlanDetails = _outputMatchesCurrentNature();
    const canCreateMessage = true;
    final canCreateCapsules = st.lastOutput?.shots.isNotEmpty ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TirResultsCard(
          result: result,
          card: card,
          border: border,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        const SizedBox(height: 8),
        TirDetailsDecomposition(
          result: result,
          niveauMeteo: st.niveauBLocal,
          dark: dark,
          card: card,
          border: border,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        if (showPlanDetails &&
            st.lastOutput != null &&
            (st.lastOutput!.hasShots || st.lastOutput!.hasResultatsPS)) ...[
          const SizedBox(height: 8),
          ElementsResultTile(
            output: st.lastOutput!,
            card: card,
            border: border,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.map_outlined),
              label: const Text('Voir répartition'),
              onPressed: () => _openRepartition(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: dark
                    ? Colors.white.withValues(alpha: 0.92)
                    : Colors.black87,
                side: BorderSide(color: border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
        if (canCreateMessage) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              icon: const Icon(Icons.description_outlined),
              label: const Text(
                'Créer le message',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () => _openMessageBuilder(context),
              style: FilledButton.styleFrom(
                backgroundColor:
                    dark ? const Color(0xFF2B2F35) : const Color(0xFFE1E4E8),
                foregroundColor: dark ? Colors.white : Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.qr_code_2_rounded),
            label: const Text(
              'Générer les QR pièces',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed:
                canCreateCapsules ? () => _openCapsulesPieces(context) : null,
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  dark ? Colors.white.withValues(alpha: 0.92) : Colors.black87,
              disabledForegroundColor: textSecondary.withValues(alpha: 0.45),
              side: BorderSide(color: border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        if (showPlanDetails &&
            st.observateurEnabled &&
            st.lastOutput != null) ...[
          const SizedBox(height: 12),
          _reglageSection(),
        ],
      ],
    );
  }
}
