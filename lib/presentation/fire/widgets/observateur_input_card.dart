import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:calculateur_etranger/domain/fire/models/tir_complet_input.dart'
    show ObservateurObjMode;
import 'package:calculateur_etranger/presentation/fire/state/tir_complet_state.dart';
import 'package:calculateur_etranger/presentation/theme/tir_tokens.dart';

/// Cartouche Observateur.
///
/// Affiché uniquement quand [st.observateurEnabled] == true.
/// Contient :
///   - Position UTM de l'observateur (X, Y, Z)
///   - Toggle DAZ / UTM pour la désignation de l'objectif
///   - Champs de désignation selon le mode choisi
///
/// Le champ "Altitude observateur" passe en orange si l'altitude de
/// l'observateur est inférieure ou égale à celle de l'objectif.
/// Dans ce cas le réglage en observation unilatérale est impossible.
class ObservateurInputCard extends StatelessWidget {
  final TirCompletState st;
  final TirCompletNotifier stN;

  // Contrôleurs position observateur
  final TextEditingController obsXCtrl;
  final TextEditingController obsYCtrl;
  final TextEditingController obsZCtrl;

  // Contrôleurs désignation DAZ depuis observateur
  final TextEditingController obsDistCtrl;
  final TextEditingController obsAzCtrl;
  final TextEditingController obsAltObjCtrl;

  // Contrôleurs désignation UTM depuis observateur
  final TextEditingController obsXObjCtrl;
  final TextEditingController obsYObjCtrl;
  final TextEditingController obsZObjCtrl;

  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final bool dark;
  final VoidCallback? onPickObserverGps;
  final VoidCallback? onPickObserverOnMap;
  final VoidCallback? onPickObjectifOnMap;
  final bool observerGpsLoading;
  final bool Function()? canPickObjectifOnMap;
  final Listenable? mapStateListenable;

  const ObservateurInputCard({
    super.key,
    required this.st,
    required this.stN,
    required this.obsXCtrl,
    required this.obsYCtrl,
    required this.obsZCtrl,
    required this.obsDistCtrl,
    required this.obsAzCtrl,
    required this.obsAltObjCtrl,
    required this.obsXObjCtrl,
    required this.obsYObjCtrl,
    required this.obsZObjCtrl,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.dark,
    this.onPickObserverGps,
    this.onPickObserverOnMap,
    this.onPickObjectifOnMap,
    this.observerGpsLoading = false,
    this.canPickObjectifOnMap,
    this.mapStateListenable,
  });

  Color get _fieldFill => dark
      ? Colors.white.withValues(alpha: 0.03)
      : Colors.black.withValues(alpha: 0.02);

  Color get _focusedBorder => dark ? Colors.white24 : Colors.black26;

  Color get _errorBorder => dark
      ? const Color(0xFFB89C61).withValues(alpha: 0.75)
      : const Color(0xFFC59A47);

  Color get _errorText =>
      dark ? const Color(0xFFE9D7AE) : const Color(0xFF7A5A16);

  // ── Couleurs orange pour l'avertissement altitude ──────────────────────
  Color get _orangeBorder => dark
      ? TirColors.warningBorder.withValues(alpha: 0.85)
      : TirColors.warningBorder;

  Color get _orangeFill => dark
      ? TirColors.warningBorder.withValues(alpha: 0.07)
      : TirColors.warningBorder.withValues(alpha: 0.06);

  Color get _orangeText =>
      dark ? TirColors.warningDark : TirColors.warningLight;

