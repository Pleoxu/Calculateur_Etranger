import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:calculateur_etranger/domain/fire/models/tir_complet_input.dart'
    show LinearFiringMode;
import 'package:calculateur_etranger/presentation/fire/widgets/fire_piece_selector.dart';
import 'package:calculateur_etranger/presentation/theme/tir_tokens.dart';

class LinearFireConfigResult {
  final LinearFiringMode mode;
  final List<String> selectedRoles;

  const LinearFireConfigResult({
    required this.mode,
    required this.selectedRoles,
  });
}

class LinearFireConfigCard extends StatefulWidget {
  final bool dark;
  final int totalCoups;
  final List<String> allPieces;
  final int sectionSize;
  final String sectionLabel;
  final String formationLabel;
  final LinearFiringMode initialMode;
  final List<String> initialSelectedRoles;
  final Map<String, int> coupsParPiece;
  final VoidCallback? onCancel;
  final VoidCallback? onOpenRepartition;
  final ValueChanged<LinearFireConfigResult>? onChanged;
  final ValueChanged<LinearFireConfigResult>? onValidate;

  const LinearFireConfigCard({
    super.key,
    required this.dark,
    required this.totalCoups,
    this.allPieces = const [
      'PD',
      'PS1',
      'PS2',
      'PS3',
      'PS4',
      'PS5',
      'PS6',
      'PS7',
    ],
    this.sectionSize = 4,
    this.sectionLabel = 'Section',
    this.formationLabel = 'Batterie',
    this.initialMode = LinearFiringMode.libre,
    this.initialSelectedRoles = const [],
    this.coupsParPiece = const {},
    this.onCancel,
    this.onOpenRepartition,
    this.onChanged,
    this.onValidate,
  });

  @override
  State<LinearFireConfigCard> createState() => _LinearFireConfigCardState();
}

class _LinearFireConfigCardState extends State<LinearFireConfigCard> {
  static const List<String> _canonicalRoles = [
    'PS7',
    'PS6',
    'PS5',
    'PD',
    'PS1',
    'PS2',
    'PS3',
    'PS4',
  ];

  static const Color _surfaceDark = TirColors.cardDark;
  static const Color _borderDark = TirColors.secondaryBorderDark;
  static const Color _textPrimaryDark = Color(0xFFD7DBE0);
  static const Color _textSecondaryDark = Color(0xFF9299A2);
  static const Color _okTextGreen = TirColors.confirmForeground;
  static const Color _okBg = TirColors.confirmBackground;
  static const Color _actionMuted = TirColors.actionMuted;
  static const Color _modeIdle = TirColors.modeIdle;
  static const Color _modeActive = TirColors.modeActive;

  late LinearFiringMode _mode;
  late Set<String> _selectedRoles;

  List<String> get _availableRoles {
    final allowed = widget.allPieces.map((e) => e.trim().toUpperCase()).toSet();
    return _canonicalRoles.where(allowed.contains).toList(growable: false);
  }

