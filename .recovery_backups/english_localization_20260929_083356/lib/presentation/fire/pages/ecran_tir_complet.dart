// lib/presentation/fire/pages/ecran_tir_complet.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/presentation/fire/controllers/tir_complet_controller.dart';
import 'package:calculateur_etranger/presentation/fire/controllers/tir_complet_form_controllers.dart';
import 'package:calculateur_etranger/presentation/fire/controllers/tir_complet_position_actions.dart';
import 'package:calculateur_etranger/presentation/fire/state/tir_complet_state.dart';
import 'package:calculateur_etranger/presentation/fire/state/tir_header_state.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/tir_complet_form_section.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/tir_complet_results_section.dart';

import 'ecran_tir_complet_dialogs.dart';
import 'ecran_tir_complet_theme.dart';

import 'package:calculateur_etranger/presentation/theme/tir_tokens.dart';
import 'package:calculateur_etranger/presentation/theme/widgets/tir_card.dart';

class EcranTirComplet extends ConsumerStatefulWidget {
  const EcranTirComplet({super.key});

  @override
  ConsumerState<EcranTirComplet> createState() => _EcranTirCompletState();
}

class _EcranTirCompletState extends ConsumerState<EcranTirComplet> {
  final TirCompletFormControllers _form = TirCompletFormControllers();

  TextEditingController get zoneCtrl => _form.zoneCtrl;
  TextEditingController get xCtrl => _form.xCtrl;
  TextEditingController get yCtrl => _form.yCtrl;
  TextEditingController get zCtrl => _form.zCtrl;
  TextEditingController get latCtrl => _form.latCtrl;
  TextEditingController get lonCtrl => _form.lonCtrl;
  TextEditingController get altCtrl => _form.altCtrl;

  TextEditingController get distCtrl => _form.distCtrl;
  TextEditingController get azCtrl => _form.azCtrl;
  TextEditingController get altObjCtrl => _form.altObjCtrl;
  TextEditingController get xObjCtrl => _form.xObjCtrl;
  TextEditingController get yObjCtrl => _form.yObjCtrl;
  TextEditingController get zObjCtrl => _form.zObjCtrl;

  TextEditingController get obsXCtrl => _form.obsXCtrl;
  TextEditingController get obsYCtrl => _form.obsYCtrl;
  TextEditingController get obsZCtrl => _form.obsZCtrl;
  TextEditingController get obsDistCtrl => _form.obsDistCtrl;
  TextEditingController get obsAzCtrl => _form.obsAzCtrl;
  TextEditingController get obsAltObjCtrl => _form.obsAltObjCtrl;
  TextEditingController get obsXObjCtrl => _form.obsXObjCtrl;
  TextEditingController get obsYObjCtrl => _form.obsYObjCtrl;
  TextEditingController get obsZObjCtrl => _form.obsZObjCtrl;

  TextEditingController get latPieceDegCtrl => _form.latPieceDegCtrl;
  TextEditingController get deltaAltMetCtrl => _form.deltaAltMetCtrl;

  FocusNode get zoneFocus => _form.zoneFocus;
  FocusNode get xFocus => _form.xFocus;
  FocusNode get yFocus => _form.yFocus;
  FocusNode get zFocus => _form.zFocus;
  FocusNode get latFocus => _form.latFocus;
  FocusNode get lonFocus => _form.lonFocus;
  FocusNode get altFocus => _form.altFocus;

  FocusNode get distFocus => _form.distFocus;
  FocusNode get azFocus => _form.azFocus;
  FocusNode get altObjFocus => _form.altObjFocus;
  FocusNode get xObjFocus => _form.xObjFocus;
  FocusNode get yObjFocus => _form.yObjFocus;
  FocusNode get zObjFocus => _form.zObjFocus;

  late final TirCompletController controller;

  ProviderSubscription<TirHeaderState>? _headerSub;
  late final TirCompletPositionActions _positionActions;

