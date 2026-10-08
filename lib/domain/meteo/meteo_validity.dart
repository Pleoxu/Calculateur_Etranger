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
        return 'Weather valid';
      case MeteoValidityStatus.expiringSoon:
        return 'Weather expiring soon';
      case MeteoValidityStatus.expired:
        return 'Weather expired';
      case MeteoValidityStatus.unknown:
        return 'Validity unknown';
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
      return '⚠️ WEATHER NOT VALID FOR TODAY\n\n'
          'This weather message is valid on day ${emission.day} of the month\n'
          'from ${_formatHM(emission)}'
          '${expiration != null ? ' until ${_formatHM(expiration)}' : ''}.\n\n'
          '⚠️ Ballistic calculations may be inaccurate.\n'
          'You may continue anyway.';
    }

    switch (status) {
      case MeteoValidityStatus.valid:
        {
          final d = timeUntilExpiration;
          if (d == null || emission == null || expiration == null) {
            return '✅ WEATHER VALID';
          }

          return '✅ WEATHER VALID\n\n'
              'Valid today from ${_formatHM(emission)} to ${_formatHM(expiration)}.\n\n'
              'Expires in: ${d.inHours}h${(d.inMinutes % 60).toString().padLeft(2, '0')}';
        }

      case MeteoValidityStatus.expiringSoon:
        {
          final d = timeUntilExpiration;
          if (d == null || emission == null || expiration == null) {
            return '⏰ WEATHER EXPIRING SOON';
          }

          return '⏰ WEATHER EXPIRING SOON\n\n'
              'Valid today from ${_formatHM(emission)} to ${_formatHM(expiration)}.\n\n'
              'Expires in: ${d.inMinutes} minutes';
        }

      case MeteoValidityStatus.expired:
        {
          final d = timeSinceExpiration;

          if (emission != null && expiration != null) {
            final h = d?.inHours ?? 0;
            final m = d != null ? d.inMinutes % 60 : 0;

            return '⚠️ WEATHER EXPIRED\n\n'
                'This weather message was valid today\n'
                'from ${_formatHM(emission)} to ${_formatHM(expiration)}.\n\n'
                'Expired since: ${h}h${m.toString().padLeft(2, '0')}\n\n'
                '⚠️ Ballistic calculations may be inaccurate.\n'
                'You may continue anyway.';
          }

          return '⚠️ WEATHER EXPIRED\n\n'
              '⚠️ Ballistic calculations may be inaccurate.\n'
              'You may continue anyway.';
        }

      case MeteoValidityStatus.unknown:
        return 'ℹ️ WEATHER VALIDITY UNKNOWN\n\n'
            'Unable to determine the validity period.\n'
            'You may continue anyway.';
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
