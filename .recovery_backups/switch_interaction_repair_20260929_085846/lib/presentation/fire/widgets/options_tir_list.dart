// lib/presentation/fire/widgets/options_tir_list.dart

import 'package:flutter/material.dart';

import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/presentation/fire/controllers/tir_complet_controller.dart';
import 'package:calculateur_etranger/presentation/fire/dialogs/masse_et_charge_dialogs.dart';
import 'package:calculateur_etranger/presentation/fire/dialogs/fusee_dialog.dart';
import 'package:calculateur_etranger/presentation/fire/state/tir_complet_state.dart';

class OptionsTirList extends StatelessWidget {
  final TirCompletState st;
  final TirCompletNotifier stN;
  final TirCompletController controller;

  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final bool dark;

  final TextEditingController deltaAltMetCtrl;
  final TextEditingController zCtrl;
  final TextEditingController distCtrl;

  /// Ouvre le dialogue Nature du tir
  final VoidCallback onOpenNature;

  /// Système d'arme actif (conditionne Fusée et Forcer la charge)
  final Systeme systeme;

  /// Ouvre le dialogue Autres pièces (stratégie + positions)
  final VoidCallback onOpenAutresPieces;

  const OptionsTirList({
    super.key,
    required this.st,
    required this.stN,
    required this.controller,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.dark,
    required this.deltaAltMetCtrl,
    required this.zCtrl,
    required this.distCtrl,
    required this.systeme,
    required this.onOpenNature,
    required this.onOpenAutresPieces,
  });

  // Switch colors (mint)
  Color get _trackOn => const Color(0xFF2A6B57);
  Color get _thumbOn => const Color(0xFFBFF5D9);
  Color get _trackOff => dark ? Colors.white24 : Colors.black26;
  Color get _thumbOff => dark ? Colors.white70 : Colors.black54;

  String get _deltaMasseLabel {
    final delta = st.carreaux - systeme.carreauxReference;
    final signe = delta > 0 ? '+' : '';
    final unite = delta.abs() == 1 ? 'carreau' : 'carreaux';
    return 'Δ mass : $signe$delta $unite (ref. ${systeme.carreauxReference})';
  }

  // Largeur "réservée" pour le switch à droite
  static const double _switchReserve = 84;

  @override
  Widget build(BuildContext context) {
    final ps = st.piecesSoutien.length;
    final total = ps + 1;

    return Column(
      children: [
        // 1) Nature du tir
        _natureCard(context),

        const SizedBox(height: 10),

        // 2) Tir vertical / Branche basse (selon le système)
        _toggleCard(
          title: systeme.labelTirVertical,
          value: st.tirVertical,
          onChanged: (v) => stN.setTirVertical(v),
          subtitle: st.tirVertical ? 'Enabled' : null,
        ),

        const SizedBox(height: 10),

        // 3) Masse obus
        _toggleCard(
          title: 'Shell weight',
          value: st.masseEnabled,
          onChanged: (v) async {
            debugPrint(
              '[MASS SWITCH] '
              'requested=$v '
              'currentEnabled=${st.masseEnabled} '
              'currentCarreaux=${st.carreaux}',
            );

            if (!v) {
              stN.setMasseEnabled(false);
              return;
            }

            final picked = await showCarreauxDialog(
              context: context,
              dark: dark,
              initialCarreaux: st.carreaux,
              minCarreaux: systeme.carreauxPlage.$1,
              maxCarreaux: systeme.carreauxPlage.$2,
            );

            if (picked == null) {
              stN.setMasseEnabled(false);
              return;
            }

            debugPrint(
              '[MASS UI BEFORE] '
              'picked=$picked '
              'stateCarreaux=${st.carreaux} '
              'enabled=${st.masseEnabled}',
            );

            stN
              ..setCarreaux(picked)
              ..setMasseEnabled(true);

            debugPrint('[MASS UI SET] squares=$picked enabled=true');
          },
          subtitle: st.masseEnabled
              ? 'Carreaux : ${st.carreaux} • $_deltaMasseLabel'
              : null,
        ),

        const SizedBox(height: 10),

        // 4) Tir similaire
        _toggleCard(
          title: 'Similar fire',
          value: st.tirSimilaire,
          onChanged: (v) => controller.handleTirSimilaireChanged(
            context,
            v,
            distanceCtrl: distCtrl,
          ),
          subtitle: st.tirSimilaire
              ? 'Carreaux: ${st.simCarreaux} • Tprev: ${st.tPrev ?? "—"} • Tact: ${st.tAct ?? "—"} • V0: ${st.v0Prev ?? "—"}'
              : null,
        ),

        const SizedBox(height: 10),

        // 5) Fusée (juste sous Tir similaire)
        // MO-120 : pas de fusee Ralec, uniquement Frappe
        _fuseeCard(context),

        const SizedBox(height: 10),

        // 6) Météo
        _toggleCard(
          title: 'Weather',
          value: st.meteo,
          onChanged: (v) => controller.handleMeteoChanged(
            context,
            v,
            zCtrl: zCtrl,
            deltaAltMetCtrl: deltaAltMetCtrl,
          ),
          subtitle: st.meteo ? (st.meteoFileName ?? 'Loaded') : null,
        ),

        const SizedBox(height: 10),

        // 7) Forcer la charge
        // MO-120 : dialogue dédié avec 14 charges (CH0 à CH10)
        // Caesar / Mepac : dialogue standard CH1..CH6
        _forcerChargeCard(context),

        const SizedBox(height: 10),

        // 8) Autres pièces
        _toggleCard(
          title: 'Other guns',
          value: st.autrePieces,
          subtitle:
              st.autrePieces ? 'Supporting guns: $ps  •  Total: $total' : null,
          onChanged: (v) {
            stN.setAutrePiecesEnabled(v);
            if (v) {
              onOpenAutresPieces();
            } else {
              stN.setPiecesSoutien(const []);
              stN.setCoupsParPieceByPiece(const {});
            }
          },
        ),
      ],
    );
  }