  InputDecoration _deco(String label, String hint, {String? errorText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      filled: true,
      fillColor: _fieldFill,
      labelStyle: TextStyle(color: textSecondary, fontSize: 12.5),
      hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
      errorStyle: TextStyle(
        color: _errorText,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TirRadius.l),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TirRadius.l),
        borderSide: BorderSide(color: _focusedBorder),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TirRadius.l),
        borderSide: BorderSide(color: _errorBorder),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TirRadius.l),
        borderSide: BorderSide(color: _errorBorder, width: 1.2),
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    bool enabled = true,
    bool loading = false,
  }) {
    final active = enabled && onTap != null && !loading;
    final bg = dark
        ? (active ? const Color(0xFF20352E) : const Color(0xFF171B22))
        : (active ? const Color(0xFFDCEFE6) : const Color(0xFFF0F1F3));
    final bd = dark
        ? (active
            ? const Color(0xFF2EE6A6).withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.12))
        : (active
            ? const Color(0xFFB7D8C9)
            : Colors.black.withValues(alpha: 0.10));
    final fg = dark
        ? (active ? const Color(0xFFDCEFE6) : Colors.white38)
        : (active ? const Color(0xFF315C49) : Colors.black38);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: active ? onTap : null,
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
          child: loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              : Icon(icon, size: 18, color: fg),
        ),
      ),
    );
  }

  /// Décoration spéciale pour le champ altitude observateur en mode avertissement.
  InputDecoration _decoAltObs(String label, String hint, {required bool warn}) {
    if (!warn) return _deco(label, hint);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: _orangeFill,
      labelStyle: TextStyle(
        color: _orangeText,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TirRadius.l),
        borderSide: BorderSide(color: _orangeBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TirRadius.l),
        borderSide: BorderSide(color: _orangeBorder, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TirRadius.l),
        borderSide: BorderSide(color: _orangeBorder, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TirRadius.l),
        borderSide: BorderSide(color: _orangeBorder, width: 1.8),
      ),
    );
  }

  double? _parse(String raw) {
    final s = raw.trim().replaceAll(',', '.');
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  String? _validateUtmX(String raw) {
    final v = _parse(raw);
    if (v == null) return 'X required';
    if (v < 100000 || v > 900000) return 'X UTM peu plausible';
    return null;
  }

  String? _validateUtmY(String raw) {
    final v = _parse(raw);
    if (v == null) return 'Y required';
    if (v < 1000000) return 'Y trop petit';
    if (v > 10000000) return 'Y UTM peu plausible';
    return null;
  }

  String? _validateDistance(String raw) {
    final v = _parse(raw);
    if (v == null) return 'Distance required';
    if (v <= 0) return 'Distance > 0';
    if (v > 100000) return 'Implausible distance';
    return null;
  }

  String? _validateAzimut(String raw) {
    final v = _parse(raw);
    if (v == null) return 'Azimuth required';
    if (v < 0 || v >= 6400) return 'Azimuth out of range [0;6400[';
    return null;
  }

  /// Retourne true si l'altitude observateur est ≤ altitude objectif.
  /// Dans ce cas le réglage en observation unilatérale est impossible.
  bool _altObsInvalide({
    required String obsZText,
    required String altObjText,
    required String zObjText,
    required ObservateurObjMode mode,
  }) {
    final obsZ = _parse(obsZText);
    if (obsZ == null) return false; // pas encore saisi → pas d'avertissement
    final double? altObj =
        mode == ObservateurObjMode.daz ? _parse(altObjText) : _parse(zObjText);
    if (altObj == null) {
      return false; // altitude objectif non saisie → pas d'avertissement
    }
    return obsZ <= altObj;
  }

  @override
  Widget build(BuildContext context) {
    final inputStyle = TextStyle(color: textPrimary, fontSize: 14);
    final formatters = <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,\-]')),
    ];

    final isDaz = st.observateurObjMode == ObservateurObjMode.daz;

    // Réagit aux changements des contrôleurs altitude
    final altListenable = Listenable.merge([
      obsZCtrl,
      obsAltObjCtrl,
      obsZObjCtrl,
    ]);

    return AnimatedBuilder(
      animation: altListenable,
      builder: (context, _) {
        final warn = _altObsInvalide(
          obsZText: obsZCtrl.text,
          altObjText: obsAltObjCtrl.text,
          zObjText: obsZObjCtrl.text,
          mode: st.observateurObjMode,
        );

        return Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(TirRadius.xl),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête ────────────────────────────────────────────────
              Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: textSecondary,
                  ),
                  const SizedBox(width: TirSpacing.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Observer',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'GPS / Map / Radio',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: TirSpacing.s),
                  _actionChip(
                    icon: Icons.my_location_outlined,
                    tooltip: 'Observer GPS position',
                    onTap: onPickObserverGps,
                    loading: observerGpsLoading,
                  ),
                  const SizedBox(width: TirSpacing.s),
                  _actionChip(
                    icon: Icons.map_outlined,
                    tooltip: 'Choose observer on map',
                    onTap: onPickObserverOnMap,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Position UTM de l'observateur ──────────────────────────
              Text(
                'Observer position',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: TirSpacing.s),
              TextField(
                controller: obsXCtrl,
                style: inputStyle,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                inputFormatters: formatters,
                decoration: _deco(
                  'Observer X (m)',
                  'ex: 500000',
                  errorText: obsXCtrl.text.isNotEmpty
                      ? _validateUtmX(obsXCtrl.text)
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: obsYCtrl,
                style: inputStyle,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                inputFormatters: formatters,
                decoration: _deco(
                  'Observer Y (m)',
                  'ex: 5150000',
                  errorText: obsYCtrl.text.isNotEmpty
                      ? _validateUtmY(obsYCtrl.text)
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              // ── Altitude observateur — orange si ≤ altitude objectif ──
              TextField(
                controller: obsZCtrl,
                style: inputStyle.copyWith(
                  color: warn ? _orangeText : textPrimary,
                  fontWeight: warn ? FontWeight.w600 : FontWeight.normal,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                inputFormatters: formatters,
                decoration: _decoAltObs(
                  'Observer altitude DEM (m)',
                  'ex: 450',
                  warn: warn,
                ),
              ),
              if (warn) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: _orangeText,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        "Observer must be higher than the target for adjustment",
                        style: TextStyle(
                          color: _orangeText,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: TirSpacing.l),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // ── Désignation de l'objectif ──────────────────────────────
              Row(
                children: [
                  Text(
                    'Target designation',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation:
                        mapStateListenable ?? const AlwaysStoppedAnimation(0),
                    builder: (context, _) {
                      final enabled = onPickObjectifOnMap != null &&
                          (canPickObjectifOnMap?.call() ?? true);
                      return _actionChip(
                        icon: Icons.add_location_alt_outlined,
                        tooltip: enabled
                            ? 'Designate target on map from observer'
                            : 'Specify observer position to enable map',
                        onTap: onPickObjectifOnMap,
                        enabled: enabled,
                      );
                    },
                  ),
                  const SizedBox(width: TirSpacing.s),
                  // Toggle DAZ / UTM
                  GestureDetector(
                    onTap: stN.cycleObservateurObjMode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: dark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFF0F1F3),
                        borderRadius: BorderRadius.circular(TirRadius.l),
                        border: Border.all(
                          color: dark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Text(
                        isDaz ? 'DAZ' : 'UTM',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: dark
                              ? Colors.white.withValues(alpha: 0.90)
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (isDaz) ...[
                // ── Mode DAZ ────────────────────────────────────────────────────────────────
                TextField(
                  controller: obsDistCtrl,
                  style: inputStyle,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: formatters,
                  decoration: _deco(
                    'OA → Target distance (m)',
                    'ex: 3500',
                    errorText: obsDistCtrl.text.isNotEmpty
                        ? _validateDistance(obsDistCtrl.text)
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: obsAzCtrl,
                  style: inputStyle,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: formatters,
                  decoration: _deco(
                    'OA → Target bearing (mils)',
                    'ex: 2800',
                    errorText: obsAzCtrl.text.isNotEmpty
                        ? _validateAzimut(obsAzCtrl.text)
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: obsAltObjCtrl,
                  style: inputStyle,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: formatters,
                  decoration: _deco('Target altitude (m)', 'ex: 600'),
                ),
              ] else ...[
                // ── Mode UTM ────────────────────────────────────────────────────────────────
                TextField(
                  controller: obsXObjCtrl,
                  style: inputStyle,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: formatters,
                  decoration: _deco(
                    'Target X (m)',
                    'ex: 503500',
                    errorText: obsXObjCtrl.text.isNotEmpty
                        ? _validateUtmX(obsXObjCtrl.text)
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: obsYObjCtrl,
                  style: inputStyle,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: formatters,
                  decoration: _deco(
                    'Target Y (m)',
                    'ex: 5153500',
                    errorText: obsYObjCtrl.text.isNotEmpty
                        ? _validateUtmY(obsYObjCtrl.text)
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: obsZObjCtrl,
                  style: inputStyle,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: formatters,
                  decoration: _deco('Target altitude (m)', 'ex: 600'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
