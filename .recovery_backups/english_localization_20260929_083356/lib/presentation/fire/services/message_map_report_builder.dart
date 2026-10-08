// lib/presentation/fire/services/message_map_report_builder.dart

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'package:calculateur_etranger/presentation/fire/models/message_map_report_models.dart';

class MessageMapReportBuilder {
  const MessageMapReportBuilder();

  MessageMapReportBundle build({
    required LatLng pdLatLng,
    required LatLng objLatLng,
    LatLng? impactLatLng,
    double? focusRadiusM,

    /// Pièces secondaires à afficher sur la carte d'implantation.
    ///
    /// La PD est ajoutée automatiquement à partir de [pdLatLng].
    List<MessageBatteryMapPoint> batteryPieces =
        const <MessageBatteryMapPoint>[],

    /// Géométrie déjà issue du dernier plan de tir.
    List<LatLng> targetGeometry = const <LatLng>[],

    /// Axe zonal largeur exact, en mil, déjà utilisé par le calcul.
    double? zonalAzimutLargeurMil,

    /// Axe zonal profondeur exact, en mil, déjà utilisé par le calcul.
    /// C'est l'axe de référence du cartouche zonal ; aucune PCA n'est utilisée
    /// lorsqu'il est disponible.
    double? zonalAzimutProfondeurMil,

    /// Contour réel de la zone d'impact déjà calculée.
    List<LatLng> impactGeometry = const <LatLng>[],

    /// Contour réel de la RED déjà calculée.
    List<LatLng> redGeometry = const <LatLng>[],
  }) {
    final impact = impactLatLng ?? objLatLng;
    final distanceM = const Distance().as(
      LengthUnit.Meter,
      pdLatLng,
      objLatLng,
    );

    final center = LatLng(
      (pdLatLng.latitude + objLatLng.latitude) / 2.0,
      (pdLatLng.longitude + objLatLng.longitude) / 2.0,
    );

    final radius =
        (focusRadiusM != null && focusRadiusM > 0) ? focusRadiusM : 300.0;

    final impactFrameGeometry = <LatLng>[
      ...targetGeometry,
      ...impactGeometry,
    ];

    final redFrameGeometry = <LatLng>[
      ...targetGeometry,
      ...redGeometry,
    ];

    // Pour un linéaire de ~330 m, on vise volontairement un cartouche
    // d'environ 400 à 450 m afin d'obtenir une lecture comparable
    // à celle de l'implantation batterie.
    final impactLayout = _zoneLayoutForGeometry(
      fallbackCenter: impact,
      axisGeometry: targetGeometry,
      frameGeometry: impactFrameGeometry,
      preferredBearingDeg: zonalAzimutProfondeurMil == null
          ? null
          : zonalAzimutProfondeurMil * 360.0 / 6400.0,
      minimumDisplayedWidthM: 400.0,
      marginFactor: 1.18,
      minimumExtraMarginM: 50.0,
    );

    final redLayout = _zoneLayoutForGeometry(
      fallbackCenter: impact,
      axisGeometry: targetGeometry,
      frameGeometry: redFrameGeometry,
      preferredBearingDeg: zonalAzimutProfondeurMil == null
          ? null
          : zonalAzimutProfondeurMil * 360.0 / 6400.0,
      minimumDisplayedWidthM: 500.0,
      marginFactor: 1.16,
      minimumExtraMarginM: 100.0,
    );

    final normalizedBattery = <MessageBatteryMapPoint>[
      MessageBatteryMapPoint(
        label: 'PD',
        latLng: pdLatLng,
        isPd: true,
      ),
      for (final piece in batteryPieces)
        if (!piece.isPd && piece.label.trim().toUpperCase() != 'PD')
          MessageBatteryMapPoint(
            label: piece.label,
            latLng: piece.latLng,
          ),
    ];

    return MessageMapReportBundle(
      // Toujours fournir une carte d'implantation.
      // Si les pièces secondaires ne sont pas encore connues, la PD seule
      // constitue l'implantation minimale et reste visible sur le fond local.
      // Extrait 1 : implantation complète de la batterie.
      // PD + toutes les PS disponibles.
      batteryView: _buildBatteryDeploymentView(normalizedBattery),
      globalView: MessageMapViewConfig(
        kind: MessageMapViewKind.globalPdToObj,
        title: 'PD → objectif',
        center: center,
        zoom: math.max(11.0, _globalZoomFromDistance(distanceM)),
        pdLatLng: pdLatLng,
        objLatLng: objLatLng,
        impactLatLng: impact,
        showPd: true,
        showObj: true,
        showTrajectory: true,
        minZoom: 4,
        maxZoom: 17,
      ),
      impactView: MessageMapViewConfig(
        kind: MessageMapViewKind.impactZone,
        title: 'Objectif / zone traitée',
        center: impactLayout.center,
        zoom: impactLayout.zoom,
        // ZONAL : conserver la carte géographique Nord en haut.
        // Les points sont déjà aux coordonnées réelles du calcul ; on ne
        // tourne pas la carte pour "redresser" le nuage de points.
        rotationDeg: 0.0,
        scaleBarMeters: impactLayout.scaleBarMeters,
        pdLatLng: pdLatLng,
        objLatLng: objLatLng,
        impactLatLng: impact,
        showObj: true,
        showImpact: false,
        // Extrait 3 : afficher les centres et le repère circulaire
        // déjà fourni par le CR, sans modifier son rayon.
        showImpactZone: true,
        minZoom: 8,
        maxZoom: 18,
      ),
      redView: MessageMapViewConfig(
        kind: MessageMapViewKind.impactPlusRed,
        title: 'Zone RED / danger',
        center: redLayout.center,
        zoom: redLayout.zoom,

        // Restitution CR uniquement : la RED garde exactement sa géométrie,
        // mais utilise la même orientation d'écran que la carte d'impact.
        // Cela évite qu'une PCA indépendante fasse paraître la RED inversée
        // ou tournée différemment alors que les coordonnées n'ont pas changé.
        rotationDeg: 0.0,
        scaleBarMeters: redLayout.scaleBarMeters,
        pdLatLng: pdLatLng,
        objLatLng: objLatLng,
        impactLatLng: impact,
        // Extrait 4 : RED uniquement.
        // Aucun marqueur objectif ni empreinte impact dans ce cartouche.
        showObj: false,
        showImpact: false,
        showImpactZone: false,
        showRedZone: true,
        minZoom: 8,
        maxZoom: 18,
      ),
    );
  }

