// lib/presentation/fire/widgets/tir_complet_form_section.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calculateur_etranger/domain/fire/models/type_charge_caesar.dart';
import 'package:calculateur_etranger/domain/radio/pd_position_state.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/presentation/fire/controllers/tir_complet_controller.dart';
import 'package:calculateur_etranger/presentation/fire/state/tir_complet_state.dart';
import 'package:calculateur_etranger/presentation/fire/state/tir_header_state.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/coordonnees_input_card.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/objectif_input_card.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/observateur_input_card.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/options_tir_list.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/tir_header_section.dart';
import 'package:calculateur_etranger/presentation/theme/tir_tokens.dart';
import 'package:calculateur_etranger/presentation/theme/widgets/tir_action_bar.dart';
import 'package:calculateur_etranger/presentation/theme/widgets/tir_card.dart';

class TirCompletFormSection extends ConsumerWidget {
  const TirCompletFormSection({
    super.key,
    required this.header,
    required this.st,
    required this.controller,
    required this.pdSource,
    required this.externalGpsSelected,
    required this.gpsLoading,
    required this.observerGpsLoading,
    required this.radioLoading,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.dark,
    required this.zoneCtrl,
    required this.xCtrl,
    required this.yCtrl,
    required this.zCtrl,
    required this.latCtrl,
    required this.lonCtrl,
    required this.altCtrl,
    required this.distCtrl,
    required this.azCtrl,
    required this.altObjCtrl,
    required this.xObjCtrl,
    required this.yObjCtrl,
    required this.zObjCtrl,
    required this.obsXCtrl,
    required this.obsYCtrl,
    required this.obsZCtrl,
    required this.obsDistCtrl,
    required this.obsAzCtrl,
    required this.obsAltObjCtrl,
    required this.obsXObjCtrl,
    required this.obsYObjCtrl,
    required this.obsZObjCtrl,
    required this.latPieceDegCtrl,
    required this.deltaAltMetCtrl,
    required this.zoneFocus,
    required this.xFocus,
    required this.yFocus,
    required this.zFocus,
    required this.latFocus,
    required this.lonFocus,
    required this.altFocus,
    required this.distFocus,
    required this.azFocus,
    required this.altObjFocus,
    required this.xObjFocus,
    required this.yObjFocus,
    required this.zObjFocus,
    required this.onPickGps,
    required this.onPickCivilGps,
    required this.onDisableGpsSource,
    required this.onPickPieceOnMap,
    required this.onOfflineZone,
    required this.onSyncRadio,
    required this.onPickObserverGps,
    required this.onPickObserverOnMap,
    required this.onPickObserverObjectifOnMap,
    required this.canPickObserverObjectifOnMap,
    required this.onPickObjectifOnMap,
    required this.canPickObjectifOnMap,
    required this.objectifMapInfo,
    required this.onOpenNature,
    required this.onOpenAutresPieces,
  });

  final TirHeaderState header;
  final TirCompletState st;
  final TirCompletController controller;

  final PdPositionSource pdSource;
  final bool externalGpsSelected;
  final bool gpsLoading;
  final bool observerGpsLoading;
  final bool radioLoading;

  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final bool dark;

  final TextEditingController zoneCtrl;
  final TextEditingController xCtrl;
  final TextEditingController yCtrl;
  final TextEditingController zCtrl;
  final TextEditingController latCtrl;
  final TextEditingController lonCtrl;
  final TextEditingController altCtrl;

  final TextEditingController distCtrl;
  final TextEditingController azCtrl;
  final TextEditingController altObjCtrl;
  final TextEditingController xObjCtrl;
  final TextEditingController yObjCtrl;
  final TextEditingController zObjCtrl;

  final TextEditingController obsXCtrl;
  final TextEditingController obsYCtrl;
  final TextEditingController obsZCtrl;
  final TextEditingController obsDistCtrl;
  final TextEditingController obsAzCtrl;
  final TextEditingController obsAltObjCtrl;
  final TextEditingController obsXObjCtrl;
  final TextEditingController obsYObjCtrl;
  final TextEditingController obsZObjCtrl;

  final TextEditingController latPieceDegCtrl;
  final TextEditingController deltaAltMetCtrl;

  final FocusNode zoneFocus;
  final FocusNode xFocus;
  final FocusNode yFocus;
  final FocusNode zFocus;
  final FocusNode latFocus;
  final FocusNode lonFocus;
  final FocusNode altFocus;

