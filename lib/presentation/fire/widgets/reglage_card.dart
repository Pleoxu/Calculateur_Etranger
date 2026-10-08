import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/reglage/reglage_engine.dart';
import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';
import 'package:calculateur_etranger/services/tableau_f_service.dart';
import 'package:calculateur_etranger/services/tableau_g_service.dart';
import 'package:calculateur_etranger/services/annexe1_service.dart';

/// Widget de réglage du tir en observation unilatérale.
///
/// L'utilisateur saisit séparément :
/// - l'écart latéral observé : droite/gauche, en millièmes ;
/// - l'écart en profondeur : court/long, en mètres dans l'axe d'observation.
///
/// Le moteur ramène ensuite ces corrections dans le repère de la pièce et
/// recalcule les éléments initiaux : portée corrigée et noire corrigée.
class ReglageCard extends StatefulWidget {
  final TirCompletOutput output;

  final double pdX;
  final double pdY;
  final double obsX;
  final double obsY;
  final double distTirM;
  final double noireMil;

  final String typeAssets;
  final String charge;
  final bool tirMontagne;

  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final bool dark;

  const ReglageCard({
    super.key,
    required this.output,
    required this.pdX,
    required this.pdY,
    required this.obsX,
    required this.obsY,
    required this.distTirM,
    required this.noireMil,
    required this.typeAssets,
    required this.charge,
    required this.tirMontagne,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.dark,
  });

  @override
  State<ReglageCard> createState() => _ReglageCardState();
}

class _ReglageCardState extends State<ReglageCard> {
  final _latCtrl = TextEditingController();
  final _profCtrl = TextEditingController();

  String _sensLat = 'right';
  String _sensProf = 'long';

  ReglageResult? _result;
  String? _error;
  bool _computing = false;

