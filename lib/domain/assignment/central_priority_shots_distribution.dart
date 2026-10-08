class CentralPriorityShotsDistributionResult {
  final Map<String, int> shotsByPiece;
  final List<String> doctrinalPriority;

  const CentralPriorityShotsDistributionResult({
    required this.shotsByPiece,
    required this.doctrinalPriority,
  });
}

class CentralPriorityShotsDistribution {
  const CentralPriorityShotsDistribution();

  /// Construit une priorité doctrinale centrée sur [pdPiece].
  ///
  /// Exemple :
  /// orderedPieces = [PS7, PS6, PS5, PD, PS1, PS2, PS3, PS4]
  /// pdPiece = PD
  ///
  /// => [PD, PS1, PS5, PS2, PS6, PS3, PS7, PS4]
  ///
  /// Si [pdPiece] n'est pas trouvé, on retombe sur un centre-out simple.
  List<String> buildPriority({
    required List<String> orderedPieces,
    required String pdPiece,
  }) {
    if (orderedPieces.isEmpty) {
      return const [];
    }

    final pdIndex = orderedPieces.indexOf(pdPiece);
    if (pdIndex < 0) {
      return _fallbackCenterOut(orderedPieces);
    }

    final priority = <String>[pdPiece];

    for (var offset = 1; offset < orderedPieces.length; offset++) {
      final rightIndex = pdIndex + offset;
      final leftIndex = pdIndex - offset;

      if (rightIndex >= 0 && rightIndex < orderedPieces.length) {
        priority.add(orderedPieces[rightIndex]);
      }

      if (leftIndex >= 0 && leftIndex < orderedPieces.length) {
        priority.add(orderedPieces[leftIndex]);
      }
    }

    return priority;
  }

  /// Distribution commune :
  /// - base = 1 coup par pièce tant qu'il reste des coups
  /// - surplus = on repart du début de la priorité doctrinale
  CentralPriorityShotsDistributionResult distribute({
    required List<String> orderedPieces,
    required String pdPiece,
    required int totalShots,
  }) {
    final shotsByPiece = <String, int>{
      for (final piece in orderedPieces) piece: 0,
    };

    if (orderedPieces.isEmpty) {
      return const CentralPriorityShotsDistributionResult(
        shotsByPiece: {},
        doctrinalPriority: [],
      );
    }

    final priority = buildPriority(
      orderedPieces: orderedPieces,
      pdPiece: pdPiece,
    );

    if (totalShots <= 0) {
      return CentralPriorityShotsDistributionResult(
        shotsByPiece: shotsByPiece,
        doctrinalPriority: priority,
      );
    }

    var remaining = totalShots;

    // Base : 1 coup par pièce suivant déjà la priorité doctrinale.
    for (final piece in priority) {
      if (remaining == 0) break;
      shotsByPiece[piece] = (shotsByPiece[piece] ?? 0) + 1;
      remaining--;
    }

    // Surplus : on repart du début de la priorité doctrinale.
    var i = 0;
    while (remaining > 0 && priority.isNotEmpty) {
      final piece = priority[i % priority.length];
      shotsByPiece[piece] = (shotsByPiece[piece] ?? 0) + 1;
      remaining--;
      i++;
    }

    return CentralPriorityShotsDistributionResult(
      shotsByPiece: shotsByPiece,
      doctrinalPriority: priority,
    );
  }

  /// Normalise une répartition existante au total demandé.
  ///
  /// Principe :
  /// - si on manque de coups : on ajoute selon la priorité doctrinale
  /// - si on dépasse : on retire en partant de la fin de la priorité
  Map<String, int> normalizeToTotal({
    required Map<String, int> input,
    required int totalShots,
    required List<String> orderedPieces,
    required String pdPiece,
    int minPerPiece = 0,
    int maxPerPiece = 40,
  }) {
    if (orderedPieces.isEmpty) {
      return const {};
    }

    final base = <String, int>{
      for (final p in orderedPieces)
        p: (input[p] ?? 0).clamp(minPerPiece, maxPerPiece),
    };

    final priority = buildPriority(
      orderedPieces: orderedPieces,
      pdPiece: pdPiece,
    );

    final sum = base.values.fold<int>(0, (a, b) => a + b);
    if (sum == totalShots) {
      return base;
    }

    if (sum < totalShots) {
      var need = totalShots - sum;
      var i = 0;

      while (need > 0 && priority.isNotEmpty) {
        final piece = priority[i % priority.length];
        final current = base[piece] ?? 0;
        if (current < maxPerPiece) {
          base[piece] = current + 1;
          need--;
        }
        i++;
      }

      return base;
    }

    var extra = sum - totalShots;
    final removeOrder = priority.reversed.toList(growable: false);

    while (extra > 0 && removeOrder.isNotEmpty) {
      var progressed = false;

      for (final piece in removeOrder) {
        if (extra <= 0) break;

        final current = base[piece] ?? 0;
        if (current > minPerPiece) {
          base[piece] = current - 1;
          extra--;
          progressed = true;
        }
      }

      if (!progressed) {
        break;
      }
    }

    return base;
  }

  List<String> _fallbackCenterOut(List<String> orderedPieces) {
    if (orderedPieces.isEmpty) return const [];
    if (orderedPieces.length == 1) return List<String>.from(orderedPieces);

    final n = orderedPieces.length;
    final result = <String>[];

    if (n.isEven) {
      int left = (n ~/ 2) - 1;
      int right = n ~/ 2;

      while (left >= 0 || right < n) {
        if (right < n) result.add(orderedPieces[right++]);
        if (left >= 0) result.add(orderedPieces[left--]);
      }
    } else {
      final center = n ~/ 2;
      result.add(orderedPieces[center]);

      int left = center - 1;
      int right = center + 1;

      while (left >= 0 || right < n) {
        if (right < n) result.add(orderedPieces[right++]);
        if (left >= 0) result.add(orderedPieces[left--]);
      }
    }

    return result;
  }
}
