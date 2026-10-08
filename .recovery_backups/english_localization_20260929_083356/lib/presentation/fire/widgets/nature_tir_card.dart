import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/zonal/zonal_doctrine_engine.dart'
    show ZonalGeometry;
import 'package:calculateur_etranger/presentation/theme/tir_tokens.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/nature_tir_small_pill.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/nature_tir_switch_doctrine.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/nature_tir_int_picker.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/nature_tir_row.dart';

enum _ZonalPresetKind { general, neutralisation, interdiction, destruction }

enum _ZonalTargetKind { infanterie, blindes, char }

class NatureTirCard extends StatefulWidget {
  const NatureTirCard({
    super.key,
    required this.dark,
    required this.initialSelection,
    required this.onChanged,
    required this.onValidate,
    required this.onCancel,
    required this.diametreEfficaciteM,
  });

  final bool dark;
  final NatureTirSelection? initialSelection;
  final ValueChanged<NatureTirSelection> onChanged;
  final ValueChanged<NatureTirSelection> onValidate;
  final VoidCallback onCancel;
  final double diametreEfficaciteM;

  @override
  State<NatureTirCard> createState() => _NatureTirCardState();
}

class _NatureTirCardState extends State<NatureTirCard> {
  late NatureTirType nature;

  late int nbCoups;
  late int lineairePar;

  double? longueurM;
  double? profondeurM;

  static const double _defaultDebord = 10.0;
  static const double _defaultDebordEclairant = 5.0;
  static const double _defaultDebordZonalNormal = 5.0;
  static const double _defaultDebordZonalParticulier = 10.0;
  static const double _defaultRecouv = 10.0;
  double debordPct = _defaultDebordZonalNormal;
  double recouvPct = _defaultRecouv;
  bool advanced = false;

  PointApplicationLineaire pointLineaire = PointApplicationLineaire.centre;
  double? azimutLineaireMil;

  PointZonal pointZonal = PointZonal.centre;
  double? azimutLargeurMil;
  double? azimutProfondeurMil;

  bool salvesEnabled = false;
  int salvesPreferenceIdx = 0;
  bool lastSalveAroundPd = true;

  late ZonalMode zonalMode;
  _ZonalPresetKind zonalPreset = _ZonalPresetKind.general;
  _ZonalTargetKind? zonalTargetKind;

  late final TextEditingController _longueurCtrl;
  late final TextEditingController _profondeurCtrl;
  late final TextEditingController _azLinCtrl;
  late final TextEditingController _azLargCtrl;
  late final TextEditingController _azProfCtrl;
  late final TextEditingController _debordCtrl;
  late final TextEditingController _recouvCtrl;

  static const _mint = Color(0xFFB8E6C8);
  static const _coverageGreen = Color(0xFFB8E6C8);
  static const _coverageOrange = Color(0xFFC49A52);
  static const _offTrack = Color(0xFFE3E3E3);
  static const _offThumb = Color(0xFF6A6A6A);

  Color get _bg => widget.dark ? const Color(0xFF12141A) : Colors.white;
  Color get _border => widget.dark
      ? Colors.white.withValues(alpha: 0.10)
      : const Color(0x1A000000);
  Color get _text =>
      widget.dark ? Colors.white.withValues(alpha: 0.92) : Colors.black87;
  Color get _sub =>
      widget.dark ? Colors.white.withValues(alpha: 0.70) : Colors.black54;

  bool get _isEclairant => widget.diametreEfficaciteM >= 600.0;

  @override
  void initState() {
    super.initState();

    final init = widget.initialSelection ??
        const NatureTirSelection(
          enabled: true,
          nature: NatureTirType.ponctuel,
          nbCoups: 1,
          lineairePar: 1,
          zonalMode: ZonalMode.otan,
        );

    nature = init.nature;
    nbCoups = (init.nbCoups ?? 1).clamp(1, 40);
    lineairePar = (init.lineairePar ?? 1).clamp(1, 12);

    longueurM = (init.nature == NatureTirType.zonal)
        ? (init.longueurZonaleM ?? init.longueurM)
        : init.longueurM;
    profondeurM = init.profondeurM;

    zonalPreset = _presetFromSelection(init);
    zonalTargetKind = zonalPreset == _ZonalPresetKind.general
        ? null
        : _targetFromSalves(lineairePar);

    final defaultDebord = _defaultDebordForCurrent;

    // Doctrine éclairant : débordement général = 5 %.
    // On force ce défaut afin d'éviter de conserver un ancien 10 %
    // issu d'un tir APPUI ou d'un état précédemment mémorisé.
    debordPct = _isEclairant
        ? _defaultDebordEclairant
        : (init.pourcentageDebordement ?? defaultDebord).toDouble();
    recouvPct = (init.pourcentageRecouvrement ?? _defaultRecouv).toDouble();

    advanced = !_isEclairant &&
        ((init.pourcentageDebordement != null &&
                init.pourcentageDebordement != defaultDebord) ||
            (init.pourcentageRecouvrement != null &&
                init.pourcentageRecouvrement != _defaultRecouv));

    pointLineaire =
        init.pointApplicationLineaire ?? PointApplicationLineaire.centre;

    azimutLineaireMil = (init.nature == NatureTirType.lineaire)
        ? (init.azimutMil ?? init.azimutLargeurMil)
        : null;

    azimutLargeurMil = init.azimutLargeurMil ?? init.azimutMil;
    azimutProfondeurMil = init.azimutProfondeurMil;
    pointZonal = init.pointZonal ?? PointZonal.centre;

    salvesEnabled = init.salvesEnabled;
    salvesPreferenceIdx = init.salvesPreferenceIdx;
    lastSalveAroundPd = init.lastSalveAroundPd;

    zonalMode = init.zonalMode;

    _longueurCtrl = TextEditingController(text: _fmt0(longueurM));
    _profondeurCtrl = TextEditingController(text: _fmt0(profondeurM));
    _azLinCtrl = TextEditingController(text: _fmt0(azimutLineaireMil));
    _azLargCtrl = TextEditingController(text: _fmt0(azimutLargeurMil));
    _azProfCtrl = TextEditingController(text: _fmt0(azimutProfondeurMil));
    _debordCtrl = TextEditingController(text: debordPct.toStringAsFixed(0));
    _recouvCtrl = TextEditingController(text: recouvPct.toStringAsFixed(0));

    _applyDefaultsIfNeeded();

    debugPrint(
      '[NATURE_CARD] init '
      'nature=$nature nbCoups=$nbCoups par=$lineairePar '
      'salves=$salvesEnabled pref=$salvesPreferenceIdx last=$lastSalveAroundPd '
      'zonalMode=$zonalMode preset=$zonalPreset',
    );

    _emit();
  }

