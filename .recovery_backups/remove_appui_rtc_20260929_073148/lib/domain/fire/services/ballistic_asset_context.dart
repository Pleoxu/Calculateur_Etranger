// lib/domain/fire/services/ballistic_asset_context.dart

import 'package:calculateur_etranger/domain/fire/models/type_charge_caesar.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';

class BallisticAssetContext {
  final Systeme systeme;
  final TypeTir typeTir;
  final TypeChargeCaesar typeChargeCaesar;

  /// Munition sélectionnée.
  ///
  /// Elle devient nécessaire pour distinguer les référentiels qui partagent
  /// le même type de tir et la même origine de charges, par exemple :
  /// - OE F2 RTC ALL -> OEF2RTC_ALL / ART375
  /// - OE F5 RTC ALL -> OEF5RTC_ALL / ART377
  final TypeMunition? typeMunition;

  /// Famille de munition M252 sélectionnée dans l'interface.
  ///
  /// Champ structurel uniquement : il ne déclenche aucun calcul balistique.
  final M252MunitionFamily? m252MunitionFamily;

  const BallisticAssetContext({
    required this.systeme,
    required this.typeTir,
    this.typeChargeCaesar = TypeChargeCaesar.fr,
    this.typeMunition,
    this.m252MunitionFamily,
  });

  String get variant {
    final base = switch (typeTir) {
      TypeTir.appui => 'APPUI',
      TypeTir.appuiRtc => 'APPUIRTC',
      TypeTir.eclairant => 'OECL',
    };

    if (systeme != Systeme.caesar) {
      return base;
    }

    // Certaines variantes CAESAR doivent être résolues par munition,
    // car elles partagent le même type de tir mais utilisent des ART distincts.
    switch (typeMunition) {
      // APPUI FR — ART387.
      case TypeMunition.oe155F1Fr:
      case TypeMunition.oe155F2Fr:
      case TypeMunition.ofum155F2AFr:
      case TypeMunition.ox155F1Fr:
        return 'APPUI_ART387';

      // APPUI FR — ART390.
      case TypeMunition.oeF5Fr:
      case TypeMunition.oeF8Fr:
      case TypeMunition.oeSemonceF6Fr:
        return 'APPUI_ART390';

      // APPUI RTC FR — ART388.
      case TypeMunition.oeF2RtcFr:
        return 'APPUIRTC_ART388';

      // APPUI RTC FR — ART391.
      case TypeMunition.oeF4RtcFr:
      case TypeMunition.oeF5RtcFr:
      case TypeMunition.oeF8RtcFr:
      case TypeMunition.oeSemonceF6RtcFr:
        return 'APPUIRTC_ART391';

      case TypeMunition.oeF2RtcAll:
        return 'OEF2RTC_ALL';
      case TypeMunition.oeF5RtcAll:
        return 'OEF5RTC_ALL';

      // OECL F1 FR : ART385 annule et remplace ART380.
      // La fusée est gérée plus loin (FU DE F2 par défaut / FUCHSIA en option),
      // mais tous les assets balistiques restent ceux d'ART385.
      case TypeMunition.oeclF1Fr:
        return 'OECL_ART385';

      // OECL F2 FR reste associé à ART392.
      case TypeMunition.oeclF2RtcFr:
      case TypeMunition.oeclF2ReductionCulotFr:
        return 'OECL_ART392';

      default:
        break;
    }

    return switch (typeChargeCaesar) {
      TypeChargeCaesar.fr => base,
      TypeChargeCaesar.allemande => '${base}_ALL',
    };
  }

  bool get isAll =>
      systeme == Systeme.caesar &&
      typeChargeCaesar == TypeChargeCaesar.allemande;

  bool get isFr =>
      systeme == Systeme.caesar && typeChargeCaesar == TypeChargeCaesar.fr;

  bool get isCaesar => systeme == Systeme.caesar;
  bool get isMo120 => systeme == Systeme.mo120;
  bool get isMepac => systeme == Systeme.mepac;
  bool get isMo81M252 => systeme == Systeme.mo81M252;
  bool get isMo81Lrr => systeme == Systeme.mo81Lrr;

  bool get isAppui => typeTir == TypeTir.appui;
  bool get isAppuiRtc => typeTir == TypeTir.appuiRtc;
  bool get isOecl => typeTir == TypeTir.eclairant;

  static String canonicalizeVariant(String raw) {
    var value = raw
        .trim()
        .toUpperCase()
        .replaceAll('É', 'E')
        .replaceAll(' ', '')
        .replaceAll('-', '_');

    if (value.startsWith('TYPETIR.')) {
      value = value.substring('TYPETIR.'.length);
    }

    final artMatch = RegExp(
      r'^(BONUS|APPUIRTC|APPUI|OECL)_ART(385|386|387|388|389|390|391|392)$',
    ).firstMatch(value);

    if (artMatch != null) {
      return '${artMatch.group(1)}_ART${artMatch.group(2)}';
    }

    final isAll = value.endsWith('_ALL');
    final base = isAll ? value.substring(0, value.length - 4) : value;

    final canonicalBase = switch (base) {
      'APPUI' => 'APPUI',
      'APPUIRTC' => 'APPUIRTC',
      'BONUS' => 'BONUS',
      'OEF2RTC' => 'OEF2RTC',
      'OEF5RTC' => 'OEF5RTC',
      'ECLAIRANT' || 'OECL' => 'OECL',
      _ => throw StateError('Variant balistique inconnu : $raw'),
    };

    return isAll ? '${canonicalBase}_ALL' : canonicalBase;
  }

  BallisticAssetContext copyWith({
    Systeme? systeme,
    TypeTir? typeTir,
    TypeChargeCaesar? typeChargeCaesar,
    TypeMunition? typeMunition,
    bool clearTypeMunition = false,
    M252MunitionFamily? m252MunitionFamily,
    bool clearM252MunitionFamily = false,
  }) {
    return BallisticAssetContext(
      systeme: systeme ?? this.systeme,
      typeTir: typeTir ?? this.typeTir,
      typeChargeCaesar: typeChargeCaesar ?? this.typeChargeCaesar,
      typeMunition:
          clearTypeMunition ? null : (typeMunition ?? this.typeMunition),
      m252MunitionFamily: clearM252MunitionFamily
          ? null
          : (m252MunitionFamily ?? this.m252MunitionFamily),
    );
  }

  @override
  String toString() =>
      'BallisticAssetContext(systeme=$systeme, typeTir=$typeTir, '
      'typeChargeCaesar=$typeChargeCaesar, typeMunition=$typeMunition, '
      'm252MunitionFamily=$m252MunitionFamily, variant=$variant)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BallisticAssetContext &&
          systeme == other.systeme &&
          typeTir == other.typeTir &&
          typeChargeCaesar == other.typeChargeCaesar &&
          typeMunition == other.typeMunition &&
          m252MunitionFamily == other.m252MunitionFamily;

  @override
  int get hashCode => Object.hash(
        systeme,
        typeTir,
        typeChargeCaesar,
        typeMunition,
        m252MunitionFamily,
      );
}