  final FocusNode distFocus;
  final FocusNode azFocus;
  final FocusNode altObjFocus;
  final FocusNode xObjFocus;
  final FocusNode yObjFocus;
  final FocusNode zObjFocus;

  final VoidCallback onPickGps;
  final VoidCallback onPickCivilGps;
  final VoidCallback onDisableGpsSource;
  final VoidCallback onPickPieceOnMap;
  final VoidCallback onOfflineZone;
  final VoidCallback onSyncRadio;

  final VoidCallback onPickObserverGps;
  final VoidCallback onPickObserverOnMap;
  final VoidCallback onPickObserverObjectifOnMap;
  final bool Function() canPickObserverObjectifOnMap;

  final VoidCallback onPickObjectifOnMap;
  final bool Function() canPickObjectifOnMap;
  final String? objectifMapInfo;

  final VoidCallback onOpenNature;
  final VoidCallback onOpenAutresPieces;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headerN = ref.read(tirHeaderProvider.notifier);
    final stN = ref.read(tirCompletProvider.notifier);

    Widget observateurSwitch() {
      final active = st.observateurEnabled;
      final colors = Theme.of(context).colorScheme;
      final textTheme = Theme.of(context).textTheme;

      return TirCard(
        padding: const EdgeInsets.symmetric(
          horizontal: TirSpacing.l,
          vertical: TirSpacing.m,
        ),
        child: Row(
          children: [
            Icon(
              Icons.visibility_outlined,
              size: 18,
              color: active ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: TirSpacing.s),
            Expanded(
              child: Text(
                'Observateur avancé',
                style: textTheme.bodyLarge?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Switch(value: active, onChanged: stN.setObservateurEnabled),
          ],
        ),
      );
    }

    Widget objectifOuObservateur() {
      if (st.observateurEnabled) {
        return ObservateurInputCard(
          st: st,
          stN: stN,
          obsXCtrl: obsXCtrl,
          obsYCtrl: obsYCtrl,
          obsZCtrl: obsZCtrl,
          obsDistCtrl: obsDistCtrl,
          obsAzCtrl: obsAzCtrl,
          obsAltObjCtrl: obsAltObjCtrl,
          obsXObjCtrl: obsXObjCtrl,
          obsYObjCtrl: obsYObjCtrl,
          obsZObjCtrl: obsZObjCtrl,
          card: card,
          border: border,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          dark: dark,
          onPickObserverGps: onPickObserverGps,
          onPickObserverOnMap: onPickObserverOnMap,
          onPickObjectifOnMap: onPickObserverObjectifOnMap,
          observerGpsLoading: observerGpsLoading,
          canPickObjectifOnMap: canPickObserverObjectifOnMap,
          mapStateListenable: Listenable.merge([
            zoneCtrl,
            obsXCtrl,
            obsYCtrl,
            obsZCtrl,
            obsXObjCtrl,
            obsYObjCtrl,
            obsZObjCtrl,
            obsAltObjCtrl,
          ]),
        );
      }

      return ObjectifInputCard(
        st: st,
        stN: stN,
        distCtrl: distCtrl,
        azCtrl: azCtrl,
        altObjCtrl: altObjCtrl,
        xObjCtrl: xObjCtrl,
        yObjCtrl: yObjCtrl,
        zObjCtrl: zObjCtrl,
        distFocus: distFocus,
        azFocus: azFocus,
        altObjFocus: altObjFocus,
        xObjFocus: xObjFocus,
        yObjFocus: yObjFocus,
        zObjFocus: zObjFocus,
        card: card,
        border: border,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        dark: dark,
        onPickOnMap: onPickObjectifOnMap,
        canPickOnMap: canPickObjectifOnMap,
        mapStateListenable: Listenable.merge([
          zoneCtrl,
          xCtrl,
          yCtrl,
          zCtrl,
          latCtrl,
          lonCtrl,
          altCtrl,
        ]),
        mapInfoText: objectifMapInfo,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TirHeaderSection(
          header: header,
          headerN: headerN,
          card: card,
          border: border,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          dark: dark,
          commandLevel: st.commandLevel,
          onCommandLevelChanged: stN.setCommandLevel,
          onTypeMunitionChanged: stN.setTypeMunition,
          onOfflineZone: onOfflineZone,
          onSystemeChanged: (systeme) {
            headerN.setSysteme(systeme);
            stN.setSysteme(systeme);

            if (systeme.calculConnecte) {
              stN.setTirVertical(systeme.tirVerticalParDefaut);

              // La masse en carreaux ne concerne pas le MO81 LLR.
              // Ne jamais appeler carreauxReference pour un système MO81.
              switch (systeme) {
                case Systeme.caesar:
                case Systeme.mepac:
                case Systeme.mo120:
                  stN.setCarreaux(systeme.carreauxReference);
                  break;
                case Systeme.mo81Lrr:
                case Systeme.mo81M252:
                  break;
              }
            }

            if (systeme != Systeme.caesar) {
              stN.setTypeChargeCaesar(TypeChargeCaesar.fr);
            }
          },
        ),
        const SizedBox(height: TirSpacing.m),
        if (gpsLoading)
          Padding(
            padding: const EdgeInsets.only(bottom: TirSpacing.s),
            child: TirCard(
              padding: const EdgeInsets.symmetric(
                horizontal: TirSpacing.m,
                vertical: TirSpacing.s,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: TirSpacing.s),
                  Text(
                    'Acquisition GPS en cours…',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        CoordonneesInputCard(
          st: st,
          stN: stN,
          pdSource: pdSource,
          zoneCtrl: zoneCtrl,
          xCtrl: xCtrl,
          yCtrl: yCtrl,
          zCtrl: zCtrl,
          latCtrl: latCtrl,
          lonCtrl: lonCtrl,
          altCtrl: altCtrl,
          zoneFocus: zoneFocus,
          xFocus: xFocus,
          yFocus: yFocus,
          zFocus: zFocus,
          latFocus: latFocus,
          lonFocus: lonFocus,
          altFocus: altFocus,
          card: card,
          border: border,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          dark: dark,
          onPickGps: onPickGps,
          onPickCivilGps: onPickCivilGps,
          externalGpsSelected: externalGpsSelected,
          onDisableGpsSource: onDisableGpsSource,
          onPickOnMap: onPickPieceOnMap,
          onSyncRadio: onSyncRadio,
          gpsLoading: gpsLoading,
          radioLoading: radioLoading,
        ),
        const SizedBox(height: TirSpacing.m),
        observateurSwitch(),
        const SizedBox(height: TirSpacing.m),
        objectifOuObservateur(),
        const SizedBox(height: TirSpacing.m),
        OptionsTirList(
          st: st,
          stN: stN,
          controller: controller,
          card: card,
          border: border,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          dark: dark,
          deltaAltMetCtrl: deltaAltMetCtrl,
          zCtrl: zCtrl,
          distCtrl: distCtrl,
          onOpenNature: onOpenNature,
          systeme: header.systeme,
          onOpenAutresPieces: onOpenAutresPieces,
        ),
        const SizedBox(height: TirSpacing.l),
        TirActionBar(
          primaryLabel: 'Calculate',
          busy: st.busy,
          onPrimaryPressed: st.busy
              ? null
              : () => controller.calculer(
                    context: context,
                    xCtrl: xCtrl,
                    yCtrl: yCtrl,
                    zCtrl: zCtrl,
                    zoneCtrl: zoneCtrl,
                    latCtrl: latCtrl,
                    lonCtrl: lonCtrl,
                    altCtrl: altCtrl,
                    distCtrl: distCtrl,
                    azCtrl: azCtrl,
                    altObjCtrl: altObjCtrl,
                    xObjCtrl: xObjCtrl,
                    yObjCtrl: yObjCtrl,
                    zObjCtrl: zObjCtrl,
                    latPieceDegCtrl: latPieceDegCtrl,
                    deltaAltMetCtrl: deltaAltMetCtrl,
                    obsXCtrl: obsXCtrl,
                    obsYCtrl: obsYCtrl,
                    obsZCtrl: obsZCtrl,
                    obsDistCtrl: obsDistCtrl,
                    obsAzCtrl: obsAzCtrl,
                    obsAltObjCtrl: obsAltObjCtrl,
                    obsXObjCtrl: obsXObjCtrl,
                    obsYObjCtrl: obsYObjCtrl,
                    obsZObjCtrl: obsZObjCtrl,
                  ),
        ),
      ],
    );
  }
}