  @override
  void dispose() {
    _longueurCtrl.dispose();
    _profondeurCtrl.dispose();
    _azLinCtrl.dispose();
    _azLargCtrl.dispose();
    _azProfCtrl.dispose();
    _debordCtrl.dispose();
    _recouvCtrl.dispose();
    super.dispose();
  }

  String _fmt0(double? v) => v == null ? '' : v.toStringAsFixed(0);

  double _normalizeMil(double v) {
    var out = v % 6400.0;
    if (out < 0) out += 6400.0;
    return out;
  }

  void _syncAzimutProfondeurFromLargeur() {
    final l = azimutLargeurMil;
    if (l == null) return;
    azimutProfondeurMil = _normalizeMil(l + 1600.0);
    _azProfCtrl.text = _fmt0(azimutProfondeurMil);
  }

  static double _defaultDebordFor({
    required NatureTirType nature,
    required _ZonalPresetKind preset,
  }) {
    if (nature == NatureTirType.zonal) {
      return preset == _ZonalPresetKind.general
          ? _defaultDebordZonalNormal
          : _defaultDebordZonalParticulier;
    }
    return _defaultDebord;
  }

  double get _defaultDebordForCurrent {
    if (_isEclairant && zonalPreset == _ZonalPresetKind.general) {
      return _defaultDebordEclairant;
    }

    return _defaultDebordFor(nature: nature, preset: zonalPreset);
  }

  void _setDebordToCurrentDefault() {
    debordPct = _defaultDebordForCurrent;
    _debordCtrl.text = debordPct.toStringAsFixed(0);
  }

  _ZonalPresetKind _presetFromSelection(NatureTirSelection init) {
    if (init.nature != NatureTirType.zonal) return _ZonalPresetKind.general;
    if (init.zonalMode != ZonalMode.force) return _ZonalPresetKind.general;
    if ((init.nbCoups ?? 0) != 8) return _ZonalPresetKind.general;

    final l = init.longueurZonaleM ?? init.longueurM ?? 0.0;
    final p = init.profondeurM ?? 0.0;
    if ((l - p).abs() > 1.0) return _ZonalPresetKind.general;

    if ((l - 200.0).abs() <= 1.0) return _ZonalPresetKind.neutralisation;
    if ((l - 150.0).abs() <= 1.0) return _ZonalPresetKind.interdiction;
    if ((l - 100.0).abs() <= 1.0) return _ZonalPresetKind.destruction;
    return _ZonalPresetKind.general;
  }

  void _applyPreset(_ZonalPresetKind preset) {
    zonalPreset = preset;

    if (preset == _ZonalPresetKind.general) {
      zonalTargetKind = null;
      _setDebordToCurrentDefault();
      nbCoups = _suggestNbCoups();
      return;
    }

    zonalMode = ZonalMode.force;
    nbCoups = 8;
    lineairePar = 1;
    zonalTargetKind = _targetFromSalves(lineairePar);
    salvesEnabled = true;
    salvesPreferenceIdx = 0;
    lastSalveAroundPd = true;

    switch (preset) {
      case _ZonalPresetKind.neutralisation:
        longueurM = 200.0;
        profondeurM = 200.0;
        break;
      case _ZonalPresetKind.interdiction:
        longueurM = 150.0;
        profondeurM = 150.0;
        break;
      case _ZonalPresetKind.destruction:
        longueurM = 100.0;
        profondeurM = 100.0;
        break;
      case _ZonalPresetKind.general:
        break;
    }

    _setDebordToCurrentDefault();
    recouvPct = _defaultRecouv;
    _longueurCtrl.text = _fmt0(longueurM);
    _profondeurCtrl.text = _fmt0(profondeurM);
    _debordCtrl.text = debordPct.toStringAsFixed(0);
    _recouvCtrl.text = recouvPct.toStringAsFixed(0);
  }

  void _clearPresetIfManualDimensionChanged() {
    if (zonalPreset != _ZonalPresetKind.general) {
      zonalPreset = _ZonalPresetKind.general;
      zonalTargetKind = null;
      if (!advanced) {
        _setDebordToCurrentDefault();
      }
    }
  }

  bool get _isSpecificZonal =>
      nature == NatureTirType.zonal && zonalPreset != _ZonalPresetKind.general;

  int _salvesForTarget(_ZonalTargetKind target) {
    switch (target) {
      case _ZonalTargetKind.infanterie:
        return 1;
      case _ZonalTargetKind.blindes:
        return 2;
      case _ZonalTargetKind.char:
        return 3;
    }
  }

  String _targetLabel(_ZonalTargetKind target) {
    switch (target) {
      case _ZonalTargetKind.infanterie:
        return 'Infanterie';
      case _ZonalTargetKind.blindes:
        return 'Blindés';
      case _ZonalTargetKind.char:
        return 'Char';
    }
  }

  _ZonalTargetKind? _targetFromSalves(int salves) {
    if (salves <= 1) return _ZonalTargetKind.infanterie;
    if (salves == 2) return _ZonalTargetKind.blindes;
    if (salves >= 3) return _ZonalTargetKind.char;
    return null;
  }

  void _applyZonalTarget(_ZonalTargetKind target) {
    zonalTargetKind = target;
    salvesEnabled = true;
    lineairePar = _salvesForTarget(target).clamp(1, 3);
    _applyDefaultsIfNeeded();
  }

