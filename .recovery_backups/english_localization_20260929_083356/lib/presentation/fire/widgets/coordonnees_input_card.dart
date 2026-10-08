import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:calculateur_etranger/presentation/fire/state/tir_complet_state.dart';
import 'package:calculateur_etranger/domain/radio/pd_position_state.dart';
import 'package:calculateur_etranger/presentation/theme/tir_tokens.dart';

class CoordonneesInputCard extends StatelessWidget {
  final TirCompletState st;
  final TirCompletNotifier stN;

  // UTM
  final TextEditingController zoneCtrl;
  final TextEditingController xCtrl;
  final TextEditingController yCtrl;
  final TextEditingController zCtrl;

  // LAT/LON/ALT
  final TextEditingController latCtrl;
  final TextEditingController lonCtrl;
  final TextEditingController altCtrl;

  final FocusNode zoneFocus;
  final FocusNode xFocus;
  final FocusNode yFocus;
  final FocusNode zFocus;
  final FocusNode latFocus;
  final FocusNode lonFocus;
  final FocusNode altFocus;

  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final bool dark;
  final VoidCallback? onPickGps;
  final VoidCallback? onPickCivilGps;
  final VoidCallback? onDisableGpsSource;
  final VoidCallback? onPickOnMap;
  final VoidCallback? onSyncRadio;
  final bool gpsLoading;
  final bool externalGpsSelected;
  final bool radioLoading;
  final PdPositionSource pdSource;

