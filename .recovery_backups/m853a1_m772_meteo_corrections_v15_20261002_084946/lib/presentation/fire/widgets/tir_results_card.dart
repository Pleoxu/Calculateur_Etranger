import 'package:flutter/material.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';

class TirResultsCard extends StatelessWidget {
  final CalculResult result;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  const TirResultsCard({
    super.key,
    required this.result,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final isOecl = result.isOECL;
    final epp = result.ecartProbablePorteeM;
    final epd = result.ecartProbableDirectionM;
    final burstHeightAglM =
        (result.details['illuminationBurstHeightAglM'] as num?)?.toDouble();
    final illuminationDiameterM =
        (result.details['illuminationEffectiveDiameterM'] as num?)?.toDouble();
    final weatherCorrectionsDeferred = result.details['correctionStatus'] ==
        'nominal_retained_weather_corrections_pending_validation';

    // largeur utile (cards padding inclus)
    final w = MediaQuery.sizeOf(context).width;
    // En dessous ~430px (iPhone), on laisse Wrap passer en 2 lignes.
    final minItemW = w < 430 ? (w - 28 /*padding card*/) / 2.1 : 160.0;

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 24,
            runSpacing: 12,
            children: [
              _kv(
                minWidth: minItemW,
                label: 'Firing bearing',
                value: '${result.noireMil.toStringAsFixed(1)} mil',
              ),
              _kv(
                minWidth: minItemW,
                label: 'AQE',
                value: '${result.aqeMil.toStringAsFixed(1)} mil',
              ),
              _kv(
                minWidth: minItemW,
                label: isOecl ? 'Time to burst' : 'Time of flight',
                value: result.tempsFormate,
              ),
              if (result.hasM772FuzeSetting)
                _kv(
                  minWidth: minItemW,
                  label: 'M772 fuze setting',
                  value: result.m772FuzeSettingFormate,
                ),
              if (burstHeightAglM != null)
                _kv(
                  minWidth: minItemW,
                  label: 'Burst height',
                  value: '${burstHeightAglM.toStringAsFixed(0)} m AGL',
                ),
              if (illuminationDiameterM != null)
                _kv(
                  minWidth: minItemW,
                  label: 'Illuminated diameter',
                  value: '${illuminationDiameterM.toStringAsFixed(0)} m',
                ),
              _kv(minWidth: minItemW, label: 'Charge', value: result.charge),
              _kv(
                minWidth: minItemW,
                label: 'EPP',
                value: '${epp.toStringAsFixed(1)} m',
              ),
              _kv(
                minWidth: minItemW,
                label: 'EPD',
                value: '${epd.toStringAsFixed(1)} m',
              ),
            ],
          ),
          if (weatherCorrectionsDeferred) ...[
            const SizedBox(height: 12),
            Text(
              'Meteorological data accepted — nominal values retained; '
              'M853A1 Table F corrections are pending validation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv({
    required double minWidth,
    required String label,
    required String value,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center, // ✅ centré
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
