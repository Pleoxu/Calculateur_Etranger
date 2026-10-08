import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:calculateur_etranger/presentation/theme/tir_tokens.dart';

enum ZonalFireMode { libre, sectionWithPd, sectionWithoutPd, batteryWithPd }

class ZonalFireConfigResult {
  final ZonalFireMode mode;
  final List<String> selectedRoles;
  final bool nomadeExterne;

  const ZonalFireConfigResult({
    required this.mode,
    required this.selectedRoles,
    required this.nomadeExterne,
  });
}

class ZonalFireConfigCard extends StatefulWidget {
  final List<String> allPieces;
  final List<String> initialSelection;
  final bool initialNomade;
  final ZonalFireMode initialMode;
  final ValueChanged<ZonalFireConfigResult> onValidate;
  final ValueChanged<ZonalFireConfigResult>? onChanged;
  final VoidCallback? onCancel;
  final VoidCallback? onOpenRepartition;
  final bool dark;
  final int? totalCoups;
  final Map<String, int> coupsParPiece;
  final String title;
  final String? subtitle;
  final int sectionSize;
  final String sectionLabel;
  final String formationLabel;

  const ZonalFireConfigCard({
    super.key,
    required this.allPieces,
    required this.initialSelection,
    required this.initialNomade,
    required this.onValidate,
    this.onChanged,
    this.onCancel,
    this.onOpenRepartition,
    this.dark = true,
    this.totalCoups,
    this.coupsParPiece = const {},
    this.title = 'Zonal configuration',
    this.subtitle,
    this.sectionSize = 4,
    this.sectionLabel = 'Section',
    this.formationLabel = 'Batterie',
    this.initialMode = ZonalFireMode.libre,
  });

  @override
  State<ZonalFireConfigCard> createState() => _ZonalFireConfigCardState();
}

enum _ZonalVisualMode { libre, section, batterie }

class _ZonalFireConfigCardState extends State<ZonalFireConfigCard> {
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

