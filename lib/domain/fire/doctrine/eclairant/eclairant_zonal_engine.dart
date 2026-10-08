import 'dart:math' as math;
import 'dart:ui';

class EclairantZonalResult {
  final List<Offset> centers;
  final int coups;

  const EclairantZonalResult({required this.centers, required this.coups});
}

class EclairantZonalEngine {
  const EclairantZonalEngine();

  EclairantZonalResult build({
    required double largeurM,
    required double profondeurM,
    required double diametreM,
    required double debordementPct,
  }) {
    final d = diametreM <= 0 ? 600.0 : diametreM;

    final largeurExt = largeurM * (1.0 + debordementPct / 100.0);
    final profondeurExt = profondeurM * (1.0 + debordementPct / 100.0);

    final cols = math.max(1, (largeurExt / d).ceil());
    final rows = math.max(1, (profondeurExt / d).ceil());

    List<double> axis(int count, double extent) {
      if (count <= 1) return const [0.0];

      final start = -extent / 2.0;
      final step = extent / count;

      return [for (var i = 0; i < count; i++) start + step * (i + 0.5)];
    }

    final xs = axis(cols, largeurExt);
    final ys = axis(rows, profondeurExt);

    final centers = <Offset>[
      for (final y in ys)
        for (final x in xs) Offset(x, y),
    ];

    return EclairantZonalResult(centers: centers, coups: centers.length);
  }
}
