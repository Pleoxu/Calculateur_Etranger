import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calculateur_etranger/domain/fire/models/tir_complet_input.dart'
    as tc;
import 'package:calculateur_etranger/domain/radio/pd_position_state.dart';
import 'package:calculateur_etranger/models/calcul_data.dart'
    show Systeme, TypeTir;
import 'package:calculateur_etranger/presentation/fire/controllers/tir_complet_form_controllers.dart';
import 'package:calculateur_etranger/presentation/fire/controllers/tir_complet_position_coordinator.dart';
import 'package:calculateur_etranger/presentation/fire/controllers/tir_complet_position_helpers.dart';
import 'package:calculateur_etranger/presentation/fire/navigation/tir_complet_map_navigation.dart';
import 'package:calculateur_etranger/presentation/fire/pages/carte_position_picker_page.dart'
    show CarteTirApercu, CarteTirEtat;
import 'package:calculateur_etranger/presentation/fire/state/tir_complet_state.dart';
import 'package:calculateur_etranger/presentation/fire/state/tir_header_state.dart';
import 'package:calculateur_etranger/services/balistique_mo81_m252_appui_service.dart';
import 'package:calculateur_etranger/services/mo81_llr_charge_selector.dart';
import 'package:calculateur_etranger/services/position/elevation_service.dart';
import 'package:calculateur_etranger/services/position/utm_converter.dart';
import 'package:calculateur_etranger/services/simulation/radio_position_simulator.dart';
import 'package:calculateur_etranger/utils/charge_utils.dart';

class TirCompletPositionActions {
  TirCompletPositionActions({
    required WidgetRef ref,
    required TirCompletFormControllers form,
    required BuildContext Function() context,
    required bool Function() mounted,
    required VoidCallback onChanged,
  })  : _ref = ref,
        _form = form,
        _context = context,
        _mounted = mounted,
        _onChanged = onChanged;

  final WidgetRef _ref;
  final TirCompletFormControllers _form;
  final BuildContext Function() _context;
  final bool Function() _mounted;
  final VoidCallback _onChanged;

  final TirCompletPositionCoordinator _positionCoordinator =
      TirCompletPositionCoordinator();

  PdPositionSource _pdSource = PdPositionSource.manual;
  bool _externalGpsSelected = false;
  bool _externalGpsPositionAcquired = false;
  bool _gpsLoading = false;
  bool _obsGpsLoading = false;
  bool _radioLoading = false;
  bool _updatingCoords = false;
  String? _objectifMapInfo;
  Timer? _obsObjectifAltitudeDebounce;
  int _obsObjectifAltitudeRequest = 0;

  PdPositionSource get pdSource => _pdSource;
  bool get externalGpsSelected => _externalGpsSelected;
  bool get gpsLoading => _gpsLoading;
  bool get observerGpsLoading => _obsGpsLoading;
  bool get radioLoading => _radioLoading;
  String? get objectifMapInfo => _objectifMapInfo;

  TextEditingController get zoneCtrl => _form.zoneCtrl;
  TextEditingController get xCtrl => _form.xCtrl;
  TextEditingController get yCtrl => _form.yCtrl;
  TextEditingController get zCtrl => _form.zCtrl;
  TextEditingController get latCtrl => _form.latCtrl;
  TextEditingController get lonCtrl => _form.lonCtrl;
  TextEditingController get altCtrl => _form.altCtrl;
  TextEditingController get distCtrl => _form.distCtrl;
  TextEditingController get azCtrl => _form.azCtrl;
  TextEditingController get altObjCtrl => _form.altObjCtrl;
  TextEditingController get xObjCtrl => _form.xObjCtrl;
  TextEditingController get yObjCtrl => _form.yObjCtrl;
  TextEditingController get zObjCtrl => _form.zObjCtrl;
  TextEditingController get obsXCtrl => _form.obsXCtrl;
  TextEditingController get obsYCtrl => _form.obsYCtrl;
  TextEditingController get obsZCtrl => _form.obsZCtrl;
  TextEditingController get obsDistCtrl => _form.obsDistCtrl;
  TextEditingController get obsAzCtrl => _form.obsAzCtrl;
  TextEditingController get obsAltObjCtrl => _form.obsAltObjCtrl;
  TextEditingController get obsXObjCtrl => _form.obsXObjCtrl;
  TextEditingController get obsYObjCtrl => _form.obsYObjCtrl;
  TextEditingController get obsZObjCtrl => _form.obsZObjCtrl;