  @override
  void initState() {
    super.initState();
    controller = TirCompletController(ref);
    _positionActions = TirCompletPositionActions(
      ref: ref,
      form: _form,
      context: () => context,
      mounted: () => mounted,
      onChanged: () {
        if (mounted) setState(() {});
      },
    )..init();
    _headerSub = ref.listenManual<TirHeaderState>(tirHeaderProvider, (
      prev,
      next,
    ) {
      final st = ref.read(tirCompletProvider);
      final stN = ref.read(tirCompletProvider.notifier);

      if (prev?.typeTir == next.typeTir) return;

      if (st.typeTir != next.typeTir) {
        stN.setTypeTir(next.typeTir);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_positionActions.dispose());
    _headerSub?.close();
    _form.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final header = ref.watch(tirHeaderProvider);
    final st = ref.watch(tirCompletProvider);
    final stN = ref.read(tirCompletProvider.notifier);

    final dark = header.dark;
    final bg = dark ? const Color(0xFF0E0F12) : const Color(0xFFF4F5F7);
    final card = dark ? const Color(0xFF12141A) : Colors.white;
    final border =
        dark ? Colors.white.withValues(alpha: 0.10) : const Color(0x1A000000);
    final textPrimary =
        dark ? Colors.white.withValues(alpha: 0.92) : Colors.black87;
    final textSecondary =
        dark ? Colors.white.withValues(alpha: 0.70) : Colors.black54;

    final bool systemeConnecte = header.systeme.calculConnecte;

    final double? diametreEfficaciteM = systemeConnecte
        ? (header.typeTir == TypeTir.eclairant
            ? 600.0
            : header.systeme.diametreEfficaciteM)
        : null;

    final themed = buildLocalTheme(
      context: context,
      dark: dark,
      card: card,
      border: border,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
    );

    final lr = st.lastResult;

    final formSection = TirCompletFormSection(
      header: header,
      st: st,
      controller: controller,
      pdSource: _positionActions.pdSource,
      externalGpsSelected: _positionActions.externalGpsSelected,
      gpsLoading: _positionActions.gpsLoading,
      observerGpsLoading: _positionActions.observerGpsLoading,
      radioLoading: _positionActions.radioLoading,
      card: card,
      border: border,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      dark: dark,
      zoneCtrl: zoneCtrl,
      xCtrl: xCtrl,
      yCtrl: yCtrl,
      zCtrl: zCtrl,
      latCtrl: latCtrl,
      lonCtrl: lonCtrl,
      altCtrl: altCtrl,
      distCtrl: distCtrl,
      azCtrl: azCtrl,
      altObjCtrl: altObjCtrl,
      xObjCtrl: xObjCtrl,
      yObjCtrl: yObjCtrl,
      zObjCtrl: zObjCtrl,
      obsXCtrl: obsXCtrl,
      obsYCtrl: obsYCtrl,
      obsZCtrl: obsZCtrl,
      obsDistCtrl: obsDistCtrl,
      obsAzCtrl: obsAzCtrl,
      obsAltObjCtrl: obsAltObjCtrl,
      obsXObjCtrl: obsXObjCtrl,
      obsYObjCtrl: obsYObjCtrl,
      obsZObjCtrl: obsZObjCtrl,
      latPieceDegCtrl: latPieceDegCtrl,
      deltaAltMetCtrl: deltaAltMetCtrl,
      zoneFocus: zoneFocus,
      xFocus: xFocus,
      yFocus: yFocus,
      zFocus: zFocus,
      latFocus: latFocus,
      lonFocus: lonFocus,
      altFocus: altFocus,
      distFocus: distFocus,
      azFocus: azFocus,
      altObjFocus: altObjFocus,
      xObjFocus: xObjFocus,
      yObjFocus: yObjFocus,
      zObjFocus: zObjFocus,
      onPickGps: _positionActions.selectDeviceGps,
      onPickCivilGps: _positionActions.selectExternalGps,
      onDisableGpsSource: _positionActions.disableGpsSource,
      onPickPieceOnMap: _positionActions.pickPieceOnMap,
      onOfflineZone: _positionActions.pickCamp,
      onSyncRadio: _positionActions.syncBatteryFromRadio,
      onPickObserverGps: _positionActions.fillObserverFromGps,
      onPickObserverOnMap: _positionActions.pickObserverOnMap,
      onPickObserverObjectifOnMap: _positionActions.pickObserverObjectifOnMap,
      canPickObserverObjectifOnMap:
          _positionActions.canPickObserverObjectifOnMap,
      onPickObjectifOnMap: _positionActions.pickObjectifOnMap,
      canPickObjectifOnMap: _positionActions.canPickObjectifOnMap,
      objectifMapInfo: _positionActions.objectifMapInfo,
      onOpenNature: () async {
        if (!systemeConnecte || diametreEfficaciteM == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${header.systeme.label} : fonctions de tir non connectées.',
              ),
            ),
          );
          return;
        }

        await openNatureDialog(
          context: context,
          dark: dark,
          initial: st.natureSelection,
          diametreEfficaciteM: diametreEfficaciteM,
          onValidated: (sel) async {
            controller.applyNatureSelectionAndAutoDistribute(sel);

            final refreshedState = ref.read(tirCompletProvider);

            if (sel.enabled && sel.nature == NatureTirType.zonal) {
              if (!refreshedState.autrePieces) {
                stN.setAutrePiecesEnabled(true);
              }

              if (refreshedState.piecesSoutien.isEmpty) {
                controller.addPieceSoutien();
                controller.addPieceSoutien();
              }

              await Future.delayed(const Duration(milliseconds: 150));

              if (context.mounted) {
                await openAutresPiecesDialog(
                  context: context,
                  ref: ref,
                  dark: dark,
                  st: ref.read(tirCompletProvider),
                  stN: stN,
                );
              }
            } else if (sel.enabled && sel.nature == NatureTirType.lineaire) {
              await Future.delayed(const Duration(milliseconds: 150));
              if (context.mounted) {
                await openAutresPiecesDialog(
                  context: context,
                  ref: ref,
                  dark: dark,
                  st: ref.read(tirCompletProvider),
                  stN: stN,
                );
              }
            }
          },
        );
      },
      onOpenAutresPieces: () async {
        await openAutresPiecesDialog(
          context: context,
          ref: ref,
          dark: dark,
          st: ref.read(tirCompletProvider),
          stN: stN,
        );
      },
    );