  void _applyDefaultsIfNeeded() {
    if (nature != NatureTirType.ponctuel) {
      if (debordPct.isNaN) debordPct = _defaultDebordForCurrent;
      if (recouvPct.isNaN) recouvPct = _defaultRecouv;

      debordPct = debordPct.clamp(0, 200);
      recouvPct = recouvPct.clamp(0, 95);
      nbCoups = nbCoups.clamp(1, 40);
      lineairePar =
          _isSpecificZonal ? lineairePar.clamp(1, 3) : lineairePar.clamp(1, 12);
    } else {
      lineairePar = 1;
      nbCoups = 1;
    }

    if (nature == NatureTirType.zonal) {
      if (profondeurM != null && profondeurM!.isNaN) profondeurM = null;
      if (profondeurM != null && profondeurM! < 0) profondeurM = 0;
    }
  }

  int _suggestNbCoups() {
    if (nature == NatureTirType.ponctuel) return 1;

    final L = (longueurM ?? 0).clamp(0, 999999);
    if (L <= 0) return 1;

    final d =
        widget.diametreEfficaciteM <= 0 ? 100.0 : widget.diametreEfficaciteM;

    final longueurEff = L * (1.0 + (debordPct / 100.0));
    final pas = d * (1.0 - (recouvPct / 100.0));
    final safePas = pas <= 0 ? d * 0.85 : pas;

    if (nature == NatureTirType.lineaire) {
      // Éclairant : le diamètre 600 m représente déjà la couverture utile.
      // On calcule donc le nombre de positions par couverture cumulée,
      // sans appliquer le recouvrement HE.
      if (_isEclairant) {
        return (longueurEff / d).ceil().clamp(1, 40);
      }

      return (longueurEff / safePas).ceil().clamp(1, 40);
    }

    if (nature == NatureTirType.zonal) {
      if (zonalPreset != _ZonalPresetKind.general) return 8;

      final P = (profondeurM ?? 0).clamp(0, 999999);
      if (P <= 0) return 1;

      final isEclairant = widget.diametreEfficaciteM >= 600.0;

      // ============================================
      // DOCTRINE ÉCLAIRANT
      // ============================================
      //
      // Le diamètre de 600 m représente déjà
      // la couverture utile.
      //
      // Donc :
      // - PAS de logique HE
      // - PAS de recouvrement OTAN
      // - PAS de géométrie "économie"
      //
      // On construit simplement une grille minimale
      // couvrant la surface avec le débord demandé.
      //
      if (isEclairant) {
        final largeurExt = L * (1.0 + debordPct / 100.0);
        final profondeurExt = P * (1.0 + debordPct / 100.0);

        final cols = math.max(1, (largeurExt / d).ceil());
        final rows = math.max(1, (profondeurExt / d).ceil());

        return (cols * rows).clamp(1, 40);
      }

      // ============================================
      // HE classique
      // ============================================

      final geo = ZonalGeometry.compute(
        largeur: L.toDouble(),
        profondeur: P.toDouble(),
        debordementRatio: debordPct / 100.0,
        recouvrementMini: recouvPct / 100.0,
        diametreEfficaceM: d,
      );

      return (zonalMode == ZonalMode.otan ? geo.coupsOtan : geo.coupsForce)
          .clamp(1, 40);
    }

    return 1;
  }

  void _setZonalModeAndSyncCoups(ZonalMode mode) {
    zonalMode = mode;
    if (zonalPreset != _ZonalPresetKind.general && mode != ZonalMode.force) {
      zonalPreset = _ZonalPresetKind.general;
      zonalTargetKind = null;
      if (!advanced) {
        _setDebordToCurrentDefault();
      }
    }
    nbCoups = _suggestNbCoups();
    _applyDefaultsIfNeeded();
  }

  int get _totalCoups {
    if (nature == NatureTirType.ponctuel) return 1;
    return (nbCoups * lineairePar).clamp(1, 400);
  }

  NatureTirSelection _buildSelection() {
    final bool effectiveSalvesEnabled =
        nature == NatureTirType.ponctuel ? false : salvesEnabled;
    final int effectiveSalvesPreferenceIdx =
        nature == NatureTirType.ponctuel ? 0 : salvesPreferenceIdx;
    final bool effectiveLastSalveAroundPd =
        nature == NatureTirType.ponctuel ? true : lastSalveAroundPd;

    return NatureTirSelection(
      enabled: true,
      nature: nature,
      nbCoups: nbCoups,
      lineairePar: nature == NatureTirType.ponctuel ? 1 : lineairePar,
      longueurM: nature == NatureTirType.lineaire ? longueurM : null,
      longueurZonaleM: nature == NatureTirType.zonal ? longueurM : null,
      profondeurM: nature == NatureTirType.zonal ? profondeurM : null,
      pointApplicationLineaire:
          nature == NatureTirType.lineaire ? pointLineaire : null,
      pointZonal: nature == NatureTirType.zonal ? pointZonal : null,
      zonalMode: nature == NatureTirType.zonal ? zonalMode : ZonalMode.otan,
      azimutMil: nature == NatureTirType.lineaire ? azimutLineaireMil : null,
      azimutLargeurMil: nature == NatureTirType.zonal ? azimutLargeurMil : null,
      azimutProfondeurMil:
          nature == NatureTirType.zonal ? azimutProfondeurMil : null,
      pourcentageDebordement:
          nature == NatureTirType.ponctuel ? null : debordPct,
      pourcentageRecouvrement:
          nature == NatureTirType.ponctuel ? null : recouvPct,
      salvesEnabled: effectiveSalvesEnabled,
      salvesPreferenceIdx: effectiveSalvesPreferenceIdx,
      lastSalveAroundPd: effectiveLastSalveAroundPd,
    );
  }

  void _emit() {
    final sel = _buildSelection();

    debugPrint(
      '[NATURE_CARD] emit '
      'nature=${sel.nature} nbCoups=${sel.nbCoups} par=${sel.lineairePar} '
      'local.salves=$salvesEnabled sel.salves=${sel.salvesEnabled} '
      'pref=${sel.salvesPreferenceIdx} last=${sel.lastSalveAroundPd} '
      'zonalMode=${sel.zonalMode} preset=$zonalPreset',
    );

    widget.onChanged(sel);
  }

