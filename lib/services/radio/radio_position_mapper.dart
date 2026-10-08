import 'dart:math' as math;

import 'package:calculateur_etranger/domain/radio/radio_position_message.dart';
import 'package:calculateur_etranger/presentation/fire/models/piece_soutien.dart';

class RadioPositionMapper {
  const RadioPositionMapper();

  List<PieceSoutien> toPiecesSoutien({
    required RadioPositionMessage pd,
    required List<RadioPositionMessage> supports,
  }) {
    return supports.map((ps) {
      final daz = _toDazFromPd(pdX: pd.x, pdY: pd.y, psX: ps.x, psY: ps.y);

      return PieceSoutien(
        nom: ps.id,
        distanceM: daz.distanceM,
        azimutMil: daz.azimutMil,
        xPS: ps.x,
        yPS: ps.y,
        zPS: ps.z,
      );
    }).toList(growable: false);
  }

  static _Daz _toDazFromPd({
    required double pdX,
    required double pdY,
    required double psX,
    required double psY,
  }) {
    final dx = psX - pdX;
    final dy = psY - pdY;

    final distanceM = math.sqrt(dx * dx + dy * dy);

    var azimutMil = math.atan2(dx, dy) * 6400.0 / (2.0 * math.pi);
    if (azimutMil < 0) azimutMil += 6400.0;

    return _Daz(distanceM: distanceM, azimutMil: azimutMil);
  }
}

class _Daz {
  final double distanceM;
  final double azimutMil;

  const _Daz({required this.distanceM, required this.azimutMil});
}
