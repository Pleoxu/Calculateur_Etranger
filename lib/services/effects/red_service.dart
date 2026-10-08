import 'dart:math' as math;

/// Service de calcul de la RED (Risk Estimate Distance).
///
/// Modèle balistique terminal pour un obus HE 155 mm OTAN :
///   1. Vitesse initiale des éclats  → Gurney
///   2. Distribution des masses      → Mott
///   3. Propagation avec traînée     → intégration numérique (Cd = 1.0)
///   4. Létalité & RED               → P(blessure) ≤ 10⁻³
///
/// La zone RED est une **ellipse** orientée dans l'axe de tir :
///   - Axe longitudinal (avant/arrière) : plus étendu car la vitesse
///     résiduelle de l'obus s'ajoute vectoriellement aux éclats vers l'avant,
///     et l'angle de chute allonge la projection au sol vers l'arrière.
///   - Axe latéral : symétrique, limité par la composante perpendiculaire.
///
/// ─────────────────────────────────────────────────────────────────────────
/// Paramètres réels 155 mm OTAN :
///
/// RALEC (hexolite HT) :
///   masse totale 43 950 g, fusée 630 g → coque 34 490 g, explosif 8 830 g
///
/// FRAPPE (XF 13333) :
///   masse totale 43 250 g, fusée 730 g → coque 34 520 g, explosif 8 000 g
/// ─────────────────────────────────────────────────────────────────────────
class RedService {
  const RedService({this.type = ObusTirType.frappe});

  final ObusTirType type;

  // ─────────────────────────────────────────────────────────────────────────
  // Constantes physiques
  // ─────────────────────────────────────────────────────────────────────────
  static const double _g = 9.81;
  static const double _rhoAir = 1.225;
  static const double _rhoSteel = 7800.0;
  static const double _cdFragment = 1.0;
  static const double _targetSurface = 0.5;
  static const double _lethalEnergyJ = 79.0;
  static const double _lethalSigmoidA = 0.05;
  static const double _redThreshold = 1e-3;

  // ─────────────────────────────────────────────────────────────────────────
  // Paramètres Mott
  // ─────────────────────────────────────────────────────────────────────────
  static const double _mottM0Kg = 0.004;
  static const int _totalFragments = 2000;
  static const int _massClasses = 10;

  // ─────────────────────────────────────────────────────────────────────────
  // Paramètres par type d'obus
  // ─────────────────────────────────────────────────────────────────────────
  static const double _gurneyRalec = 2.56e6;
  static const double _meRalec = 8.830;
  static const double _mcRalec = 34.490;

  static const double _gurneyFrappe = 2.40e6;
  static const double _meFrappe = 8.000;
  static const double _mcFrappe = 34.520;

  double get _gurneyEnergy =>
      type == ObusTirType.ralec ? _gurneyRalec : _gurneyFrappe;
  double get _me => type == ObusTirType.ralec ? _meRalec : _meFrappe;
  double get _mc => type == ObusTirType.ralec ? _mcRalec : _mcFrappe;

  // ─────────────────────────────────────────────────────────────────────────
  // API publique
  // ─────────────────────────────────────────────────────────────────────────