  Widget _salvePreferencePicker() {
    return DropdownButton<int>(
      value: salvesPreferenceIdx,
      items: const [
        DropdownMenuItem(value: 0, child: Text('Auto')),
        DropdownMenuItem(value: 1, child: Text('Droite')),
        DropdownMenuItem(value: 2, child: Text('Gauche')),
      ],
      onChanged: (v) {
        if (v != null) {
          setState(() {
            salvesPreferenceIdx = v;
          });
          debugPrint('[NATURE_CARD] pref salves -> $salvesPreferenceIdx');
          _emit();
        }
      },
      isExpanded: true,
      underline: Container(),
      style: TextStyle(
        color: _text,
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
      ),
      dropdownColor: _bg,
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.82;

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Container(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(TirRadius.xl),
            border: Border.all(color: _border),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fire Mission Type',
                  style: TextStyle(
                    color: _text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: TirSpacing.xs),
                Text(
                  'Choisir la géométrie puis ajuster uniquement les paramètres nécessaires.',
                  style: TextStyle(
                    color: _sub,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: TirSpacing.l),
                Row(
                  children: [
                    Expanded(child: _pill('Ponctuel', NatureTirType.ponctuel)),
                    const SizedBox(width: 10),
                    Expanded(child: _pill('Linéaire', NatureTirType.lineaire)),
                    const SizedBox(width: 10),
                    Expanded(child: _pill('Zonal', NatureTirType.zonal)),
                  ],
                ),
                if (nature == NatureTirType.zonal) ...[
                  const SizedBox(height: TirSpacing.m),
                  _sectionTitle('Type zonal'),
                  const SizedBox(height: 10),
                  _zonalPresetPicker(),
                  const SizedBox(height: TirSpacing.m),
                  _row(
                    label: 'Mode',
                    child: Row(
                      children: [
                        Text(
                          'OTAN',
                          style: TextStyle(
                            color: zonalMode == ZonalMode.otan ? _mint : _sub,
                            fontSize: 12.5,
                            fontWeight: zonalMode == ZonalMode.otan
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: TirSpacing.s),
                        _switchDoctrine(
                          value: zonalMode == ZonalMode.force,
                          onChanged: (v) {
                            setState(() {
                              _setZonalModeAndSyncCoups(
                                v ? ZonalMode.force : ZonalMode.otan,
                              );
                            });
                            debugPrint(
                              '[NATURE_CARD] zonalMode -> $zonalMode nbCoups=$nbCoups',
                            );
                            _emit();
                          },
                        ),
                        const SizedBox(width: TirSpacing.s),
                        Text(
                          'Forcé',
                          style: TextStyle(
                            color: zonalMode == ZonalMode.force ? _mint : _sub,
                            fontSize: 12.5,
                            fontWeight: zonalMode == ZonalMode.force
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isSpecificZonal) ...[
                    const SizedBox(height: TirSpacing.m),
                    _zonalEnemyNaturePanel(),
                  ],
                ],
                if (nature != NatureTirType.ponctuel) ...[
                  const SizedBox(height: TirSpacing.l),
                  _sectionTitle('Dimensions'),
                  const SizedBox(height: 10),
                  _dimensionsFields(),
                  const SizedBox(height: 14),
                  _sectionTitle('Point d’application'),
                  const SizedBox(height: 10),
                  if (nature == NatureTirType.lineaire) _tileChoiceLineaire(),
                  if (nature == NatureTirType.zonal) ...[
                    _tileChoiceZonal(),
                    const SizedBox(height: TirSpacing.s),
                    Text(
                      'Coin / Milieu (de la longueur) / Centre.\n'
                      'Le sens droite/gauche est porté par l’azimut largeur.',
                      style: TextStyle(color: _sub, fontSize: 12.0),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _sectionTitle('Conventions'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Débord ${debordPct.toStringAsFixed(0)}% • '
                          'Recouv ${recouvPct.toStringAsFixed(0)}%',
                          style: TextStyle(color: _sub, fontSize: 12.5),
                        ),
                      ),
                      _switchDoctrine(
                        value: advanced,
                        onChanged: (v) {
                          setState(() {
                            advanced = v;
                            if (!advanced) {
                              _setDebordToCurrentDefault();
                              recouvPct = _defaultRecouv;
                              _recouvCtrl.text = recouvPct.toStringAsFixed(0);
                              _applyDefaultsIfNeeded();
                            }
                          });
                          debugPrint('[NATURE_CARD] advanced -> $advanced');
                          _emit();
                        },
                      ),
                    ],
                  ),
                  if (advanced) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _numberField(
                            label: 'Débord (%)',
                            controller: _debordCtrl,
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  debordPct = v;
                                  _applyDefaultsIfNeeded();
                                });
                                debugPrint(
                                  '[NATURE_CARD] debord -> $debordPct',
                                );
                                _emit();
                              }
                            },
                            inlineLabel: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _numberField(
                            label: 'Recouv (%)',
                            controller: _recouvCtrl,
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  recouvPct = v;
                                  _applyDefaultsIfNeeded();
                                });
                                debugPrint(
                                  '[NATURE_CARD] recouv -> $recouvPct',
                                );
                                _emit();
                              }
                            },
                            inlineLabel: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  _sectionTitle('Consommation'),
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _row(
                        label: 'Nb coups',
                        child: _intPickerCentered(
                          value: nbCoups,
                          min: 1,
                          max: 40,
                          onChanged: (v) {
                            setState(() {
                              nbCoups = v;
                              if (nature == NatureTirType.zonal &&
                                  zonalPreset != _ZonalPresetKind.general &&
                                  v != 8) {
                                zonalPreset = _ZonalPresetKind.general;
                                zonalTargetKind = null;
                              }
                              _applyDefaultsIfNeeded();
                            });
                            debugPrint('[NATURE_CARD] nbCoups -> $nbCoups');
                            _emit();
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              nbCoups = _suggestNbCoups();
                              _applyDefaultsIfNeeded();
                            });
                            debugPrint(
                              '[NATURE_CARD] suggest nbCoups -> $nbCoups',
                            );
                            _emit();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _text,
                            side: BorderSide(color: _border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Suggérer'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _row(
                          label: _isSpecificZonal ? 'Nb salves' : 'Par',
                          child: _intPickerCentered(
                            value: lineairePar,
                            min: 1,
                            max: _isSpecificZonal ? 3 : 12,
                            onChanged: (v) {
                              setState(() {
                                lineairePar = v;
                                if (_isSpecificZonal) {
                                  zonalTargetKind = _targetFromSalves(
                                    lineairePar,
                                  );
                                }
                                _applyDefaultsIfNeeded();
                              });
                              debugPrint('[NATURE_CARD] par -> $lineairePar');
                              _emit();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isSpecificZonal
                              ? 'Total = $nbCoups coups × $lineairePar salve(s)'
                              : 'Total = $nbCoups × $lineairePar = $_totalCoups',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: _sub, fontSize: 12.0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _sectionTitle('Tir en salve'),
                  const SizedBox(height: 10),
                  _row(
                    label: 'Activer',
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _switchDoctrine(
                        value: salvesEnabled,
                        onChanged: (v) {
                          setState(() {
                            salvesEnabled = v;
                          });
                          debugPrint(
                            '[NATURE_CARD] switch salves -> $salvesEnabled',
                          );
                          _emit();
                        },
                      ),
                    ),
                  ),
                  if (salvesEnabled) ...[
                    const SizedBox(height: 10),
                    _row(label: 'Préférence', child: _salvePreferencePicker()),
                    const SizedBox(height: 10),
                    _row(
                      label: 'Dernière salve PD',
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _switchDoctrine(
                          value: lastSalveAroundPd,
                          onChanged: (v) {
                            setState(() {
                              lastSalveAroundPd = v;
                            });
                            debugPrint(
                              '[NATURE_CARD] switch last PD -> $lastSalveAroundPd',
                            );
                            _emit();
                          },
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: TirSpacing.l),
                const Divider(height: 1),
                const SizedBox(height: TirSpacing.l),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _text,
                          side: BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(TirRadius.l),
                          ),
                        ),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _applyDefaultsIfNeeded();
                          });

                          final sel = _buildSelection();

                          debugPrint(
                            '[NATURE_CARD] validate '
                            'nature=${sel.nature} nbCoups=${sel.nbCoups} par=${sel.lineairePar} '
                            'local.salves=$salvesEnabled sel.salves=${sel.salvesEnabled} '
                            'pref=${sel.salvesPreferenceIdx} last=${sel.lastSalveAroundPd} '
                            'zonalMode=${sel.zonalMode} preset=$zonalPreset',
                          );

                          widget.onValidate(sel);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.dark
                              ? const Color(0xFF2A2E35)
                              : const Color(0xFFE7E8EC),
                          foregroundColor: _text,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(TirRadius.l),
                          ),
                          elevation: 0,
                        ),
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
    );
  }

