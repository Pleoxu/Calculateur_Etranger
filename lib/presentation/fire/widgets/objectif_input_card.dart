import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calculateur_etranger/domain/fire/models/tir_complet_input.dart';
import 'package:calculateur_etranger/presentation/fire/controllers/tir_complet_controller.dart';
import 'package:calculateur_etranger/presentation/fire/state/tir_complet_state.dart';
import 'package:calculateur_etranger/presentation/fire/state/tir_header_state.dart';
import 'package:calculateur_etranger/presentation/theme/tir_tokens.dart';

class ObjectifInputCard extends ConsumerWidget {
  final TirCompletState st;
  final TirCompletNotifier stN;

  final TextEditingController distCtrl;
  final TextEditingController azCtrl;
  final TextEditingController altObjCtrl;

  final TextEditingController xObjCtrl;
  final TextEditingController yObjCtrl;
  final TextEditingController zObjCtrl;

  final FocusNode distFocus;
  final FocusNode azFocus;
  final FocusNode altObjFocus;
  final FocusNode xObjFocus;
  final FocusNode yObjFocus;
  final FocusNode zObjFocus;

  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final bool dark;
  final VoidCallback? onPickOnMap;
  final bool Function()? canPickOnMap;
  final Listenable? mapStateListenable;
  final String? mapInfoText;

  const ObjectifInputCard({
    super.key,
    required this.st,
    required this.stN,
    required this.distCtrl,
    required this.azCtrl,
    required this.altObjCtrl,
    required this.xObjCtrl,
    required this.yObjCtrl,
    required this.zObjCtrl,
    required this.distFocus,
    required this.azFocus,
    required this.altObjFocus,
    required this.xObjFocus,
    required this.yObjFocus,
    required this.zObjFocus,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.dark,
    this.onPickOnMap,
    this.canPickOnMap,
    this.mapStateListenable,
    this.mapInfoText,
  });

  Color get _fieldFillDark => Colors.white.withValues(alpha: 0.03);
  Color get _fieldFillLight => Colors.black.withValues(alpha: 0.02);

  Color get _focusedBorderDark => Colors.white24;
  Color get _focusedBorderLight => Colors.black26;

  Color get _errorBorderDark => const Color(0xFFFF5252).withValues(alpha: 0.90);
  Color get _errorBorderLight => const Color(0xFFD32F2F);

  Color get _errorTextDark => const Color(0xFFFF8A80);
  Color get _errorTextLight => const Color(0xFFB71C1C);

