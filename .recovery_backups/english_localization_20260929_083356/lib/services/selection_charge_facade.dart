// lib/services/selection_charge_facade.dart
//
// Façade métier pour la sélection automatique de charge par écart probable
// en portée (Ex) issu du tableau G.
//
// Règle appliquée :
// 1) interpoler strictement la ligne G à la distance topographique ;
// 2) éliminer les charges dont la hausse interpolée est hors du domaine
//    d'emploi du tir indirect ;
// 3) choisir, parmi les charges restantes, celle dont l'Ex est le plus faible.
//
// Le moteur générique reste dans selection_charge_service.dart.

import 'package:flutter/foundation.dart';

import 'secure_asset_resolver.dart';
import 'selection_charge_service.dart';
import 'tableau_g_service.dart';

final class SelectionChargeFacade {
  const SelectionChargeFacade._();

  static const double _epsilon = 1e-9;

  static final Map<String, TableauGService> _tableauGServices = {};

  /// Sélectionne, parmi les charges utilisables fournies, celle dont l'écart
  /// probable en portée est le plus faible à la distance demandée.
  ///
  /// La distance utilisée doit être la distance topographique, avant toute
  /// correction issue du tableau B.
  ///
  /// Une charge est considérée comme utilisable lorsque :
  /// - son tableau G couvre strictement la distance ;
  /// - la branche de tir demandée existe ;
  /// - sa hausse interpolée est comprise entre [hausseMinMil] et
  ///   [hausseMaxMil], bornes incluses.
  ///
  /// Retourne null lorsqu'aucune charge n'est admissible.
  ///
  /// Les erreurs de lecture, déchiffrement, décodage ou format sont propagées.
  static Future<ChargeSelectionResult<String>?> selectBestCharge({
    required SystemeArme systeme,
    required String typeTirAssets,
    required double distanceM,
    required bool tirMontagne,
    required Iterable<String> chargesUtilisables,
    double hausseMinMil = 300.0,
    double hausseMaxMil = 1200.0,
    bool verbose = false,
  }) async {
    _validateDistance(distanceM);
    _validateHausseDomain(
      hausseMinMil: hausseMinMil,
      hausseMaxMil: hausseMaxMil,
    );

    final canonicalType = typeTirAssets.trim().toUpperCase();
    final charges = _normalizeCharges(chargesUtilisables);

    if (canonicalType.isEmpty) {
      throw ArgumentError.value(
        typeTirAssets,
        'typeTirAssets',
        'Le type d’assets ne doit pas être vide.',
      );
    }

    if (charges.isEmpty) {
      return null;
    }

    final service = SelectionChargeService<SystemeArme, String, String,
        _EvaluatedChargeRow, _EvaluatedChargeTable>(
      loadTable: ({
        required SystemeArme system,
        required String category,
        required String charge,
      }) async {
        final gService = _tableFor(
          systeme: system,
          typeTirAssets: category,
          charge: charge,
          tirMontagne: tirMontagne,
          verbose: verbose,
        );

        final row = await gService.rowInterpolatedStrict(
          distanceM: distanceM,
          tirMontagne: tirMontagne,
        );

        if (row == null) {
          if (kDebugMode || verbose) {
            debugPrint(
              '[SELECTION CHARGE] Rejet $charge : '
              'distance hors domaine ou branche absente '
              'type=$category '
              'distance=${distanceM.toStringAsFixed(1)}m '
              'tirMontagne=$tirMontagne',
            );
          }

          return const _EvaluatedChargeTable(
            rows: <_EvaluatedChargeRow>[],
          );
        }

        final hausse = row.hausse;
        final hausseAdmissible = hausse >= hausseMinMil - _epsilon &&
            hausse <= hausseMaxMil + _epsilon;

        if (!hausseAdmissible) {
          if (kDebugMode || verbose) {
            debugPrint(
              '[SELECTION CHARGE] Rejet $charge : '
              'hausse=${hausse.toStringAsFixed(3)} mil '
              'hors domaine '
              '[${hausseMinMil.toStringAsFixed(1)}..'
              '${hausseMaxMil.toStringAsFixed(1)}] '
              'distance=${distanceM.toStringAsFixed(1)}m',
            );
          }

          return const _EvaluatedChargeTable(
            rows: <_EvaluatedChargeRow>[],
          );
        }

        if (kDebugMode || verbose) {
          debugPrint(
            '[SELECTION CHARGE] Candidat $charge : '
            'hausse=${hausse.toStringAsFixed(3)} mil '
            'Ex=${row.ecartProbablePortee.toStringAsFixed(3)} '
            'distance=${distanceM.toStringAsFixed(1)}m',
          );
        }

        return _EvaluatedChargeTable(
          rows: <_EvaluatedChargeRow>[
            _EvaluatedChargeRow(
              distance: distanceM,
              criterionValue: row.ecartProbablePortee,
              alternateBranch: tirMontagne,
            ),
          ],
        );
      },
      chargesForSystem: (_) => charges,
      chargeRank: _chargeRank,
    );

    final result = await service.selectBestCharge(
      system: systeme,
      category: canonicalType,
      distance: distanceM,
      alternateBranch: tirMontagne,
    );

    if (kDebugMode || verbose) {
      if (result == null) {
        debugPrint(
          '[SELECTION CHARGE] Aucun candidat admissible '
          'systeme=$systeme '
          'type=$canonicalType '
          'distance=${distanceM.toStringAsFixed(1)}m '
          'tirMontagne=$tirMontagne '
          'hausse=['
          '${hausseMinMil.toStringAsFixed(1)}..'
          '${hausseMaxMil.toStringAsFixed(1)}] '
          'charges=$charges',
        );
      } else {
        debugPrint(
          '[SELECTION CHARGE] '
          'systeme=$systeme '
          'type=$canonicalType '
          'distance=${distanceM.toStringAsFixed(1)}m '
          'tirMontagne=$tirMontagne '
          'charge=${result.charge} '
          'Ex=${result.criterionValue.toStringAsFixed(3)} '
          'hausse=['
          '${hausseMinMil.toStringAsFixed(1)}..'
          '${hausseMaxMil.toStringAsFixed(1)}] '
          'candidats=${result.candidates}',
        );
      }
    }

    return result;
  }

