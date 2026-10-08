import 'package:flutter/material.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';

class TirDetailsDecomposition extends StatefulWidget {
  final CalculResult result;
  final double? niveauMeteo;
  final bool dark;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  const TirDetailsDecomposition({
    super.key,
    required this.result,
    this.niveauMeteo,
    required this.dark,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  State<TirDetailsDecomposition> createState() =>
      _TirDetailsDecompositionState();
}

class _TirDetailsDecompositionState extends State<TirDetailsDecomposition> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final isM252 = r.typeAssets.startsWith('M252_');
    final isOECL = _isOECL(r);
    final isBONUS = _isBONUS(r);
    final isM853A1M772 = _isM853A1M772(r);
    final usesEclNominal = _usesEclNominal(r);

    return Container(
      decoration: BoxDecoration(
        color: widget.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            initiallyExpanded: _expanded,
            onExpansionChanged: (v) => setState(() => _expanded = v),
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            title: Row(
              children: [
                Text(
                  'Details',
                  style: TextStyle(
                    color: widget.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _expanded
                        ? ''
                        : 'Lat ${_fmtMil(r.totalCorrectionAzimutMil)} · Site ${_fmtMil(r.aqeMil)} · Long ${_fmtM(r.totalLongM)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            iconColor: widget.textPrimary,
            collapsedIconColor: widget.textPrimary,
            children: [
              Divider(color: widget.border),
              const SizedBox(height: 10),
              _sectionTitle('Firing base'),
              const SizedBox(height: 8),
              _row2('Gun latitude (°)', _fmtLatN(r.latitudePieceDeg)),
              _row2('Topographic distance (m)', _fmtM0N(r.distanceTopoM)),
              _row2('Azimuth (mil)', _fmtMilN(r.azimutMil)),
              if (!isM252)
                _row2(
                  'Target/gun elevation difference (m)',
                  _fmtM0N(r.deniveleeM),
                ),
              if (!isM252)
                _row2('Site correction (m)', _fmtM1N(r.correctionSiteBM)),
              if (widget.niveauMeteo != null && widget.niveauMeteo! > 0)
                _row2('Weather level', widget.niveauMeteo!.toStringAsFixed(0)),
              _row2('ΔZ gun / weather station (m)', _fmtM0N(r.deltaZStationM)),
              const SizedBox(height: 12),
              Divider(color: widget.border),
              const SizedBox(height: 12),
              _sectionTitle('Lateral (mil)'),
              const SizedBox(height: 8),
              _row2('Drift', _fmtMil(r.deriveMil)),
              _row2('RotZ abs', _fmtMil(r.rotzMilAbs)),
              _row2('Wz', _fmtMil(r.wzMil)),
              _row2('Total azimuth', _fmtMil(r.totalCorrectionAzimutMil)),
              const SizedBox(height: 12),
              Divider(color: widget.border),
              const SizedBox(height: 12),
              _sectionTitle('Site / Angle (mil)'),
              const SizedBox(height: 8),
              if (isM252) ...[
                _row2('AE', _fmtMil(r.aeMil)),
                _row2('Elevation basis', 'Table D / corrected range'),
                _row2('AQE', _fmtMil(r.aqeMil)),
              ] else if (isOECL) ...[
                _row2('AE', _fmtMil(r.aeMil)),
                _row2('Coef ECL (+50m)', _fmtMilN(r.corrEclPour50mMil)),
                _row2('ΔZ target / gun', _fmtM0N(r.deniveleeM)),
                _row2('ECL correction', _fmtMilN(r.corrEclDeniveleeMil)),
                _row2('AQE', _fmtMil(r.aqeMil)),
              ] else if (isBONUS) ...[
                _row2('AE', _fmtMil(r.aeMil)),
                _row2('ΔZ target / gun', _fmtM0N(r.deniveleeM)),
                _row2('AQE DSPD correction', _fmtMil(r.siteTotalAsMil)),
                _row2('AQE', _fmtMil(r.aqeMil)),
              ] else ...[
                _row2('AE', _fmtMil(r.aeMil)),
                _row2('Site brut', _fmtMil(r.siteBrutMil)),
                _row2('Corr site vraie', _fmtMil(r.corrSiteVraiMil)),
                _row2('Site total AS', _fmtMil(r.siteTotalAsMil)),
                _row2('ACS', _fmtMil(r.acsMil)),
                _row2('AQE', _fmtMil(r.aqeMil)),
              ],
              const SizedBox(height: 12),
              Divider(color: widget.border),
              const SizedBox(height: 12),
              _sectionTitle('Longitudinal (m)'),
              const SizedBox(height: 8),
              _row2('Wx', _fmtM(r.wxM)),
              _row2('ΔT', _fmtM(r.deltaTBM)),
              _row2('ΔP', _fmtM(r.deltaPBM)),
              _row2('ΔV0', _fmtM(r.deltaV0M)),
              _row2('ΔMasse', _fmtM(r.masseM)),
              _row2('ΔcRTC', _fmtM(r.rtcM)),
              _row2('ROTx', _fmtM(r.rotxM)),
              _row2('Total longitudinal', _fmtM(r.totalLongM)),
              if (r.tempageDetails != null) ...[
                const SizedBox(height: 12),
                Divider(color: widget.border),
                const SizedBox(height: 12),
                if (isM853A1M772) ...[
                  _sectionTitle('M772 setting (Table D + Table F)'),
                  const SizedBox(height: 8),
                  _row2(
                    'Nominal Table D time to M772 event',
                    _fmtS(r.tempsVolS),
                  ),
                  _row2(
                    'Nominal M772 setting (Table D)',
                    _fmtSetting(r.tempageDetails!.tNominal),
                  ),
                  _row2(
                    'ΔFS wind (Table F)',
                    _fmtSetting(r.tempageDetails!.deltaTvent),
                  ),
                  _row2(
                    'ΔFS air temperature (Table F)',
                    _fmtSetting(r.tempageDetails!.deltaTTb),
                  ),
                  _row2(
                    'ΔFS air density (Table F)',
                    _fmtSetting(r.tempageDetails!.deltaTPb),
                  ),
                  _row2(
                    'ΔFS V0 (Table F)',
                    _fmtSetting(r.tempageDetails!.deltaTV0),
                  ),
                  const SizedBox(height: 8),
                  Divider(color: widget.border.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  _row2(
                    'Σ M772 corrections',
                    _fmtSetting(r.tempageDetails!.totalCorrectionsGlobal),
                  ),
                  _row2(
                    'Final M772 setting',
                    _fmtSetting(r.tempageDetails!.tFusee),
                  ),
                ] else ...[
                  _sectionTitle('Fuze time (s)'),
                  const SizedBox(height: 8),
                  _row2(
                    isBONUS
                        ? 'Nominal DSPD time'
                        : (usesEclNominal
                            ? 'T nominal (Tableau ECL)'
                            : 'T nominal (Tableau F)'),
                    _fmtS(r.tempageDetails!.tNominal),
                  ),
                  _row2('ΔT wind', _fmtS(r.tempageDetails!.deltaTvent)),
                  _row2('ΔT TB', _fmtS(r.tempageDetails!.deltaTTb)),
                  _row2('ΔT PB', _fmtS(r.tempageDetails!.deltaTPb)),
                  _row2('ΔT V0', _fmtS(r.tempageDetails!.deltaTV0)),
                  if (isBONUS)
                    _row2('ΔT ammunition', 'Non applicable')
                  else
                    _row2('ΔT ammunition', _fmtS(r.tempageDetails!.deltaTMun)),
                  if (!isBONUS)
                    _row2(
                      'ΔT mass',
                      r.tempageDetails!.deltaTMasse.abs() < 0.0005
                          ? '—'
                          : _fmtS(r.tempageDetails!.deltaTMasse),
                    ),
                  if (isOECL &&
                      r.tempageDetails!.deltaTEvent50m.abs() >= 0.0005)
                    _row2(
                      'ΔT burst +50m',
                      _fmtS(r.tempageDetails!.deltaTEvent50m),
                    ),
                  const SizedBox(height: 8),
                  Divider(color: widget.border.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  _row2(
                    isOECL ? 'Overall dump correction' : 'Σ corrections',
                    _fmtS(
                      isOECL
                          ? r.tempageDetails!.totalCorrectionsGlobal -
                              r.tempageDetails!.deltaTDenivelee
                          : r.tempageDetails!.totalCorrectionsGlobal,
                    ),
                  ),
                  _row2(
                    isBONUS ? 'ΔT elevation DSPD' : 'ΔT elevation',
                    _fmtS(r.tempageDetails!.deltaTDenivelee),
                  ),
                  _row2(
                    'Final fuze setting (FS)',
                    _fmtS(r.tempageDetails!.tFusee),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: widget.textPrimary,
        fontSize: 13.5,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _row2(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: widget.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              color: widget.textPrimary,
              fontSize: 12.8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtMil(double v) {
    final s = v >= 0 ? '+' : '';
    return '$s${v.toStringAsFixed(2)} mil';
  }

  static String _fmtM(double v) {
    final s = v >= 0 ? '+' : '';
    return '$s${v.toStringAsFixed(2)} m';
  }

  static String _fmtS(double v) {
    final s = v >= 0 ? '+' : '';
    return '$s${v.toStringAsFixed(3)} s';
  }

  static String _fmtSetting(double v) {
    final s = v >= 0 ? '+' : '';
    return '$s${v.toStringAsFixed(3)}';
  }

  static String _fmtLatN(double? v) =>
      v == null ? '—' : '${v.toStringAsFixed(5)} °';

  static String _fmtMilN(double? v) =>
      v == null ? '—' : '${v.toStringAsFixed(2)} mil';

  static String _fmtM0N(double? v) =>
      v == null ? '—' : '${v.toStringAsFixed(0)} m';

  static String _fmtM1N(double? v) =>
      v == null ? '—' : '${v.toStringAsFixed(2)} m';

  static bool _usesEclNominal(CalculResult r) {
    final type = r.typeAssets.toUpperCase();

    // ART392 est FUCHSIA uniquement : le tempage nominal vient de l'ECL.
    if (type.contains('ART392')) {
      return true;
    }

    // ART385 :
    // - FU DE F2 -> nominal Tableau F
    // - FUCHSIA  -> nominal Tableau ECL
    //
    // CalculResult ne transporte pas encore directement la fusée sélectionnée.
    // Pour ART385, la correction de masse de tempage n'est appliquée que pour
    // FUCHSIA ; on l'utilise donc ici comme indicateur fiable avec le modèle
    // actuel.
    if (type.contains('ART385')) {
      final masse = r.tempageDetails?.deltaTMasse ?? 0.0;
      return masse.abs() >= 0.0005;
    }

    return false;
  }

  static bool _isOECL(CalculResult r) {
    return r.isOECL;
  }

  static bool _isM853A1M772(CalculResult r) {
    return r.typeAssets.toUpperCase().contains('M853A1_M772');
  }

  static bool _isBONUS(CalculResult r) {
    return r.typeAssets.toUpperCase().contains('BONUS');
  }
}
