import 'package:flutter/foundation.dart';

import 'package:calculateur_etranger/domain/assignment/central_priority_shots_distribution.dart';

const String _defaultPdPiece = 'PD';

final CentralPriorityShotsDistribution _distribution =
    const CentralPriorityShotsDistribution();

List<String> doctrinalShotPriority({
  required List<String> piecesOrdered,
  required int totalCoups,
}) {
  if (piecesOrdered.isEmpty || totalCoups <= 0) {
    return const [];
  }

  return _distribution.buildPriority(
    orderedPieces: piecesOrdered,
    pdPiece: _defaultPdPiece,
  );
}

Map<String, int> doctrinalRepartition({
  required int totalCoups,
  required List<String> piecesOrdered,
  int minPerPiece = 0,
  int maxPerPiece = 40,
}) {
  if (piecesOrdered.isEmpty) {
    return const {};
  }

  final result = _distribution.distribute(
    orderedPieces: piecesOrdered,
    pdPiece: _defaultPdPiece,
    totalShots: totalCoups,
  );

  return result.shotsByPiece.map(
    (key, value) => MapEntry(key, value.clamp(minPerPiece, maxPerPiece)),
  );
}

Map<String, int> equitableRepartition({
  required int totalCoups,
  required List<String> piecesOrdered,
  int minPerPiece = 0,
  int maxPerPiece = 40,
}) {
  return doctrinalRepartition(
    totalCoups: totalCoups,
    piecesOrdered: piecesOrdered,
    minPerPiece: minPerPiece,
    maxPerPiece: maxPerPiece,
  );
}

Map<String, int> normalizeToTotal({
  required Map<String, int> input,
  required int totalCoups,
  required List<String> piecesOrdered,
  int minPerPiece = 0,
  int maxPerPiece = 40,
}) {
  if (piecesOrdered.isEmpty) {
    return const {};
  }

  final normalized = _distribution.normalizeToTotal(
    input: input,
    totalShots: totalCoups,
    orderedPieces: piecesOrdered,
    pdPiece: _defaultPdPiece,
    minPerPiece: minPerPiece,
    maxPerPiece: maxPerPiece,
  );

  return normalized.map(
    (key, value) => MapEntry(key, value.clamp(minPerPiece, maxPerPiece)),
  );
}

Map<String, int> normalizeToTotalWithTiming({
  required Map<String, int> input,
  required int totalCoups,
  required List<String> piecesOrdered,
  int minPerPiece = 0,
  int maxPerPiece = 40,
}) {
  if (!kDebugMode) {
    return normalizeToTotal(
      input: input,
      totalCoups: totalCoups,
      piecesOrdered: piecesOrdered,
      minPerPiece: minPerPiece,
      maxPerPiece: maxPerPiece,
    );
  }

  final sw = Stopwatch()..start();

  final result = normalizeToTotal(
    input: input,
    totalCoups: totalCoups,
    piecesOrdered: piecesOrdered,
    minPerPiece: minPerPiece,
    maxPerPiece: maxPerPiece,
  );

  sw.stop();
  debugPrint(
    sw.elapsedMilliseconds > 50
        ? '[ROUNDS] TIMING SLOW: ${sw.elapsedMilliseconds}ms'
        : '[ROUNDS] TIMING OK: ${sw.elapsedMilliseconds}ms',
  );

  return result;
}