  int get _safeSectionSize =>
      widget.sectionSize.clamp(1, _availableRoles.length);

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _selectedRoles = _normalizeSelection(
      mode: widget.initialMode,
      roles: widget.initialSelectedRoles,
    );
  }

  void _emitChanged() {
    widget.onChanged?.call(
      LinearFireConfigResult(
        mode: _mode,
        selectedRoles: _sortRoles(_selectedRoles),
      ),
    );
  }

  void _setVisualMode(_LinearVisualMode visualMode) {
    setState(() {
      switch (visualMode) {
        case _LinearVisualMode.libre:
          _mode = LinearFiringMode.libre;
          _selectedRoles = _normalizeSelection(
            mode: _mode,
            roles: _selectedRoles,
          );
          break;
        case _LinearVisualMode.section:
          final nextMode = _isNomadeSection
              ? LinearFiringMode.sectionWithoutPd
              : LinearFiringMode.sectionWithPd;
          _mode = nextMode;
          _selectedRoles = _normalizeSelection(
            mode: _mode,
            roles: _selectedRoles,
          );
          break;
        case _LinearVisualMode.batterie:
          _mode = LinearFiringMode.batteryWithPd;
          _selectedRoles = _normalizeSelection(
            mode: _mode,
            roles: _selectedRoles,
          );
          break;
      }
    });
    _emitChanged();
  }

  void _toggleNomade(bool value) {
    if (_visualMode != _LinearVisualMode.section) return;
    setState(() {
      _mode = value
          ? LinearFiringMode.sectionWithoutPd
          : LinearFiringMode.sectionWithPd;
      _selectedRoles = _normalizeSelection(mode: _mode, roles: _selectedRoles);
    });
    _emitChanged();
  }

  void _toggleRole(String role) {
    if (!_canInteractWithRole(role)) return;

    final selected = _selectedRoles.contains(role);

    setState(() {
      if (selected) {
        _selectedRoles.remove(role);
      } else {
        _selectedRoles.add(role);
      }
      _selectedRoles = _normalizeSelection(mode: _mode, roles: _selectedRoles);
    });
    _emitChanged();
  }

  _LinearVisualMode get _visualMode {
    switch (_mode) {
      case LinearFiringMode.libre:
        return _LinearVisualMode.libre;
      case LinearFiringMode.sectionWithPd:
      case LinearFiringMode.sectionWithoutPd:
        return _LinearVisualMode.section;
      case LinearFiringMode.batteryWithPd:
        return _LinearVisualMode.batterie;
    }
  }

  bool get _isNomadeSection => _mode == LinearFiringMode.sectionWithoutPd;

  Set<String> _normalizeSelection({
    required LinearFiringMode mode,
    required Iterable<String> roles,
  }) {
    final filtered = _sortRoles(roles).toSet();

    switch (mode) {
      case LinearFiringMode.libre:
        return filtered;
      case LinearFiringMode.sectionWithPd:
        final withoutPd = filtered
            .where((e) => e != 'PD')
            .take(math.max(0, _safeSectionSize - 1))
            .toList();
        return {'PD', ...withoutPd};
      case LinearFiringMode.sectionWithoutPd:
        return _sortRoles(
          filtered.where((e) => e != 'PD'),
        ).take(_safeSectionSize).toSet();
      case LinearFiringMode.batteryWithPd:
        return _availableRoles.toSet();
    }
  }

  List<String> _sortRoles(Iterable<String> roles) {
    final allowed = _availableRoles.toSet();
    final set = roles
        .map((e) => e.trim().toUpperCase())
        .where(allowed.contains)
        .toSet();
    return _canonicalRoles.where(set.contains).toList();
  }

  bool _canInteractWithRole(String role) {
    if (_mode == LinearFiringMode.batteryWithPd) return false;
    if (_mode == LinearFiringMode.sectionWithoutPd && role == 'PD') {
      return false;
    }
    if (_mode == LinearFiringMode.sectionWithPd && role == 'PD') return false;

    if (_selectedRoles.contains(role)) return true;

    switch (_mode) {
      case LinearFiringMode.libre:
        return true;
      case LinearFiringMode.sectionWithPd:
        return _selectedRoles.where((e) => e != 'PD').length <
            math.max(0, _safeSectionSize - 1);
      case LinearFiringMode.sectionWithoutPd:
        return _selectedRoles.length < _safeSectionSize;
      case LinearFiringMode.batteryWithPd:
        return false;
    }
  }

  int get _selectedShooterCount => _selectedRoles.length;

  int get _pdCoups => widget.coupsParPiece['PD'] ?? 0;

  int get _sumCoups {
    var total = 0;
    for (final role in _sortRoles(_selectedRoles)) {
      total += widget.coupsParPiece[role] ?? 0;
    }
    return total;
  }

  String get _modeLabel {
    switch (_mode) {
      case LinearFiringMode.libre:
        return 'Libre';
      case LinearFiringMode.sectionWithPd:
        return '${widget.sectionLabel} avec PD';
      case LinearFiringMode.sectionWithoutPd:
        return '${widget.sectionLabel} sans PD';
      case LinearFiringMode.batteryWithPd:
        return widget.formationLabel;
    }
  }

  String get _piecesSummary {
    final roles = _sortRoles(_selectedRoles);
    if (roles.isEmpty) return 'Aucune pièce sélectionnée';
    return roles.join(' • ');
  }

  String get _doctrineHint {
    switch (_mode) {
      case LinearFiringMode.libre:
        return 'Sélection libre dans l’ordre canonique doctrinal.';
      case LinearFiringMode.sectionWithPd:
        return '${widget.sectionLabel} = $_safeSectionSize pièce(s), PD comprise.';
      case LinearFiringMode.sectionWithoutPd:
        return 'Configuration externe = $_safeSectionSize pièce(s) sans PD.';
      case LinearFiringMode.batteryWithPd:
        return '${widget.formationLabel} = ${_availableRoles.length} pièce(s) disponibles, PD comprise si présente.';
    }
  }

  bool get _canValidate {
    switch (_mode) {
      case LinearFiringMode.libre:
        return _selectedRoles.isNotEmpty;
      case LinearFiringMode.sectionWithPd:
      case LinearFiringMode.sectionWithoutPd:
        return _selectedRoles.length == _safeSectionSize;
      case LinearFiringMode.batteryWithPd:
        return _selectedRoles.length == _availableRoles.length &&
            _availableRoles.isNotEmpty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.dark ? _surfaceDark : TirColors.cardLight;
    final border = widget.dark ? _borderDark : const Color(0x1A000000);
    final textPrimary = widget.dark ? _textPrimaryDark : Colors.black87;
    final textSecondary = widget.dark ? _textSecondaryDark : Colors.black54;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(TirRadius.xl),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(TirSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configuration linéaire',
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pièces disponibles : ${_availableRoles.join(', ')}',
            style: TextStyle(
              color: textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: TirSpacing.l),
          _sectionTitle('Mode linéaire', textPrimary),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _modeButton(
                label: 'Libre',
                selected: _visualMode == _LinearVisualMode.libre,
                onTap: () => _setVisualMode(_LinearVisualMode.libre),
              ),
              _modeButton(
                label: widget.sectionLabel,
                selected: _visualMode == _LinearVisualMode.section,
                onTap: () => _setVisualMode(_LinearVisualMode.section),
              ),
              _modeButton(
                label: widget.formationLabel,
                selected: _visualMode == _LinearVisualMode.batterie,
                onTap: () => _setVisualMode(_LinearVisualMode.batterie),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _nomadeToggle(textPrimary, textSecondary, border),
          const SizedBox(height: 18),
          _sectionTitle('Pièces tireuses', textPrimary),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableRoles.map((role) {
              final selected = _selectedRoles.contains(role);
              final enabled = _canInteractWithRole(role);

              return Opacity(
                opacity: enabled || selected ? 1 : 0.38,
                child: IgnorePointer(
                  ignoring: !enabled && !selected,
                  child: FirePieceSelector(
                    label: role,
                    selected: selected,
                    onTap: () => _toggleRole(role),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          _statsCard(textPrimary, textSecondary, border),
          const SizedBox(height: 14),
          _summaryCard(textPrimary, textSecondary, border),
          const SizedBox(height: TirSpacing.l),
          SizedBox(
            width: double.infinity,
            height: TirSizes.compactActionHeight,
            child: OutlinedButton(
              onPressed: widget.onOpenRepartition,
              style: OutlinedButton.styleFrom(
                foregroundColor: _actionMuted,
                side: BorderSide(color: border),
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TirRadius.l),
                ),
              ),
              child: const Text(
                'Répartir coups',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: TirSpacing.l),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: TirSizes.compactActionHeight,
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      side: BorderSide(color: border),
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      'Annuler',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: TirSpacing.m),
              Expanded(
                child: SizedBox(
                  height: TirSizes.compactActionHeight,
                  child: ElevatedButton(
                    onPressed: _canValidate
                        ? () {
                            widget.onValidate?.call(
                              LinearFireConfigResult(
                                mode: _mode,
                                selectedRoles: _sortRoles(_selectedRoles),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _okBg,
                      disabledBackgroundColor: _okBg.withValues(alpha: 0.55),
                      foregroundColor: _okTextGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        color: _okTextGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String label, Color color) {
    return Text(
      label,
      style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700),
    );
  }

  Widget _modeButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TirRadius.m),
          color: selected ? _modeActive : _modeIdle,
          border: Border.all(color: _borderDark),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _nomadeToggle(Color textPrimary, Color textSecondary, Color border) {
    final enabled = _visualMode == _LinearVisualMode.section;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TirRadius.l),
        border: Border.all(color: border),
        color: Colors.transparent,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: TirSpacing.m,
        vertical: 10,
      ),
      child: Row(
        children: [
          Switch.adaptive(
            value: _isNomadeSection,
            onChanged: enabled ? _toggleNomade : null,
            activeThumbColor: _okTextGreen,
          ),
          const SizedBox(width: TirSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pièce nomade externe',
                  style: TextStyle(
                    color: enabled ? textPrimary : textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  enabled
                      ? 'Pièce hors batterie, affichée séparément des pièces batterie. Le mode Section reste actif.'
                      : 'Disponible uniquement lorsque le mode Section est sélectionné.',
                  style: TextStyle(color: textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsCard(Color textPrimary, Color textSecondary, Color border) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TirRadius.l),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(TirSpacing.m),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          _statChip(
            label: 'Mode',
            value: _modeLabel,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            border: border,
          ),
          _statChip(
            label: 'Pièces tireuses',
            value: '$_selectedShooterCount',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            border: border,
          ),
          _statChip(
            label: 'Total coups',
            value: '${widget.totalCoups}',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            border: border,
          ),
          _statChip(
            label: 'PD',
            value: '$_pdCoups',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            border: border,
          ),
        ],
      ),
    );
  }

  Widget _statChip({
    required String label,
    required String value,
    required Color textPrimary,
    required Color textSecondary,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TirRadius.m),
        border: Border.all(color: border),
        color: _modeIdle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(Color textPrimary, Color textSecondary, Color border) {
    final warning =
        !_canValidate ? _buildValidationMessage() : 'Configuration valide.';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TirRadius.l),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(TirSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Résumé pièces / coups',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: TirSpacing.s),
          Text(
            _piecesSummary,
            style: TextStyle(
              color: textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Coups affectés aux pièces sélectionnées : $_sumCoups / ${widget.totalCoups}',
            style: TextStyle(color: textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 6),
          Text(
            _doctrineHint,
            style: TextStyle(color: textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 6),
          Text(
            warning,
            style: TextStyle(
              color: _canValidate ? textSecondary : const Color(0xFFC7A66A),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _buildValidationMessage() {
    switch (_mode) {
      case LinearFiringMode.libre:
        return 'Sélectionner au moins une pièce.';
      case LinearFiringMode.sectionWithPd:
        return '${widget.sectionLabel} avec PD : sélectionner exactement $_safeSectionSize pièce(s).';
      case LinearFiringMode.sectionWithoutPd:
        return 'Configuration sans PD : sélectionner exactement $_safeSectionSize pièce(s).';
      case LinearFiringMode.batteryWithPd:
        return '${widget.formationLabel} : sélectionner toutes les pièces disponibles (${_availableRoles.length}).';
    }
  }
}

enum _LinearVisualMode { libre, section, batterie }
