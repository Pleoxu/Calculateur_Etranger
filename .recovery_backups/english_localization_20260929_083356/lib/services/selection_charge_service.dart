import 'package:flutter/foundation.dart';

/// Une ligne issue d'une table utilisée pour la sélection de charge.
///
/// Le modèle métier concret, par exemple [TableauGRow], doit implémenter
/// cette interface directement ou être adapté dans la couche d'intégration.
abstract interface class SelectionChargeDataRow {
  double get distance;

  /// Critère à minimiser.
  ///
  /// Pour le tableau G, cette valeur correspond à l'écart probable en portée
  /// [ecartProbablePortee].
  double? get criterionValue;

  /// Permet de distinguer deux branches d'une même table.
  ///
  /// Dans le contexte balistique actuel, cette valeur peut représenter
  /// notamment le tir montagne.
  bool get alternateBranch;
}

/// Une table contenant les lignes d'une charge.
abstract interface class SelectionChargeDataTable<
    R extends SelectionChargeDataRow> {
  List<R> get rows;
}

/// Exception signalant que la table d'une charge n'existe pas.
///
/// Une table absente élimine uniquement la charge concernée.
/// Une erreur de décodage, de déchiffrement ou de format ne doit pas être
/// transformée silencieusement en table absente.
final class SelectionChargeTableNotFoundException implements Exception {
  final String message;

  const SelectionChargeTableNotFoundException(this.message);

  @override
  String toString() => 'SelectionChargeTableNotFoundException: $message';
}

/// Résultat détaillé d'une sélection de charge.
final class ChargeSelectionResult<C> {
  /// Charge retenue.
  final C charge;

  /// Valeur du critère ayant conduit à la sélection.
  ///
  /// Pour le tableau G, il s'agit de l'écart probable en portée.
  final double criterionValue;

  /// Valeurs calculées pour toutes les charges admissibles.
  final Map<C, double> candidates;

  const ChargeSelectionResult({
    required this.charge,
    required this.criterionValue,
    required this.candidates,
  });

  @override
  String toString() {
    return 'ChargeSelectionResult('
        'charge: $charge, '
        'criterionValue: $criterionValue, '
        'candidates: $candidates'
        ')';
  }
}

/// Charge une table pour une charge donnée.
typedef SelectionChargeTableLoader<S, T, C, R extends SelectionChargeDataRow,
        D extends SelectionChargeDataTable<R>>
    = Future<D> Function({
  required S system,
  required T category,
  required C charge,
});

/// Retourne les charges disponibles pour un système.
typedef SelectionChargesProvider<S, C> = List<C> Function(S system);

/// Retourne un rang stable pour départager deux charges de même valeur.
///
/// Il est préférable d'utiliser une propriété métier explicite plutôt que
/// l'index d'un enum, car l'ordre de déclaration d'un enum peut évoluer.
typedef SelectionChargeRank<C> = int Function(C charge);