  void init() {
    zoneCtrl.addListener(_updateLatLonFromUtm);
    xCtrl.addListener(_updateLatLonFromUtm);
    yCtrl.addListener(_updateLatLonFromUtm);
    zCtrl.addListener(_updateLatLonFromUtm);

    for (final c in [obsXCtrl, obsYCtrl, obsZCtrl, obsDistCtrl, obsAzCtrl]) {
      c.addListener(_scheduleObserverDazObjectifAltitude);
    }
  }

  Future<void> dispose() async {
    zoneCtrl.removeListener(_updateLatLonFromUtm);
    xCtrl.removeListener(_updateLatLonFromUtm);
    yCtrl.removeListener(_updateLatLonFromUtm);
    zCtrl.removeListener(_updateLatLonFromUtm);
    _obsObjectifAltitudeDebounce?.cancel();

    for (final c in [obsXCtrl, obsYCtrl, obsZCtrl, obsDistCtrl, obsAzCtrl]) {
      c.removeListener(_scheduleObserverDazObjectifAltitude);
    }

    await _positionCoordinator.dispose();
  }

  void _notify() {
    if (_mounted()) _onChanged();
  }

  void _updateLatLonFromUtm() {
    if (_updatingCoords) return;

    final zoneText = zoneCtrl.text.trim().toUpperCase();
    final xText = xCtrl.text.trim();
    final yText = yCtrl.text.trim();
    final zText = zCtrl.text.trim();

    if (zoneText.length < 2 || xText.isEmpty || yText.isEmpty) return;

    final match = RegExp(r'^(\d{1,2})([C-HJ-NP-X])$').firstMatch(zoneText);
    if (match == null) return;

    final zone = int.tryParse(match.group(1)!);
    final band = match.group(2)!;
    final x = double.tryParse(xText.replaceAll(',', '.'));
    final y = double.tryParse(yText.replaceAll(',', '.'));
    final z = double.tryParse(zText.replaceAll(',', '.')) ?? 0;

    if (zone == null || x == null || y == null) return;

    try {
      _updatingCoords = true;
      final latLon = UtmConverter.toLatLon(
        zone: zone,
        band: band,
        x: x,
        y: y,
        z: z,
      );
      latCtrl.text = latLon.latitude.toStringAsFixed(6);
      lonCtrl.text = latLon.longitude.toStringAsFixed(6);
      altCtrl.text = latLon.altitude.toStringAsFixed(0);
    } finally {
      _updatingCoords = false;
    }
  }

  void _startGpsTracking() {
    _positionCoordinator.startDeviceTracking(
      onData: (gps) {
        final utm = UtmConverter.fromLatLon(
          latitude: gps.latitude,
          longitude: gps.longitude,
          altitude: gps.altitude,
        );

        try {
          _updatingCoords = true;
          if (!_mounted()) return;

          zoneCtrl.text = '${utm.zone}${utm.band}';
          xCtrl.text = utm.x.toStringAsFixed(0);
          yCtrl.text = utm.y.toStringAsFixed(0);
          zCtrl.text = utm.z.toStringAsFixed(0);
          latCtrl.text = gps.latitude.toStringAsFixed(6);
          lonCtrl.text = gps.longitude.toStringAsFixed(6);
          altCtrl.text = gps.altitude.toStringAsFixed(0);
          _notify();

          debugPrint(
            '[OPS GPS STREAM] '
            'lat=${gps.latitude} '
            'lon=${gps.longitude} '
            'alt=${gps.altitude} '
            'acc=${gps.accuracy} '
            'apiAlt=${gps.altitudeFromApi}',
          );
        } finally {
          _updatingCoords = false;
        }
      },
      onError: (error, stackTrace) {
        debugPrint('[OPS GPS STREAM] error: $error');
      },
    );
  }

  void _stopGpsTracking() => _positionCoordinator.stopDeviceTracking();

