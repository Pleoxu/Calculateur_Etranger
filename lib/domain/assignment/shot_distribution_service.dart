import 'central_priority_shots_distribution.dart';

class ShotDistributionResult {
  final Map<String, int> shotsByPiece;
  final List<String> doctrinalPriority;

  const ShotDistributionResult({
    required this.shotsByPiece,
    required this.doctrinalPriority,
  });
}

class ShotDistributionService {
  final CentralPriorityShotsDistribution _distribution;

  const ShotDistributionService({
    CentralPriorityShotsDistribution distribution =
        const CentralPriorityShotsDistribution(),
  }) : _distribution = distribution;

  /// Répartition doctrinale commune, utilisée ici pour le linéaire.
  ///
  /// L'ordre réel des pièces est donné par [orderedPieces].
  /// La centralité doctrinale est donnée par [pdPiece].
  ///
  /// Exemple :
  /// orderedPieces = [PS7, PS6, PS5, PD, PS1, PS2, PS3, PS4]
  /// pdPiece = PD
  ///
  /// priorité => [PD, PS1, PS5, PS2, PS6, PS3, PS7, PS4]
  ShotDistributionResult distributeLinearShots({
    required List<String> orderedPieces,
    required String pdPiece,
    required int totalShots,
  }) {
    if (orderedPieces.isEmpty) {
      return const ShotDistributionResult(
        shotsByPiece: {},
        doctrinalPriority: [],
      );
    }

    if (!orderedPieces.contains(pdPiece)) {
      throw ArgumentError('pdPiece "$pdPiece" does not exist in orderedPieces');
    }

    final result = _distribution.distribute(
      orderedPieces: orderedPieces,
      pdPiece: pdPiece,
      totalShots: totalShots,
    );

    return ShotDistributionResult(
      shotsByPiece: result.shotsByPiece,
      doctrinalPriority: result.doctrinalPriority,
    );
  }
}