  MessageMapViewConfig _buildBatteryDeploymentView(
    List<MessageBatteryMapPoint> pieces,
  ) {
    final pd = pieces.firstWhere(
      (piece) => piece.isPd,
      orElse: () => pieces.first,
    );

    final local = <_LocalBatteryPoint>[
      for (final piece in pieces)
        _toLocalMeters(
          origin: pd.latLng,
          piece: piece,
        ),
    ];

    final bearingDeg = _principalAxisBearingDeg(local);
    final bearingRad = bearingDeg * math.pi / 180.0;

    final sinB = math.sin(bearingRad);
    final cosB = math.cos(bearingRad);

    var minAlong = double.infinity;
    var maxAlong = double.negativeInfinity;
    var minCross = double.infinity;
    var maxCross = double.negativeInfinity;

    for (final p in local) {
      // Repère orienté selon l'axe de batterie :
      // along = axe longitudinal, cross = axe transversal.
      final along = p.eastM * sinB + p.northM * cosB;
      final cross = p.eastM * cosB - p.northM * sinB;

      minAlong = math.min(minAlong, along);
      maxAlong = math.max(maxAlong, along);
      minCross = math.min(minCross, cross);
      maxCross = math.max(maxCross, cross);
    }

    final alongSpanM = math.max(1.0, maxAlong - minAlong);
    final crossSpanM = math.max(1.0, maxCross - minCross);

    final centerAlong = (minAlong + maxAlong) / 2.0;
    final centerCross = (minCross + maxCross) / 2.0;

    final centerEast = centerAlong * sinB + centerCross * cosB;
    final centerNorth = centerAlong * cosB - centerCross * sinB;

    final mapCenter = _offsetLatLng(
      origin: pd.latLng,
      eastM: centerEast,
      northM: centerNorth,
    );

    // Le cartouche est horizontal. Il faut cadrer non seulement les coordonnées
    // des pièces mais aussi les marqueurs + étiquettes. Une marge trop faible
    // coupe précisément les pièces placées aux deux extrémités de la batterie.
    //
    // On affiche environ 1,5 fois l'emprise longitudinale réelle, avec au moins
    // 150 m de marge totale. Pour une batterie de ~300 m, cela donne ~450 m.
    final widthFromAlong = math.max(
      alongSpanM * 1.50,
      alongSpanM + 150.0,
    );

    // La hauteur utile du cartouche est environ 2,4 fois plus petite que sa
    // largeur ; on garde une marge supplémentaire pour les libellés.
    final widthFromCross = math.max(
      crossSpanM * 3.0,
      crossSpanM + 120.0,
    );

    final displayedWidthM = math.max(widthFromAlong, widthFromCross);

    return MessageMapViewConfig(
      kind: MessageMapViewKind.batteryDeployment,
      title: 'Carte implantation batterie',
      center: mapCenter,
      zoom: _zoomForDisplayedWidth(
        widthM: displayedWidthM,
        latitudeDeg: mapCenter.latitude,
      ),
      batteryPoints: pieces,
      rotationDeg: 0.0,
      scaleBarMeters: _scaleBarForWidth(displayedWidthM),
      minZoom: 13,
      maxZoom: 18.5,
    );
  }