  const CoordonneesInputCard({
    super.key,
    required this.st,
    required this.stN,
    required this.zoneCtrl,
    required this.xCtrl,
    required this.yCtrl,
    required this.zCtrl,
    required this.latCtrl,
    required this.lonCtrl,
    required this.altCtrl,
    required this.zoneFocus,
    required this.xFocus,
    required this.yFocus,
    required this.zFocus,
    required this.latFocus,
    required this.lonFocus,
    required this.altFocus,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.dark,
    this.onPickGps,
    this.onPickCivilGps,
    this.onDisableGpsSource,
    this.onPickOnMap,
    this.onSyncRadio,
    this.gpsLoading = false,
    this.externalGpsSelected = false,
    this.radioLoading = false,
    required this.pdSource,
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
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      helperText: helperText,
      filled: true,
      fillColor: dark ? _fieldFillDark : _fieldFillLight,
      labelStyle: TextStyle(color: textSecondary, fontSize: 12.5),
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
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TirRadius.l),
        borderSide: BorderSide(
          color: dark ? _focusedBorderDark : _focusedBorderLight,
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

  String? _validateUtmZone(String raw) {
    final value = raw.trim().toUpperCase();
    if (value.isEmpty) return null;

    final match = RegExp(r'^(\d{1,2})([C-HJ-NP-X])?$').firstMatch(value);
    if (match == null) {
      return 'Format UTM invalide (ex. 31T)';
    }

    final zone = int.tryParse(match.group(1)!);
    if (zone == null || zone < 1 || zone > 60) {
      return 'Zone UTM hors plage [1 ; 60]';
    }

    return null;
  }

  String? _validateUtmX(String raw) {
    if (raw.trim().isEmpty) return null;
    final value = _parseDouble(raw);
    if (value == null) return 'X invalide';
    if (value < 100000 || value > 900000) {
      return 'X UTM peu plausible';
    }
    return null;
  }

  String? _validateUtmY(String raw) {
    if (raw.trim().isEmpty) return null;
    final value = _parseDouble(raw);
    if (value == null) return 'Y invalide';
    if (value < 1000000) {
      return 'Y trop petit : vérifier les mètres complets';
    }
    if (value > 10000000) {
      return 'Y UTM peu plausible';
    }
    return null;
  }

  String? _validateAltitude(String raw) {
    if (raw.trim().isEmpty) return null;
    final value = _parseDouble(raw);
    if (value == null) return 'Altitude invalide';
    if (value < -500 || value > 10000) {
      return 'Altitude peu plausible';
    }
    return null;
  }

  String? _validateLatitude(String raw) {
    if (raw.trim().isEmpty) return null;
    final value = _parseDouble(raw);
    if (value == null) return 'Latitude invalide';
    if (value < -90 || value > 90) {
      return 'Latitude hors plage [-90 ; 90]';
    }
    return null;
  }

  String? _validateLongitude(String raw) {
    if (raw.trim().isEmpty) return null;
    final value = _parseDouble(raw);
    if (value == null) return 'Longitude invalide';
    if (value < -180 || value > 180) {
      return 'Longitude hors plage [-180 ; 180]';
    }
    return null;
  }

  Widget _actionChip({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    final active = onTap != null && !loading;
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
          width: 40,
          height: 40,
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

  Widget _gpsSourceChip({
    required String label,
    required bool active,
    required String tooltip,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    Color bg;
    Color bd;
    Color fg;

    if (!active) {
      bg = dark ? const Color(0xFF171B22) : const Color(0xFFF0F1F3);
      bd = dark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.10);
      fg = dark ? Colors.white38 : Colors.black38;
    } else {
      switch (label) {
        case 'W':
          bg = dark ? Colors.white.withValues(alpha: 0.14) : Colors.white;
          bd = dark
              ? Colors.white.withValues(alpha: 0.35)
              : Colors.black.withValues(alpha: 0.12);
          fg = dark ? Colors.white.withValues(alpha: 0.95) : Colors.black87;
          break;

        case 'C':
          bg = dark ? const Color(0xFF123A5C) : const Color(0xFFDCEBFF);
          bd = dark
              ? const Color(0xFF64B5F6).withValues(alpha: 0.70)
              : const Color(0xFF1976D2).withValues(alpha: 0.35);
          fg = dark ? const Color(0xFFB9DDFF) : const Color(0xFF0D47A1);
          break;

        case 'M':
          bg = dark ? const Color(0xFF29351F) : const Color(0xFFE6EBD8);
          bd = dark
              ? const Color(0xFF8FBC8F).withValues(alpha: 0.70)
              : const Color(0xFF556B2F).withValues(alpha: 0.35);
          fg = dark ? const Color(0xFFDDE8C6) : const Color(0xFF3E4F22);
          break;

        default:
          bg = dark ? const Color(0xFF171B22) : const Color(0xFFF0F1F3);
          bd = dark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.10);
          fg = dark ? Colors.white38 : Colors.black38;
      }
    }

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(TirRadius.l),
        child: Container(
          width: 40,
          height: 40,
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
              : Text(
                  active ? label : '⊕',
                  style: TextStyle(
                    color: fg,
                    fontSize: active ? 16 : 18,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _mapChip({required VoidCallback? onTap, required String tooltip}) {
    final bool enabled = onTap != null;
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(TirRadius.l),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(TirRadius.l),
            border: Border.all(color: bd),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.map_outlined, size: 18, color: fg),
        ),
      ),
    );
  }

  String _sourceLabel() {
    if (externalGpsSelected) return 'GPS civil NMEA';

    switch (pdSource) {
      case PdPositionSource.gpsAtlas:
        return 'GPS';
      case PdPositionSource.radioPct:
        return 'Radio';
      case PdPositionSource.manual:
        return 'Manual / GPS off';
    }
  }

  void _showGpsSourcePanel(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: dark ? const Color(0xFF12141A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        Widget item({
          required String code,
          required String title,
          required String subtitle,
          required bool selected,
          required VoidCallback? onTap,
          bool enabled = true,
        }) {
          final Color badgeBg;
          final Color badgeFg;

          switch (code) {
            case 'W':
              badgeBg = selected
                  ? (dark ? Colors.white.withValues(alpha: 0.16) : Colors.white)
                  : (dark ? const Color(0xFF171B22) : const Color(0xFFF0F1F3));
              badgeFg = dark ? Colors.white : Colors.black87;
              break;
            case 'C':
              badgeBg = selected
                  ? (dark ? const Color(0xFF123A5C) : const Color(0xFFDCEBFF))
                  : (dark ? const Color(0xFF171B22) : const Color(0xFFF0F1F3));
              badgeFg =
                  dark ? const Color(0xFFB9DDFF) : const Color(0xFF0D47A1);
              break;
            case 'M':
              badgeBg = selected
                  ? (dark ? const Color(0xFF29351F) : const Color(0xFFE6EBD8))
                  : (dark ? const Color(0xFF171B22) : const Color(0xFFF0F1F3));
              badgeFg =
                  dark ? const Color(0xFFDDE8C6) : const Color(0xFF3E4F22);
              break;
            default:
              badgeBg =
                  dark ? const Color(0xFF171B22) : const Color(0xFFF0F1F3);
              badgeFg = dark ? Colors.white38 : Colors.black38;
          }

          return ListTile(
            enabled: enabled,
            leading: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(TirRadius.l),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF2EE6A6).withValues(alpha: 0.65)
                      : (dark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.10)),
                ),
              ),
              child: Text(
                code,
                style: TextStyle(
                  color: enabled ? badgeFg : badgeFg.withValues(alpha: 0.35),
                  fontWeight: FontWeight.w800,
                  fontSize: code == '⊕' ? 18 : 15,
                  height: 1,
                ),
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: enabled
                    ? textPrimary
                    : textSecondary.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
            trailing: selected
                ? const Icon(Icons.check_circle, color: Color(0xFF2EE6A6))
                : null,
            onTap: !enabled || onTap == null
                ? null
                : () {
                    Navigator.pop(context);
                    onTap();
                  },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: TirSpacing.l),
                Text(
                  'Source de position',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                item(
                  code: '⊕',
                  title: 'Désactivé',
                  subtitle: 'Aucune source GPS active',
                  selected: pdSource == PdPositionSource.manual,
                  onTap: onDisableGpsSource,
                ),
                item(
                  code: 'W',
                  title: 'Téléphone / Wi-Fi',
                  subtitle: 'Position fournie par CoreLocation',
                  selected: pdSource == PdPositionSource.gpsAtlas,
                  onTap: onPickGps,
                ),
                item(
                  code: 'C',
                  title: 'GPS civil externe',
                  subtitle: 'NMEA 0183 — en attente du récepteur',
                  selected: externalGpsSelected,
                  enabled: onPickCivilGps != null,
                  onTap: onPickCivilGps,
                ),
                item(
                  code: 'M',
                  title: 'GPS militaire',
                  subtitle: 'Non connecté pour l’instant',
                  selected: false,
                  enabled: false,
                  onTap: null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final inputStyle = TextStyle(color: textPrimary, fontSize: 14);
    final formatters = <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,\-]')),
    ];

    final pieceListenable = Listenable.merge([
      zoneCtrl,
      xCtrl,
      yCtrl,
      zCtrl,
      latCtrl,
      lonCtrl,
      altCtrl,
      zoneFocus,
      xFocus,
      yFocus,
      zFocus,
      latFocus,
      lonFocus,
      altFocus,
    ]);

    return AnimatedBuilder(
      animation: pieceListenable,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(TirRadius.l),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.all(TirSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Ligne 1 : titre du cartouche ──────────────────────────────
              Row(
                children: [
                  Text(
                    'Position pièce',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: TirSpacing.s),
                  Text(
                    '· ${_sourceLabel()}',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TirSpacing.m),
              // ── Ligne 2 : toggle UTM/LAT + GPS, Carte, Radio ─────────────
              Row(
                children: [
                  _toggleChip(
                    label: st.pieceUtm ? 'UTM' : 'LAT',
                    onTap: stN.togglePieceUtm,
                  ),
                  const Spacer(),
                  _gpsSourceChip(
                    label: externalGpsSelected
                        ? 'C'
                        : (pdSource == PdPositionSource.gpsAtlas ? 'W' : '⊕'),
                    active: externalGpsSelected ||
                        pdSource == PdPositionSource.gpsAtlas,
                    tooltip: 'Source de position',
                    onTap: () => _showGpsSourcePanel(context),
                    loading: gpsLoading,
                  ),
                  const SizedBox(width: TirSpacing.s),
                  _mapChip(
                    onTap: onPickOnMap,
                    tooltip: 'Choisir la pièce sur carte',
                  ),
                  const SizedBox(width: TirSpacing.s),
                  _actionChip(
                    icon: Icons.settings_input_antenna,
                    tooltip: 'Synchroniser la batterie par radio',
                    onTap: onSyncRadio,
                    loading: radioLoading,
                  ),
                ],
              ),
              const SizedBox(height: TirSpacing.l),
              // ── Champs de saisie ──────────────────────────────────────────
              if (st.pieceUtm) ...[
                TextField(
                  controller: zoneCtrl,
                  focusNode: zoneFocus,
                  style: inputStyle,
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  decoration: _deco(
                    'UTM Zone',
                    'ex: 31U',
                    errorText: _errorAfterFocusLost(
                      zoneFocus,
                      () => _validateUtmZone(zoneCtrl.text),
                    ),
                  ),
                ),
                const SizedBox(height: TirSpacing.m),
                TextField(
                  controller: xCtrl,
                  focusNode: xFocus,
                  style: inputStyle,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: formatters,
                  decoration: _deco(
                    'X (m)',
                    'ex: 500000',
                    errorText: _errorAfterFocusLost(
                      xFocus,
                      () => _validateUtmX(xCtrl.text),
                    ),
                    helperText: 'UTM en mètres complets',
                  ),
                ),
                const SizedBox(height: TirSpacing.m),
                TextField(
                  controller: yCtrl,
                  focusNode: yFocus,
                  style: inputStyle,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: formatters,
                  decoration: _deco(
                    'Y (m)',
                    'ex: 5150000',
                    errorText: _errorAfterFocusLost(
                      yFocus,
                      () => _validateUtmY(yCtrl.text),
                    ),
                    helperText: 'Exemple : 5153450 et non 515345',
                  ),
                ),
                const SizedBox(height: TirSpacing.m),
                TextField(
                  controller: zCtrl,
                  focusNode: zFocus,
                  style: inputStyle,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: formatters,
                  decoration: _deco(
                    'Altitude DEM (m)',
                    'ex: 120',
                    errorText: _errorAfterFocusLost(
                      zFocus,
                      () => _validateAltitude(zCtrl.text),
                    ),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: latCtrl,
                  focusNode: latFocus,
                  style: inputStyle,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: formatters,
                  decoration: _deco(
                    'Latitude (°)',
                    'ex: 48.8566',
                    errorText: _errorAfterFocusLost(
                      latFocus,
                      () => _validateLatitude(latCtrl.text),
                    ),
                  ),
                ),
                const SizedBox(height: TirSpacing.m),
                TextField(
                  controller: lonCtrl,
                  focusNode: lonFocus,
                  style: inputStyle,
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
                      lonFocus,
                      () => _validateLongitude(lonCtrl.text),
                    ),
                  ),
                ),
                const SizedBox(height: TirSpacing.m),
                TextField(
                  controller: altCtrl,
                  focusNode: altFocus,
                  style: inputStyle,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  inputFormatters: formatters,
                  decoration: _deco(
                    'Altitude DEM (m)',
                    'ex: 120',
                    errorText: _errorAfterFocusLost(
                      altFocus,
                      () => _validateAltitude(altCtrl.text),
                    ),
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