    return Theme(
      data: themed,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isWide = width >= TirBreakpoints.medium;
              final horizontalPadding =
                  width < TirBreakpoints.compact ? TirSpacing.m : TirSpacing.xl;
              final maxContentWidth = width >= TirBreakpoints.expanded
                  ? TirSizes.maxContentWidth
                  : width;

              if (!isWide) {
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: ListView(
                      padding: EdgeInsets.all(horizontalPadding),
                      children: [
                        formSection,
                        if (systemeConnecte && lr is CalculResult) ...[
                          const SizedBox(height: TirSpacing.l),
                          TirCompletResultsSection(
                            st: st,
                            result: lr,
                            zoneCtrl: zoneCtrl,
                            obsXCtrl: obsXCtrl,
                            obsYCtrl: obsYCtrl,
                            obsZCtrl: obsZCtrl,
                            obsAltObjCtrl: obsAltObjCtrl,
                            obsZObjCtrl: obsZObjCtrl,
                            diametreEfficaciteM: diametreEfficaciteM!,
                            card: card,
                            border: border,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            dark: dark,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Padding(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: ListView(children: [formSection]),
                        ),
                        const SizedBox(width: TirSpacing.l),
                        Expanded(
                          flex: 4,
                          child: ListView(
                            children: [
                              if (systemeConnecte && lr is CalculResult)
                                TirCompletResultsSection(
                                  st: st,
                                  result: lr,
                                  zoneCtrl: zoneCtrl,
                                  obsXCtrl: obsXCtrl,
                                  obsYCtrl: obsYCtrl,
                                  obsZCtrl: obsZCtrl,
                                  obsAltObjCtrl: obsAltObjCtrl,
                                  obsZObjCtrl: obsZObjCtrl,
                                  diametreEfficaciteM: diametreEfficaciteM!,
                                  card: card,
                                  border: border,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                  dark: dark,
                                )
                              else
                                TirCard(
                                  child: Text(
                                    'Les résultats apparaîtront ici après calcul.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
