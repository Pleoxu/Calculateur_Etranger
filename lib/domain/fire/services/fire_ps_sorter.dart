import 'dart:math' as math;
import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';

class FirePsSorter {
  static void sort({
    required List<PieceSoutienOutput> ps,
    required double pdX,
    required double pdY,
  }) {
    double norm(double az) => ((az % 6400) + 6400) % 6400;

    double signed(double az) {
      final n = norm(az);
      return (n > 3200) ? n - 6400 : n;
    }

    ps.sort((a, b) {
      double az(double x1, double y1, double x2, double y2) {
        final dx = x2 - x1;
        final dy = y2 - y1;
        final angleRad = math.atan2(dx, dy);
        return norm(angleRad * 6400 / (2 * math.pi));
      }

      final azA = signed(az(pdX, pdY, a.xPS, a.yPS));
      final azB = signed(az(pdX, pdY, b.xPS, b.yPS));

      final cmp = azA.compareTo(azB);
      if (cmp != 0) return cmp;

      final distA = math.sqrt(
        (a.xPS - pdX) * (a.xPS - pdX) + (a.yPS - pdY) * (a.yPS - pdY),
      );

      final distB = math.sqrt(
        (b.xPS - pdX) * (b.xPS - pdX) + (b.yPS - pdY) * (b.yPS - pdY),
      );

      return distA.compareTo(distB);
    });
  }
}
