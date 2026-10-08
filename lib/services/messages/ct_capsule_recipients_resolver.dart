// lib/services/messages/ct_capsule_recipients_resolver.dart
//
// Resolves CTMSG recipients from the pieces actually present in the
// calculated shot output. It does not infer recipients from shot count
// or from the report/CR.

import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';

class CtCapsuleRecipientsResolver {
  const CtCapsuleRecipientsResolver();

  /// Source of truth after CALCUL: the actual shots produced by the engine.
  ///
  /// A piece appearing in several shots/salves is returned only once.
  List<String> resolveOutput(TirCompletOutput output) {
    return resolvePieceIds(output.shots.map((shot) => shot.nomPiece));
  }

  /// Pure helper kept testable independently from TirCompletOutput.
  List<String> resolvePieceIds(Iterable<String> pieceIds) {
    final unique = <String>{};

    for (final raw in pieceIds) {
      final id = raw.trim().toUpperCase();
      if (id.isEmpty) continue;
      unique.add(id);
    }

    final result = unique.toList(growable: false);
    result.sort(_comparePieceIds);
    return result;
  }

  int _comparePieceIds(String a, String b) {
    if (a == b) return 0;

    // PD is always shown first.
    if (a == 'PD') return -1;
    if (b == 'PD') return 1;

    final aPs = _psNumber(a);
    final bPs = _psNumber(b);

    if (aPs != null && bPs != null) {
      final byNumber = aPs.compareTo(bPs);
      if (byNumber != 0) return byNumber;
      return a.compareTo(b);
    }

    if (aPs != null) return -1;
    if (bPs != null) return 1;

    return a.compareTo(b);
  }

  int? _psNumber(String value) {
    final match = RegExp(r'^PS(\d+)$').firstMatch(value);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }
}