  /// Raccourci Caesar.
  ///
  /// Par défaut, les six charges Caesar sont évaluées dans le domaine du tir
  /// indirect compris entre 300 et 1200 mil.
  static Future<ChargeSelectionResult<String>?> selectCaesar({
    required String typeTirAssets,
    required double distanceM,
    required bool tirMontagne,
    Iterable<String> chargesUtilisables = const <String>[
      'CH1',
      'CH2',
      'CH3',
      'CH4',
      'CH5',
      'CH6',
    ],
    double hausseMinMil = 300.0,
    double hausseMaxMil = 1200.0,
    bool verbose = false,
  }) {
    return selectBestCharge(
      systeme: SystemeArme.caesar,
      typeTirAssets: typeTirAssets,
      distanceM: distanceM,
      tirMontagne: tirMontagne,
      chargesUtilisables: chargesUtilisables,
      hausseMinMil: hausseMinMil,
      hausseMaxMil: hausseMaxMil,
      verbose: verbose,
    );
  }

  static TableauGService _tableFor({
    required SystemeArme systeme,
    required String typeTirAssets,
    required String charge,
    required bool tirMontagne,
    required bool verbose,
  }) {
    final key = _cacheKey(
      systeme: systeme,
      typeTirAssets: typeTirAssets,
      charge: charge,
      tirMontagne: tirMontagne,
    );

    return _tableauGServices.putIfAbsent(
      key,
      () => TableauGService(
        systeme: systeme,
        typeTir: typeTirAssets,
        charge: charge,
        tirMontagne: tirMontagne,
        verbose: verbose,
      ),
    );
  }

  static List<String> _normalizeCharges(Iterable<String> values) {
    final unique = <String>{};

    for (final value in values) {
      final normalized = value.trim().toUpperCase();

      if (normalized.isNotEmpty) {
        unique.add(normalized);
      }
    }

    final charges = unique.toList()
      ..sort((first, second) {
        final rankComparison = _chargeRank(
          first,
        ).compareTo(_chargeRank(second));

        if (rankComparison != 0) {
          return rankComparison;
        }

        return first.compareTo(second);
      });

    return List<String>.unmodifiable(charges);
  }

  /// Rang métier stable utilisé uniquement pour départager deux charges
  /// ayant exactement le même Ex.
  ///
  /// CH1 est prioritaire sur CH2, puis CH3, etc.
  static int _chargeRank(String charge) {
    final match = RegExp(r'^CH(\d+)$').firstMatch(charge.trim().toUpperCase());

    if (match == null) {
      return 1 << 30;
    }

    return int.tryParse(match.group(1)!) ?? (1 << 30);
  }

  static String _cacheKey({
    required SystemeArme systeme,
    required String typeTirAssets,
    required String charge,
    required bool tirMontagne,
  }) {
    return '$systeme|'
        '${typeTirAssets.trim().toUpperCase()}|'
        '${charge.trim().toUpperCase()}|'
        '$tirMontagne';
  }

  static void _validateDistance(double distanceM) {
    if (!distanceM.isFinite || distanceM < 0) {
      throw ArgumentError.value(
        distanceM,
        'distanceM',
        'La distance doit être finie et positive ou nulle.',
      );
    }
  }

  static void _validateHausseDomain({
    required double hausseMinMil,
    required double hausseMaxMil,
  }) {
    if (!hausseMinMil.isFinite ||
        !hausseMaxMil.isFinite ||
        hausseMinMil < 0 ||
        hausseMaxMil < hausseMinMil) {
      throw ArgumentError(
        'Domaine de hausse invalide : '
        '[$hausseMinMil..$hausseMaxMil].',
      );
    }
  }

  /// Vide les instances de TableauGService conservées par la façade.
  static void clearCache() {
    _tableauGServices.clear();
  }
}

/// Ligne synthétique contenant le résultat déjà interpolé pour une charge.
///
/// Elle permet de conserver le moteur générique de sélection tout en appliquant
/// auparavant les règles métier d'admissibilité fondées sur la hausse.
final class _EvaluatedChargeRow implements SelectionChargeDataRow {
  @override
  final double distance;

  @override
  final double criterionValue;

  @override
  final bool alternateBranch;

  const _EvaluatedChargeRow({
    required this.distance,
    required this.criterionValue,
    required this.alternateBranch,
  });
}

final class _EvaluatedChargeTable
    implements SelectionChargeDataTable<_EvaluatedChargeRow> {
  @override
  final List<_EvaluatedChargeRow> rows;

  const _EvaluatedChargeTable({required this.rows});
}
