import 'package:flutter/material.dart';

import 'package:calculateur_etranger/presentation/fire/models/repartition_view_mode.dart';

class ViewModeControl extends StatelessWidget {
  const ViewModeControl({
    super.key,
    required this.selected,
    required this.dark,
    required this.onChanged,
  });

  final RepartitionViewMode selected;
  final bool dark;
  final ValueChanged<RepartitionViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final subtitleColor = dark ? Colors.white60 : Colors.black54;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ModeChip(
          label: selected.label,
          selected: true,
          dark: dark,
          onTap: () => onChanged(selected.next),
        ),
        const SizedBox(height: 3),
        Text(
          'Tap to cycle: Theoretical → Actual → Distribution',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: subtitleColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class SalveFilterControl extends StatelessWidget {
  const SalveFilterControl({
    super.key,
    required this.salves,
    required this.selectedSalve,
    required this.dark,
    required this.onChanged,
  });

  final List<int> salves;
  final int? selectedSalve;
  final bool dark;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        ModeChip(
          label: 'Tout',
          selected: selectedSalve == null,
          dark: dark,
          onTap: () => onChanged(null),
        ),
        for (final salve in salves)
          ModeChip(
            label: 'Salvo $salve',
            selected: selectedSalve == salve,
            dark: dark,
            onTap: () => onChanged(salve),
          ),
      ],
    );
  }
}

class RepartitionControlsRow extends StatelessWidget {
  const RepartitionControlsRow({
    super.key,
    required this.viewMode,
    required this.salves,
    required this.selectedSalve,
    required this.dark,
    required this.onViewModeChanged,
    required this.onSalveChanged,
  });

  final RepartitionViewMode viewMode;
  final List<int> salves;
  final int? selectedSalve;
  final bool dark;
  final ValueChanged<RepartitionViewMode> onViewModeChanged;
  final ValueChanged<int?> onSalveChanged;

  int? get _nextSalve {
    if (salves.isEmpty) return null;
    if (selectedSalve == null) return salves.first;
    final index = salves.indexOf(selectedSalve!);
    if (index < 0 || index >= salves.length - 1) return null;
    return salves[index + 1];
  }

  String get _salveLabel {
    if (selectedSalve == null) return 'Tout';
    return 'Salvo $selectedSalve';
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        ModeChip(
          label: viewMode.label,
          selected: true,
          dark: dark,
          onTap: () => onViewModeChanged(viewMode.next),
        ),
        ModeChip(
          label: _salveLabel,
          selected: true,
          dark: dark,
          onTap: () => onSalveChanged(_nextSalve),
        ),
      ],
    );
  }
}

class ModeChip extends StatelessWidget {
  const ModeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactiveTextColor = dark ? Colors.grey.shade300 : Colors.black87;
    final inactiveBgColor = dark ? Colors.grey.shade900 : Colors.grey.shade200;
    final inactiveBorderColor = dark ? Colors.grey.shade700 : Colors.black26;

    const selectedBgColor = Color(0xFF245A4A);
    const selectedBorderColor = Color(0xFF7FD8B5);

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            const Icon(Icons.check, size: 16, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        color: selected ? Colors.white : inactiveTextColor,
        fontWeight: FontWeight.w800,
      ),
      selectedColor: selectedBgColor,
      backgroundColor: inactiveBgColor,
      side: BorderSide(
        color: selected ? selectedBorderColor : inactiveBorderColor,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      visualDensity: VisualDensity.compact,
    );
  }
}