  @override
  void dispose() {
    _latCtrl.dispose();
    _profCtrl.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    final lat = double.tryParse(_latCtrl.text.trim().replaceAll(',', '.'));
    final prof = double.tryParse(_profCtrl.text.trim().replaceAll(',', '.'));

    if (lat == null || lat < 0) {
      setState(() {
        _error = 'Enter a valid right/left offset, zero or positive.';
        _result = null;
      });
      return;
    }
    if (prof == null || prof < 0) {
      setState(() {
        _error = 'Enter a valid short/long offset, zero or positive.';
        _result = null;
      });
      return;
    }

    setState(() {
      _computing = true;
      _error = null;
    });

    try {
      double? bondParMil;
      try {
        final fService = TableauFService(
          typeTir: widget.typeAssets,
          charge: widget.charge,
        );
        bondParMil = await fService.bondPorteeParMil(
          distance: widget.distTirM,
          tirMontagne: widget.tirMontagne,
        );
      } catch (_) {
        bondParMil = null;
      }

      final ecartLatSigne = _sensLat == 'right' ? lat : -lat;
      final ecartProfSigne = _sensProf == 'long' ? prof : -prof;

      final baseRes = ReglageEngine.compute(
        pX: widget.pdX,
        pY: widget.pdY,
        rX: widget.output.prX,
        rY: widget.output.prY,
        oX: widget.obsX,
        oY: widget.obsY,
        ecartLateralObsMil: ecartLatSigne,
        ecartProfondeurObsM: ecartProfSigne,
        distTirM: widget.distTirM,
        noireInitialeMil: widget.noireMil,
        bondPorteeParMil: bondParMil,
      );

      final bal =
          widget.output.resultatPdAffecte ?? widget.output.resultatPrincipal;
      double? aeCorrigeMil;
      double? siteTotalAsCorrigeMil;
      double? acsCorrigeMil;
      double? aqeCorrigeeMil;

      if (bal != null) {
        final fService = TableauFService(
          typeTir: widget.typeAssets,
          charge: widget.charge,
        );
        final gService = TableauGService(
          typeTir: widget.typeAssets,
          charge: widget.charge,
          tirMontagne: widget.tirMontagne,
        );

        aeCorrigeMil = await fService.hausseMil(
          distance: baseRes.porteeCorrigeeM,
          tirMontagne: widget.tirMontagne,
        );

        final siteBrutCorrigeMil =
            bal.deniveleeM / (baseRes.porteeCorrigeeM / 1000.0);
        final corrSiteVraiCorrigeMil = await Annexe1Service.correctionSiteVrai(
          siteBrutCorrigeMil,
        );
        siteTotalAsCorrigeMil = siteBrutCorrigeMil + corrSiteVraiCorrigeMil;

        final kAcsCorrige = await gService.kAcs(
          distanceM: baseRes.porteeCorrigeeM,
          asMil: siteTotalAsCorrigeMil,
        );
        acsCorrigeMil = siteTotalAsCorrigeMil.abs() * kAcsCorrige;
        aqeCorrigeeMil =
            (aeCorrigeMil ?? 0.0) + siteTotalAsCorrigeMil + acsCorrigeMil;
      }

      final res = ReglageEngine.compute(
        pX: widget.pdX,
        pY: widget.pdY,
        rX: widget.output.prX,
        rY: widget.output.prY,
        oX: widget.obsX,
        oY: widget.obsY,
        ecartLateralObsMil: ecartLatSigne,
        ecartProfondeurObsM: ecartProfSigne,
        distTirM: widget.distTirM,
        noireInitialeMil: widget.noireMil,
        bondPorteeParMil: bondParMil,
        aeInitialMil: bal?.aeMil,
        aqeInitialeMil: bal?.aqeMil,
        aeCorrigeMil: aeCorrigeMil,
        siteTotalAsCorrigeMil: siteTotalAsCorrigeMil,
        acsCorrigeMil: acsCorrigeMil,
        aqeCorrigeeMil: aqeCorrigeeMil,
      );

      setState(() {
        _result = res;
        _computing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Calculation error: $e';
        _result = null;
        _computing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color btnBg = Color(0xFF2C2C2E);
    const Color btnFg = Color(0xFFAEAEB2);
    const Color badgeBg = Color(0xFF3A3A3C);
    const Color badgeFg = Color(0xFFAEAEB2);
    const Color corrBg = Color(0xFF1C1C1E);
    const Color corrBdr = Color(0xFF3A3A3C);
    const Color corrTitle = Color(0xFFAEAEB2);
    const Color corrValue = Color(0xFFE5E5EA);

    return Container(
      decoration: BoxDecoration(
        color: widget.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 18, color: badgeFg),
              const SizedBox(width: 8),
              Text(
                'Fire adjustment',
                style: TextStyle(
                  color: widget.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: corrBdr),
                ),
                child: Text(
                  '${widget.typeAssets} · ${widget.charge}',
                  style: const TextStyle(
                    color: badgeFg,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow('Initial range', '${widget.distTirM.toStringAsFixed(0)} m'),
          _infoRow(
            'Initial firing bearing',
            '${widget.noireMil.toStringAsFixed(1)} mil',
          ),
          if (_result != null) ...[
            _infoRow(
              'Angle d\'observation i',
              '${_result!.angleObsMil.toStringAsFixed(0)} mil',
            ),
            _infoRow(
              'Observation distance d',
              '${(_result!.distObsM / 1000).toStringAsFixed(2)} km',
            ),
          ],
          const SizedBox(height: 8),
          Divider(color: widget.border.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          _sectionTitle('Observed lateral offset'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _numberField(_latCtrl, 'ex: 23 mil')),
              const SizedBox(width: 8),
              SizedBox(
                width: 116,
                child: _dropdown(
                  value: _sensLat,
                  items: const ['right', 'left'],
                  onChanged: (v) => setState(() => _sensLat = v ?? _sensLat),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _sectionTitle('Depth offset, observation axis'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _numberField(_profCtrl, 'ex: 100 m')),
              const SizedBox(width: 8),
              SizedBox(
                width: 116,
                child: _dropdown(
                  value: _sensProf,
                  items: const ['long', 'court'],
                  onChanged: (v) => setState(() => _sensProf = v ?? _sensProf),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _computing ? null : _calculate,
              style: ElevatedButton.styleFrom(
                backgroundColor: btnBg,
                foregroundColor: btnFg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _computing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFAEAEB2),
                      ),
                    )
                  : const Text(
                      'Calculate corrected elements',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Divider(color: widget.border.withValues(alpha: 0.5)),
            const SizedBox(height: 10),
            _sectionTitle('Conversion et projection'),
            const SizedBox(height: 6),
            _infoRow(
              'Coeff. observation',
              '${_result!.coeffObservation.toStringAsFixed(2)} m/mil',
            ),
            _infoRow(
              'Observed lateral offset',
              '${_signed(_result!.ecartLateralObsM, 0)} m',
            ),
            _infoRow(
              'Lateral FO correction',
              '${_signed(_result!.correctionLateraleObsM, 0)} m',
            ),
            _infoRow(
              'Range FO correction',
              '${_signed(_result!.correctionProfondeurObsM, 0)} m',
            ),
            const SizedBox(height: 8),
            _sectionTitle('Corrections converted to gun frame'),
            const SizedBox(height: 6),
            _infoRow(
              'Gun range correction',
              '${_signed(_result!.correctionPorteePieceM, 0)} m',
            ),
            _infoRow(
              'Gun lateral correction',
              '${_signed(_result!.correctionLateralePieceM, 0)} m',
            ),
            _infoRow(
              'Azimuth correction',
              '${_signed(_result!.correctionDirectionMil, 1)} mil',
            ),
            if (_result!.correctionHausseMil != null)
              _infoRow(
                'Elevation correction',
                '${_signed(_result!.correctionHausseMil!, 1)} mil',
              ),
            if (_result!.aeCorrigeMil != null)
              _infoRow(
                'Corrected AE (Table F)',
                '${_result!.aeCorrigeMil!.toStringAsFixed(1)} mil',
              ),
            if (_result!.siteTotalAsCorrigeMil != null)
              _infoRow(
                'Corrected AS',
                '${_result!.siteTotalAsCorrigeMil!.toStringAsFixed(1)} mil',
              ),
            if (_result!.acsCorrigeMil != null)
              _infoRow(
                'Corrected ACS (Table G)',
                '${_result!.acsCorrigeMil!.toStringAsFixed(1)} mil',
              ),
            if (_result!.aqeCorrigeeMil != null)
              _infoRow(
                'Corrected AQE',
                '${_result!.aqeCorrigeeMil!.toStringAsFixed(1)} mil',
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: corrBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: corrBdr),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recalculated elements to use',
                    style: TextStyle(
                      color: corrTitle,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _correctionBox(
                          label: 'Range',
                          value:
                              '${_result!.porteeCorrigeeM.toStringAsFixed(0)} m',
                          subtitle:
                              '${_signed(_result!.correctionPorteePieceM, 0)} m',
                          valueColor: corrValue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _correctionBox(
                          label: 'Firing bearing',
                          value:
                              '${_result!.noireCorrigeeMil.toStringAsFixed(1)} mil',
                          subtitle:
                              '${_signed(_result!.correctionDirectionMil, 1)} mil',
                          valueColor: corrValue,
                        ),
                      ),
                    ],
                  ),
                  if (_result!.aqeCorrigeeMil != null) ...[
                    const SizedBox(height: 10),
                    _correctionBox(
                      label: 'AQE',
                      value:
                          '${_result!.aqeCorrigeeMil!.toStringAsFixed(1)} mil',
                      subtitle: 'recalculated F + AS + ACS',
                      valueColor: corrValue,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _signed(double value, int decimals) =>
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(decimals)}';

  Widget _numberField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d*')),
      ],
      style: TextStyle(
        color: widget.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: widget.textSecondary.withValues(alpha: 0.5),
          fontSize: 13,
        ),
        filled: true,
        fillColor: widget.dark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.border),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items
          .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      dropdownColor: widget.dark ? const Color(0xFF2C2C2E) : Colors.white,
      style: TextStyle(
        color: widget.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: widget.dark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.border),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: widget.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: widget.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
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

  Widget _correctionBox({
    required String label,
    required String value,
    required String subtitle,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: widget.dark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: widget.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: widget.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(color: widget.textSecondary, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}
