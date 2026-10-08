// lib/services/report/message_pd_collector.dart

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'package:calculateur_etranger/domain/fire/input/fire_request.dart';
import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';
import 'package:calculateur_etranger/domain/report/message_pd_data.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/models/effects/coverage_ellipse.dart';
import 'package:calculateur_etranger/services/effects/red_service.dart';

class MessagePdCollector {
  const MessagePdCollector();

  String _enumLabel(Object value) {
    final raw = value.toString();
    final dot = raw.lastIndexOf('.');
    if (dot >= 0 && dot < raw.length - 1) {
      return raw.substring(dot + 1);
    }
    return raw;
  }

  String _systemeLabel(Object value) {
    switch (_enumLabel(value)) {
      case 'caesar':
        return 'Caesar';
      case 'mepac':
        return 'MEPAC';
      case 'mo120':
        return 'MO-120';
      case 'mo81M252':
        return 'MO81 M252';
      case 'mo81Lrr':
        return 'MO81 LLR';
      default:
        return _enumLabel(value);
    }
  }

  String _typeTirLabel(Object value) {
    switch (_enumLabel(value)) {
      case 'appui':
        return 'Appui au contact';
      case 'eclairant':
        return 'Éclairant';
      default:
        return _enumLabel(value);
    }
  }

  String _fuseeLabel(Object value) {
    switch (_enumLabel(value)) {
      case 'frappe':
        return 'Frappe';
      case 'ralec':
        return 'RALEC';
      default:
        final raw = _enumLabel(value);
        return raw.isEmpty ? raw : '${raw[0].toUpperCase()}${raw.substring(1)}';
    }
  }

  String _munitionLabel(Object value) {
    switch (_enumLabel(value)) {
      case 'oe155F1Fr':
        return 'OE 155 F1';
      case 'oe155F2Fr':
        return 'OE 155 F2';
      case 'oeF5Fr':
      case 'oe155F5':
        return 'OE 155 F5';
      case 'oeF8Fr':
        return 'OE 155 F8';
      case 'oeF5All':
        return 'OE 155 F5 (ALL)';
      case 'oe81F1':
        return 'OE 81 F1';
      case 'oe81Fa32':
        return 'OE 81 FA32';
      case 'oe81F2':
        return 'OE 81 F2';
      case 'oe120F1':
        return 'OE 120 F1';
      case 'oecl120F1':
        return 'OECL 120 F1';
      case 'oecl81F1':
        return 'OECL 81 F1';
      case 'oecl81F3':
        return 'OECL 81 F3';
      case 'oeclIr81F2':
        return 'OECL IR 81 F2';
      default:
        return _enumLabel(value);
    }
  }

  String? _formatDouble(
    double? value, {
    required int digits,
    required String unit,
  }) {
    if (value == null || !value.isFinite) return null;
    return '${value.toStringAsFixed(digits)} $unit';
  }

