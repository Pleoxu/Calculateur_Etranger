// lib/domain/meteo/meteo_validity.dart

import 'package:calculateur_etranger/domain/meteo/meteo_parse_result.dart';

/// État de validité d'un message météo
enum MeteoValidityStatus { valid, expiringSoon, expired, unknown }

/// Résultat du calcul de validité météo
class MeteoValidityResult {
  final MeteoValidityStatus status;
  final DateTime? emissionTime;
  final DateTime? expirationTime;
  final Duration? timeUntilExpiration;
  final Duration? timeSinceExpiration;

  const MeteoValidityResult({
    required this.status,
    this.emissionTime,
    this.expirationTime,
    this.timeUntilExpiration,
    this.timeSinceExpiration,
  });

  bool get hasExpiration => expirationTime != null;

  bool get isUsable =>
      status == MeteoValidityStatus.valid ||
      status == MeteoValidityStatus.expiringSoon;

  bool get shouldShowAlert => status != MeteoValidityStatus.valid;

  String getAlertTitle() {
    switch (status) {
      case MeteoValidityStatus.valid:
        return 'Météo valide';
      case MeteoValidityStatus.expiringSoon:
        return 'Météo bientôt expirée';
      case MeteoValidityStatus.expired:
        return 'Météo expirée';
      case MeteoValidityStatus.unknown:
        return 'Validité inconnue';
    }
  }

  String _formatHM(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${h}h$m';
  }

  String getAlertMessage() {
    final emission = emissionTime;
    final expiration = expirationTime;
    final now = DateTime.now();

    // 🔴 CAS : mauvais jour
    if (emission != null && emission.day != now.day) {
      return '⚠️ MÉTÉO NON VALIDE POUR CE JOUR\n\n'
          'Ce message météo est valable le ${emission.day} du mois\n'
          'à partir de ${_formatHM(emission)}'
          '${expiration != null ? ' jusqu’à ${_formatHM(expiration)}' : ''}.\n\n'
          '⚠️ Les calculs balistiques peuvent être imprécis.\n'
          'Vous pouvez continuer quand même.';
    }

    switch (status) {
      case MeteoValidityStatus.valid:
        {
          final d = timeUntilExpiration;
          if (d == null || emission == null || expiration == null) {
            return '✅ MÉTÉO VALIDE';
          }

          return '✅ MÉTÉO VALIDE\n\n'
              'Valable aujourd’hui de ${_formatHM(emission)} à ${_formatHM(expiration)}.\n\n'
              'Expire dans : ${d.inHours}h${(d.inMinutes % 60).toString().padLeft(2, '0')}';
        }

      case MeteoValidityStatus.expiringSoon:
        {
          final d = timeUntilExpiration;
          if (d == null || emission == null || expiration == null) {
            return '⏰ MÉTÉO BIENTÔT EXPIRÉE';
          }

          return '⏰ MÉTÉO BIENTÔT EXPIRÉE\n\n'
              'Valable aujourd’hui de ${_formatHM(emission)} à ${_formatHM(expiration)}.\n\n'
              'Expire dans : ${d.inMinutes} minutes';
        }

      case MeteoValidityStatus.expired:
        {
          final d = timeSinceExpiration;

          if (emission != null && expiration != null) {
            final h = d?.inHours ?? 0;
            final m = d != null ? d.inMinutes % 60 : 0;

            return '⚠️ MÉTÉO EXPIRÉE\n\n'
                'Ce message météo était valable aujourd’hui\n'
                'de ${_formatHM(emission)} à ${_formatHM(expiration)}.\n\n'
                'Expirée depuis : ${h}h${m.toString().padLeft(2, '0')}\n\n'
                '⚠️ Les calculs balistiques peuvent être imprécis.\n'
                'Vous pouvez continuer quand même.';
          }

          return '⚠️ MÉTÉO EXPIRÉE\n\n'
              '⚠️ Les calculs balistiques peuvent être imprécis.\n'
              'Vous pouvez continuer quand même.';
        }

      case MeteoValidityStatus.unknown:
        return 'ℹ️ VALIDITÉ MÉTÉO INCONNUE\n\n'
            'Impossible de déterminer la période de validité.\n'
            'Vous pouvez continuer quand même.';
    }
  }
}

/// Service de calcul de validité météo
class MeteoValidityService {
  static const Duration expiringSoonThreshold = Duration(hours: 1);

  static MeteoValidityResult checkValidity(
    MeteoTemporalInfo? temporalInfo, {
    DateTime? now,
  }) {
    if (temporalInfo == null) {
      return const MeteoValidityResult(status: MeteoValidityStatus.unknown);
    }

    final current = now ?? DateTime.now();
    final emission = temporalInfo.getEmissionDateTime(now: current);
    final expiration = temporalInfo.getExpirationDateTime(now: current);

    if (expiration == null) {
      return MeteoValidityResult(
        status: MeteoValidityStatus.unknown,
        emissionTime: emission,
        expirationTime: null,
      );
    }

    if (current.isAfter(expiration)) {
      return MeteoValidityResult(
        status: MeteoValidityStatus.expired,
        emissionTime: emission,
        expirationTime: expiration,
        timeSinceExpiration: current.difference(expiration),
      );
    }

    final until = expiration.difference(current);

    if (until <= expiringSoonThreshold) {
      return MeteoValidityResult(
        status: MeteoValidityStatus.expiringSoon,
        emissionTime: emission,
        expirationTime: expiration,
        timeUntilExpiration: until,
      );
    }

    return MeteoValidityResult(
      status: MeteoValidityStatus.valid,
      emissionTime: emission,
      expirationTime: expiration,
      timeUntilExpiration: until,
    );
  }
}