  late ZonalFireMode _mode;
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
      roles: widget.initialSelection,
    );
  }

  List<String> _sortRoles(Iterable<String> roles) {
    final allowed = _availableRoles.toSet();
    final set = roles
        .map((e) => e.trim().toUpperCase())
        .where(allowed.contains)
        .toSet();
    return _canonicalRoles.where(set.contains).toList();
  }

  Set<String> _normalizeSelection({
    required ZonalFireMode mode,
    required Iterable<String> roles,
  }) {
    final filtered = _sortRoles(roles).toSet();

    switch (mode) {
      case ZonalFireMode.libre:
        return filtered;
      case ZonalFireMode.sectionWithPd:
        final withoutPd = filtered
            .where((e) => e != 'PD')
            .take(math.max(0, _safeSectionSize - 1))
            .toList();
        return {'PD', ...withoutPd};
      case ZonalFireMode.sectionWithoutPd:
        return _sortRoles(
          filtered.where((e) => e != 'PD'),
        ).take(_safeSectionSize).toSet();
      case ZonalFireMode.batteryWithPd:
        return _availableRoles.toSet();
    }
  }

  _ZonalVisualMode get _visualMode {
    switch (_mode) {
      case ZonalFireMode.libre:
        return _ZonalVisualMode.libre;
      case ZonalFireMode.sectionWithPd:
      case ZonalFireMode.sectionWithoutPd:
        return _ZonalVisualMode.section;
      case ZonalFireMode.batteryWithPd:
        return _ZonalVisualMode.batterie;
    }
  }

  bool get _isNomadeSection => _mode == ZonalFireMode.sectionWithoutPd;

  void _emitChanged() {
    widget.onChanged?.call(
      ZonalFireConfigResult(
        mode: _mode,
        selectedRoles: _sortRoles(_selectedRoles),
        nomadeExterne: _isNomadeSection,
      ),
    );
  }

  void _setVisualMode(_ZonalVisualMode visualMode) {
    setState(() {
      switch (visualMode) {
        case _ZonalVisualMode.libre:
          _mode = ZonalFireMode.libre;
          _selectedRoles = _normalizeSelection(
            mode: _mode,
            roles: _selectedRoles,
          );
          break;
        case _ZonalVisualMode.section:
          _mode = _isNomadeSection
              ? ZonalFireMode.sectionWithoutPd
              : ZonalFireMode.sectionWithPd;
          _selectedRoles = _normalizeSelection(
            mode: _mode,
            roles: _selectedRoles,
          );
          break;
        case _ZonalVisualMode.batterie:
          _mode = ZonalFireMode.batteryWithPd;
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
    if (_visualMode != _ZonalVisualMode.section) return;
    setState(() {
      _mode =
          value ? ZonalFireMode.sectionWithoutPd : ZonalFireMode.sectionWithPd;
      _selectedRoles = _normalizeSelection(mode: _mode, roles: _selectedRoles);
    });
    _emitChanged();
  }

  bool _canInteractWithRole(String role) {
    if (!widget.allPieces.contains(role)) return false;
    if (_mode == ZonalFireMode.batteryWithPd) return false;
    if (_mode == ZonalFireMode.sectionWithoutPd && role == 'PD') return false;
    if (_mode == ZonalFireMode.sectionWithPd && role == 'PD') return false;

    if (_selectedRoles.contains(role)) return true;

    switch (_mode) {
      case ZonalFireMode.libre:
        return true;
      case ZonalFireMode.sectionWithPd:
        return _selectedRoles.where((e) => e != 'PD').length <
            math.max(0, _safeSectionSize - 1);
      case ZonalFireMode.sectionWithoutPd:
        return _selectedRoles.length < _safeSectionSize;
      case ZonalFireMode.batteryWithPd:
        return false;
    }
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
      case ZonalFireMode.libre:
        return 'Libre';
      case ZonalFireMode.sectionWithPd:
        return '${widget.sectionLabel} with PD';
      case ZonalFireMode.sectionWithoutPd:
        return '${widget.sectionLabel} without PD';
      case ZonalFireMode.batteryWithPd:
        return widget.formationLabel;
    }
  }

  String get _piecesSummary {
    final roles = _sortRoles(_selectedRoles);
    if (roles.isEmpty) return 'No gun selected';
    return roles.join(' • ');
  }

  String get _doctrineHint {
    switch (_mode) {
      case ZonalFireMode.libre:
        return 'Free selection in doctrinal canonical order.';
      case ZonalFireMode.sectionWithPd:
        return '${widget.sectionLabel} = $_safeSectionSize gun(s), PD included.';
      case ZonalFireMode.sectionWithoutPd:
        return 'External configuration = $_safeSectionSize gun(s) without PD.';
      case ZonalFireMode.batteryWithPd:
        return '${widget.formationLabel} = ${_availableRoles.length} available gun(s), PD included if present.';
    }
  }

  bool get _canValidate {
    switch (_mode) {
      case ZonalFireMode.libre:
        return _selectedRoles.isNotEmpty;
      case ZonalFireMode.sectionWithPd:
      case ZonalFireMode.sectionWithoutPd:
        return _selectedRoles.length == _safeSectionSize;
      case ZonalFireMode.batteryWithPd:
        return _selectedRoles.length == _availableRoles.length &&
            _availableRoles.isNotEmpty;
    }
  }

  String _buildValidationMessage() {
    switch (_mode) {
      case ZonalFireMode.libre:
        return 'Select at least one gun.';
      case ZonalFireMode.sectionWithPd:
        return '${widget.sectionLabel} with PD: select exactly $_safeSectionSize gun(s).';
      case ZonalFireMode.sectionWithoutPd:
        return 'Configuration without PD: select exactly $_safeSectionSize gun(s).';
      case ZonalFireMode.batteryWithPd:
        return '${widget.formationLabel}: select all available guns (${_availableRoles.length}).';
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.dark ? _surfaceDark : TirColors.cardLight;
    final border = widget.dark ? _borderDark : const Color(0x1A000000);
    final textPrimary = widget.dark ? _textPrimaryDark : Colors.black87;
    final textSecondary = widget.dark ? _textSecondaryDark : Colors.black54;

    final totalCoups = widget.totalCoups ?? _sumCoups;

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
            widget.title,
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.subtitle ?? 'Available guns: ${_availableRoles.join(', ')}',
            style: TextStyle(
              color: textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: TirSpacing.l),
          _sectionTitle('Zonal mode', textPrimary),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _modeButton(
                label: 'Libre',
                selected: _visualMode == _ZonalVisualMode.libre,
                onTap: () => _setVisualMode(_ZonalVisualMode.libre),
              ),
              _modeButton(
                label: widget.sectionLabel,
                selected: _visualMode == _ZonalVisualMode.section,
                onTap: () => _setVisualMode(_ZonalVisualMode.section),
              ),
              _modeButton(
                label: widget.formationLabel,
                selected: _visualMode == _ZonalVisualMode.batterie,
                onTap: () => _setVisualMode(_ZonalVisualMode.batterie),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _nomadeToggle(textPrimary, textSecondary, border),
          const SizedBox(height: 18),
          _sectionTitle('Firing guns', textPrimary),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableRoles.map((role) {
              final selected = _selectedRoles.contains(role);
              final enabled = _canInteractWithRole(role);
              final coupsRole = widget.coupsParPiece[role] ?? 0;

              return Opacity(
                opacity: enabled || selected ? 1 : 0.38,
                child: IgnorePointer(
                  ignoring: !enabled && !selected,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(TirRadius.m),
                    onTap: () => _toggleRole(role),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? _modeActive : Colors.transparent,
                        borderRadius: BorderRadius.circular(TirRadius.m),
                        border: Border.all(
                          color: selected ? _okTextGreen : border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            role,
                            style: TextStyle(
                              color: selected ? Colors.white : textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (selected) ...[
                            const SizedBox(width: TirSpacing.s),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: _okTextGreen),
                              ),
                              child: Text(
                                '$coupsRole',
                                style: const TextStyle(
                                  color: _okTextGreen,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          _statsCard(textPrimary, textSecondary, border, totalCoups),
          const SizedBox(height: 14),
          _summaryCard(textPrimary, textSecondary, border, totalCoups),
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
                'Allocate rounds',
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
                      'Cancel',
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
                            widget.onValidate(
                              ZonalFireConfigResult(
                                mode: _mode,
                                selectedRoles: _sortRoles(_selectedRoles),
                                nomadeExterne: _isNomadeSection,
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
    final enabled = _visualMode == _ZonalVisualMode.section;

    return Semantics(
      label: 'External mobile gun',
      enabled: enabled,
      toggled: _isNomadeSection,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => _toggleNomade(!_isNomadeSection) : null,
        child: Container(
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
              SizedBox(
                width: 60,
                height: 48,
                child: Center(
                  child: Switch.adaptive(
                    value: _isNomadeSection,
                    onChanged: enabled ? _toggleNomade : null,
                    activeThumbColor: _okTextGreen,
                  ),
                ),
              ),
              const SizedBox(width: TirSpacing.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'External mobile gun',
                      style: TextStyle(
                        color: enabled ? textPrimary : textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      enabled
                          ? 'Out-of-battery gun, displayed separately from battery guns. Section mode remains active.'
                          : 'Available only when Section mode is selected.',
                      style: TextStyle(color: textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statsCard(
    Color textPrimary,
    Color textSecondary,
    Color border,
    int totalCoups,
  ) {
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
            label: 'Firing guns',
            value: '$_selectedShooterCount',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            border: border,
          ),
          _statChip(
            label: 'Total rounds',
            value: '$totalCoups',
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

  Widget _summaryCard(
    Color textPrimary,
    Color textSecondary,
    Color border,
    int totalCoups,
  ) {
    final warning =
        !_canValidate ? _buildValidationMessage() : 'Valid configuration.';

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
            'Guns / rounds summary',
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
            'Rounds assigned to selected guns: $_sumCoups / $totalCoups',
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
}