  Widget _zonalPresetPicker() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _smallPill(
                'Général',
                zonalPreset == _ZonalPresetKind.general,
                () {
                  setState(() {
                    _applyPreset(_ZonalPresetKind.general);
                    _applyDefaultsIfNeeded();
                  });
                  debugPrint('[NATURE_CARD] zonalPreset -> general');
                  _emit();
                },
              ),
            ),
            const SizedBox(width: TirSpacing.s),
            Expanded(
              child: _smallPill(
                'Neutralisation',
                zonalPreset == _ZonalPresetKind.neutralisation,
                () {
                  setState(() {
                    _applyPreset(_ZonalPresetKind.neutralisation);
                    _applyDefaultsIfNeeded();
                  });
                  debugPrint('[NATURE_CARD] zonalPreset -> neutralisation');
                  _emit();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: TirSpacing.s),
        Row(
          children: [
            Expanded(
              child: _smallPill(
                'Interdiction',
                zonalPreset == _ZonalPresetKind.interdiction,
                () {
                  setState(() {
                    _applyPreset(_ZonalPresetKind.interdiction);
                    _applyDefaultsIfNeeded();
                  });
                  debugPrint('[NATURE_CARD] zonalPreset -> interdiction');
                  _emit();
                },
              ),
            ),
            const SizedBox(width: TirSpacing.s),
            Expanded(
              child: _smallPill(
                'Destruction',
                zonalPreset == _ZonalPresetKind.destruction,
                () {
                  setState(() {
                    _applyPreset(_ZonalPresetKind.destruction);
                    _applyDefaultsIfNeeded();
                  });
                  debugPrint('[NATURE_CARD] zonalPreset -> destruction');
                  _emit();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _zonalEnemyNaturePanel() {
    final effectiveTarget = zonalTargetKind ?? _targetFromSalves(lineairePar);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TirSpacing.m),
      decoration: BoxDecoration(
        color: _mint.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(TirRadius.l),
        border: Border.all(color: _mint.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nature de l’ennemi',
            style: TextStyle(
              color: _text,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: TirSpacing.s),
          LayoutBuilder(
            builder: (context, constraints) {
              final isTight = constraints.maxWidth < 360;
              final items = _ZonalTargetKind.values.map((target) {
                final isOn = effectiveTarget == target;
                return SizedBox(
                  width: isTight ? double.infinity : null,
                  child: _smallPill(
                    '${_targetLabel(target)} • ${_salvesForTarget(target)}S',
                    isOn,
                    () {
                      setState(() => _applyZonalTarget(target));
                      debugPrint(
                        '[NATURE_CARD] objectif zonal -> ${_targetLabel(target)} salves=$lineairePar',
                      );
                      _emit();
                    },
                  ),
                );
              }).toList();

              if (isTight) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      items[i],
                      if (i != items.length - 1)
                        const SizedBox(height: TirSpacing.s),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: items[0]),
                  const SizedBox(width: TirSpacing.s),
                  Expanded(child: items[1]),
                  const SizedBox(width: TirSpacing.s),
                  Expanded(child: items[2]),
                ],
              );
            },
          ),
          const SizedBox(height: TirSpacing.m),
          _row(
            label: 'Nb salves',
            child: _intPickerCentered(
              value: lineairePar,
              min: 1,
              max: 3,
              onChanged: (v) {
                setState(() {
                  lineairePar = v.clamp(1, 3);
                  zonalTargetKind = _targetFromSalves(lineairePar);
                  salvesEnabled = true;
                  _applyDefaultsIfNeeded();
                });
                debugPrint('[NATURE_CARD] nb salves zonal -> $lineairePar');
                _emit();
              },
            ),
          ),
          const SizedBox(height: TirSpacing.s),
          Text(
            'Les éléments de tir sont calculés pour toutes les salves.',
            style: TextStyle(
              color: _sub,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _zonalCoverageAdvisor() {
    final coverage = _computeZonalCoverageSummary();
    if (coverage == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 110),
          child: Text(
            'Couverture du zonal réel ${coverage.surfaceM2.toStringAsFixed(0)} m²',
            style: TextStyle(color: _sub, fontSize: 11.5),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 110),
          child: Row(
            children: [
              Expanded(
                child: _coverageBadge(
                  label: 'FORCÉ',
                  valuePct: coverage.forcePct,
                  coups: coverage.forceCoups,
                  selected: zonalMode == ZonalMode.force,
                  onTap: () {
                    setState(() {
                      _setZonalModeAndSyncCoups(ZonalMode.force);
                    });
                    debugPrint(
                      '[NATURE_CARD] coverage badge -> force ${coverage.forcePct.toStringAsFixed(1)}% nbCoups=$nbCoups',
                    );
                    _emit();
                  },
                ),
              ),
              const SizedBox(width: TirSpacing.s),
              Expanded(
                child: _coverageBadge(
                  label: 'OTAN',
                  valuePct: coverage.otanPct,
                  coups: coverage.otanCoups,
                  selected: zonalMode == ZonalMode.otan,
                  onTap: () {
                    setState(() {
                      _setZonalModeAndSyncCoups(ZonalMode.otan);
                    });
                    debugPrint(
                      '[NATURE_CARD] coverage badge -> otan ${coverage.otanPct.toStringAsFixed(1)}% nbCoups=$nbCoups',
                    );
                    _emit();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coverageBadge({
    required String label,
    required double valuePct,
    required int coups,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final color = valuePct >= 95.0 ? _coverageGreen : _coverageOrange;
    final bg = selected
        ? color.withValues(alpha: 0.24)
        : color.withValues(alpha: 0.11);
    final border = selected ? color : color.withValues(alpha: 0.70);

    return InkWell(
      borderRadius: BorderRadius.circular(TirRadius.m),
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(TirRadius.m),
          border: Border.all(color: border, width: selected ? 1.6 : 1.1),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$label ${valuePct.toStringAsFixed(1)} % • $coups c.',
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 12.0,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  _ZonalCoverageSummary? _computeZonalCoverageSummary() {
    if (nature != NatureTirType.zonal) return null;

    final largeur = longueurM;
    final profondeur = profondeurM;
    if (largeur == null || profondeur == null) return null;
    if (largeur <= 0 || profondeur <= 0) return null;

    final d =
        widget.diametreEfficaciteM <= 0 ? 100.0 : widget.diametreEfficaciteM;
    final r = d / 2.0;
    final recouv = (recouvPct / 100.0).clamp(0.0, 0.95).toDouble();
    final debord = (debordPct / 100.0).clamp(0.0, 2.0).toDouble();
    final surface = largeur * profondeur;

    // Pour les trois tirs prédéfinis, le pourcentage affiché est calculé sur
    // les vrais 8 centres du preset, pas sur une grille générique OTAN/forcé.
    if (zonalPreset != _ZonalPresetKind.general) {
      final presetCenters = _presetCoverageCenters(
        largeur: largeur,
        profondeur: profondeur,
        radius: r,
        debordementRatio: debord,
      );

      final presetPct = _coveragePctInNominalRectangle(
        largeur: largeur,
        profondeur: profondeur,
        radius: r,
        centers: presetCenters,
      );

      return _ZonalCoverageSummary(
        surfaceM2: surface,
        forcePct: presetPct,
        otanPct: presetPct,
        forceCoups: 8,
        otanCoups: 8,
      );
    }

    final pas = math.max(1.0, d * (1.0 - recouv));

    final largeurExt = largeur * (1.0 + debord);
    final profondeurExt = profondeur * (1.0 + debord);

    final nCols = math.max(1, (largeurExt / pas).ceil());
    final nRows = math.max(1, (profondeurExt / pas).ceil());

    final xs = _axisCenters(count: nCols, extent: largeurExt, radius: r);
    final ys = _axisCenters(count: nRows, extent: profondeurExt, radius: r);

    final forceCenters = <Offset>[
      for (final y in ys)
        for (final x in xs) Offset(x, y),
    ];

    final otanCenters = <Offset>[];
    for (var row = 0; row < ys.length; row++) {
      for (var col = 0; col < xs.length; col++) {
        final isInternalAlternatingRow = row.isOdd && row < ys.length - 1;
        final removeEconomyCell = xs.length >= 3 &&
            ys.length >= 3 &&
            isInternalAlternatingRow &&
            col == 0;
        if (!removeEconomyCell) {
          otanCenters.add(Offset(xs[col], ys[row]));
        }
      }
    }

    final geo = ZonalGeometry.compute(
      largeur: largeur,
      profondeur: profondeur,
      debordementRatio: debordPct / 100.0,
      recouvrementMini: recouvPct / 100.0,
      diametreEfficaceM: d,
    );

    final forcePct = _coveragePctInNominalRectangle(
      largeur: largeur,
      profondeur: profondeur,
      radius: r,
      centers: forceCenters,
    );
    final otanPct = _coveragePctInNominalRectangle(
      largeur: largeur,
      profondeur: profondeur,
      radius: r,
      centers: otanCenters,
    );

    return _ZonalCoverageSummary(
      surfaceM2: surface,
      forcePct: forcePct,
      otanPct: otanPct,
      forceCoups: geo.coupsForce.clamp(1, 40),
      otanCoups: geo.coupsOtan.clamp(1, 40),
    );
  }

  List<Offset> _presetCoverageCenters({
    required double largeur,
    required double profondeur,
    required double radius,
    required double debordementRatio,
  }) {
    final halfExtendedWidth = largeur * (1.0 + debordementRatio) / 2.0;
    final halfExtendedDepth = profondeur * (1.0 + debordementRatio) / 2.0;

    // Centres diagonaux : cercle tangent au coin du rectangle étendu.
    final diagonal = math.sqrt(
      halfExtendedWidth * halfExtendedWidth +
          halfExtendedDepth * halfExtendedDepth,
    );
    final diagonalFactor =
        diagonal <= 0.0 ? 0.0 : math.max(0.0, (diagonal - radius) / diagonal);
    final dx = halfExtendedWidth * diagonalFactor;
    final dy = halfExtendedDepth * diagonalFactor;

    // Centres axiaux : cercles tangents aux côtés du rectangle étendu.
    final sx = math.max(0.0, halfExtendedWidth - radius);
    final sy = math.max(0.0, halfExtendedDepth - radius);

    return <Offset>[
      Offset(dx, dy),
      Offset(-dx, dy),
      Offset(-dx, -dy),
      Offset(dx, -dy),
      Offset(sx, 0.0),
      Offset(-sx, 0.0),
      Offset(0.0, sy),
      Offset(0.0, -sy),
    ];
  }

  List<double> _axisCenters({
    required int count,
    required double extent,
    required double radius,
  }) {
    if (count <= 1) return const [0.0];
    final min = -(extent / 2.0 - radius);
    final max = -min;
    final step = (max - min) / (count - 1);
    return [for (var i = 0; i < count; i++) min + i * step];
  }

  double _coveragePctInNominalRectangle({
    required double largeur,
    required double profondeur,
    required double radius,
    required List<Offset> centers,
  }) {
    if (centers.isEmpty || largeur <= 0 || profondeur <= 0 || radius <= 0) {
      return 0.0;
    }

    final samplesX = math.max(120, math.min(420, (largeur * 2.0).round()));
    final samplesY = math.max(120, math.min(420, (profondeur * 2.0).round()));
    final left = -largeur / 2.0;
    final top = -profondeur / 2.0;
    final dx = largeur / samplesX;
    final dy = profondeur / samplesY;
    final r2 = radius * radius;

    var covered = 0;
    final total = samplesX * samplesY;

    for (var iy = 0; iy < samplesY; iy++) {
      final y = top + (iy + 0.5) * dy;
      for (var ix = 0; ix < samplesX; ix++) {
        final x = left + (ix + 0.5) * dx;
        var hit = false;
        for (final c in centers) {
          final ddx = x - c.dx;
          final ddy = y - c.dy;
          if (ddx * ddx + ddy * ddy <= r2) {
            hit = true;
            break;
          }
        }
        if (hit) covered++;
      }
    }

    return 100.0 * covered / total;
  }

  Widget _sectionTitle(String t) {
    return Text(
      t,
      style: TextStyle(
        color: _text,
        fontSize: 13.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _pill(String label, NatureTirType t) {
    final isOn = nature == t;
    final bg = isOn
        ? (widget.dark ? TirColors.actionDark : TirColors.actionLight)
        : _bg;
    final bd =
        isOn ? _mint.withValues(alpha: widget.dark ? 0.55 : 0.45) : _border;

    return InkWell(
      borderRadius: BorderRadius.circular(TirRadius.l),
      onTap: () {
        setState(() {
          final previousNature = nature;
          nature = t;

          if (nature == NatureTirType.ponctuel) {
            lineairePar = 1;
            nbCoups = 1;
            salvesEnabled = false;
            salvesPreferenceIdx = 0;
            lastSalveAroundPd = true;
            zonalPreset = _ZonalPresetKind.general;
            zonalTargetKind = null;
          } else {
            if (nature == NatureTirType.zonal &&
                previousNature != NatureTirType.zonal &&
                !salvesEnabled) {
              salvesEnabled = true;
              salvesPreferenceIdx = 0;
              lastSalveAroundPd = true;
              if (!advanced) {
                zonalPreset = _ZonalPresetKind.general;
                _setDebordToCurrentDefault();
              }
            }

            if (nature != NatureTirType.zonal) {
              zonalMode = ZonalMode.otan;
              zonalPreset = _ZonalPresetKind.general;
              zonalTargetKind = null;
            }

            nbCoups = _suggestNbCoups();
            lineairePar = _isSpecificZonal
                ? lineairePar.clamp(1, 3)
                : lineairePar.clamp(1, 12);
          }

          _applyDefaultsIfNeeded();
        });

        debugPrint(
          '[NATURE_CARD] change nature -> $nature '
          'nbCoups=$nbCoups par=$lineairePar salves=$salvesEnabled '
          'zonalMode=$zonalMode preset=$zonalPreset',
        );

        _emit();
      },
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(TirRadius.l),
          border: Border.all(color: bd),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: _text,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }

  Widget _dimensionsFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;

        final longueur = _numberField(
          label: 'Longueur (m)',
          controller: _longueurCtrl,
          onChanged: (v) {
            if (v != null) {
              setState(() {
                longueurM = v;
                if (nature == NatureTirType.zonal) {
                  _clearPresetIfManualDimensionChanged();
                }
                _applyDefaultsIfNeeded();
              });
              debugPrint('[NATURE_CARD] longueur -> $longueurM');
              _emit();
            }
          },
        );

        final azimutLineaire = _numberField(
          label: 'Azimut (mil)',
          controller: _azLinCtrl,
          onChanged: (v) {
            if (v != null) {
              setState(() {
                azimutLineaireMil = v;
                _applyDefaultsIfNeeded();
              });
              debugPrint('[NATURE_CARD] azimutLineaire -> $azimutLineaireMil');
              _emit();
            }
          },
        );

        final azimutLargeur = _numberField(
          label: 'Az. larg. (mil)',
          controller: _azLargCtrl,
          onChanged: (v) {
            if (v != null) {
              setState(() {
                azimutLargeurMil = _normalizeMil(v);
                _syncAzimutProfondeurFromLargeur();
                _applyDefaultsIfNeeded();
              });
              debugPrint(
                '[NATURE_CARD] azimutLargeur -> $azimutLargeurMil azimutProfondeur -> $azimutProfondeurMil',
              );
              _emit();
            }
          },
        );

        final profondeur = _numberField(
          label: 'Profondeur (m)',
          controller: _profondeurCtrl,
          onChanged: (v) {
            if (v != null) {
              setState(() {
                profondeurM = v;
                _clearPresetIfManualDimensionChanged();
                _applyDefaultsIfNeeded();
              });
              debugPrint('[NATURE_CARD] profondeur -> $profondeurM');
              _emit();
            }
          },
        );

        final azimutProfondeur = _numberField(
          label: 'Az. prof. (mil)',
          controller: _azProfCtrl,
          onChanged: (v) {
            if (v != null) {
              setState(() {
                azimutProfondeurMil = _normalizeMil(v);
                _applyDefaultsIfNeeded();
              });
              debugPrint(
                '[NATURE_CARD] azimutProfondeur -> $azimutProfondeurMil',
              );
              _emit();
            }
          },
        );

        if (compact) {
          return Column(
            children: [
              longueur,
              if (nature == NatureTirType.lineaire) ...[
                const SizedBox(height: 10),
                azimutLineaire,
              ],
              if (nature == NatureTirType.zonal) ...[
                const SizedBox(height: 10),
                azimutLargeur,
                const SizedBox(height: 10),
                profondeur,
                const SizedBox(height: 10),
                azimutProfondeur,
                const SizedBox(height: 10),
                _zonalCoverageAdvisor(),
              ],
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: longueur),
                if (nature == NatureTirType.lineaire) ...[
                  const SizedBox(width: 10),
                  Expanded(child: azimutLineaire),
                ],
                if (nature == NatureTirType.zonal) ...[
                  const SizedBox(width: 10),
                  Expanded(child: azimutLargeur),
                ],
              ],
            ),
            if (nature == NatureTirType.zonal) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: profondeur),
                  const SizedBox(width: 10),
                  Expanded(child: azimutProfondeur),
                ],
              ),
              const SizedBox(height: 10),
              _zonalCoverageAdvisor(),
            ],
          ],
        );
      },
    );
  }

  Widget _tileChoiceLineaire() {
    return _row(
      label: 'Point application',
      child: Row(
        children: [
          Expanded(
            child: _smallPill(
              'Centré',
              pointLineaire == PointApplicationLineaire.centre,
              () {
                setState(() {
                  pointLineaire = PointApplicationLineaire.centre;
                });
                debugPrint('[NATURE_CARD] pointLineaire -> centre');
                _emit();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _smallPill(
              'Extrémité',
              pointLineaire == PointApplicationLineaire.extremite,
              () {
                setState(() {
                  pointLineaire = PointApplicationLineaire.extremite;
                });
                debugPrint('[NATURE_CARD] pointLineaire -> extremite');
                _emit();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tileChoiceZonal() {
    return _row(
      label: 'Point application',
      child: Row(
        children: [
          Expanded(
            child: _smallPill('Centre', pointZonal == PointZonal.centre, () {
              setState(() {
                pointZonal = PointZonal.centre;
              });
              debugPrint('[NATURE_CARD] pointZonal -> centre');
              _emit();
            }),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _smallPill('Milieu', pointZonal == PointZonal.milieu, () {
              setState(() {
                pointZonal = PointZonal.milieu;
              });
              debugPrint('[NATURE_CARD] pointZonal -> milieu');
              _emit();
            }),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _smallPill('Coin', pointZonal == PointZonal.coin, () {
              setState(() {
                pointZonal = PointZonal.coin;
              });
              debugPrint('[NATURE_CARD] pointZonal -> coin');
              _emit();
            }),
          ),
        ],
      ),
    );
  }

  Widget _row({required String label, required Widget child}) {
    return NatureTirRow(label: label, labelColor: _sub, child: child);
  }

  Widget _smallPill(String label, bool isOn, VoidCallback onTap) {
    return NatureTirSmallPill(
      label: label,
      isOn: isOn,
      onTap: onTap,
      activeColor: _mint,
      backgroundColor: _bg,
      borderColor: _border,
      textColor: _text,
    );
  }

  Widget _numberField({
    required String label,
    required TextEditingController controller,
    required ValueChanged<double?> onChanged,
    bool inlineLabel = false,
  }) {
    if (inlineLabel) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: _sub, fontSize: 12.5)),
          const SizedBox(height: 4),
          _field(controller, onChanged),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 220) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _sub, fontSize: 12.0),
              ),
              const SizedBox(height: 6),
              _field(controller, onChanged),
            ],
          );
        }

        return Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: TextStyle(color: _sub, fontSize: 12.5)),
            ),
            Expanded(child: _field(controller, onChanged)),
          ],
        );
      },
    );
  }

  Widget _field(
    TextEditingController controller,
    ValueChanged<double?> onChanged,
  ) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        onChanged: (s) => onChanged(double.tryParse(s.replaceAll(',', '.'))),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        textAlign: TextAlign.center,
        style: TextStyle(color: _text, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          filled: true,
          fillColor: _bg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _mint, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _intPickerCentered({
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return NatureTirIntPicker(
      value: value,
      min: min,
      max: max,
      onChanged: onChanged,
      textColor: _text,
      backgroundColor: _bg,
      borderColor: _border,
    );
  }

  Widget _switchDoctrine({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return NatureTirSwitchDoctrine(
      value: value,
      onChanged: onChanged,
      activeThumbColor: _mint,
      inactiveThumbColor: _offThumb,
      inactiveTrackColor: _offTrack,
    );
  }
}

class _ZonalCoverageSummary {
  final double surfaceM2;
  final double forcePct;
  final double otanPct;
  final int forceCoups;
  final int otanCoups;

  const _ZonalCoverageSummary({
    required this.surfaceM2,
    required this.forcePct,
    required this.otanPct,
    required this.forceCoups,
    required this.otanCoups,
  });
}
