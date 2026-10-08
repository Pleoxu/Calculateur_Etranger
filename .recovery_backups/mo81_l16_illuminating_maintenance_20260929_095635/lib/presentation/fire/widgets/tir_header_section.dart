// lib/presentation/fire/widgets/tir_header_section.dart

import 'package:flutter/material.dart';

import 'package:calculateur_etranger/domain/fire/models/fire_command_level.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/presentation/fire/state/tir_header_state.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/command_level_tabs.dart';
import 'package:calculateur_etranger/services/maps/local_map_service.dart';

/// Les quatre entrées principales, identiques pour tous les systèmes.
enum _FamilleTirUi { appuiContact, appuiProfondeur, tirsSpeciaux, destruction }

/// Les sous-catégories affichées uniquement lorsque « Tirs spéciaux » est actif.
enum _TirSpecialUi { aveuglement, eclairement, semonce }

class TirHeaderSection extends StatefulWidget {
  final TirHeaderState header;
  final TirHeaderNotifier headerN;

  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final bool dark;

  final FireCommandLevel commandLevel;
  final ValueChanged<FireCommandLevel>? onCommandLevelChanged;

  final ValueChanged<Systeme>? onSystemeChanged;
  final ValueChanged<TypeMunition>? onTypeMunitionChanged;
  final VoidCallback? onOfflineZone;

  const TirHeaderSection({
    super.key,
    required this.header,
    required this.headerN,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.dark,
    this.commandLevel = FireCommandLevel.ue,
    this.onCommandLevelChanged,
    this.onSystemeChanged,
    this.onTypeMunitionChanged,
    this.onOfflineZone,
  });

  @override
  State<TirHeaderSection> createState() => _TirHeaderSectionState();
}