  /// Calcule la RED avec zone elliptique.
  ///
  /// [residualVelocityMps] : vitesse résiduelle de l'obus à l'impact (m/s).
  ///   Utilisée pour calculer le lobe avant (éclats accélérés dans l'axe de tir).
  /// [angleChuteDeg] : angle de chute en degrés (0° = rasant, 90° = vertical).
  ///   Utilisé pour la projection au sol de la zone arrière.
  RedResult computeRed({double? residualVelocityMps, double? angleChuteDeg}) {
    final vf = _gurneyVelocity(_gurneyEnergy, _me, _mc);
    final classes = _buildMottClasses(_mottM0Kg, _totalFragments, _massClasses);

    // Vitesse résiduelle et angle de chute (valeurs par défaut si non fournis)
    final vr = (residualVelocityMps != null && residualVelocityMps > 0)
        ? residualVelocityMps
        : 300.0;
    final thetaDeg =
        (angleChuteDeg != null && angleChuteDeg > 0) ? angleChuteDeg : 45.0;
    final thetaRad = thetaDeg * math.pi / 180.0;
    final sinTheta = math.sin(thetaRad).clamp(0.20, 1.0);
    final cosTheta = math.cos(thetaRad).clamp(0.0, 1.0);

    // ── RED isotrope de base ────────────────────────────────────────────────
    final redBase = _computeRedIsotropic(vf, classes);

    // ── Corrections elliptiques ─────────────────────────────────────────────
    //
    // 1. Lobe AVANT (dans l'axe de tir) :
    //    La vitesse résiduelle Vr s'ajoute à la vitesse d'éjection Vf.
    //    Les éclats projetés vers l'avant ont une vitesse effective ≈ Vf + Vr·cosθ.
    //    On modélise l'extension avant par un facteur multiplicatif.
    final vEffFront = vf + vr * cosTheta;
    final frontFactor = (vEffFront / vf).clamp(1.0, 2.5);

    // 2. Lobe ARRIÈRE (dans l'axe de tir) :
    //    L'angle de chute allonge la projection au sol vers l'arrière.
    //    Pour un angle rasant (petit θ), les éclats arrière touchent le sol
    //    plus loin. Facteur ≈ 1/sin(θ), borné.
    final rearFactor = (1.0 / sinTheta).clamp(1.0, 2.0);

    // 3. Axe LATÉRAL :
    //    Perpendiculaire à l'axe de tir, symétrique.
    //    Légèrement réduit par rapport au rayon isotrope car la composante
    //    latérale de la vitesse résiduelle est nulle.
    final lateralFactor = math.sqrt(sinTheta).clamp(0.70, 1.0);

    // ── Dimensions finales de l'ellipse RED ────────────────────────────────
    final redFront = redBase.redM * frontFactor; // avant (axe tir)
    final redRear = redBase.redM * rearFactor; // arrière (axe tir)
    final redLateral = redBase.redM * lateralFactor; // latéral

    // Demi-grand axe longitudinal = max(avant, arrière)
    final semiLongM = math.max(redFront, redRear);
    final semiLatM = redLateral;

    // ── Zone de danger (P ≥ 50%) ────────────────────────────────────────────
    final dangerFront = redBase.dangerRadiusM * frontFactor;
    final dangerRear = redBase.dangerRadiusM * rearFactor;
    final dangerLateral = redBase.dangerRadiusM * lateralFactor;

    return RedResult(
      redM: redBase.redM,
      dangerRadiusM: redBase.dangerRadiusM,
      fragmentVelocityMps: vf,
      type: type,
      // Ellipse RED
      redSemiLongM: semiLongM,
      redSemiLatM: semiLatM,
      redFrontM: redFront,
      redRearM: redRear,
      // Ellipse danger
      dangerSemiLongM: math.max(dangerFront, dangerRear),
      dangerSemiLatM: dangerLateral,
      dangerFrontM: dangerFront,
      dangerRearM: dangerRear,
      // Paramètres balistiques utilisés
      angleChuteDeg: thetaDeg,
      residualVelocityMps: vr,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Calcul isotrope interne
  // ─────────────────────────────────────────────────────────────────────────

  _RedBaseResult _computeRedIsotropic(double vf, List<_MassClass> classes) {
    final rvTables = <List<_RV>>[];
    final rMaxes = <double>[];

    for (final mc in classes) {
      final rv = _buildRangeVelocityTable(vf, mc.massKg, mc.areaM2);
      rvTables.add(rv);
      rMaxes.add(rv.isEmpty ? 0.0 : rv.last.r);
    }

    const int nRings = 300;
    const double rMax = 1500.0;
    const double dr = rMax / nRings;

    double redM = rMax;
    double dangerM = 0.0;

    for (int i = nRings; i >= 1; i--) {
      final r = i * dr;
      double lambda = 0.0;

      for (int j = 0; j < classes.length; j++) {
        if (r > rMaxes[j]) continue;
        final vr = _velocityAtRange(rvTables[j], r);
        final ek = 0.5 * classes[j].massKg * vr * vr;
        final pLet = _lethalityProb(ek);
        final rho = _surfaceDensity(
          classes[j].count.toDouble(),
          math.max(0.0, r - dr / 2),
          r + dr / 2,
        );
        lambda += rho * _targetSurface * pLet;
      }

      final p = 1.0 - math.exp(-lambda);
      if (p >= _redThreshold && redM == rMax) redM = r;
      if (p >= 0.5 && dangerM == 0.0) dangerM = r;
      if (redM < rMax && dangerM > 0.0) break;
    }

    return _RedBaseResult(redM: redM, dangerRadiusM: dangerM);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Méthodes privées
  // ─────────────────────────────────────────────────────────────────────────

  double _gurneyVelocity(double eg, double me, double mc) =>
      math.sqrt(2.0 * eg * me / mc);

  List<_MassClass> _buildMottClasses(double m0, int nTotal, int nClasses) {
    final mMax = 10.0 * m0;
    final dm = mMax / nClasses;
    final weights = <double>[];
    final means = <double>[];
    for (int i = 0; i < nClasses; i++) {
      final mMid = (i + 0.5) * dm;
      weights.add(math.exp(-math.sqrt(mMid / m0)) * dm);
      means.add(mMid);
    }
    final totalW = weights.fold(0.0, (a, b) => a + b);
    return List.generate(nClasses, (i) {
      final frac = weights[i] / totalW;
      final rSphere = math
          .pow(3 * means[i] / (4 * math.pi * _rhoSteel), 1.0 / 3.0)
          .toDouble();
      return _MassClass(
        massKg: means[i],
        count: (frac * nTotal).round().clamp(1, nTotal),
        areaM2: math.pi * rSphere * rSphere,
      );
    });
  }

  List<_RV> _buildRangeVelocityTable(double vf0, double massKg, double areaM2) {
    const double phi = math.pi / 4;
    const double dt = 0.002;
    final double k = 0.5 * _rhoAir * _cdFragment * areaM2;
    double vx = vf0 * math.cos(phi);
    double vz = vf0 * math.sin(phi);
    double x = 0.0, z = 0.0;
    final table = <_RV>[_RV(0.0, vf0)];
    for (int step = 0; step < 50000; step++) {
      final v = math.sqrt(vx * vx + vz * vz);
      if (v < 1.0) break;
      final ax = -k * v * vx / massKg;
      final az = -_g - k * v * vz / massKg;
      vx += ax * dt;
      vz += az * dt;
      x += vx * dt;
      z += vz * dt;
      if (z < 0.0) break;
      table.add(_RV(x, v));
    }
    return table;
  }

  double _velocityAtRange(List<_RV> rv, double r) {
    if (rv.isEmpty) return 0.0;
    if (r <= 0.0) return rv.first.v;
    if (r >= rv.last.r) return 0.0;
    int lo = 0, hi = rv.length - 1;
    while (lo < hi - 1) {
      final mid = (lo + hi) ~/ 2;
      if (rv[mid].r < r) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final t = (r - rv[lo].r) / (rv[hi].r - rv[lo].r);
    return rv[lo].v + t * (rv[hi].v - rv[lo].v);
  }

  double _surfaceDensity(double n, double rInner, double rOuter) {
    final area = math.pi * (rOuter * rOuter - rInner * rInner);
    return area > 0 ? n / area : 0.0;
  }

  double _lethalityProb(double ek) =>
      1.0 / (1.0 + math.exp(-_lethalSigmoidA * (ek - _lethalEnergyJ)));
}

// ─────────────────────────────────────────────────────────────────────────────
// Enums & modèles
// ─────────────────────────────────────────────────────────────────────────────

enum ObusTirType { ralec, frappe }

extension ObusTirTypeX on ObusTirType {
  String get label {
    switch (this) {
      case ObusTirType.ralec:
        return 'RALEC (HT 8,83 kg)';
      case ObusTirType.frappe:
        return 'FRAPPE (XF 8,00 kg)';
    }
  }
}

/// Résultat complet du calcul RED avec ellipse.
class RedResult {
  const RedResult({
    required this.redM,
    required this.dangerRadiusM,
    required this.fragmentVelocityMps,
    required this.type,
    required this.redSemiLongM,
    required this.redSemiLatM,
    required this.redFrontM,
    required this.redRearM,
    required this.dangerSemiLongM,
    required this.dangerSemiLatM,
    required this.dangerFrontM,
    required this.dangerRearM,
    required this.angleChuteDeg,
    required this.residualVelocityMps,
  });

  /// RED isotrope de référence (m).
  final double redM;

  /// Rayon de danger isotrope (m).
  final double dangerRadiusM;

  /// Vitesse initiale des éclats (m/s).
  final double fragmentVelocityMps;

  final ObusTirType type;

  // ── Ellipse RED ────────────────────────────────────────────────────────
  /// Demi-grand axe longitudinal RED (max avant/arrière) (m).
  final double redSemiLongM;

  /// Demi-axe latéral RED (m).
  final double redSemiLatM;

  /// Extension avant RED dans l'axe de tir (m).
  final double redFrontM;

  /// Extension arrière RED dans l'axe de tir (m).
  final double redRearM;

  // ── Ellipse danger ─────────────────────────────────────────────────────
  final double dangerSemiLongM;
  final double dangerSemiLatM;
  final double dangerFrontM;
  final double dangerRearM;

  // ── Paramètres balistiques utilisés ───────────────────────────────────
  final double angleChuteDeg;
  final double residualVelocityMps;
}

class _RedBaseResult {
  const _RedBaseResult({required this.redM, required this.dangerRadiusM});
  final double redM;
  final double dangerRadiusM;
}

class _MassClass {
  const _MassClass({
    required this.massKg,
    required this.count,
    required this.areaM2,
  });
  final double massKg;
  final int count;
  final double areaM2;
}

class _RV {
  const _RV(this.r, this.v);
  final double r;
  final double v;
}