  _LocalBatteryPoint _toLocalMeters({
    required LatLng origin,
    required MessageBatteryMapPoint piece,
  }) {
    const earthRadiusM = 6378137.0;
    final lat0Rad = origin.latitude * math.pi / 180.0;

    final dLatRad = (piece.latLng.latitude - origin.latitude) * math.pi / 180.0;
    final dLonRad =
        (piece.latLng.longitude - origin.longitude) * math.pi / 180.0;

    return _LocalBatteryPoint(
      eastM: dLonRad * earthRadiusM * math.cos(lat0Rad),
      northM: dLatRad * earthRadiusM,
    );
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

  /// Axe principal de l'implantation, exprimé en degrés depuis le nord.
  ///
  /// Une PCA simple suffit ici : l'implantation reste de petite dimension
  /// géographique et l'objectif est uniquement de choisir l'orientation
  /// d'affichage la plus compacte.
  double _principalAxisBearingDeg(List<_LocalBatteryPoint> points) {
    if (points.length < 2) return 90.0;

    var meanE = 0.0;
    var meanN = 0.0;

    for (final p in points) {
      meanE += p.eastM;
      meanN += p.northM;
    }

    meanE /= points.length;
    meanN /= points.length;

    var covEE = 0.0;
    var covNN = 0.0;
    var covEN = 0.0;

    for (final p in points) {
      final de = p.eastM - meanE;
      final dn = p.northM - meanN;
      covEE += de * de;
      covNN += dn * dn;
      covEN += de * dn;
    }

    if ((covEE + covNN).abs() < 1e-6) return 90.0;

    // Angle de l'axe principal mesuré depuis l'Est.
    final thetaFromEast = 0.5 * math.atan2(2.0 * covEN, covEE - covNN);

    // Conversion en relèvement géographique : 0° = Nord, 90° = Est.
    var bearing = 90.0 - thetaFromEast * 180.0 / math.pi;

    // L'axe est non orienté : 10° et 190° décrivent la même implantation.
    while (bearing < 0.0) {
      bearing += 180.0;
    }
    while (bearing >= 180.0) {
      bearing -= 180.0;
    }

    return bearing;
  }

  /// Axe d'affichage du CR uniquement.
  ///
  /// Pour un nuage zonal 2D (ex. répartition 3-2-3), la PCA seule peut choisir
  /// une diagonale presque équivalente et donner visuellement l'impression d'un
  /// octogone régulier. On conserve les coordonnées exactes et on choisit
  /// seulement une orientation d'écran plus fidèle à la structure des rangées :
  /// les deux points les plus proches du centre définissent l'axe de la rangée
  /// centrale. Pour une géométrie quasi-linéaire, on garde la PCA historique.
  double _reportAxisBearingDeg(List<_LocalBatteryPoint> points) {
    if (points.length < 2) return 90.0;

    var meanE = 0.0;
    var meanN = 0.0;
    for (final p in points) {
      meanE += p.eastM;
      meanN += p.northM;
    }
    meanE /= points.length;
    meanN /= points.length;

    var covEE = 0.0;
    var covNN = 0.0;
    var covEN = 0.0;
    for (final p in points) {
      final de = p.eastM - meanE;
      final dn = p.northM - meanN;
      covEE += de * de;
      covNN += dn * dn;
      covEN += de * dn;
    }

    final trace = covEE + covNN;
    if (trace <= 1e-9) return 90.0;

    final delta = math.sqrt(
      math.max(0.0, (covEE - covNN) * (covEE - covNN) + 4.0 * covEN * covEN),
    );
    final lambdaMax = (trace + delta) / 2.0;
    final lambdaMin = (trace - delta) / 2.0;
    final isTwoDimensional =
        lambdaMax > 1e-9 && (lambdaMin / lambdaMax) >= 0.20;

    if (isTwoDimensional && points.length >= 5) {
      final ranked = List<_LocalBatteryPoint>.from(points)
        ..sort((a, b) {
          final da = (a.eastM - meanE) * (a.eastM - meanE) +
              (a.northM - meanN) * (a.northM - meanN);
          final db = (b.eastM - meanE) * (b.eastM - meanE) +
              (b.northM - meanN) * (b.northM - meanN);
          return da.compareTo(db);
        });

      final a = ranked[0];
      final b = ranked[1];
      final dE = b.eastM - a.eastM;
      final dN = b.northM - a.northM;

      if ((dE * dE + dN * dN) > 1.0) {
        var bearing = math.atan2(dE, dN) * 180.0 / math.pi;
        while (bearing < 0.0) {
          bearing += 180.0;
        }
        while (bearing >= 180.0) {
          bearing -= 180.0;
        }
        return bearing;
      }
    }

    return _principalAxisBearingDeg(points);
  }

  double _mapRotationForAxis(double bearingDeg) {
    // flutter_map : cette convention conserve l'axe principal de batterie
    // horizontal à l'écran.
    //
    // Exemple :
    // - axe Est-Ouest (90°) => 0°
    // - axe NE-SO (45°)     => +45°
    var rotation = 90.0 - bearingDeg;

    // L'axe est non orienté : on garde la rotation visuelle la plus courte.
    while (rotation > 90.0) {
      rotation -= 180.0;
    }
    while (rotation < -90.0) {
      rotation += 180.0;
    }

    return rotation;
  }

  double _zoomForDisplayedWidth({
    required double widthM,
    required double latitudeDeg,
  }) {
    // Largeur de référence du cartouche de CR. Le calcul donne un zoom initial
    // cohérent sur mobile, tablette et capture PDF ; la carte reste non interactive.
    const referenceWidthPx = 720.0;
    const webMercatorMetersPerPixelAtZoom0 = 156543.03392;

    final latitudeRad = latitudeDeg * math.pi / 180.0;
    final metersPerPixelAtZoom0 = webMercatorMetersPerPixelAtZoom0 *
        math.max(0.01, math.cos(latitudeRad).abs());

    final targetMetersPerPixel = math.max(1.0, widthM) / referenceWidthPx;

    final zoom = math.log(
          metersPerPixelAtZoom0 / targetMetersPerPixel,
        ) /
        math.ln2;

    return zoom.clamp(13.0, 18.5).toDouble();
  }

  double _scaleBarForWidth(double widthM) {
    if (widthM <= 300) return 50;
    if (widthM <= 700) return 100;
    if (widthM <= 1500) return 200;
    return 500;
  }

  ({
    LatLng center,
    double zoom,
    double rotationDeg,
    double scaleBarMeters,
  }) _zoneLayoutForGeometry({
    required LatLng fallbackCenter,
    required List<LatLng> axisGeometry,
    required List<LatLng> frameGeometry,
    double? preferredBearingDeg,
    required double minimumDisplayedWidthM,
    required double marginFactor,
    required double minimumExtraMarginM,
  }) {
    final geometry = frameGeometry.length >= 2 ? frameGeometry : axisGeometry;

    if (geometry.length < 2) {
      final displayedWidthM = minimumDisplayedWidthM;
      return (
        center: fallbackCenter,
        zoom: _zoomForDisplayedWidth(
          widthM: displayedWidthM,
          latitudeDeg: fallbackCenter.latitude,
        ),
        rotationDeg: 0.0,
        scaleBarMeters: _scaleBarForWidth(displayedWidthM),
      );
    }

    final origin = geometry.first;
    final local = <_LocalBatteryPoint>[
      for (var i = 0; i < geometry.length; i++)
        _toLocalMeters(
          origin: origin,
          piece: MessageBatteryMapPoint(
            label: 'G$i',
            latLng: geometry[i],
          ),
        ),
    ];

    final axisLocal = <_LocalBatteryPoint>[
      for (var i = 0; i < axisGeometry.length; i++)
        _toLocalMeters(
          origin: origin,
          piece: MessageBatteryMapPoint(
            label: 'A$i',
            latLng: axisGeometry[i],
          ),
        ),
    ];

    final bearingDeg = preferredBearingDeg ??
        (axisLocal.length >= 2
            ? _reportAxisBearingDeg(axisLocal)
            : _reportAxisBearingDeg(local));
    final bearingRad = bearingDeg * math.pi / 180.0;
    final sinB = math.sin(bearingRad);
    final cosB = math.cos(bearingRad);

    var minAlong = double.infinity;
    var maxAlong = double.negativeInfinity;
    var minCross = double.infinity;
    var maxCross = double.negativeInfinity;

    for (final p in local) {
      final along = p.eastM * sinB + p.northM * cosB;
      final cross = p.eastM * cosB - p.northM * sinB;
      minAlong = math.min(minAlong, along);
      maxAlong = math.max(maxAlong, along);
      minCross = math.min(minCross, cross);
      maxCross = math.max(maxCross, cross);
    }

    final alongSpanM = math.max(1.0, maxAlong - minAlong);
    final crossSpanM = math.max(1.0, maxCross - minCross);

    final centerAlong = (minAlong + maxAlong) / 2.0;
    final centerCross = (minCross + maxCross) / 2.0;
    final centerEast = centerAlong * sinB + centerCross * cosB;
    final centerNorth = centerAlong * cosB - centerCross * sinB;

    final center = _offsetLatLng(
      origin: origin,
      eastM: centerEast,
      northM: centerNorth,
    );

    // Le cartouche est horizontal : l'emprise longitudinale pilote le zoom,
    // tandis que la profondeur est convertie en largeur équivalente pour ne
    // jamais couper une ellipse ou une RED.
    final widthFromAlong = math.max(
      alongSpanM * marginFactor,
      alongSpanM + minimumExtraMarginM,
    );

    // Les cartouches du CR sont très horizontaux. Pour garantir que la zone
    // complète reste visible, la profondeur doit être convertie en largeur
    // équivalente avec un facteur proche du ratio largeur/hauteur réel.
    // Cartouche ~2:1 : profondeur × 2.25 donne une marge visible en haut
    // et en bas sans réduire excessivement la zone utile.
    final widthFromCross = math.max(
      crossSpanM * 2.25,
      crossSpanM + minimumExtraMarginM,
    );

    final displayedWidthM = math.max(
      minimumDisplayedWidthM,
      math.max(widthFromAlong, widthFromCross),
    );

    return (
      center: center,
      zoom: _zoomForDisplayedWidth(
        widthM: displayedWidthM,
        latitudeDeg: center.latitude,
      ),
      rotationDeg: _mapRotationForAxis(bearingDeg),
      scaleBarMeters: _scaleBarForWidth(displayedWidthM),
    );
  }

  ({
    LatLng center,
    double zoom,
    double rotationDeg,
    double scaleBarMeters,
  }) _focusLayoutForGeometry({
    required LatLng fallbackCenter,
    required double fallbackRadiusM,
    required List<LatLng> geometry,
  }) {
    if (geometry.length < 2) {
      final displayedWidthM = math.max(250.0, fallbackRadiusM * 2.4);
      return (
        center: fallbackCenter,
        zoom: _zoomForDisplayedWidth(
          widthM: displayedWidthM,
          latitudeDeg: fallbackCenter.latitude,
        ),
        rotationDeg: 0.0,
        scaleBarMeters: _scaleBarForWidth(displayedWidthM),
      );
    }

    final origin = geometry.first;
    final local = <_LocalBatteryPoint>[
      for (var i = 0; i < geometry.length; i++)
        _toLocalMeters(
          origin: origin,
          piece: MessageBatteryMapPoint(
            label: 'T$i',
            latLng: geometry[i],
          ),
        ),
    ];

    final bearingDeg = _principalAxisBearingDeg(local);
    final bearingRad = bearingDeg * math.pi / 180.0;
    final sinB = math.sin(bearingRad);
    final cosB = math.cos(bearingRad);

    var minAlong = double.infinity;
    var maxAlong = double.negativeInfinity;
    var minCross = double.infinity;
    var maxCross = double.negativeInfinity;

    for (final p in local) {
      final along = p.eastM * sinB + p.northM * cosB;
      final cross = p.eastM * cosB - p.northM * sinB;
      minAlong = math.min(minAlong, along);
      maxAlong = math.max(maxAlong, along);
      minCross = math.min(minCross, cross);
      maxCross = math.max(maxCross, cross);
    }

    final alongSpanM = math.max(1.0, maxAlong - minAlong);
    final crossSpanM = math.max(1.0, maxCross - minCross);

    final centerAlong = (minAlong + maxAlong) / 2.0;
    final centerCross = (minCross + maxCross) / 2.0;
    final centerEast = centerAlong * sinB + centerCross * cosB;
    final centerNorth = centerAlong * cosB - centerCross * sinB;

    final center = _offsetLatLng(
      origin: origin,
      eastM: centerEast,
      northM: centerNorth,
    );

    // Même logique visuelle que l'implantation batterie :
    // axe principal horizontal et marge suffisante pour les marqueurs.
    final widthFromAlong = math.max(
      alongSpanM * 1.55,
      alongSpanM + 120.0,
    );
    final widthFromCross = math.max(
      crossSpanM * 3.0,
      crossSpanM + 100.0,
    );
    final displayedWidthM = math.max(
      math.max(widthFromAlong, widthFromCross),
      fallbackRadiusM * 2.2,
    );

    return (
      center: center,
      zoom: _zoomForDisplayedWidth(
        widthM: displayedWidthM,
        latitudeDeg: center.latitude,
      ),
      rotationDeg: _mapRotationForAxis(bearingDeg),
      scaleBarMeters: _scaleBarForWidth(displayedWidthM),
    );
  }

  ({LatLng center, double radiusM}) _focusFrameForGeometry({
    required LatLng fallbackCenter,
    required double fallbackRadiusM,
    required List<LatLng> geometry,
  }) {
    if (geometry.isEmpty) {
      return (center: fallbackCenter, radiusM: fallbackRadiusM);
    }

    var minLat = fallbackCenter.latitude;
    var maxLat = fallbackCenter.latitude;
    var minLon = fallbackCenter.longitude;
    var maxLon = fallbackCenter.longitude;

    for (final p in geometry) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLon = math.min(minLon, p.longitude);
      maxLon = math.max(maxLon, p.longitude);
    }

    final center = LatLng(
      (minLat + maxLat) / 2.0,
      (minLon + maxLon) / 2.0,
    );

    final distance = const Distance();
    var maxDistanceM = 0.0;

    for (final p in <LatLng>[fallbackCenter, ...geometry]) {
      final d = distance.as(LengthUnit.Meter, center, p);
      if (d > maxDistanceM) maxDistanceM = d;
    }

    // 20 % de marge afin que les extrémités d'un linéaire ou d'une zone
    // ne touchent pas le bord du cartouche.
    final geometryRadiusM = math.max(40.0, maxDistanceM * 1.20);

    return (
      center: center,
      radiusM: math.max(fallbackRadiusM, geometryRadiusM),
    );
  }

  double _globalZoomFromDistance(double distanceM) {
    final d = math.max(distanceM, 1.0);

    // Marge supplémentaire pour que les marqueurs PD / OBJ restent
    // entièrement visibles dans l'aperçu et dans la capture PDF.
    if (d <= 500) return 15.4;
    if (d <= 1000) return 14.4;
    if (d <= 2000) return 13.5;
    if (d <= 4000) return 12.5;
    if (d <= 8000) return 11.5;
    if (d <= 12000) return 10.7;
    if (d <= 18000) return 10.0;
    if (d <= 25000) return 9.4;
    return 8.7;
  }

  double _focusZoomFromRadius(double radiusM) {
    if (radiusM <= 75) return 17.8;
    if (radiusM <= 120) return 17.1;
    if (radiusM <= 180) return 16.5;
    if (radiusM <= 260) return 15.9;
    if (radiusM <= 400) return 15.2;
    if (radiusM <= 650) return 14.5;
    if (radiusM <= 1000) return 13.8;
    return 13.1;
  }
}

class _LocalBatteryPoint {
  const _LocalBatteryPoint({
    required this.eastM,
    required this.northM,
  });

  final double eastM;
  final double northM;
}