  Widget _toggleChip({required String label, required VoidCallback onTap}) {
    final bg =
        dark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F1F3);
    final bd = dark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.10);
    final fg = dark ? Colors.white.withValues(alpha: 0.90) : Colors.black87;

    return TextButton(
      onPressed: onTap,
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        backgroundColor: WidgetStatePropertyAll(bg),
        side: WidgetStatePropertyAll(BorderSide(color: bd)),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  InputDecoration _deco(
    String label,
    String hint, {
    String? errorText,
    String? helperText,
    bool isErrorStyle = false,
  }) {
    final effectiveBorderColor =
        isErrorStyle ? (dark ? _errorBorderDark : _errorBorderLight) : border;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      helperText: helperText,
      filled: true,
      fillColor: dark ? _fieldFillDark : _fieldFillLight,
      labelStyle: TextStyle(
        color: isErrorStyle
            ? (dark ? _errorTextDark : _errorTextLight)
            : textSecondary,
        fontSize: 12.5,
      ),
      helperStyle: TextStyle(color: textSecondary, fontSize: 11.5),
      hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
      errorStyle: TextStyle(
        color: dark ? _errorTextDark : _errorTextLight,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TirRadius.l),
        borderSide: BorderSide(color: effectiveBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TirRadius.l),
        borderSide: BorderSide(
          color: isErrorStyle
              ? effectiveBorderColor
              : (dark ? _focusedBorderDark : _focusedBorderLight),
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TirRadius.l),
        borderSide: BorderSide(
          color: dark ? _errorBorderDark : _errorBorderLight,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TirRadius.l),
        borderSide: BorderSide(
          color: dark ? _errorBorderDark : _errorBorderLight,
          width: 1.2,
        ),
      ),
    );
  }

  String? _errorAfterFocusLost(
    FocusNode focusNode,
    String? Function() validator,
  ) {
    if (focusNode.hasFocus) return null;
    return validator();
  }

  double? _parseDouble(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  String? _validateDistance(String raw) {
    if (raw.trim().isEmpty) return null;
    final value = _parseDouble(raw);
    if (value == null) return 'Invalid distance';
    if (value <= 0) return 'Distance > 0 required';
    if (value > 100000) return 'Implausible distance';
    return null;
  }

  String? _validateAzimut(String raw) {
    if (raw.trim().isEmpty) return null;
    final value = _parseDouble(raw);
    if (value == null) return 'Invalid azimuth';
    if (value < 0 || value >= 6400) {
      return 'Azimuth out of range [0 ; 6400[';
    }
    return null;
  }

  String? _validateAltitude(String raw) {
    if (raw.trim().isEmpty) return null;
    final value = _parseDouble(raw);
    if (value == null) return 'Invalid altitude';
    if (value < -500 || value > 10000) return 'Implausible altitude';
    return null;
  }

  String? _validateUtmX(String raw) {
    if (raw.trim().isEmpty) return null;
    final value = _parseDouble(raw);
    if (value == null) return 'Invalid X';
    if (value < 100000 || value > 900000) return 'X UTM peu plausible';
    return null;
  }

  String? _validateUtmY(String raw) {
    if (raw.trim().isEmpty) return null;
    final value = _parseDouble(raw);
    if (value == null) return 'Invalid Y';
    if (value < 1000000) {
      return 'Y too small: absolute coordinates expected';
    }
    if (value > 10000000) return 'Y UTM peu plausible';
    return null;
  }

  Widget _mapChip({
    required VoidCallback? onTap,
    required bool enabled,
    required String tooltip,
  }) {
    final Color bg = dark
        ? (enabled ? const Color(0xFF20352E) : const Color(0xFF171B22))
        : (enabled ? const Color(0xFFDCEFE6) : const Color(0xFFF0F1F3));
    final Color bd = dark
        ? (enabled
            ? const Color(0xFF2EE6A6).withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.12))
        : (enabled
            ? const Color(0xFFB7D8C9)
            : Colors.black.withValues(alpha: 0.10));
    final Color fg = dark
        ? (enabled ? const Color(0xFFDCEFE6) : Colors.white38)
        : (enabled ? const Color(0xFF315C49) : Colors.black38);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(TirRadius.l),
        child: Container(
          width: TirSizes.iconButtonSize,
          height: TirSizes.iconButtonSize,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(TirRadius.l),
            border: Border.all(color: bd),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.add_location_alt_outlined, size: 18, color: fg),
        ),
      ),
    );
  }

  String? _validateLatitude(String raw) {
    if (raw.trim().isEmpty) return null;
    final value = _parseDouble(raw);
    if (value == null) return 'Invalid latitude';
    if (value < -90 || value > 90) return 'Latitude hors plage';
    return null;
  }

  String? _validateLongitude(String raw) {
    if (raw.trim().isEmpty) return null;
    final value = _parseDouble(raw);
    if (value == null) return 'Invalid longitude';
    if (value < -180 || value > 180) return 'Longitude hors plage';
    return null;
  }

  String _currentModeLabel() {
    switch (st.objectifMode) {
      case ObjectifInputMode.utm:
        return 'UTM';
      case ObjectifInputMode.daz:
        return 'DAZ';
      case ObjectifInputMode.lat:
        return 'LAT';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxDistSeuil = ref.watch(porteeMaxSeuilProvider);
    final currentDist = _parseDouble(distCtrl.text) ?? 0.0;
    final bool isHorsPortee = maxDistSeuil > 0 && currentDist > maxDistSeuil;

    final inputStyle = TextStyle(
      color: isHorsPortee
          ? (dark ? _errorTextDark : _errorTextLight)
          : textPrimary,
      fontSize: 14,
      fontWeight: isHorsPortee ? FontWeight.bold : FontWeight.normal,
    );

    final formatters = <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,\-]')),
    ];

    final objectifListenable = Listenable.merge([
      distCtrl,
      azCtrl,
      altObjCtrl,
      xObjCtrl,
      yObjCtrl,
      zObjCtrl,
      distFocus,
      azFocus,
      altObjFocus,
      xObjFocus,
      yObjFocus,
      zObjFocus,
    ]);

    return AnimatedBuilder(
      animation: objectifListenable,
      builder: (context, _) {
        final double distVal = _parseDouble(distCtrl.text) ?? 0.0;
        final bool showWarning = maxDistSeuil > 0 && distVal > maxDistSeuil;

        return Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(TirRadius.l),
            border: Border.all(
              color: showWarning
                  ? (dark ? _errorBorderDark : _errorBorderLight)
                  : border,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Ligne 1 : titre du cartouche ──────────────────────────────
              Row(
                children: [
                  Text(
                    'Target position',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: TirSpacing.s),
                  Text(
                    '· Map / DEM',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // ── Ligne 2 : toggle DAZ/UTM/LAT + bouton Carte ───────────────
              Row(
                children: [
                  _toggleChip(
                    label: _currentModeLabel(),
                    onTap: stN.cycleObjectifMode,
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation:
                        mapStateListenable ?? const AlwaysStoppedAnimation(0),
                    builder: (context, _) {
                      final bool enabled =
                          onPickOnMap != null && (canPickOnMap?.call() ?? true);
                      return _mapChip(
                        onTap: onPickOnMap,
                        enabled: enabled,
                        tooltip: enabled
                            ? 'Choose target on map'
                            : 'Specify directing gun to enable the map',
                      );
                    },
                  ),
                ],
              ),
              // ── Bandeau d'avertissement "Tir impossible" ─────────────────
              if (showWarning) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B1719),
                    borderRadius: BorderRadius.circular(TirRadius.l),
                    border: Border.all(
                      color: Colors.redAccent.shade700,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cancel,
                        color: Colors.redAccent,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fire not possible',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'No charge available covers this distance (${distVal.toInt()} m > ${maxDistSeuil.toInt()} m).',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // ── Bandeau d'info carte (optionnel) ──────────────────────────
              if (mapInfoText != null && mapInfoText!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(TirRadius.l),
                    border: Border.all(color: border),
                  ),
                  child: Text(
                    mapInfoText!,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              // ── Champs de saisie selon le mode ────────────────────────────
              if (st.objectifMode == ObjectifInputMode.daz) ...[
                TextField(
                  controller: distCtrl,
                  focusNode: distFocus,
                  style: inputStyle,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: formatters,
                  decoration: _deco(
                    'Distance (m)',
                    'ex: 15000',
                    isErrorStyle: showWarning,
                    errorText: _errorAfterFocusLost(
                      distFocus,
                      () => _validateDistance(distCtrl.text),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: azCtrl,
                  focusNode: azFocus,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: formatters,
                  decoration: _deco(
                    'Azimuth (mils)',
                    'ex: 2800',
                    errorText: _errorAfterFocusLost(
                      azFocus,
                      () => _validateAzimut(azCtrl.text),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: altObjCtrl,
                  focusNode: altObjFocus,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: formatters,
                  decoration: _deco(
                    'Target DEM Elevation (m)',
                    'ex: 600',
                    errorText: _errorAfterFocusLost(
                      altObjFocus,
                      () => _validateAltitude(altObjCtrl.text),
                    ),
                  ),
                ),
              ] else if (st.objectifMode == ObjectifInputMode.utm) ...[
                TextField(
                  controller: xObjCtrl,
                  focusNode: xObjFocus,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: formatters,
                  decoration: _deco(
                    'Target X (m)',
                    'ex: 500000',
                    errorText: _errorAfterFocusLost(
                      xObjFocus,
                      () => _validateUtmX(xObjCtrl.text),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: yObjCtrl,
                  focusNode: yObjFocus,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: formatters,
                  decoration: _deco(
                    'Target Y (m)',
                    'ex: 5150000',
                    errorText: _errorAfterFocusLost(
                      yObjFocus,
                      () => _validateUtmY(yObjCtrl.text),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: zObjCtrl,
                  focusNode: zObjFocus,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: formatters,
                  decoration: _deco(
                    'Target Z DEM (m)',
                    'ex: 350',
                    errorText: _errorAfterFocusLost(
                      zObjFocus,
                      () => _validateAltitude(zObjCtrl.text),
                    ),
                    helperText: 'Target altitude (optional)',
                  ),
                ),
              ] else ...[
                TextField(
                  controller: xObjCtrl,
                  focusNode: xObjFocus,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: formatters,
                  decoration: _deco(
                    'Latitude (°)',
                    'ex: 46.5934',
                    errorText: _errorAfterFocusLost(
                      xObjFocus,
                      () => _validateLatitude(xObjCtrl.text),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: yObjCtrl,
                  focusNode: yObjFocus,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: formatters,
                  decoration: _deco(
                    'Longitude (°)',
                    'ex: 2.3522',
                    errorText: _errorAfterFocusLost(
                      yObjFocus,
                      () => _validateLongitude(yObjCtrl.text),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: zObjCtrl,
                  focusNode: zObjFocus,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: formatters,
                  decoration: _deco(
                    'DEM elevation (m)',
                    'ex: 350',
                    errorText: _errorAfterFocusLost(
                      zObjFocus,
                      () => _validateAltitude(zObjCtrl.text),
                    ),
                    helperText: 'Target altitude (optional)',
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