  String? _formatSignedDouble(
    double? value, {
    required int digits,
    required String unit,
  }) {
    if (value == null || !value.isFinite) return null;
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(digits)} $unit';
  }

  String _compactNumber(double value, {int maxDecimals = 1}) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(maxDecimals);
  }

  String? _formatTirSimilaire(FireRequest request) {
    if (!request.tirSimilaire) return null;

    final parts = <String>[];

    if (request.systeme.name == 'mo81Lrr') {
      if (request.tAct != null && request.tAct!.isFinite) {
        parts.add('T poudre ${_compactNumber(request.tAct!)} °C');
      }
      if (request.v0Prev != null && request.v0Prev!.isFinite) {
        parts.add('V0 réf. ${_compactNumber(request.v0Prev!)} m/s');
      }
      return parts.isEmpty ? 'activé' : parts.join(' • ');
    }

    if (request.simCarreaux > 0) {
      parts.add(
        '${request.simCarreaux} carreau${request.simCarreaux == 1 ? '' : 'x'}',
      );
    }

    if (request.simFusee != null) {
      parts.add(_fuseeLabel(request.simFusee!));
    }

    if (request.tPrev != null && request.tPrev!.isFinite) {
      parts.add('T préc. ${_compactNumber(request.tPrev!)} °C');
    }

    if (request.tAct != null && request.tAct!.isFinite) {
      parts.add('T act. ${_compactNumber(request.tAct!)} °C');
    }

    if (request.v0Prev != null && request.v0Prev!.isFinite) {
      parts.add('V0 préc. ${_compactNumber(request.v0Prev!)} m/s');
    }

    return parts.isEmpty ? 'activé' : parts.join(' • ');
  }

  String? _formatMeteoUsed({
    required FireRequest request,
    required CalculResult? result,
  }) {
    final meteo = request.meteo;
    if (meteo == null || meteo.rows.isEmpty || result == null) return null;

    final usedLevel = result.niveauMeteoBUsed;
    if (usedLevel == null) return null;

    final rows = meteo.rows;
    var picked = rows.first;
    var bestDelta = (picked.level - usedLevel).abs();

    for (final row in rows.skip(1)) {
      final delta = (row.level - usedLevel).abs();
      if (delta < bestDelta) {
        picked = row;
        bestDelta = delta;
      }
    }

    final level = picked.level.toString().padLeft(2, '0');
    final azGroup =
        (picked.azimutMils / 100).round().toString().padLeft(2, '0');
    final wind = picked.vKn.toString().padLeft(2, '0');
    final temp = picked.tempPermil.toString().padLeft(3, '0');
    final pressureValue = picked.pressPermil >= 1000
        ? picked.pressPermil - 1000
        : picked.pressPermil;
    final pressure = pressureValue.toString().padLeft(3, '0');

    return '$level $azGroup $wind $temp $pressure';
  }

  LatLng? _safeGeo(double? lat, double? lon) {
    if (lat == null || lon == null) return null;
    if (!lat.isFinite || !lon.isFinite) return null;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
    return LatLng(lat, lon);
  }

  LatLng? _safeUtmToLatLng(double? x, double? y, String? zone) {
    if (x == null || y == null) return null;
    if (!x.isFinite || !y.isFinite) return null;
    if (x < 100000 || x > 900000) return null;
    if (y < 1000000 || y > 10000000) return null;

    final z = (zone ?? '').trim().toUpperCase();
    var zoneNum = 31;
    var isNorth = true;

    if (z.isNotEmpty) {
      final m = RegExp(r'^(\d{1,2})([A-Z])?$').firstMatch(z);
      if (m != null) {
        zoneNum = int.tryParse(m.group(1)!) ?? 31;
        final letter = m.group(2);
        if (letter != null) {
          isNorth = letter.compareTo('N') >= 0;
        }
      } else {
        zoneNum = int.tryParse(z.replaceAll(RegExp(r'[^0-9]'), '')) ?? 31;
      }
    }

    const a = 6378137.0;
    const f = 1 / 298.257223563;
    const k0 = 0.9996;
    const b = a * (1 - f);
    final e2 = (a * a - b * b) / (a * a);
    final lon0Rad = ((zoneNum - 1) * 6 - 180 + 3) * (math.pi / 180.0);

    final xx = x - 500000.0;
    final yy = isNorth ? y : y - 10000000.0;

    final m = yy / k0;
    final mu =
        m / (a * (1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256));

    final e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2));
    final fp = mu +
        (3 * e1 / 2 - 27 * e1 * e1 * e1 / 32) * math.sin(2 * mu) +
        (21 * e1 * e1 / 16 - 55 * e1 * e1 * e1 * e1 / 32) * math.sin(4 * mu) +
        (151 * e1 * e1 * e1 / 96) * math.sin(6 * mu) +
        (1097 * e1 * e1 * e1 * e1 / 512) * math.sin(8 * mu);

    final c1 = e2 * math.pow(math.cos(fp), 2) / (1 - e2);
    final t1 = math.pow(math.tan(fp), 2);
    final n1 = a / math.sqrt(1 - e2 * math.pow(math.sin(fp), 2));
    final r1 = a * (1 - e2) / math.pow(1 - e2 * math.pow(math.sin(fp), 2), 1.5);
    final d = xx / (n1 * k0);

    final latRad = fp -
        (n1 * math.tan(fp) / r1) *
            (d * d / 2 -
                (5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * e2) *
                    d *
                    d *
                    d *
                    d /
                    24 +
                (61 +
                        90 * t1 +
                        298 * c1 +
                        45 * t1 * t1 -
                        252 * e2 -
                        3 * c1 * c1) *
                    d *
                    d *
                    d *
                    d *
                    d *
                    d /
                    720);

    final lonRad = lon0Rad +
        (d -
                (1 + 2 * t1 + c1) * d * d * d / 6 +
                (5 - 2 * c1 + 28 * t1 - 3 * c1 * c1 + 8 * e2 + 24 * t1 * t1) *
                    d *
                    d *
                    d *
                    d *
                    d /
                    120) /
            math.cos(fp);

    final lat = latRad * 180.0 / math.pi;
    final lon = lonRad * 180.0 / math.pi;
    return _safeGeo(lat, lon);
  }

  String? _formatUtm(String? zone, double? x, double? y) {
    if (x == null || y == null) return null;
    if (!x.isFinite || !y.isFinite) return null;
    final zoneLabel = (zone == null || zone.trim().isEmpty) ? '?' : zone.trim();
    return 'UTM $zoneLabel  ${x.toStringAsFixed(0)}  ${y.toStringAsFixed(0)}';
  }

  String? _formatGeoLine(double? lat, double? lon) {
    if (lat == null || lon == null) return null;
    if (!lat.isFinite || !lon.isFinite) return null;
    return 'GPS ${lat.toStringAsFixed(5)}  ${lon.toStringAsFixed(5)}';
  }

  String? _formatAltitude(double? altitude) {
    if (altitude == null || !altitude.isFinite) return null;
    return 'Alt ${altitude.toStringAsFixed(0)} m';
  }

  String? _joinLines(List<String?> items) {
    final values =
        items.whereType<String>().where((e) => e.trim().isNotEmpty).toList();
    if (values.isEmpty) return null;
    return values.join('\n');
  }

  String? _piecePositionText(FireRequest request) {
    return _joinLines([
      _formatUtm(request.piece.utmZone, request.piece.utmX, request.piece.utmY),
      _formatGeoLine(request.piece.latitude, request.piece.longitude),
      _formatAltitude(request.piece.altitude),
    ]);
  }

  String? _objectifPositionText(
    FireRequest request,
    TirCompletOutput output,
    String? utmZoneFallback,
  ) {
    final lines = <String?>[];

    final zone = (request.piece.utmZone?.trim().isNotEmpty ?? false)
        ? request.piece.utmZone
        : utmZoneFallback;

    // Le bloc principal du CR décrit l'objectif DE RÉFÉRENCE demandé par
    // l'opérateur, jamais le premier objectif décalé du plan de feu.
    //
    // Si D/AZ sont disponibles, on reconstruit le centre depuis la PD.
    // Cela évite qu'un objectif affecté à la PD (OPD avec offset) remplace
    // accidentellement le centre du linéaire dans le compte rendu.
    final d = request.target.distanceM;
    final az = request.target.azimutMil;
    final px = request.piece.utmX;
    final py = request.piece.utmY;

    if (d != null &&
        az != null &&
        px != null &&
        py != null &&
        d.isFinite &&
        az.isFinite &&
        px.isFinite &&
        py.isFinite) {
      final azRad = az * 2.0 * math.pi / 6400.0;
      final centerX = px + d * math.sin(azRad);
      final centerY = py + d * math.cos(azRad);
      lines.add(_formatUtm(zone, centerX, centerY));
    } else if (request.target.utmX != null && request.target.utmY != null) {
      lines.add(_formatUtm(zone, request.target.utmX, request.target.utmY));
    }

    if (request.target.latitude != null && request.target.longitude != null) {
      lines.add(
        _formatGeoLine(request.target.latitude, request.target.longitude),
      );
    }

    lines.add(_formatAltitude(request.target.altitude));
    return _joinLines(lines);
  }

  LatLng? _resolvePieceLatLng(FireRequest request, String? utmZoneFallback) {
    return _safeGeo(request.piece.latitude, request.piece.longitude) ??
        _safeUtmToLatLng(
          request.piece.utmX,
          request.piece.utmY,
          request.piece.utmZone ?? utmZoneFallback,
        );
  }

  LatLng? _resolveObjectifLatLng(
    FireRequest request,
    TirCompletOutput output,
    String? utmZoneFallback,
  ) {
    final zone = request.piece.utmZone ?? utmZoneFallback;
    final pdLatLng = _resolvePieceLatLng(request, utmZoneFallback);

    // Pour la carte générale, priorité au centre D/AZ demandé.
    // Les impacts / offsets restent gérés séparément par impactLatLng et
    // targetGeometry.
    return _offsetFromPdDaz(
          pdLatLng: pdLatLng,
          distanceM: request.target.distanceM,
          azimutMil: request.target.azimutMil,
        ) ??
        _safeGeo(request.target.latitude, request.target.longitude) ??
        _safeUtmToLatLng(request.target.utmX, request.target.utmY, zone) ??
        (output.shots.isNotEmpty
            ? _safeUtmToLatLng(
                output.shots.first.objX,
                output.shots.first.objY,
                zone,
              )
            : null);
  }

  LatLng? _resolveImpactLatLng(
    FireRequest request,
    TirCompletOutput output,
    String? utmZoneFallback,
  ) {
    final zone = request.piece.utmZone ?? utmZoneFallback;
    if (output.shots.isNotEmpty) {
      return _safeUtmToLatLng(
          output.shots.first.objX, output.shots.first.objY, zone);
    }
    return _resolveObjectifLatLng(request, output, utmZoneFallback);
  }

  LatLng _offsetLatLng({
    required LatLng origin,
    required double eastM,
    required double northM,
  }) {
    const earthRadiusM = 6378137.0;
    final lat0Rad = origin.latitude * math.pi / 180.0;

    final lat = origin.latitude + (northM / earthRadiusM) * 180.0 / math.pi;
    final cosLat = math.max(0.000001, math.cos(lat0Rad).abs());
    final lon =
        origin.longitude + (eastM / (earthRadiusM * cosLat)) * 180.0 / math.pi;

    return LatLng(lat, lon);
  }

  LatLng? _offsetFromPdDaz({
    required LatLng? pdLatLng,
    required double? distanceM,
    required double? azimutMil,
  }) {
    if (pdLatLng == null || distanceM == null || azimutMil == null) return null;
    if (!distanceM.isFinite || !azimutMil.isFinite) return null;

    final azRad = azimutMil * 2.0 * math.pi / 6400.0;
    final northM = distanceM * math.cos(azRad);
    final eastM = distanceM * math.sin(azRad);
    return _offsetLatLng(origin: pdLatLng, eastM: eastM, northM: northM);
  }

  List<LatLng> _uniqueLatLng(List<LatLng> points) {
    const eps = 1e-7;
    final out = <LatLng>[];
    for (final p in points) {
      final exists = out.any((e) =>
          (e.latitude - p.latitude).abs() <= eps &&
          (e.longitude - p.longitude).abs() <= eps);
      if (!exists) out.add(p);
    }
    return out;
  }

  List<LatLng> _sortAlongPrincipalAxis(List<LatLng> points) {
    if (points.length <= 2) return List<LatLng>.from(points);

    final meanLat =
        points.map((e) => e.latitude).reduce((a, b) => a + b) / points.length;
    final cosLat = math.max(0.01, math.cos(meanLat * math.pi / 180.0).abs());

    final xy = <({LatLng p, double x, double y})>[];
    for (final p in points) {
      xy.add((
        p: p,
        x: p.longitude * cosLat,
        y: p.latitude,
      ));
    }

    final meanX = xy.map((e) => e.x).reduce((a, b) => a + b) / xy.length;
    final meanY = xy.map((e) => e.y).reduce((a, b) => a + b) / xy.length;

    var covXX = 0.0;
    var covYY = 0.0;
    var covXY = 0.0;
    for (final e in xy) {
      final dx = e.x - meanX;
      final dy = e.y - meanY;
      covXX += dx * dx;
      covYY += dy * dy;
      covXY += dx * dy;
    }

    final theta = 0.5 * math.atan2(2.0 * covXY, covXX - covYY);
    final ux = math.cos(theta);
    final uy = math.sin(theta);

    xy.sort((a, b) {
      final pa = a.x * ux + a.y * uy;
      final pb = b.x * ux + b.y * uy;
      return pa.compareTo(pb);
    });

    return [for (final e in xy) e.p];
  }

  List<LatLng> _convexHull(List<LatLng> points) {
    if (points.length <= 3) return List<LatLng>.from(points);

    final meanLat =
        points.map((e) => e.latitude).reduce((a, b) => a + b) / points.length;
    final cosLat = math.max(0.01, math.cos(meanLat * math.pi / 180.0).abs());

    final pts = [
      for (final p in points)
        (
          p: p,
          x: p.longitude * cosLat,
          y: p.latitude,
        )
    ]..sort((a, b) {
        final c = a.x.compareTo(b.x);
        return c != 0 ? c : a.y.compareTo(b.y);
      });

    double cross(dynamic o, dynamic a, dynamic b) =>
        (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

    final lower = <dynamic>[];
    for (final p in pts) {
      while (lower.length >= 2 &&
          cross(lower[lower.length - 2], lower[lower.length - 1], p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }

    final upper = <dynamic>[];
    for (final p in pts.reversed) {
      while (upper.length >= 2 &&
          cross(upper[upper.length - 2], upper[upper.length - 1], p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }

    final hull = <LatLng>[];
    for (final e in [
      ...lower.take(lower.length - 1),
      ...upper.take(upper.length - 1)
    ]) {
      hull.add(e.p as LatLng);
    }
    return _uniqueLatLng(hull);
  }

  bool _isMostlyLinear(List<LatLng> points) {
    if (points.length <= 2) return true;

    final meanLat =
        points.map((e) => e.latitude).reduce((a, b) => a + b) / points.length;
    final cosLat = math.max(0.01, math.cos(meanLat * math.pi / 180.0).abs());

    final xs = [for (final p in points) p.longitude * cosLat];
    final ys = [for (final p in points) p.latitude];

    final meanX = xs.reduce((a, b) => a + b) / xs.length;
    final meanY = ys.reduce((a, b) => a + b) / ys.length;

    var covXX = 0.0;
    var covYY = 0.0;
    var covXY = 0.0;
    for (var i = 0; i < points.length; i++) {
      final dx = xs[i] - meanX;
      final dy = ys[i] - meanY;
      covXX += dx * dx;
      covYY += dy * dy;
      covXY += dx * dy;
    }

    final tr = covXX + covYY;
    final det = covXX * covYY - covXY * covXY;
    final disc = math.max(0.0, tr * tr - 4.0 * det);
    final lambda1 = (tr + math.sqrt(disc)) / 2.0;
    final lambda2 = (tr - math.sqrt(disc)) / 2.0;

    if (lambda1 <= 1e-12) return true;
    final ratio = lambda2 / lambda1;
    return ratio <= 0.04;
  }

  ({List<LatLng> points, bool closed}) _buildTargetGeometry({
    required FireRequest request,
    required TirCompletOutput output,
    required String? utmZoneFallback,
  }) {
    final zone = request.piece.utmZone ?? utmZoneFallback;

    // Pour un zonal, la carte du CR doit représenter les objectifs qui ont
    // réellement été utilisés par chaque calcul de coup. Les coordonnées
    // finales sont celles de output.shots (objX/objY).
    //
    // Le FirePlan peut conserver une géométrie préparatoire / hardcodée dont
    // les positions ne reflètent pas nécessairement la normalisation doctrinale
    // finalement affectée aux pièces (par ex. rangée centrale resserrée).
    final rawPoints = <LatLng>[];

    if (output.firePlan.kind.isZonal && output.shots.isNotEmpty) {
      // CR ZONAL : un élément de targetGeometry = un COUP réel.
      //
      // On groupe explicitement les coups par numéro de salve, tout en
      // conservant leur ordre d'origine à l'intérieur de chaque salve.
      // Surtout : aucun dédoublonnage spatial ici. Deux coups restent deux
      // coups même si leurs coordonnées sont identiques ou très proches.
      final orderedShots = <({int index, TirLineaireShot shot})>[
        for (var i = 0; i < output.shots.length; i++)
          (index: i, shot: output.shots[i]),
      ]..sort((a, b) {
          final sa = a.shot.numeroSalve ?? 999999;
          final sb = b.shot.numeroSalve ?? 999999;
          final bySalve = sa.compareTo(sb);
          if (bySalve != 0) return bySalve;
          return a.index.compareTo(b.index);
        });

      for (final item in orderedShots) {
        final shot = item.shot;
        final p = _safeUtmToLatLng(shot.objX, shot.objY, zone);
        if (p != null) rawPoints.add(p);
      }

      if (rawPoints.isNotEmpty) {
        return (
          points: rawPoints,
          closed: true,
        );
      }
    } else {
      // Pour les autres plans, conserver le FirePlan comme source prioritaire.
      for (final target in output.firePlan.allTargets) {
        final p = _safeUtmToLatLng(target.x, target.y, zone);
        if (p != null) rawPoints.add(p);
      }

      // Compatibilité avec les anciens outputs.
      if (rawPoints.isEmpty) {
        for (final shot in output.shots) {
          final p = _safeUtmToLatLng(shot.objX, shot.objY, zone);
          if (p != null) rawPoints.add(p);
        }
      }
    }

    if (rawPoints.isEmpty) {
      final obj = _resolveObjectifLatLng(request, output, utmZoneFallback);
      return (
        points: obj == null ? const <LatLng>[] : <LatLng>[obj],
        closed: false,
      );
    }

    final unique = _uniqueLatLng(rawPoints);
    if (unique.length <= 1) {
      return (points: unique, closed: false);
    }

    // Le type de plan est l'information la plus fiable.
    if (output.firePlan.kind.isLineaire) {
      return (
        points: _sortAlongPrincipalAxis(unique),
        closed: false,
      );
    }

    if (output.firePlan.kind.isZonal) {
      // IMPORTANT : conserver TOUS les objectifs zonaux pour que la carte
      // puisse afficher chaque impact calculé. Le contour visuel est construit
      // séparément dans MessageMapReportView à partir de l'enveloppe convexe.
      return (
        points: unique,
        closed: true,
      );
    }

    // Repli de compatibilité pour d'anciens FirePlanKind.
    if (_isMostlyLinear(unique)) {
      return (
        points: _sortAlongPrincipalAxis(unique),
        closed: false,
      );
    }

    return (
      points: _convexHull(unique),
      closed: true,
    );
  }

  ({
    List<String> salveLabels,
    List<String> pieceIds,
  }) _buildTargetDisplayData({
    required FireRequest request,
    required TirCompletOutput output,
    required List<LatLng> targetGeometry,
    required String? utmZoneFallback,
  }) {
    if (targetGeometry.isEmpty || output.shots.isEmpty) {
      return (
        salveLabels: const <String>[],
        pieceIds: const <String>[],
      );
    }

    final zone = request.piece.utmZone ?? utmZoneFallback;

    // Même ordre strict que _buildTargetGeometry pour le zonal :
    // Salve 1, puis Salve 2, etc. Les métadonnées restent ainsi alignées
    // 1 pour 1 avec les centres d'impact, sans rematching géographique.
    if (output.firePlan.kind.isZonal) {
      final orderedShots = <({int index, TirLineaireShot shot})>[
        for (var i = 0; i < output.shots.length; i++)
          (index: i, shot: output.shots[i]),
      ]..sort((a, b) {
          final sa = a.shot.numeroSalve ?? 999999;
          final sb = b.shot.numeroSalve ?? 999999;
          final bySalve = sa.compareTo(sb);
          if (bySalve != 0) return bySalve;
          return a.index.compareTo(b.index);
        });

      final salveLabels = <String>[];
      final pieceIds = <String>[];

      for (final item in orderedShots) {
        final shot = item.shot;
        final p = _safeUtmToLatLng(shot.objX, shot.objY, zone);
        if (p == null) continue;

        salveLabels.add(
          shot.numeroSalve == null ? '' : '${shot.numeroSalve}',
        );
        pieceIds.add(shot.nomPiece.trim().toUpperCase());
      }

      return (
        salveLabels: salveLabels,
        pieceIds: pieceIds,
      );
    }

    final candidates = <({
      LatLng point,
      String pieceId,
      int? numeroSalve,
    })>[];

    for (final shot in output.shots) {
      final p = _safeUtmToLatLng(shot.objX, shot.objY, zone);
      if (p == null) continue;

      candidates.add((
        point: p,
        pieceId: shot.nomPiece.trim().toUpperCase(),
        numeroSalve: shot.numeroSalve,
      ));
    }

    if (candidates.isEmpty) {
      return (
        salveLabels: const <String>[],
        pieceIds: const <String>[],
      );
    }

    final remaining = List.of(candidates);
    final salveLabels = <String>[];
    final pieceIds = <String>[];

    double d2(LatLng a, LatLng b) {
      final latScale = math.cos(
        ((a.latitude + b.latitude) / 2.0) * math.pi / 180.0,
      );
      final dx = (a.longitude - b.longitude) * latScale;
      final dy = a.latitude - b.latitude;
      return dx * dx + dy * dy;
    }

    for (final target in targetGeometry) {
      if (remaining.isEmpty) {
        salveLabels.add('');
        pieceIds.add('');
        continue;
      }

      var bestIndex = 0;
      var best = d2(target, remaining.first.point);
      for (var i = 1; i < remaining.length; i++) {
        final current = d2(target, remaining[i].point);
        if (current < best) {
          best = current;
          bestIndex = i;
        }
      }

      final matched = remaining.removeAt(bestIndex);
      pieceIds.add(matched.pieceId);

      // Ne jamais reconstruire le numéro depuis l'ordre des points :
      // on affiche uniquement la vraie salve portée par TirLineaireShot.
      final numero = matched.numeroSalve;
      salveLabels.add(numero == null ? '' : '$numero');
    }

    return (
      salveLabels: salveLabels,
      pieceIds: pieceIds,
    );
  }

  MessagePieceResultData _pieceResultData(
    String label,
    CalculResult? result, {
    double? offsetM,
  }) {
    final charge = result == null || result.charge.trim().isEmpty
        ? null
        : result.charge.trim().toUpperCase();

    return MessagePieceResultData(
      label: label,
      noire: result == null
          ? null
          : _formatDouble(result.noireMil, digits: 1, unit: 'mil'),
      aqe: result == null
          ? null
          : _formatDouble(result.aqeMil, digits: 1, unit: 'mil'),
      charge: charge,
      temps: result == null
          ? null
          : _formatDouble(result.tempsVolS, digits: 2, unit: 's'),
      offsetM: offsetM,
    );
  }

  List<MessagePieceResultData> _buildPieceResults({
    required TirCompletOutput output,
  }) {
    MessagePieceResultData fromResult({
      required String label,
      required CalculResult result,
      required double offsetM,
      int? numeroSalve,
    }) {
      final charge = result.charge.trim().isEmpty
          ? null
          : result.charge.trim().toUpperCase();

      return MessagePieceResultData(
        label: label,
        noire: _formatDouble(result.noireMil, digits: 1, unit: 'mil'),
        aqe: _formatDouble(result.aqeMil, digits: 1, unit: 'mil'),
        charge: charge,
        temps: _formatDouble(result.tempsVolS, digits: 2, unit: 's'),
        offsetM: offsetM,
        numeroSalve: numeroSalve,
      );
    }

    // ZONAL : le CR doit restituer UN résultat PAR COUP.
    // Une Map indexée par nom de pièce écrasait jusqu'ici la salve 1 par la
    // salve 2 (ou inversement) et ramenait 14 coups à 8 pièces uniques.
    if (output.firePlan.kind.isZonal && output.shots.isNotEmpty) {
      final orderedShots = <({int index, TirLineaireShot shot})>[
        for (var i = 0; i < output.shots.length; i++)
          (index: i, shot: output.shots[i]),
      ]..sort((a, b) {
          final sa = a.shot.numeroSalve ?? 999999;
          final sb = b.shot.numeroSalve ?? 999999;
          final bySalve = sa.compareTo(sb);
          if (bySalve != 0) return bySalve;
          return a.index.compareTo(b.index);
        });

      return [
        for (final item in orderedShots)
          if (item.shot.nomPiece.trim().isNotEmpty)
            fromResult(
              label: item.shot.nomPiece.trim().toUpperCase(),
              result: item.shot.resultat,
              offsetM: item.shot.offsetM,
              numeroSalve: item.shot.numeroSalve,
            ),
      ];
    }

    // Compatibilité ponctuel / linéaire : restitution historique par pièce.
    final byPiece = <String, MessagePieceResultData>{};

    for (final shot in output.shots) {
      final label = shot.nomPiece.trim().toUpperCase();
      if (label.isEmpty) continue;

      byPiece[label] = fromResult(
        label: label,
        result: shot.resultat,
        offsetM: shot.offsetM,
        numeroSalve: shot.numeroSalve,
      );
    }

    for (final ps in output.psOutputs) {
      final label = ps.nom.trim().toUpperCase();
      if (label.isEmpty) continue;

      byPiece[label] = fromResult(
        label: label,
        result: ps.resultat,
        offsetM: ps.offsetM,
      );
    }

    final pdResult = output.resultatPdAffecte ?? output.resultatPrincipal;
    if (!byPiece.containsKey('PD') && pdResult != null) {
      byPiece['PD'] = fromResult(
        label: 'PD',
        result: pdResult,
        offsetM: output.pdOffsetM,
      );
    }

    final ordered = <MessagePieceResultData>[];

    final pd = byPiece.remove('PD');
    if (pd != null) ordered.add(pd);

    final others = byPiece.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    ordered.addAll(others);
    return ordered;
  }

  List<LatLng> _ellipsePoints({
    required LatLng center,
    required double frontM,
    required double rearM,
    required double semiLatM,
    required double azimutTirMil,
    int steps = 72,
  }) {
    final azTirRad = azimutTirMil * 2 * math.pi / 6400.0;
    final points = <LatLng>[];

    for (var i = 0; i <= steps; i++) {
      final angle = (i / steps) * 2 * math.pi;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      final rLong = cosA >= 0 ? frontM : rearM;
      final dForward = rLong * cosA;
      final dLateral = semiLatM * sinA;
      final dNorth =
          dForward * math.cos(azTirRad) - dLateral * math.sin(azTirRad);
      final dEast =
          dForward * math.sin(azTirRad) + dLateral * math.cos(azTirRad);

      const earthR = 6371000.0;
      final dLat = dNorth / earthR * (180.0 / math.pi);
      final dLon = dEast /
          (earthR * math.cos(center.latitude * math.pi / 180.0)) *
          (180.0 / math.pi);

      points.add(LatLng(center.latitude + dLat, center.longitude + dLon));
    }

    return points;
  }

  List<LatLng> _circlePoints({
    required LatLng center,
    required double radiusM,
    int steps = 72,
  }) {
    const earthR = 6371000.0;
    final points = <LatLng>[];

    for (var i = 0; i <= steps; i++) {
      final angle = (i / steps) * 2 * math.pi;
      final dNorth = radiusM * math.cos(angle);
      final dEast = radiusM * math.sin(angle);
      final dLat = dNorth / earthR * (180.0 / math.pi);
      final dLon = dEast /
          (earthR * math.cos(center.latitude * math.pi / 180.0)) *
          (180.0 / math.pi);
      points.add(LatLng(center.latitude + dLat, center.longitude + dLon));
    }

    return points;
  }

  ObusTirType _resolveObusType(FireRequest request, TirCompletOutput output) {
    final isRtc = request.fusee == TypeFusee.ralec ||
        (output.shots.isNotEmpty &&
            output.shots.first.resultat.typeAssets
                .toUpperCase()
                .contains('RTC'));
    return isRtc ? ObusTirType.ralec : ObusTirType.frappe;
  }

  bool _isEclairant(FireRequest request, CalculResult? result) {
    return request.typeTir == TypeTir.eclairant ||
        (result?.typeAssets.toUpperCase().contains('OECL') ?? false);
  }

  List<LatLng> _buildImpactPolygon({
    required LatLng center,
    required double azimutMil,
    required CoverageEllipse? coverage,
    required CalculResult? result,
    required double fallbackRadiusM,
  }) {
    final semiMajor = coverage?.semiMajorAxis ??
        math.max(result?.ecartProbablePorteeM ?? fallbackRadiusM, 30.0);
    final semiMinor = coverage?.semiMinorAxis ??
        math.max(
            result?.ecartProbableDirectionM ?? (fallbackRadiusM * 0.6), 20.0);

    return _ellipsePoints(
      center: center,
      frontM: semiMajor,
      rearM: semiMajor,
      semiLatM: semiMinor,
      azimutTirMil: azimutMil,
    );
  }

  List<LatLng> _buildRedPolygon({
    required LatLng center,
    required FireRequest request,
    required TirCompletOutput output,
    required CalculResult? result,
    required CoverageEllipse? coverage,
    double? azimutTirMil,
  }) {
    if (_isEclairant(request, result)) {
      return _circlePoints(center: center, radiusM: 300.0);
    }

    final angleChuteDeg = coverage?.angleChuteDeg ?? result?.angleChuteDeg;
    final residualVelocity = result?.vitesseRestanteMps;
    final redResult =
        RedService(type: _resolveObusType(request, output)).computeRed(
      residualVelocityMps: residualVelocity,
      angleChuteDeg: angleChuteDeg,
    );

    return _ellipsePoints(
      center: center,
      frontM: redResult.redFrontM,
      rearM: redResult.redRearM,
      semiLatM: redResult.redSemiLatM,
      azimutTirMil: azimutTirMil ?? output.firePlan.azimutMilOut,
    );
  }

  double? _impactFocusRadius({
    required CoverageEllipse? coverage,
    required CalculResult? result,
    required double fallbackRadiusM,
  }) {
    return coverage?.semiMajorAxis ??
        result?.ecartProbablePorteeM ??
        fallbackRadiusM;
  }

  /// Enveloppe RED du CR zonal, construite dans le même repère que la vue de
  /// répartition des coups : tous les impacts et toutes les ellipses RED sont
  /// orientés par le gisement unique du tir (`azimutMilOut`).
  ///
  /// Il ne faut pas orienter chaque ellipse avec le relèvement local
  /// pièce -> impact. Ces relèvements varient légèrement selon la position des
  /// pièces et déforment l'enveloppe convexe, alors que la carte doit afficher
  /// l'emprise globale dans l'axe de tir choisi par l'opérateur.
  List<LatLng> _buildZonalRedEnvelope({
    required FireRequest request,
    required TirCompletOutput output,
    required String? utmZoneFallback,
  }) {
    if (!output.firePlan.kind.isZonal || output.shots.isEmpty) {
      return const <LatLng>[];
    }

    final zone = request.piece.utmZone ?? utmZoneFallback;
    final firingAxisMil = output.firePlan.azimutMilOut;

    print(
      '[CR RED AXIS] '
      'azimutMilOut=${output.firePlan.azimutMilOut} '
      'largeur=${request.doctrine.zonal.azimutLargeurMil} '
      'profondeur=${request.doctrine.zonal.azimutProfondeurMil}',
    );

    final allRedPoints = <LatLng>[];

    for (final shot in output.shots) {
      final center = _safeUtmToLatLng(shot.objX, shot.objY, zone);
      if (center == null) continue;

      final poly = _buildRedPolygon(
        center: center,
        request: request,
        output: output,
        result: shot.resultat,
        coverage: shot.coverageEllipse,
        azimutTirMil: firingAxisMil,
      );

      allRedPoints.addAll(poly);
    }

    if (allRedPoints.length < 3) return allRedPoints;
    return _buildAxisAlignedRedEnvelopeEllipse(
      points: allRedPoints,
      azimutTirMil: firingAxisMil,
    );
  }

  /// Construit UNE enveloppe RED elliptique globale dans le repère de tir.
  ///
  /// Les RED individuelles sont déjà calculées par [RedService] et orientées
  /// selon le même axe de tir. On ne recalcule aucun critère RED ici :
  /// on cherche seulement une ellipse lisse, alignée sur cet axe, qui englobe
  /// tous les points des ellipses individuelles.
  ///
  /// La première ellipse est définie par les demi-emprises avant/latérale,
  /// puis elle est dilatée homothétiquement juste assez pour contenir chaque
  /// point échantillonné. On évite ainsi le rectangle / convex hull anguleux.
  List<LatLng> _buildAxisAlignedRedEnvelopeEllipse({
    required List<LatLng> points,
    required double azimutTirMil,
    int steps = 96,
  }) {
    if (points.length < 3 || !azimutTirMil.isFinite) {
      return _convexHull(points);
    }

    final origin = LatLng(
      points.fold<double>(0.0, (sum, point) => sum + point.latitude) /
          points.length,
      points.fold<double>(0.0, (sum, point) => sum + point.longitude) /
          points.length,
    );

    final azimutRad = azimutTirMil * 2.0 * math.pi / 6400.0;
    final forwardNorth = math.cos(azimutRad);
    final forwardEast = math.sin(azimutRad);
    final lateralNorth = -math.sin(azimutRad);
    final lateralEast = math.cos(azimutRad);

    const earthRadiusM = 6378137.0;
    final cosLat = math.max(
      0.000001,
      math.cos(origin.latitude * math.pi / 180.0).abs(),
    );

    final local = <({double forward, double lateral})>[];
    var minForward = double.infinity;
    var maxForward = double.negativeInfinity;
    var minLateral = double.infinity;
    var maxLateral = double.negativeInfinity;

    for (final point in points) {
      final north =
          (point.latitude - origin.latitude) * math.pi / 180.0 * earthRadiusM;
      final east = (point.longitude - origin.longitude) *
          math.pi /
          180.0 *
          earthRadiusM *
          cosLat;

      final forward = north * forwardNorth + east * forwardEast;
      final lateral = north * lateralNorth + east * lateralEast;

      local.add((forward: forward, lateral: lateral));
      minForward = math.min(minForward, forward);
      maxForward = math.max(maxForward, forward);
      minLateral = math.min(minLateral, lateral);
      maxLateral = math.max(maxLateral, lateral);
    }

    final centerForward = (minForward + maxForward) / 2.0;
    final centerLateral = (minLateral + maxLateral) / 2.0;

    var semiForward = math.max(1.0, (maxForward - minForward) / 2.0);
    var semiLateral = math.max(1.0, (maxLateral - minLateral) / 2.0);

    // DOCTRINE CR RED :
    // le grand axe doit rester porté par l'AXE DE TIR.
    //
    // Si l'emprise brute est momentanément plus large latéralement (ce qui peut
    // arriver avec un zonal large + plusieurs RED individuelles), on ne laisse
    // pas l'ellipse basculer visuellement de 90°. On augmente d'abord le
    // demi-axe longitudinal pour qu'il reste au moins égal au demi-axe latéral.
    if (semiForward < semiLateral) {
      semiForward = semiLateral;
    }

    // Une ellipse construite uniquement sur la bounding-box peut laisser
    // sortir un point situé près d'un "coin". On mesure donc le rayon
    // elliptique maximal et on dilate les deux demi-axes du même facteur.
    var maxNormalizedRadius = 1.0;
    for (final p in local) {
      final u = (p.forward - centerForward) / semiForward;
      final v = (p.lateral - centerLateral) / semiLateral;
      maxNormalizedRadius =
          math.max(maxNormalizedRadius, math.sqrt(u * u + v * v));
    }

    // Petite marge numérique pour que le contour ne tangente pas les points.
    final scale = maxNormalizedRadius * 1.01;
    semiForward *= scale;
    semiLateral *= scale;

    // Après dilatation homothétique, conserver explicitement l'axe de tir comme
    // grand axe. Cette garde est normalement redondante mais documente la règle.
    if (semiForward < semiLateral) {
      semiForward = semiLateral;
    }

    LatLng fromLocal(double forward, double lateral) {
      final north = forward * forwardNorth + lateral * lateralNorth;
      final east = forward * forwardEast + lateral * lateralEast;
      return LatLng(
        origin.latitude + north / earthRadiusM * 180.0 / math.pi,
        origin.longitude + east / (earthRadiusM * cosLat) * 180.0 / math.pi,
      );
    }

    return <LatLng>[
      for (var i = 0; i <= steps; i++)
        (() {
          final angle = 2.0 * math.pi * i / steps;
          return fromLocal(
            centerForward + semiForward * math.cos(angle),
            centerLateral + semiLateral * math.sin(angle),
          );
        })(),
    ];
  }

  double? _redFocusRadius({
    required FireRequest request,
    required TirCompletOutput output,
    required CalculResult? result,
    required CoverageEllipse? coverage,
  }) {
    if (_isEclairant(request, result)) {
      return 300.0;
    }

    final angleChuteDeg = coverage?.angleChuteDeg ?? result?.angleChuteDeg;
    final residualVelocity = result?.vitesseRestanteMps;
    final redResult =
        RedService(type: _resolveObusType(request, output)).computeRed(
      residualVelocityMps: residualVelocity,
      angleChuteDeg: angleChuteDeg,
    );
    return redResult.redSemiLongM;
  }

  List<MessageBatteryPieceData> _buildBatteryPieces({
    required FireRequest request,
    required TirCompletOutput output,
    required String? utmZoneFallback,
  }) {
    if (request.supportPieces.isEmpty) {
      return const <MessageBatteryPieceData>[];
    }

    final zone = request.piece.utmZone ?? utmZoneFallback;
    final pdAltitude = request.piece.altitude;
    final pdLatLng = _resolvePieceLatLng(request, utmZoneFallback);

    final outputById = <String, PieceSoutienOutput>{
      for (final ps in output.psOutputs) ps.nom.trim().toUpperCase(): ps,
    };

    // Le FirePlan contient l'implantation exacte de toutes les pièces retenues.
    final planPieceById = <String, PieceGeom>{
      for (final piece in output.firePlan.pieces)
        piece.id.trim().toUpperCase(): piece,
    };

    final pieces = <MessageBatteryPieceData>[];

    for (final ps in request.supportPieces) {
      final key = ps.pieceId.trim().toUpperCase();
      final psOut = outputById[key];
      final planPiece = planPieceById[key];

      final absoluteZ = planPiece?.z ?? ps.zPS ?? psOut?.zPS;

      final double? deltaZPd = absoluteZ != null &&
              absoluteZ.isFinite &&
              pdAltitude != null &&
              pdAltitude.isFinite
          ? absoluteZ - pdAltitude
          : ps.deltaZPd;

      // Ordre de confiance :
      // 1. géométrie exacte du plan utilisé ;
      // 2. sortie PS ;
      // 3. reconstruction d'affichage D/Az depuis la PD.
      final latLng = _safeUtmToLatLng(planPiece?.x, planPiece?.y, zone) ??
          _safeUtmToLatLng(psOut?.xPS, psOut?.yPS, zone) ??
          _offsetFromPdDaz(
            pdLatLng: pdLatLng,
            distanceM: ps.distanceM,
            azimutMil: ps.azimutMil,
          );

      pieces.add(
        MessageBatteryPieceData(
          label: ps.pieceId,
          latLng: latLng,
          distanceFromPdM: ps.distanceM,
          azimutFromPdMil: ps.azimutMil,
          deltaZFromPdM: deltaZPd,
        ),
      );
    }

    pieces.sort((a, b) {
      int rank(String label) {
        final up = label.trim().toUpperCase();
        final m = RegExp(r'^PS(\d+)$').firstMatch(up);
        if (m != null) return int.tryParse(m.group(1)!) ?? 999;
        return 999;
      }

      final ra = rank(a.label);
      final rb = rank(b.label);
      if (ra != rb) return ra.compareTo(rb);
      return a.label.compareTo(b.label);
    });

    return pieces;
  }

  MessagePdData collect({
    required FireRequest request,
    required TirCompletOutput output,
    String? utmZoneFallback,
    double? diametreEfficaciteM,
  }) {
    final result = output.resultatPdAffecte ?? output.resultatPrincipal;
    final coverage =
        output.shots.isNotEmpty ? output.shots.first.coverageEllipse : null;
    final fallbackRadiusM =
        (((diametreEfficaciteM ?? 100.0) / 2.0).clamp(20.0, 1000.0) as num)
            .toDouble();

    final pieceUtmDisponible =
        request.piece.utmX != null && request.piece.utmY != null;
    final pieceGeoDisponible =
        request.piece.latitude != null && request.piece.longitude != null;

    final objectifUtmDisponible =
        request.target.utmX != null && request.target.utmY != null;
    final objectifGeoDisponible =
        request.target.latitude != null && request.target.longitude != null;
    final objectifDazDisponible =
        request.target.distanceM != null && request.target.azimutMil != null;
    final objectifCalculeDisponible = output.shots.isNotEmpty ||
        (output.pdObjX.isFinite && output.pdObjY.isFinite);

    final pieceDirectriceDisponible = pieceUtmDisponible || pieceGeoDisponible;
    final objectifDisponible = objectifUtmDisponible ||
        objectifGeoDisponible ||
        objectifDazDisponible ||
        objectifCalculeDisponible;

    final pieceLatLng = _resolvePieceLatLng(request, utmZoneFallback);
    final objectifLatLng =
        _resolveObjectifLatLng(request, output, utmZoneFallback);
    final impactLatLng = _resolveImpactLatLng(request, output, utmZoneFallback);

    final carteDisponible = pieceLatLng != null && objectifLatLng != null;

    // Les "éléments du calcul principal" du CR décrivent le point central
    // demandé, pas l'OPD/OS affecté après répartition.
    final referenceDistanceM = request.target.distanceM;
    final referenceAzimutMil = request.target.azimutMil;
    final referenceDeniveleeM =
        (request.target.altitude != null && request.piece.altitude != null)
            ? request.target.altitude! - request.piece.altitude!
            : null;

    final distance = referenceDistanceM != null && referenceDistanceM.isFinite
        ? _formatDouble(referenceDistanceM, digits: 0, unit: 'm')
        : (result == null
            ? null
            : _formatDouble(result.distanceTopoM, digits: 0, unit: 'm'));

    final azimut = referenceAzimutMil != null && referenceAzimutMil.isFinite
        ? _formatDouble(referenceAzimutMil, digits: 1, unit: 'mil')
        : (result == null
            ? null
            : _formatDouble(result.azimutMil, digits: 1, unit: 'mil'));

    final denivelee =
        referenceDeniveleeM != null && referenceDeniveleeM.isFinite
            ? _formatSignedDouble(referenceDeniveleeM, digits: 0, unit: 'm')
            : (result == null
                ? null
                : _formatSignedDouble(result.deniveleeM, digits: 0, unit: 'm'));

    final noire = result == null
        ? null
        : _formatDouble(result.noireMil, digits: 1, unit: 'mil');

    final aqe = result == null
        ? null
        : _formatDouble(result.aqeMil, digits: 1, unit: 'mil');

    final charge = (result == null || result.charge.trim().isEmpty)
        ? null
        : result.charge.trim().toUpperCase();

    final temps = result == null
        ? null
        : _formatDouble(result.tempsVolS, digits: 2, unit: 's');

    final munition = request.typeMunition == null
        ? null
        : _munitionLabel(request.typeMunition!);

    final chargeOperateur = request.forcerCharge
        ? (request.chargeForceeStr != null &&
                request.chargeForceeStr!.trim().isNotEmpty
            ? request.chargeForceeStr!.trim().toUpperCase()
            : (request.chargeForcee == null
                ? 'forcée'
                : 'CH${request.chargeForcee}'))
        : null;

    final masse = request.masseEnabled
        ? '${request.carreaux} carreau${request.carreaux == 1 ? '' : 'x'}'
        : null;

    final tirSimilaire = _formatTirSimilaire(request);
    final meteo = _formatMeteoUsed(request: request, result: result);

    final batteryPieces = _buildBatteryPieces(
      request: request,
      output: output,
      utmZoneFallback: utmZoneFallback,
    );

    final targetGeometryData = _buildTargetGeometry(
      request: request,
      output: output,
      utmZoneFallback: utmZoneFallback,
    );

    final targetDisplayData = _buildTargetDisplayData(
      request: request,
      output: output,
      targetGeometry: targetGeometryData.points,
      utmZoneFallback: utmZoneFallback,
    );

    final pieceResults = _buildPieceResults(output: output);

    final impactPolygon = (impactLatLng != null)
        ? _buildImpactPolygon(
            center: impactLatLng,
            azimutMil: output.firePlan.azimutMilOut,
            coverage: coverage,
            result: result,
            fallbackRadiusM: fallbackRadiusM,
          )
        : const <LatLng>[];

    final zonalRedEnvelope = _buildZonalRedEnvelope(
      request: request,
      output: output,
      utmZoneFallback: utmZoneFallback,
    );

    final redPolygon = zonalRedEnvelope.isNotEmpty
        ? zonalRedEnvelope
        : (impactLatLng != null)
            ? _buildRedPolygon(
                center: impactLatLng,
                request: request,
                output: output,
                result: result,
                coverage: coverage,
              )
            : const <LatLng>[];

    // Axes zonaux exacts issus de la saisie/doctrine.
    // Aucun axe ne doit être redéduit du nuage de points dans le CR.
    final double? zonalAzimutProfondeurMil = output.firePlan.kind.isZonal
        ? (request.doctrine.zonal.azimutProfondeurMil ??
            output.firePlan.azimutMilOut)
        : null;

    final double? zonalAzimutLargeurMil = output.firePlan.kind.isZonal
        ? (request.doctrine.zonal.azimutLargeurMil ??
            ((zonalAzimutProfondeurMil! + 1600.0) % 6400.0))
        : null;

    // Dimensions nominales du zonal : transport direct depuis la requête
    // construite à partir de la saisie. Aucune mesure sur targetGeometry.
    final double? zonalLargeurM =
        output.firePlan.kind.isZonal ? request.doctrine.zonal.longueurM : null;
    final double? zonalProfondeurM = output.firePlan.kind.isZonal
        ? request.doctrine.zonal.profondeurM
        : null;
    final double? zonalDebordementPct = output.firePlan.kind.isZonal
        ? request.doctrine.zonal.debordementPct
        : null;

    return MessagePdData(
      pieceDirectriceDisponible: pieceDirectriceDisponible,
      objectifDisponible: objectifDisponible,
      carteDisponible: carteDisponible,
      distanceDisponible: distance != null,
      azimutDisponible: azimut != null,
      deniveleeDisponible: denivelee != null,
      noireDisponible: noire != null,
      aqeDisponible: aqe != null,
      chargeDisponible: charge != null,
      tempsDisponible: temps != null,
      distance: distance,
      azimut: azimut,
      denivelee: denivelee,
      noire: noire,
      aqe: aqe,
      charge: charge,
      temps: temps,
      systeme: _systemeLabel(request.systeme),
      typeTir: _typeTirLabel(request.typeTir),
      munition: munition,
      fusee: request.fusee == null ? '—' : _fuseeLabel(request.fusee!),
      chargeOperateur: chargeOperateur,
      masse: masse,
      tirSimilaire: tirSimilaire,
      meteo: meteo,
      piecePosition: _piecePositionText(request),
      objectifPosition: _objectifPositionText(request, output, utmZoneFallback),
      pieceLatLng: pieceLatLng,
      objectifLatLng: objectifLatLng,
      impactLatLng: impactLatLng,
      impactPolygon: impactPolygon,
      redPolygon: redPolygon,
      impactFocusRadiusM: _impactFocusRadius(
        coverage: coverage,
        result: result,
        fallbackRadiusM: fallbackRadiusM,
      ),
      redFocusRadiusM: _redFocusRadius(
        request: request,
        output: output,
        result: result,
        coverage: coverage,
      ),
      batteryPieces: batteryPieces,
      targetGeometry: targetGeometryData.points,
      targetGeometryClosed: targetGeometryData.closed,
      targetLabels: targetDisplayData.salveLabels,
      targetPieceIds: targetDisplayData.pieceIds,
      pieceResults: pieceResults,
      zonalAzimutLargeurMil: zonalAzimutLargeurMil,
      zonalAzimutProfondeurMil: zonalAzimutProfondeurMil,
      zonalLargeurM: zonalLargeurM,
      zonalProfondeurM: zonalProfondeurM,
      zonalDebordementPct: zonalDebordementPct,
    );
  }
}