class _TirHeaderSectionState extends State<TirHeaderSection> {
  bool _onlineEnabled = false;
  bool _mapModeLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMapMode();
  }

  Future<void> _loadMapMode() async {
    final enabled = await LocalMapService.instance.isOnlineEnabled();
    if (!mounted) return;
    setState(() {
      _onlineEnabled = enabled;
      _mapModeLoading = false;
    });
  }

  Future<void> _setOnlineEnabled(bool value) async {
    setState(() {
      _onlineEnabled = value;
      _mapModeLoading = true;
    });

    try {
      await LocalMapService.instance.setOnlineEnabled(value);
    } finally {
      if (mounted) {
        setState(() {
          _mapModeLoading = false;
        });
      }
    }

    if (value && mounted) {
      widget.onOfflineZone?.call();
    }
  }

  static const _familles = <_FamilleTirUi>[
    _FamilleTirUi.appuiContact,
    _FamilleTirUi.appuiProfondeur,
    _FamilleTirUi.tirsSpeciaux,
    _FamilleTirUi.destruction,
  ];

  static const _tirsSpeciaux = <_TirSpecialUi>[
    _TirSpecialUi.aveuglement,
    _TirSpecialUi.eclairement,
    _TirSpecialUi.semonce,
  ];

  String _familleLabel(_FamilleTirUi famille) {
    switch (famille) {
      case _FamilleTirUi.appuiContact:
        return 'Close Support';
      case _FamilleTirUi.appuiProfondeur:
        return 'Deep Fire';
      case _FamilleTirUi.tirsSpeciaux:
        return 'Special Fires';
      case _FamilleTirUi.destruction:
        return 'Destruction';
    }
  }

  IconData _familleIcon(_FamilleTirUi famille) {
    switch (famille) {
      case _FamilleTirUi.appuiContact:
        return Icons.my_location_rounded;
      case _FamilleTirUi.appuiProfondeur:
        return Icons.radar_rounded;
      case _FamilleTirUi.tirsSpeciaux:
        return Icons.auto_awesome_rounded;
      case _FamilleTirUi.destruction:
        return Icons.warning_amber_rounded;
    }
  }

  String _specialLabel(_TirSpecialUi special) {
    switch (special) {
      case _TirSpecialUi.aveuglement:
        return 'Aveuglement';
      case _TirSpecialUi.eclairement:
        return 'Illumination';
      case _TirSpecialUi.semonce:
        return 'Semonce';
    }
  }

  IconData _specialIcon(_TirSpecialUi special) {
    switch (special) {
      case _TirSpecialUi.aveuglement:
        return Icons.visibility_off_rounded;
      case _TirSpecialUi.eclairement:
        return Icons.lightbulb_outline_rounded;
      case _TirSpecialUi.semonce:
        return Icons.campaign_outlined;
    }
  }

  List<TypeMunition> _munitions(Systeme systeme, TypeTir typeTir) {
    return munitionsDisponiblesPour(systeme: systeme, typeTir: typeTir);
  }

  bool _isAveuglement(TypeMunition munition) {
    switch (munition) {
      case TypeMunition.ofum155F2AFr:
      case TypeMunition.ofum81Fa32:
      case TypeMunition.ofum120F1:
        return true;
      default:
        return false;
    }
  }

  bool _isSemonce(TypeMunition munition) {
    switch (munition) {
      case TypeMunition.oeSemonceF6Fr:
      case TypeMunition.ox155F1Fr:
      case TypeMunition.ox81F1:
      case TypeMunition.ox81F2:
      case TypeMunition.ox120F1:
        return true;
      default:
        return false;
    }
  }

  bool _isDestruction(TypeMunition munition) {
    return munition == TypeMunition.bonusFr;
  }

  bool _isSpecialMunition(TypeMunition munition) {
    return _isAveuglement(munition) ||
        _isSemonce(munition) ||
        _isDestruction(munition);
  }

  // Libellés précis pour MO81 L16 / M252
  List<String> _mo81MunitionsFor(
    _FamilleTirUi famille, [
    _TirSpecialUi? special,
  ]) {
    switch (famille) {
      case _FamilleTirUi.appuiContact:
        return const ['M821', 'M821A1', 'M889', 'M889A1', 'TP M879'];
      case _FamilleTirUi.tirsSpeciaux:
        return const ['RP M819', 'ILL M853A1'];
      case _FamilleTirUi.appuiProfondeur:
      case _FamilleTirUi.destruction:
        return const [];
    }
  }

  List<TypeMunition> _munitionsFor(
    Systeme systeme,
    _FamilleTirUi famille, [
    _TirSpecialUi? special,
  ]) {
    if (systeme == Systeme.mo81M252) return const [];

    final appui = _munitions(systeme, TypeTir.appui);
    final eclairant = _munitions(systeme, TypeTir.eclairant);

    switch (famille) {
      case _FamilleTirUi.appuiContact:
        return appui
            .where((munition) => !_isSpecialMunition(munition))
            .toList();
      case _FamilleTirUi.appuiProfondeur:
        return const <TypeMunition>[];
      case _FamilleTirUi.destruction:
        return appui.where(_isDestruction).toList();
      case _FamilleTirUi.tirsSpeciaux:
        switch (special) {
          case _TirSpecialUi.aveuglement:
            return appui.where(_isAveuglement).toList();
          case _TirSpecialUi.eclairement:
            return eclairant;
          case _TirSpecialUi.semonce:
            return <TypeMunition>[
              ...appui.where(_isSemonce),
            ];
          case null:
            return const [];
        }
    }
  }

  bool _hasChoices(
    Systeme systeme,
    _FamilleTirUi famille, [
    _TirSpecialUi? special,
  ]) {
    if (systeme == Systeme.mo81M252) {
      return _mo81MunitionsFor(famille, special).isNotEmpty;
    }
    return _munitionsFor(systeme, famille, special).isNotEmpty;
  }

  bool _hasSpecialChoice(Systeme systeme) {
    if (systeme == Systeme.mo81M252) return true;
    return _tirsSpeciaux.any(
      (special) => _hasChoices(systeme, _FamilleTirUi.tirsSpeciaux, special),
    );
  }

  bool _hasFamilyChoice(Systeme systeme, _FamilleTirUi famille) {
    if (famille == _FamilleTirUi.tirsSpeciaux) {
      return _hasSpecialChoice(systeme);
    }
    return _hasChoices(systeme, famille);
  }

  _FamilleTirUi _familyFromHeader(TirHeaderState header) {
    if (header.systeme == Systeme.mo81M252) {
      return header.typeTir == TypeTir.eclairant
          ? _FamilleTirUi.tirsSpeciaux
          : _FamilleTirUi.appuiContact;
    }

    final munition = header.typeMunition;
    if (munition != null) {
      if (_isDestruction(munition)) return _FamilleTirUi.destruction;
      if (_isAveuglement(munition) || _isSemonce(munition)) {
        return _FamilleTirUi.tirsSpeciaux;
      }
    }

    switch (header.typeTir) {
      case TypeTir.appui:
        return _FamilleTirUi.appuiContact;
      case TypeTir.eclairant:
        return _FamilleTirUi.tirsSpeciaux;
    }
  }

  _TirSpecialUi _specialFromHeader(TirHeaderState header) {
    final munition = header.typeMunition;
    if (munition != null) {
      if (_isAveuglement(munition)) return _TirSpecialUi.aveuglement;
      if (_isSemonce(munition)) return _TirSpecialUi.semonce;
    }

    return _TirSpecialUi.eclairement;
  }

  _FamilleTirUi _safeFamily(Systeme systeme, _FamilleTirUi family) {
    if (_hasFamilyChoice(systeme, family)) return family;
    return _familles.firstWhere(
      (candidate) => _hasFamilyChoice(systeme, candidate),
      orElse: () => _FamilleTirUi.appuiContact,
    );
  }

  _TirSpecialUi? _safeSpecial(Systeme systeme, _TirSpecialUi current) {
    if (systeme == Systeme.mo81M252) return current;
    if (_hasChoices(systeme, _FamilleTirUi.tirsSpeciaux, current)) {
      return current;
    }
    for (final candidate in _tirsSpeciaux) {
      if (_hasChoices(systeme, _FamilleTirUi.tirsSpeciaux, candidate)) {
        return candidate;
      }
    }
    return null;
  }

  void _select(_FamilleTirUi family, {_TirSpecialUi? special}) {
    final notifier = widget.headerN;
    final systeme = widget.header.systeme;

    if (systeme == Systeme.mo81M252) {
      final typeTir = family == _FamilleTirUi.tirsSpeciaux
          ? TypeTir.eclairant
          : TypeTir.appui;
      notifier.setTypeTir(typeTir);

      final mo81List = _mo81MunitionsFor(family, special);
      if (mo81List.isNotEmpty) {
        final defaultMunition =
            mo81List.contains('M821A1') ? 'M821A1' : mo81List.first;
        notifier.setMo81Munition(defaultMunition);
      }
      return;
    }

    final choices = _munitionsFor(systeme, family, special);
    if (choices.isEmpty) return;
    final munition = choices.first;
    notifier.setTypeTir(munition.typeTir);
    notifier.setTypeMunition(munition);
    widget.onTypeMunitionChanged?.call(munition);
  }

  void _selectMunition(TypeMunition munition) {
    widget.headerN.setTypeTir(munition.typeTir);
    widget.headerN.setTypeMunition(munition);
    widget.onTypeMunitionChanged?.call(munition);
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.header;
    final systeme = header.systeme;
    final isMobile = MediaQuery.sizeOf(context).width < 760;
    final currentFamily = _safeFamily(systeme, _familyFromHeader(header));
    final currentSpecial = _safeSpecial(systeme, _specialFromHeader(header));
    final isSpecial = currentFamily == _FamilleTirUi.tirsSpeciaux;

    final standardMunitions = systeme == Systeme.mo81M252
        ? const <TypeMunition>[]
        : _munitionsFor(systeme, currentFamily, currentSpecial);
    final currentMunition = standardMunitions.contains(header.typeMunition)
        ? header.typeMunition
        : (standardMunitions.isEmpty ? null : standardMunitions.first);

    final mo81Munitions = systeme == Systeme.mo81M252
        ? _mo81MunitionsFor(currentFamily, currentSpecial)
        : const <String>[];

    Widget sectionLabel(String value) {
      return Text(
        value,
        style: TextStyle(
          color: widget.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.25,
        ),
      );
    }

    Widget systemSelector() {
      Widget equipmentButton(String label, {bool isMo81 = false}) {
        final isSelected = isMo81 ? systeme == Systeme.mo81M252 : false;

        final textColor = isSelected
            ? widget.textPrimary
            : widget.textSecondary.withValues(alpha: 0.4);

        final borderColor = isSelected
            ? (widget.dark
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.black.withValues(alpha: 0.6))
            : widget.border.withValues(alpha: 0.4);

        final backgroundColor = isSelected
            ? (widget.dark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08))
            : Colors.transparent;

        return OutlinedButton(
          onPressed: isMo81
              ? () {
                  widget.headerN.setSysteme(Systeme.mo81M252);
                  widget.onSystemeChanged?.call(Systeme.mo81M252);
                  final mo81List =
                      _mo81MunitionsFor(currentFamily, currentSpecial);
                  if (mo81List.isNotEmpty) {
                    final defaultMunition =
                        mo81List.contains('M821A1') ? 'M821A1' : mo81List.first;
                    widget.headerN.setMo81Munition(defaultMunition);
                  }
                }
              : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            foregroundColor: textColor,
            disabledForegroundColor:
                widget.textSecondary.withValues(alpha: 0.4),
            backgroundColor: backgroundColor,
            side: BorderSide(
              color: borderColor,
              width: isSelected ? 1.5 : 1.0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          child: Text(label),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              equipmentButton('M109'),
              equipmentButton('M777'),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              equipmentButton('L118 LG'),
              equipmentButton('MO81 L16', isMo81: true),
            ],
          ),
        ],
      );
    }

    Widget mapModeControl() {
      final online = _onlineEnabled;
      const activeColor = Color(0xFF5E9F7A);
      final neutralColor =
          widget.dark ? Colors.white.withValues(alpha: 0.92) : Colors.black87;
      final fg = online ? activeColor : neutralColor;
      final bg = online
          ? activeColor.withValues(alpha: widget.dark ? 0.10 : 0.08)
          : (widget.dark
              ? Colors.white.withValues(alpha: 0.035)
              : Colors.black.withValues(alpha: 0.025));
      final bd = online ? activeColor.withValues(alpha: 0.55) : widget.border;

      return Tooltip(
        message: online ? 'Go offline' : 'Temporarily enable online mode',
        child: InkWell(
          onTap:
              _mapModeLoading ? null : () => _setOnlineEnabled(!_onlineEnabled),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: isMobile ? 38 : 42,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 13 : 16,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: bd),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_mapModeLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: fg,
                    ),
                  )
                else
                  Icon(
                    online ? Icons.public_rounded : Icons.public_off_outlined,
                    size: isMobile ? 18 : 19,
                    color: fg,
                  ),
                SizedBox(width: isMobile ? 7 : 8),
                Text(
                  online ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: fg,
                    fontSize: isMobile ? 11.5 : 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget themeButton() {
      return Tooltip(
        message: widget.dark ? 'Passer au mode jour' : 'Passer au mode nuit',
        child: IconButton(
          onPressed: () => widget.headerN.setDark(!widget.dark),
          constraints: BoxConstraints.tightFor(
            width: isMobile ? 38 : 42,
            height: isMobile ? 38 : 42,
          ),
          padding: EdgeInsets.zero,
          icon: Icon(
            widget.dark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
            color: widget.textPrimary,
          ),
        ),
      );
    }

    Widget familyButton(_FamilleTirUi family) {
      final enabled = _hasFamilyChoice(systeme, family);
      final selected = family == currentFamily;
      final button = OutlinedButton.icon(
        onPressed: enabled
            ? () {
                if (family == _FamilleTirUi.tirsSpeciaux) {
                  final firstSpecial = _safeSpecial(
                    systeme,
                    _specialFromHeader(header),
                  );
                  _select(family, special: firstSpecial);
                  return;
                }
                _select(family);
              }
            : null,
        icon: Icon(_familleIcon(family), size: 17),
        label: Text(
          _familleLabel(family),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.center,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          foregroundColor: widget.textPrimary,
          backgroundColor: selected
              ? (widget.dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05))
              : Colors.transparent,
          disabledForegroundColor: widget.textSecondary.withValues(alpha: 0.35),
          side: BorderSide(
            color: selected
                ? (widget.dark
                    ? Colors.white.withValues(alpha: 0.22)
                    : Colors.black.withValues(alpha: 0.16))
                : widget.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      return enabled
          ? button
          : Tooltip(
              message: 'Not available for this weapon system',
              child: button,
            );
    }

    Widget specialButton(_TirSpecialUi special) {
      final enabled = _hasChoices(systeme, _FamilleTirUi.tirsSpeciaux, special);
      final selected = special == currentSpecial;
      return ChoiceChip(
        avatar: Icon(
          _specialIcon(special),
          size: 17,
          color: widget.textPrimary,
        ),
        label: Text(_specialLabel(special), textAlign: TextAlign.center),
        selected: selected,
        onSelected: enabled
            ? (selectedNow) {
                if (selectedNow) {
                  _select(_FamilleTirUi.tirsSpeciaux, special: special);
                }
              }
            : null,
        selectedColor: widget.dark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.05),
        backgroundColor: Colors.transparent,
        disabledColor: widget.card.withValues(alpha: 0.35),
        side: BorderSide(
          color: selected
              ? (widget.dark
                  ? Colors.white.withValues(alpha: 0.20)
                  : Colors.black.withValues(alpha: 0.14))
              : widget.border,
        ),
        labelStyle: TextStyle(
          fontSize: 11,
          color: widget.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
    }

    Widget munitionChip(TypeMunition munition) {
      final selected = munition == currentMunition;
      return ChoiceChip(
        avatar: selected
            ? Icon(Icons.check, size: 16, color: widget.textPrimary)
            : null,
        label: Text(munition.label, textAlign: TextAlign.center),
        selected: selected,
        onSelected: (selectedNow) {
          if (selectedNow) {
            _selectMunition(munition);
          }
        },
        selectedColor: widget.dark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08),
        backgroundColor: Colors.transparent,
        side: BorderSide(
          color: selected
              ? (widget.dark
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.black.withValues(alpha: 0.6))
              : widget.border.withValues(alpha: 0.4),
          width: selected ? 1.5 : 1.0,
        ),
        labelStyle: TextStyle(
          color: selected
              ? widget.textPrimary
              : widget.textSecondary.withValues(alpha: 0.5),
          fontSize: 12,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
    }

    Widget mo81Chip(String label) {
      final selected = header.mo81MunitionLabel == label;

      return ChoiceChip(
        avatar: selected
            ? Icon(Icons.check, size: 16, color: widget.textPrimary)
            : null,
        label: Text(label, textAlign: TextAlign.center),
        selected: selected,
        onSelected: (selectedNow) {
          if (selectedNow) {
            widget.headerN.setMo81Munition(label);
          }
        },
        selectedColor: widget.dark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08),
        backgroundColor: Colors.transparent,
        side: BorderSide(
          color: selected
              ? (widget.dark
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.black.withValues(alpha: 0.6))
              : widget.border.withValues(alpha: 0.4),
          width: selected ? 1.5 : 1.0,
        ),
        labelStyle: TextStyle(
          color: selected
              ? widget.textPrimary
              : widget.textSecondary.withValues(alpha: 0.5),
          fontSize: 12,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
    }

    final systemConnected = systeme.calculConnecte;
    final noMunition = standardMunitions.isEmpty && mo81Munitions.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        decoration: BoxDecoration(
          color: widget.dark ? const Color(0xFF0B0D10) : widget.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: widget.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isMobile ? 220 : 360,
                    ),
                    child: CommandLevelTabs(
                      selected: widget.commandLevel,
                      onChanged: widget.onCommandLevelChanged ??
                          (FireCommandLevel _) {},
                    ),
                  ),
                ),
                Center(child: mapModeControl()),
                Align(
                  alignment: Alignment.centerRight,
                  child: themeButton(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  sectionLabel('Weapon system'),
                  const SizedBox(height: 8),
                  systemSelector(),
                ],
              ),
            ),
            const SizedBox(height: 18),
            sectionLabel('Fire type'),
            const SizedBox(height: 12),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(child: familyButton(_FamilleTirUi.appuiContact)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: familyButton(_FamilleTirUi.appuiProfondeur),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: familyButton(_FamilleTirUi.tirsSpeciaux)),
                    const SizedBox(width: 8),
                    Expanded(child: familyButton(_FamilleTirUi.destruction)),
                  ],
                ),
              ],
            ),
            if (isSpecial && systeme != Systeme.mo81M252) ...[
              const SizedBox(height: 16),
              sectionLabel('Special fire type'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Center(
                      child: specialButton(_TirSpecialUi.aveuglement),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Center(
                      child: specialButton(_TirSpecialUi.eclairement),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Center(child: specialButton(_TirSpecialUi.semonce)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Divider(height: 1, color: widget.border),
            const SizedBox(height: 16),
            sectionLabel('Munitions'),
            const SizedBox(height: 8),
            if (noMunition)
              Text(
                'No cartridge available for this combination.',
                style: TextStyle(color: widget.textSecondary, fontSize: 12),
              )
            else
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...standardMunitions.map(munitionChip),
                  ...mo81Munitions.map(mo81Chip),
                ],
              ),
            if (!systemConnected) ...[
              const SizedBox(height: 8),
              Text(
                'Catalog displayed — calculation not connected for this system.',
                style: TextStyle(
                  color: widget.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