  void _startExternalGpsTracking() {
    _positionCoordinator.startExternalTracking(
      onData: (data) async {
        if (_externalGpsPositionAcquired) return;

        final lat = data.latitude;
        final lon = data.longitude;
        final terrainAltitude = await _altitudeMntOrFallback(
          latitude: lat,
          longitude: lon,
          fallback: data.altitude,
        );
        final utm = UtmConverter.fromLatLon(
          latitude: lat,
          longitude: lon,
          altitude: terrainAltitude,
        );

        if (!_mounted() || !_externalGpsSelected) return;

        try {
          _updatingCoords = true;
          zoneCtrl.text = '${utm.zone}${utm.band}';
          xCtrl.text = utm.x.toStringAsFixed(0);
          yCtrl.text = utm.y.toStringAsFixed(0);
          zCtrl.text = utm.z.toStringAsFixed(0);
          latCtrl.text = lat.toStringAsFixed(6);
          lonCtrl.text = lon.toStringAsFixed(6);
          altCtrl.text = utm.z.toStringAsFixed(0);
          _notify();

          // Acquisition ponctuelle : une fois les champs remplis,
          // on fige la position côté application mais on laisse le port
          // série ouvert pour éviter une fermeture native pendant une lecture.
          _externalGpsPositionAcquired = true;

          debugPrint(
            '[GNSS CIVIL] position acquired and fixed '
            'zone=${utm.zone}${utm.band} '
            'x=${utm.x.toStringAsFixed(0)} '
            'y=${utm.y.toStringAsFixed(0)} '
            'z=${utm.z.toStringAsFixed(0)}',
          );

          debugPrint(
            '[GNSS CIVIL] '
            'protocol=${data.protocol.name} '
            'lat=$lat lon=$lon '
            'gnssAlt=${data.altitude} terrainAlt=${utm.z} '
            'zone=${utm.zone}${utm.band} x=${utm.x} y=${utm.y} '
            'sat=${data.quality.satellitesUsed ?? '-'} '
            'hdop=${data.quality.hdop ?? '-'} '
            'pdop=${data.quality.pdop ?? '-'} '
            'carr=${data.quality.carrierSolution ?? '-'}',
          );
        } finally {
          _updatingCoords = false;
        }
      },
      onError: (error, stackTrace) {
        debugPrint('[GNSS CIVIL] stream error: $error');
      },
    );
  }

  void selectExternalGps() {
    _stopGpsTracking();
    _externalGpsPositionAcquired = false;
    _pdSource = PdPositionSource.manual;
    _externalGpsSelected = true;
    _notify();
    _startExternalGpsTracking();

    ScaffoldMessenger.of(_context()).showSnackBar(
      const SnackBar(
        content: Text(
          'External civil GPS selected — waiting for external GPS stream.',
        ),
      ),
    );

    debugPrint(
      '[GNSS CIVIL] source selected — waiting for actual transport',
    );
  }

  void _stopExternalGpsTracking() {
    _positionCoordinator.stopExternalTracking();
    _externalGpsSelected = false;
    _externalGpsPositionAcquired = false;
  }

  Future<void> selectDeviceGps() async {
    debugPrint('[OPS GPS] acquisition from map coordinates');
    _stopExternalGpsTracking();
    _pdSource = PdPositionSource.gpsAtlas;
    _externalGpsSelected = false;
    _notify();
    await _fillCoordsFromGps();
    _startGpsTracking();
  }

  void disableGpsSource() {
    debugPrint('[OPS GPS] source disabled');
    _stopGpsTracking();
    _stopExternalGpsTracking();
    _pdSource = PdPositionSource.manual;
    _externalGpsSelected = false;
    _notify();
  }

  double? _parseDoubleField(TextEditingController ctrl) =>
      TirCompletPositionHelpers.parseDoubleField(ctrl);

  ({int zone, String band})? _parseUtmZoneText(String raw) =>
      TirCompletPositionHelpers.parseUtmZoneText(raw);

  bool canPickObjectifOnMap() {
    return _currentPieceLatLon() != null &&
        _parseDoubleField(xCtrl) != null &&
        _parseDoubleField(yCtrl) != null;
  }

  void _scheduleObserverDazObjectifAltitude() {
    if (_updatingCoords) return;
    _obsObjectifAltitudeDebounce?.cancel();
    _obsObjectifAltitudeDebounce = Timer(
      const Duration(milliseconds: 450),
      _updateObserverDazObjectifAltitude,
    );
  }

