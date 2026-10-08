enum SystemeArme { caesar, mo, mepac }

class SecureAssetResolver {
  const SecureAssetResolver();

  String assetId({
    required SystemeArme systeme,
    required String famille,
    required String typeTir,
    required String charge,
  }) {
    final family = _normalizeFamily(famille);

    if (family == 'C') {
      return 'C_GLOBAL';
    }

    if (family == 'D') {
      return 'D_GLOBAL';
    }

    final normalizedType = _normalizeTypeTir(
      systeme: systeme,
      typeTir: typeTir,
    );

    switch (systeme) {
      case SystemeArme.caesar:
        return '${family}_${normalizedType}_$charge';
      case SystemeArme.mo:
        return 'MO_${family}_${normalizedType}_$charge';
      case SystemeArme.mepac:
        return 'MEPAC_${family}_${normalizedType}_$charge';
    }
  }

  String folder({required SystemeArme systeme, required String famille}) {
    final family = _normalizeFamily(famille);

    if (family == 'C' || family == 'D') {
      return 'tableaux/$family';
    }

    switch (systeme) {
      case SystemeArme.caesar:
        return 'tableaux/$family';
      case SystemeArme.mo:
        return 'tableaux/MO/$family';
      case SystemeArme.mepac:
        return 'tableaux/MEPAC/$family';
    }
  }

  String normalizeCharge(String charge) {
    final raw = charge.trim();

    if (raw.toLowerCase().contains('horsportee')) {
      throw StateError('Charge invalide : $charge');
    }

    final x = raw
        .toUpperCase()
        .replaceAll('CHARGE.', '')
        .replaceAll('CH', '')
        .replaceAll(',', '.')
        .trim();

    final value = double.tryParse(x);
    if (value == null || value < 0 || value > 10) {
      throw StateError('Charge invalide : $charge');
    }

    final allowed = <double>[0, 0.5, 1, 1.5, 2, 2.5, 3, 4, 5, 6, 7, 8, 9, 10];

    final ok = allowed.any((v) => (v - value).abs() < 0.0001);
    if (!ok) {
      throw StateError('Charge invalide : $charge');
    }

    if ((value - value.roundToDouble()).abs() < 0.0001) {
      return 'CH${value.round()}';
    }

    return 'CH${value.floor()}_5';
  }

  String encryptedAsset({
    required SystemeArme systeme,
    required String famille,
    required String typeTir,
    required String charge,
    required String extension,
  }) {
    final ch = normalizeCharge(charge);
    final id = assetId(
      systeme: systeme,
      famille: famille,
      typeTir: typeTir,
      charge: ch,
    );

    return '${folder(systeme: systeme, famille: famille)}/'
        '$id.$extension.gz.enc';
  }

  String clearAsset({
    required SystemeArme systeme,
    required String famille,
    required String typeTir,
    required String charge,
    required String extension,
  }) {
    final ch = normalizeCharge(charge);
    final id = assetId(
      systeme: systeme,
      famille: famille,
      typeTir: typeTir,
      charge: ch,
    );

    return '${folder(systeme: systeme, famille: famille)}/'
        '$id.$extension.gz';
  }

  String _normalizeFamily(String famille) {
    final family = famille.trim().toUpperCase();

    if (family.isEmpty) {
      throw StateError('Famille de table vide.');
    }

    return family;
  }

  String _normalizeTypeTir({
    required SystemeArme systeme,
    required String typeTir,
  }) {
    final normalized = typeTir
        .trim()
        .toUpperCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'_+'), '_');

    if (normalized.isEmpty) {
      throw StateError('Type de tir vide.');
    }

    if (systeme != SystemeArme.caesar) {
      return normalized;
    }

    switch (normalized) {
      case 'APPUI':
      case 'APPUI_ALL':
        return 'APPUI_ART390';

      case 'OECL':
      case 'OECL_ALL':
        return 'OECL_ART392';

      default:
        // Les types déjà qualifiés (par exemple APPUI_ART390) sont conservés.
        return normalized;
    }
  }
}