/// Service générique sélectionnant la charge qui minimise un critère tabulaire.
///
/// Dans l'utilisation balistique prévue, le critère est l'écart probable en
/// portée provenant du tableau G.
final class SelectionChargeService<S, T, C, R extends SelectionChargeDataRow,
    D extends SelectionChargeDataTable<R>> {
  static const double _epsilon = 1e-9;

  final SelectionChargeTableLoader<S, T, C, R, D> loadTable;
  final SelectionChargesProvider<S, C> chargesForSystem;
  final SelectionChargeRank<C> chargeRank;

  const SelectionChargeService({
    required this.loadTable,
    required this.chargesForSystem,
    required this.chargeRank,
  });

  /// Interpole linéairement le critère à une distance donnée.
  ///
  /// Règles :
  /// - filtre la branche demandée ;
  /// - ignore les lignes dont le critère est absent ou non fini ;
  /// - n'extrapole jamais hors du domaine ;
  /// - accepte une égalité avec une petite tolérance ;
  /// - élimine les doublons de distance de manière déterministe.
  double? interpolateCriterion({
    required List<R> rows,
    required double distance,
    required bool alternateBranch,
  }) {
    _validateDistance(distance);

    final filtered = rows.where((row) {
      final value = row.criterionValue;

      return row.alternateBranch == alternateBranch &&
          row.distance.isFinite &&
          value != null &&
          value.isFinite;
    }).toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));

    if (filtered.isEmpty) {
      return null;
    }

    // Déduplication des distances.
    // En cas de doublon, la dernière ligne rencontrée après tri est conservée.
    final byDistance = <double, R>{};

    for (final row in filtered) {
      byDistance[row.distance] = row;
    }

    final branch = byDistance.values.toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));

    if (branch.isEmpty) {
      return null;
    }

    final minimum = branch.first.distance;
    final maximum = branch.last.distance;

    if (distance < minimum - _epsilon || distance > maximum + _epsilon) {
      return null;
    }

    for (final row in branch) {
      if ((row.distance - distance).abs() <= _epsilon) {
        return row.criterionValue;
      }
    }

    for (var index = 0; index < branch.length - 1; index++) {
      final lower = branch[index];
      final upper = branch[index + 1];

      if (distance < lower.distance - _epsilon ||
          distance > upper.distance + _epsilon) {
        continue;
      }

      final lowerValue = lower.criterionValue!;
      final upperValue = upper.criterionValue!;
      final span = upper.distance - lower.distance;

      if (span.abs() <= _epsilon) {
        return lowerValue;
      }

      final ratio = (distance - lower.distance) / span;

      return lowerValue + (upperValue - lowerValue) * ratio;
    }

    return null;
  }

  /// Sélectionne la charge admissible ayant la valeur de critère la plus faible.
  ///
  /// Une table absente élimine uniquement la charge correspondante.
  /// Toute autre erreur est propagée afin de ne pas masquer :
  /// - une corruption de données ;
  /// - une erreur de décodage ;
  /// - une erreur de déchiffrement ;
  /// - un format invalide.
  Future<ChargeSelectionResult<C>?> selectBestCharge({
    required S system,
    required T category,
    required double distance,
    required bool alternateBranch,
  }) async {
    _validateDistance(distance);

    final charges = List<C>.unmodifiable(chargesForSystem(system));

    if (charges.isEmpty) {
      return null;
    }

    final evaluations = await Future.wait(
      charges.map(
        (charge) => _evaluateCharge(
          system: system,
          category: category,
          charge: charge,
          distance: distance,
          alternateBranch: alternateBranch,
        ),
      ),
    );

    final candidates = evaluations.whereType<_ChargeCandidate<C>>().toList();

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((first, second) {
      final criterionComparison = first.criterionValue.compareTo(
        second.criterionValue,
      );

      if (criterionComparison != 0) {
        return criterionComparison;
      }

      return chargeRank(first.charge).compareTo(chargeRank(second.charge));
    });

    final selected = candidates.first;

    return ChargeSelectionResult<C>(
      charge: selected.charge,
      criterionValue: selected.criterionValue,
      candidates: Map<C, double>.unmodifiable({
        for (final candidate in candidates)
          candidate.charge: candidate.criterionValue,
      }),
    );
  }

  Future<_ChargeCandidate<C>?> _evaluateCharge({
    required S system,
    required T category,
    required C charge,
    required double distance,
    required bool alternateBranch,
  }) async {
    try {
      final table = await loadTable(
        system: system,
        category: category,
        charge: charge,
      );

      final value = interpolateCriterion(
        rows: table.rows,
        distance: distance,
        alternateBranch: alternateBranch,
      );

      if (value == null) {
        return null;
      }

      return _ChargeCandidate<C>(charge: charge, criterionValue: value);
    } on SelectionChargeTableNotFoundException catch (error) {
      if (kDebugMode) {
        debugPrint('[SELECTION CHARGE] Table absente pour $charge : $error');
      }

      return null;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[SELECTION CHARGE] Échec de lecture pour $charge : $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  void _validateDistance(double distance) {
    if (!distance.isFinite || distance < 0) {
      throw ArgumentError.value(
        distance,
        'distance',
        'La distance doit être finie et positive ou nulle.',
      );
    }
  }
}

final class _ChargeCandidate<C> {
  final C charge;
  final double criterionValue;

  const _ChargeCandidate({required this.charge, required this.criterionValue});
}