  Future<void> _updateObserverDazObjectifAltitude() async {
    final st = _ref.read(tirCompletProvider);
    if (!st.observateurEnabled ||
        st.observateurObjMode != tc.ObservateurObjMode.daz) {
      return;
    }

    final zoneParsed = _parseUtmZoneText(zoneCtrl.text);
    if (zoneParsed == null) return;

    final obsX = _parseDoubleField(obsXCtrl);
    final obsY = _parseDoubleField(obsYCtrl);
    final obsZ = _parseDoubleField(obsZCtrl) ?? 0;
    final distance = _parseDoubleField(obsDistCtrl);
    final azimutMil = _parseDoubleField(obsAzCtrl);

    if (obsX == null || obsY == null || distance == null || azimutMil == null) {
      return;
    }
    if (distance <= 0 || azimutMil < 0 || azimutMil >= 6400) return;

    final requestId = ++_obsObjectifAltitudeRequest;
    final azRad = azimutMil * 2.0 * math.pi / 6400.0;
    final objX = obsX + distance * math.sin(azRad);
    final objY = obsY + distance * math.cos(azRad);

    late final LatLonPosition ll;
    try {
      ll = UtmConverter.toLatLon(
        zone: zoneParsed.zone,
        band: zoneParsed.band,
        x: objX,
        y: objY,
        z: obsZ,
      );
    } catch (_) {
      return;
    }

    final z = await ElevationService.instance.elevationAt(
      latitude: ll.latitude,
      longitude: ll.longitude,
    );

    if (!_mounted() || requestId != _obsObjectifAltitudeRequest || z == null) {
      return;
    }

    obsXObjCtrl.text = objX.toStringAsFixed(0);
    obsYObjCtrl.text = objY.toStringAsFixed(0);
    obsZObjCtrl.text = z.toStringAsFixed(0);
    obsAltObjCtrl.text = z.toStringAsFixed(0);
    _notify();
  }

  LatLonPosition? _currentPieceLatLon() =>
      TirCompletPositionHelpers.currentPieceLatLon(_form);

  LatLonPosition? _currentObjectifLatLon() {
    final st = _ref.read(tirCompletProvider);
    return TirCompletPositionHelpers.currentObjectifLatLon(
      form: _form,
      mode: st.objectifMode,
    );
  }

  LatLonPosition? _currentObserverLatLon() =>
      TirCompletPositionHelpers.currentObserverLatLon(_form);

  LatLonPosition? _currentObserverObjectifLatLon() =>
      TirCompletPositionHelpers.currentObserverObjectifLatLon(_form);

  bool canPickObserverObjectifOnMap() => _currentObserverLatLon() != null;

  UtmPosition _utmInPieceZone({
    required double latitude,
    required double longitude,
    required double altitude,
  }) {
    return TirCompletPositionHelpers.utmInPieceZone(
      form: _form,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
    );
  }

  Future<double> _altitudeMntOrFallback({
    required double latitude,
    required double longitude,
    required double fallback,
  }) async {
    final z = await ElevationService.instance.elevationAt(
      latitude: latitude,
      longitude: longitude,
    );
    return z ?? fallback;
  }

  Future<void> pickCamp() async {
    _stopGpsTracking();
    _stopExternalGpsTracking();

    final dark = _ref.read(tirHeaderProvider).dark;
    final campId = await TirCompletMapNavigation.chooseCamp(
      context: _context(),
      dark: dark,
    );
    if (campId == null || !_mounted()) return;

    _pdSource = PdPositionSource.manual;
    _notify();

    final result = await TirCompletMapNavigation.pickPieceDirectrice(
      context: _context(),
      dark: dark,
      utmZoneLabel: zoneCtrl.text.trim(),
      localMapZoneId: campId,
    );
    if (result == null || !_mounted()) return;

    try {
      _updatingCoords = true;
      zoneCtrl.text = '${result.utm.zone}${result.utm.band}';
      xCtrl.text = result.utm.x.toStringAsFixed(0);
      yCtrl.text = result.utm.y.toStringAsFixed(0);
      zCtrl.text = result.utm.z.toStringAsFixed(0);
      latCtrl.text = result.latitude.toStringAsFixed(6);
      lonCtrl.text = result.longitude.toStringAsFixed(6);
      altCtrl.text = result.utm.z.toStringAsFixed(0);
      _objectifMapInfo = null;
      _notify();
    } finally {
      _updatingCoords = false;
    }
  }

