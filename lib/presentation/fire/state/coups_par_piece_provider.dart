import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Map: nomPiece -> nbCoups choisis par l'utilisateur
final coupsParPieceByPieceProvider =
    StateNotifierProvider<CoupsParPieceNotifier, Map<String, int>>(
  (ref) => CoupsParPieceNotifier(),
);

class CoupsParPieceNotifier extends StateNotifier<Map<String, int>> {
  CoupsParPieceNotifier() : super(const {});

  void set(String piece, int value) {
    final v = value < 0 ? 0 : value;
    state = <String, int>{...state, piece: v};
  }

  void setAll(Map<String, int> map) {
    state = Map<String, int>.from(map);
  }

  /// Assure que toutes les pièces demandées existent dans la map.
  /// Supprime celles qui n'existent plus.
  ///
  /// IMPORTANT: ne pas appeler ça depuis un build().
  /// Appeler depuis initState (microtask / postFrame) ou depuis un callback (onPressed).
  void ensurePieces(Iterable<String> pieces, {int defaultValue = 0}) {
    final wanted = pieces.toList(growable: false);

    final next = <String, int>{...state};
    var changed = false;

    for (final p in wanted) {
      if (!next.containsKey(p)) {
        next[p] = defaultValue;
        changed = true;
      }
    }

    final toRemove = next.keys.where((k) => !wanted.contains(k)).toList();
    for (final k in toRemove) {
      next.remove(k);
      changed = true;
    }

    if (changed) state = next;
  }

  void clear() => state = const {};
}