  // ───────────────────────── Fusée ─────────────────────────

  Widget _fuseeCard(BuildContext context) {
    debugPrint(
      '[FUSEE UI] '
      'typeTir=${st.typeTir} '
      'munition=${st.typeMunition} '
      'fusee=${st.fusee}',
    );

    final TypeMunition? munition = st.typeMunition ??
        munitionParDefautPour(systeme: systeme, typeTir: st.typeTir);

    final compatibility = fuseeCompatibilityPour(
      systeme: systeme,
      typeTir: st.typeTir,
      munition: munition,
    );

    final TypeFusee selected = compatibility.normalise(st.fusee);

    final TypeFusee? fuseeTirSimilaire = st.tirSimilaire && st.simFusee != null
        ? compatibility.normalise(st.simFusee!)
        : null;

    final bool fuseeTirSimilaireAConfirmer =
        fuseeTirSimilaire != null && fuseeTirSimilaire != selected;

    if (compatibility.estVerrouillee) {
      return _toggleCard(
        title: 'Fuze',
        value: true,
        onChanged: (_) {},
        subtitle: '${selected.label} — imposed',
        disabled: true,
      );
    }

    final bool enabled = st.fuseeEnabled;

    final String subtitle;
    if (fuseeTirSimilaireAConfirmer) {
      subtitle = 'To confirm: ${fuseeTirSimilaire.label} (similar fire)';
    } else {
      subtitle = enabled
          ? selected.label
          : 'Reference: ${compatibility.reference.label}';
    }

    return _toggleCard(
      title: 'Fuze',
      value: enabled,
      subtitle: subtitle,
      onChanged: (value) async {
        if (!value) {
          stN.setFuseeEnabled(false);
          return;
        }

        final picked = await showFuseeDialog(
          context: context,
          dark: dark,
          initial: fuseeTirSimilaire ??
              (enabled ? selected : compatibility.reference),
          fuseesAutorisees: compatibility.autorisees,
        );

        if (picked == null) {
          stN.setFuseeEnabled(false);
          return;
        }

        stN.setFusee(picked);
      },
    );
  }

  // ───────────────────────── Forcer la charge ─────────────────────────