  Future<void> pickPieceOnMap() async {
    _stopGpsTracking();
    _stopExternalGpsTracking();
    _pdSource = PdPositionSource.manual;
    _notify();

    final dark = _ref.read(tirHeaderProvider).dark;
    final pieceLL = _currentPieceLatLon();
    final result = await TirCompletMapNavigation.pickPieceDirectrice(
      context: _context(),
      dark: dark,
      utmZoneLabel: zoneCtrl.text.trim(),
      initial: pieceLL,
      initialAltitude: _parseDoubleField(zCtrl),
    );
    if (result == null || !_mounted()) return;

    try {
      _updatingCoords = true;
      zoneCtrl.text = '${result.utm.zone}${result.utm.band}';
      xCtrl.text = result.utm.x.toStringAsFixed(0);
      yCtrl.text = result.utm.y.toStringAsFixed(0);
      zCtrl.text = result.utm.z.toStringAsFixed(0);
      latCtrl.text = result.latitude.toStringAsFixed(6);
      lonCtrl.text = result.longitude.toStringAsFixed(6);
      altCtrl.text = result.utm.z.toStringAsFixed(0);
      _objectifMapInfo = null;
      _notify();
    } finally {
      _updatingCoords = false;
    }
  }

  String _resumeTirCarte(CarteTirApercu apercu) {
    final charge = apercu.charge;
    return switch (apercu.etat) {
      CarteTirEtat.ok =>
        charge == null ? 'Fire possible' : 'Fire possible $charge',
      CarteTirEtat.limite =>
        charge == null ? 'Charge limit' : 'Charge limit $charge',
      CarteTirEtat.impossible => 'Fire not possible',
    };
  }

  /// Retourne une indication rapide pour la carte. Cette estimation ne lance
  /// pas le calcul balistique complet et ne remplace pas les validations de
  /// tir, mais elle utilise le même sélecteur de charge que MO81 LLR.
  Future<CarteTirApercu> _evaluerTirCarte(double distanceM) async {
    final header = _ref.read(tirHeaderProvider);
    final munition = header.typeMunition;

    if (!distanceM.isFinite || distanceM <= 0) {
      return const CarteTirApercu(
        etat: CarteTirEtat.impossible,
        titre: 'Fire not possible',
        detail: 'Invalid target distance.',
      );
    }

    if (header.systeme == Systeme.mo81M252) {
      final min = BalistiqueMo81M252AppuiService.minimumRangeM;
      final max = BalistiqueMo81M252AppuiService.maximumRangeM;
      if (header.typeTir != TypeTir.appui) {
        return const CarteTirApercu(
          etat: CarteTirEtat.impossible,
          titre: 'Fire not possible',
          detail: 'M252 M821A1 / CH3 supports fire only.',
        );
      }
      if (distanceM < min || distanceM > max) {
        return CarteTirApercu(
          etat: CarteTirEtat.impossible,
          titre: 'Fire not possible',
          detail:
              'M252 M821A1 / CH3 is qualified only from ${min.toStringAsFixed(0)} '
              'to ${max.toStringAsFixed(0)} m.',
        );
      }
      return const CarteTirApercu(
        etat: CarteTirEtat.ok,
        titre: 'Fire possible — CH3',
        detail: 'M252 M821A1 / CH3 reference pipeline.',
        charge: BalistiqueMo81M252AppuiService.charge,
      );
    }

    if (header.systeme == Systeme.mo81Lrr) {
      if (munition == null) {
        return const CarteTirApercu(
          etat: CarteTirEtat.impossible,
          titre: 'Fire not possible',
          detail: 'Select a MO81 LLR munition.',
        );
      }

      try {
        final choice = await Mo81LlrChargeSelector.selectForDistance(
          distanceM: distanceM,
          munition: munition,
        );
        final isDerniereCharge = header.typeTir == TypeTir.eclairant
            ? choice.charge == 'CH5'
            : choice.charge == 'CH6';
        return CarteTirApercu(
          etat: isDerniereCharge ? CarteTirEtat.limite : CarteTirEtat.ok,
          titre: isDerniereCharge
              ? 'Charge limit — ${choice.charge}'
              : 'Fire possible — ${choice.charge}',
          detail: isDerniereCharge
              ? 'Last available charge for this type of fire.'
              : 'Estimated elevation: ${choice.hausseMil.toStringAsFixed(0)} mil.',
          charge: choice.charge,
        );
      } catch (_) {
        return const CarteTirApercu(
          etat: CarteTirEtat.impossible,
          titre: 'Fire not possible',
          detail: 'No MO81 LLR charge covers this range.',
        );
      }
    }

    final charge = header.systeme == Systeme.mo120
        ? choisirChargeMo120(distanceM)
        : choisirChargeEnum(distanceM, typeTir: header.typeTir);
    if (charge == 'HorsPortee') {
      return const CarteTirApercu(
        etat: CarteTirEtat.impossible,
        titre: 'Fire not possible',
        detail: 'No available charge covers this range.',
      );
    }

    final double seuilM;
    if (header.systeme == Systeme.mo120) {
      seuilM = 0.85 * porteeMaxChargeMo120(charge);
    } else {
      final maxM = porteeMaxChargeEnum(charge, typeTir: header.typeTir);
      final coeff = header.typeTir == TypeTir.eclairant
          ? 0.95
          : (const <String, double>{
                'CH1': 0.90,
                'CH2': 0.90,
                'CH3': 0.90,
                'CH4': 0.95,
                'CH5': 0.95,
                'CH6': 0.97,
              }[charge] ??
              0.80);
      seuilM = coeff * maxM;
    }

    final isLimite = distanceM >= seuilM * 0.90;
    final margeM = (seuilM - distanceM).clamp(0.0, double.infinity);
    return CarteTirApercu(
      etat: isLimite ? CarteTirEtat.limite : CarteTirEtat.ok,
      titre: isLimite ? 'Charge limit — $charge' : 'Fire possible — $charge',
      detail: isLimite
          ? 'Estimated margin: ${margeM.toStringAsFixed(0)} m.'
          : 'Estimated margin: ${margeM.toStringAsFixed(0)} m.',
      charge: charge,
    );
  }