  Widget _forcerChargeCard(BuildContext context) {
    if (systeme == Systeme.mo120) {
      // MO-120 : dialogue dédié avec 14 charges (CH0 à CH10)
      // La charge forcée est stockée comme String dans chargeForcee
      // (le champ existant est int? mais on passe la String via setChargeForcee)
      final String? chargeActuelle = st.forcerCharge
          ? (st.chargeForcee != null ? 'CH${st.chargeForcee}' : null)
          : null;

      return _toggleCard(
        title: 'Override charge',
        value: st.forcerCharge,
        subtitle: st.forcerCharge ? (chargeActuelle ?? '—') : null,
        onChanged: (v) async {
          if (!v) {
            stN.clearChargeForcee();
            return;
          }
          final picked = await showChargeMo120Dialog(
            context: context,
            dark: dark,
            initialCharge: chargeActuelle,
          );
          if (picked == null) {
            stN.clearChargeForcee();
          } else {
            // Extraire le numéro de charge pour setChargeForcee(int)
            // Pour MO-120, on stocke temporairement via chargeForcee
            // en utilisant une valeur conventionnelle.
            // Note : le champ chargeForcee dans CalculInput est String?,
            // donc on peut passer directement la String.
            stN.setChargeForceeString(picked);
          }
        },
      );
    }

    // Caesar / Mepac : CH1..CH6
    return _toggleCard(
      title: 'Override charge',
      value: st.forcerCharge,
      onChanged: (v) async {
        if (!v) {
          stN.clearChargeForcee();
          return;
        }
        final picked = await showChargeDialog(
          context: context,
          dark: dark,
          initialCharge: st.chargeForcee,
        );
        if (picked == null) {
          stN.clearChargeForcee();
        } else {
          stN.setChargeForcee(picked);
        }
      },
      subtitle: st.forcerCharge ? 'CH${st.chargeForcee ?? "—"}' : null,
    );
  }

  // ───────────────────────── Nature ─────────────────────────

  Widget _natureCard(BuildContext context) {
    final sel = st.natureSelection;
    final enabled = sel?.enabled ?? false;

    String? resume;
    if (enabled && sel != null) {
      final t = sel.nature == NatureTirType.ponctuel
          ? 'Point'
          : (sel.nature == NatureTirType.lineaire ? 'Linear' : 'Zonal');

      final base =
          (sel.nbCoups ?? (sel.nature == NatureTirType.ponctuel ? 1 : 3)).clamp(
        1,
        400,
      );

      final par = (sel.lineairePar ?? 1).clamp(1, 12);

      if (sel.nature == NatureTirType.ponctuel) {
        resume = '$t · x$base rounds';
      } else if (sel.nature == NatureTirType.lineaire) {
        final L = sel.longueurM?.toStringAsFixed(0) ?? '—';
        final az = sel.azimutMil?.toStringAsFixed(0) ?? '—';

        final p =
            (sel.pointApplicationLineaire == PointApplicationLineaire.extremite)
                ? 'End'
                : 'Centered';

        final total = (base * par).clamp(1, 9999);
        resume =
            '$t $L m · $az mil · $p · $base offsets × $par rounds = $total rounds';
      } else {
        // ZONAL : afficher longueur x profondeur et les deux azimuts
        final L = sel.longueurM?.toStringAsFixed(0) ?? '—';
        final P = sel.profondeurM?.toStringAsFixed(0) ?? '—';
        final azL = sel.azimutLargeurMil?.toStringAsFixed(0) ?? '—';
        final azP = sel.azimutProfondeurMil?.toStringAsFixed(0) ?? '—';

        final total = (base * par).clamp(1, 9999);
        resume =
            '$t ${L}x$P m · Az L:$azL/P:$azP mil · $base offsets × $par rounds = $total rounds';
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: enabled ? onOpenNature : null,
      child: Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: SizedBox(
          height: 56,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: _switchReserve,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Fire Mission Type',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (resume != null)
                Positioned(
                  left: 0,
                  right: _switchReserve,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      resume,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondary, fontSize: 12.5),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: _styledSwitch(
                  value: enabled,
                  onChanged: (v) {
                    if (v) {
                      const newSel = NatureTirSelection(
                        enabled: true,
                        nature: NatureTirType.ponctuel,
                        nbCoups: 1,
                        lineairePar: 1,
                      );
                      stN.setNatureSelection(newSel);
                      onOpenNature();
                    } else {
                      final base = sel ??
                          const NatureTirSelection(
                            enabled: false,
                            nature: NatureTirType.ponctuel,
                            nbCoups: 1,
                            lineairePar: 1,
                          );
                      stN.setNatureSelection(base.copyWith(enabled: false));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Toggle cards ─────────────────────────

  Widget _toggleCard({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? subtitle,
    bool disabled = false,
  }) {
    final effectiveOnChanged = disabled ? null : onChanged;

    return Opacity(
      opacity: disabled ? 0.55 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: SizedBox(
          height: subtitle == null ? 56 : 64,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: _switchReserve,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (subtitle != null)
                Positioned(
                  left: 0,
                  right: _switchReserve,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondary, fontSize: 12.5),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: _styledSwitch(
                  value: value,
                  onChanged: effectiveOnChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _styledSwitch({
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Switch(
      value: value,
      onChanged: onChanged,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      activeTrackColor: _trackOn,
      thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) return _thumbOn;
        return _thumbOff;
      }),
      inactiveTrackColor: _trackOff,
    );
  }
}