  Future<void> pickObjectifOnMap() async {
    final dark = _ref.read(tirHeaderProvider).dark;
    final stN = _ref.read(tirCompletProvider.notifier);
    final pieceLL = _currentPieceLatLon();
    final objLL = _currentObjectifLatLon();
    final pieceX = _parseDoubleField(xCtrl);
    final pieceY = _parseDoubleField(yCtrl);

    if (pieceLL == null || pieceX == null || pieceY == null) {
      ScaffoldMessenger.of(_context()).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter the directing gun in UTM first to center the map.',
          ),
        ),
      );
      return;
    }

    final result = await TirCompletMapNavigation.pickObjectif(
      context: _context(),
      dark: dark,
      utmZoneLabel: zoneCtrl.text.trim(),
      piece: pieceLL,
      pieceX: pieceX,
      pieceY: pieceY,
      pieceAltitude: _parseDoubleField(zCtrl),
      initial: objLL,
      initialAltitude:
          _parseDoubleField(zObjCtrl) ?? _parseDoubleField(altObjCtrl),
      tirApercuBuilder: _evaluerTirCarte,
    );
    if (result == null || !_mounted()) return;

    final distance = result.distanceFromPieceM;
    final azimut = result.azimutFromPieceMil;
    final apercu = distance == null ? null : await _evaluerTirCarte(distance);
    if (!_mounted()) return;

    xObjCtrl.text = result.utm.x.toStringAsFixed(0);
    yObjCtrl.text = result.utm.y.toStringAsFixed(0);
    zObjCtrl.text = result.utm.z.toStringAsFixed(0);
    if (distance != null) distCtrl.text = distance.toStringAsFixed(0);
    if (azimut != null) azCtrl.text = azimut.toStringAsFixed(1);
    altObjCtrl.text = result.utm.z.toStringAsFixed(0);
    _objectifMapInfo = distance != null && azimut != null
        ? 'Map: ${distance.toStringAsFixed(0)} m · ${apercu == null ? 'Fire cannot be evaluated' : _resumeTirCarte(apercu)} · azimuth ${azimut.toStringAsFixed(1)} mil · UTM ${result.utm.zone}${result.utm.band} ${result.utm.x.toStringAsFixed(0)} ${result.utm.y.toStringAsFixed(0)}'
        : 'Map: UTM ${result.utm.zone}${result.utm.band} ${result.utm.x.toStringAsFixed(0)} ${result.utm.y.toStringAsFixed(0)}';
    _notify();

    stN.setObjectifMode(tc.ObjectifInputMode.utm);
  }

  Future<void> fillObserverFromGps() async {
    _obsGpsLoading = true;
    _notify();

    try {
      final gps = await _positionCoordinator.getCurrentDevicePosition();
      if (gps == null) {
        if (_mounted()) {
          ScaffoldMessenger.of(_context()).showSnackBar(
            const SnackBar(
              content: Text(
                'Observer location unavailable — check permissions.',
              ),
            ),
          );
        }
        return;
      }

      final altitude = await _altitudeMntOrFallback(
        latitude: gps.latitude,
        longitude: gps.longitude,
        fallback: gps.altitude,
      );
      final utm = _utmInPieceZone(
        latitude: gps.latitude,
        longitude: gps.longitude,
        altitude: altitude,
      );

      if (!_mounted()) return;
      obsXCtrl.text = utm.x.toStringAsFixed(0);
      obsYCtrl.text = utm.y.toStringAsFixed(0);
      obsZCtrl.text = utm.z.toStringAsFixed(0);
      _notify();

      debugPrint(
        '[OBS GPS] lat=${gps.latitude} lon=${gps.longitude} '
        'gpsAlt=${gps.altitude} alt=${utm.z} zone=${utm.zone}${utm.band} '
        'x=${utm.x} y=${utm.y} z=${utm.z}',
      );
    } finally {
      _obsGpsLoading = false;
      _notify();
    }
  }

  Future<void> pickObserverOnMap() async {
    final dark = _ref.read(tirHeaderProvider).dark;
    final pieceLL = _currentPieceLatLon();
    final obsLL = _currentObserverLatLon();

    final result = await TirCompletMapNavigation.pickObserver(
      context: _context(),
      dark: dark,
      utmZoneLabel: zoneCtrl.text.trim(),
      piece: pieceLL,
      observer: obsLL,
      pieceAltitude: _parseDoubleField(zCtrl),
      observerAltitude: _parseDoubleField(obsZCtrl),
    );
    if (result == null || !_mounted()) return;

    obsXCtrl.text = result.utm.x.toStringAsFixed(0);
    obsYCtrl.text = result.utm.y.toStringAsFixed(0);
    obsZCtrl.text = result.utm.z.toStringAsFixed(0);
    _notify();
  }

  Future<void> pickObserverObjectifOnMap() async {
    final dark = _ref.read(tirHeaderProvider).dark;
    final obsLL = _currentObserverLatLon();
    final objLL = _currentObserverObjectifLatLon();
    final pieceLL = _currentPieceLatLon();

    if (obsLL == null) {
      ScaffoldMessenger.of(_context()).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter the observer position first to designate the target on the map.',
          ),
        ),
      );
      return;
    }

    final result = await TirCompletMapNavigation.pickObserverObjectif(
      context: _context(),
      dark: dark,
      utmZoneLabel: zoneCtrl.text.trim(),
      observer: obsLL,
      piece: pieceLL,
      initial: objLL,
      initialAltitude:
          _parseDoubleField(obsZObjCtrl) ?? _parseDoubleField(obsAltObjCtrl),
      pieceAltitude: _parseDoubleField(zCtrl),
      observerAltitude: _parseDoubleField(obsZCtrl),
    );
    if (result == null || !_mounted()) return;

    final distance = result.distanceFromPieceM;
    final azimut = result.azimutFromPieceMil;

    obsXObjCtrl.text = result.utm.x.toStringAsFixed(0);
    obsYObjCtrl.text = result.utm.y.toStringAsFixed(0);
    obsZObjCtrl.text = result.utm.z.toStringAsFixed(0);
    obsAltObjCtrl.text = result.utm.z.toStringAsFixed(0);
    if (distance != null) obsDistCtrl.text = distance.toStringAsFixed(0);
    if (azimut != null) obsAzCtrl.text = azimut.toStringAsFixed(1);
    _notify();
  }

  Future<void> syncBatteryFromRadio() async {
    _stopGpsTracking();
    _stopExternalGpsTracking();
    _pdSource = PdPositionSource.radioPct;
    _notify();
    if (_radioLoading) return;

    _radioLoading = true;
    _notify();

    try {
      final result = await RadioPositionSimulator().loadBattery();
      final stN = _ref.read(tirCompletProvider.notifier);
      final pdZone = result.pdZone?.trim();

      if (pdZone != null && pdZone.isNotEmpty) zoneCtrl.text = pdZone;
      xCtrl.text = result.pdX.toStringAsFixed(0);
      yCtrl.text = result.pdY.toStringAsFixed(0);
      zCtrl.text = result.pdZ.toStringAsFixed(0);
      altCtrl.text = result.pdZ.toStringAsFixed(0);
      latCtrl.clear();
      lonCtrl.clear();

      if (result.observer != null) {
        obsXCtrl.text = result.observer!.x.toStringAsFixed(0);
        obsYCtrl.text = result.observer!.y.toStringAsFixed(0);
        obsZCtrl.text = result.observer!.z.toStringAsFixed(0);
      }
      _notify();

      stN.setPiecesSoutien(result.piecesSoutien);
      if (result.piecesSoutien.isNotEmpty) stN.setAutrePiecesEnabled(true);
      if (result.observer != null) stN.setObservateurEnabled(true);

      debugPrint(
        '[RADIO] Synchronisation batterie OK '
        'pieces=${result.piecesSoutien.length} '
        'observer=${result.observer != null}',
      );

      if (_mounted()) {
        ScaffoldMessenger.of(_context()).showSnackBar(
          SnackBar(
            content: Text(
              result.observer != null
                  ? 'Radio: PD, ${result.piecesSoutien.length} PS and observer received.'
                  : 'Radio: PD and ${result.piecesSoutien.length} PS received.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[RADIO] synchronization error: $e');
      if (_mounted()) {
        ScaffoldMessenger.of(_context()).showSnackBar(
          SnackBar(content: Text('Radio synchronization failed: $e')),
        );
      }
    } finally {
      _radioLoading = false;
      _notify();
    }
  }

  Future<void> _fillCoordsFromGps() async {
    _gpsLoading = true;
    _notify();

    try {
      final gps = await _positionCoordinator.getCurrentDevicePosition();
      if (gps == null) {
        debugPrint('[OPS GPS] no position received');
        if (_mounted()) {
          ScaffoldMessenger.of(_context()).showSnackBar(
            const SnackBar(
              content: Text(
                'Location unavailable — check permissions.',
              ),
            ),
          );
        }
        return;
      }

      debugPrint(
        '[OPS GPS] lat=${gps.latitude} '
        'lon=${gps.longitude} '
        'alt=${gps.altitude} '
        'acc=${gps.accuracy}',
      );

      final altitude = await _altitudeMntOrFallback(
        latitude: gps.latitude,
        longitude: gps.longitude,
        fallback: gps.altitude,
      );
      final st = _ref.read(tirCompletProvider);

      try {
        _updatingCoords = true;
        if (st.pieceUtm || _pdSource == PdPositionSource.gpsAtlas) {
          final utm = UtmConverter.fromLatLon(
            latitude: gps.latitude,
            longitude: gps.longitude,
            altitude: altitude,
          );

          debugPrint(
            '[OPS UTM] zone=${utm.zone}${utm.band} '
            'x=${utm.x} y=${utm.y} z=${utm.z}',
          );

          zoneCtrl.text = '${utm.zone}${utm.band}';
          xCtrl.text = utm.x.toStringAsFixed(0);
          yCtrl.text = utm.y.toStringAsFixed(0);
          zCtrl.text = utm.z.toStringAsFixed(0);
          latCtrl.text = gps.latitude.toStringAsFixed(6);
          lonCtrl.text = gps.longitude.toStringAsFixed(6);
          altCtrl.text = utm.z.toStringAsFixed(0);
        } else {
          latCtrl.text = gps.latitude.toStringAsFixed(6);
          lonCtrl.text = gps.longitude.toStringAsFixed(6);
          altCtrl.text = altitude.toStringAsFixed(0);
        }
        _notify();
      } finally {
        _updatingCoords = false;
      }
    } finally {
      _gpsLoading = false;
      _notify();
    }
  }
}
