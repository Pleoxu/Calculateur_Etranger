// lib/presentation/fire/controllers/tir_complet_controller.dart

import 'dart:convert';

import 'package:calculateur_etranger/security/security_service.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/domain/fire/input/fire_request.dart';
import 'package:calculateur_etranger/domain/fire/doctrine/mo81_llr_initial_conditions.dart';
import 'package:calculateur_etranger/services/balistique_mo81_m252_appui_service.dart';
import 'package:calculateur_etranger/services/mo81_llr_charge_selector.dart';
import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';
import 'package:calculateur_etranger/domain/fire/usecases/tir_complet_usecase.dart'
    show TirCompletUsecase;

import 'package:calculateur_etranger/presentation/fire/state/tir_header_state.dart';
import 'package:calculateur_etranger/presentation/fire/state/tir_complet_state.dart';
import 'package:calculateur_etranger/presentation/fire/helpers/coups_repartition_helper.dart';
import 'package:calculateur_etranger/presentation/fire/models/piece_soutien.dart';
import 'package:calculateur_etranger/presentation/fire/mappers/fire_request_mapper.dart';

import 'package:calculateur_etranger/presentation/fire/dialogs/masse_et_charge_dialogs.dart';
import 'package:calculateur_etranger/presentation/fire/dialogs/mo81_powder_temperature_dialog.dart';
import 'package:calculateur_etranger/presentation/fire/dialogs/tir_similaire_dialog.dart';
import 'package:calculateur_etranger/presentation/fire/dialogs/fusee_dialog.dart';
import 'package:calculateur_etranger/presentation/fire/dialogs/meteo_picker_dialog.dart';
import 'package:calculateur_etranger/utils/charge_utils.dart';

final porteeMaxSeuilProvider = Provider<double>((ref) {
  final header = ref.watch(tirHeaderProvider);
  final st = ref.watch(tirCompletProvider);

  return getPorteeMaxAbsolueCaesar(
    typeTir: header.typeTir,
    typeChargeCaesar: st.typeChargeCaesar,
  );
});

class TirCompletController {
  TirCompletController(this.ref) : _usecase = TirCompletUsecase();

  final WidgetRef ref;
  final TirCompletUsecase _usecase;
  final SecurityService _securityService = SecurityService();

  TirHeaderState get _header => ref.read(tirHeaderProvider);
  TirCompletState get _state => ref.read(tirCompletProvider);
  TirCompletNotifier get _notifier => ref.read(tirCompletProvider.notifier);

  double? _d(String? s) =>
      s == null ? null : double.tryParse(s.trim().replaceAll(',', '.'));

  static const bool _traceEnabled = bool.fromEnvironment(
    'CALC_TRACE',
    defaultValue: false,
  );

  static const int _traceSchemaVersion = 3;

  void _tracePrintJsonLine(Map<String, dynamic> payload) {
    if (!_traceEnabled) return;
    try {
      debugPrint(jsonEncode(payload));
    } catch (_) {}
  }

  Map<String, num?> _extractDeltaV0Candidates(dynamic rp) {
    num? read(String field) {
      try {
        final v = (rp as dynamic).deltaV0;
        if (field == 'deltaV0' && v is num) return v;
      } catch (_) {}
      try {
        final v = (rp as dynamic).v0Used;
        if (field == 'v0Used' && v is num) return v;
      } catch (_) {}
      try {
        final v = (rp as dynamic).v0Final;
        if (field == 'v0Final' && v is num) return v;
      } catch (_) {}
      try {
        final v = (rp as dynamic).v0;
        if (field == 'v0' && v is num) return v;
      } catch (_) {}
      return null;
    }

    return {
      'deltaV0': read('deltaV0'),
      'v0Used': read('v0Used'),
      'v0Final': read('v0Final'),
      'v0': read('v0'),
    };
  }

  Map<String, dynamic> _snapshotUiRaw({
    required TextEditingController xCtrl,
    required TextEditingController yCtrl,
    required TextEditingController zCtrl,
    required TextEditingController zoneCtrl,
    required TextEditingController latCtrl,
    required TextEditingController lonCtrl,
    required TextEditingController altCtrl,
    required TextEditingController distCtrl,
    required TextEditingController azCtrl,
    required TextEditingController altObjCtrl,
    required TextEditingController xObjCtrl,
    required TextEditingController yObjCtrl,
    required TextEditingController zObjCtrl,
    required bool forceOecl,
  }) {
    final header = _header;
    final st = _state;

    return {
      'schema': _traceSchemaVersion,
      'header': {
        'systeme': header.systeme.toString(),
        'typeTir': (forceOecl ? TypeTir.eclairant : header.typeTir).toString(),
        'dark': header.dark,
      },
      'state': {
        'pieceUtm': st.pieceUtm,
        'objectifMode': st.objectifMode.toString(),
        'tirVertical': st.tirVertical,
        'forcerCharge': st.forcerCharge,
        'chargeForcee': st.chargeForcee,
        'masseEnabled': st.masseEnabled,
        'carreaux': st.carreaux,
        'fusee': st.fusee.toString(),
        'tirSimilaire': st.tirSimilaire,
        'simCarreaux': st.simCarreaux,
        'tPrev': st.tPrev,
        'tAct': st.tAct,
        'v0Prev': st.v0Prev,
        'meteo': st.meteo,
        'meteoFileName': st.meteoFileName,
        'meteoRowsCount': st.meteoRows?.length ?? 0,
        'meteoStationAltM': st.meteoStationAltM,
        'autrePieces': st.autrePieces,
        'piecesSoutien': st.piecesSoutien
            .map(
              (ps) => {
                'nom': ps.nom,
                'distanceM': ps.distanceM,
                'azimutMil': ps.azimutMil,
              },
            )
            .toList(),
        'coupsParPieceByPiece': st.coupsParPieceByPiece,
      },
      'ui': {
        'piece': {
          'zone': zoneCtrl.text,
          'x': xCtrl.text,
          'y': yCtrl.text,
          'z': zCtrl.text,
          'lat': latCtrl.text,
          'lon': lonCtrl.text,
          'alt': altCtrl.text,
        },
        'objectif': {
          'dist': distCtrl.text,
          'az': azCtrl.text,
          'altObj': altObjCtrl.text,
          'xObj': xObjCtrl.text,
          'yObj': yObjCtrl.text,
          'zObj': zObjCtrl.text,
        },
      },
    };
  }

  Map<String, dynamic> _snapshotInputNormalized(FireRequest request) {
    return {
      'systeme': request.systeme.toString(),
      'typeTir': request.typeTir.toString(),
      'piece': {
        'utmX': request.piece.utmX,
        'utmY': request.piece.utmY,
        'altitude': request.piece.altitude,
        'utmZone': request.piece.utmZone,
        'latitude': request.piece.latitude,
        'longitude': request.piece.longitude,
      },
      'target': {
        'mode': request.target.mode.toString(),
        'utmX': request.target.utmX,
        'utmY': request.target.utmY,
        'altitude': request.target.altitude,
        'distanceM': request.target.distanceM,
        'azimutMil': request.target.azimutMil,
        'latitude': request.target.latitude,
        'longitude': request.target.longitude,
      },
      'tirVertical': request.tirVertical,
      'forcerCharge': request.forcerCharge,
      'chargeForcee': request.chargeForcee,
      'doctrine': {
        'nature': request.doctrine.nature.toString(),
        'shotPlan': {
          'nbCoups': request.doctrine.shotPlan.nbCoups,
          'par': request.doctrine.shotPlan.par,
          'coupsParPiece': request.doctrine.shotPlan.coupsParPiece,
        },
        'zonal': {
          'longueurM': request.doctrine.zonal.longueurM,
          'profondeurM': request.doctrine.zonal.profondeurM,
          'debordementPct': request.doctrine.zonal.debordementPct,
          'recouvrementPct': request.doctrine.zonal.recouvrementPct,
          'zonalMode': request.doctrine.zonal.zonalMode.toString(),
          'pointZonal': request.doctrine.zonal.pointZonal?.toString(),
          'azimutLargeurMil': request.doctrine.zonal.azimutLargeurMil,
          'azimutProfondeurMil': request.doctrine.zonal.azimutProfondeurMil,
        },
        'lineaire': {
          'referencePoint': request.doctrine.lineaire.referencePoint
              ?.toString(),
          'azimutLineaireMil': request.doctrine.lineaire.azimutLineaireMil,
          'firingMode': request.doctrine.lineaire.firingMode.toString(),
          'selectedRoles': request.doctrine.lineaire.selectedRoles,
        },
      },
      'salves': {
        'enabled': request.salves.enabled,
        'preferenceIdx': request.salves.preferenceIdx,
        'lastSalveAroundPd': request.salves.lastSalveAroundPd,
      },
      'supportPiecesCount': request.supportPieces.length,
      'masseEnabled': request.masseEnabled,
      'carreaux': request.carreaux,
      'fusee': request.fusee.toString(),
      'tirSimilaire': request.tirSimilaire,
      'meteo': request.meteo != null,
      'meteoFileName': request.meteo?.fileName,
      'meteoRowsCount': request.meteo?.rows.length ?? 0,
      'meteoStationAltM': request.meteo?.stationAltM,
      'tPrev': request.tPrev,
      'tAct': request.tAct,
      'v0Prev': request.v0Prev,
    };
  }

  Map<String, dynamic> _snapshotABloc(FireRequest request) {
    final zP = request.piece.altitude;
    final zO = request.target.altitude;
    final dz = (zP != null && zO != null) ? (zO - zP) : null;

    return {
      'systeme': request.systeme.toString(),
      'typeTir': request.typeTir.toString(),
      'charge': request.forcerCharge ? request.chargeForcee : null,
      'chargeForced': request.forcerCharge,
      'dist': request.target.distanceM,
      'azMil': request.target.azimutMil,
      'zPiece': zP,
      'zObj': zO,
      'deltaZ': dz,
      'latDeg': request.piece.latitude,
      'tirVertical': request.tirVertical,
      'objectifMode': request.target.mode.toString(),
    };
  }

  Map<String, dynamic> _snapshotOutputSafe(TirCompletOutput output) {
    final rp = output.resultatPrincipal;
    final deltaV0 = rp == null ? null : _extractDeltaV0Candidates(rp);

    return {
      'ok': rp != null,
      'resultatPrincipalType': rp?.runtimeType.toString(),
      'niveauBLocal': output.niveauBLocal,
      'siteBLocalM': output.siteBLocalM,
      'latitudePieceDeg': output.latitudePieceDeg,
      'deltaAltMet': output.deltaAltMet,
      if (deltaV0 != null) 'deltaV0Candidates': deltaV0,
    };
  }

  void syncDeltaAltFromFields({
    required TextEditingController zCtrl,
    required TextEditingController deltaAltMetCtrl,
  }) {
    final zP = _d(zCtrl.text) ?? 0.0;
    final stationAlt = _state.meteoStationAltM;
    if (stationAlt != null) {
      deltaAltMetCtrl.text = (zP - stationAlt).toStringAsFixed(0);
    }
  }

  int _computeTotalCoupsForSelection({
    required NatureTirSelection sel,
    required int piecesCount,
  }) {
    final int baseCoups =
        (sel.nbCoups ?? (sel.nature == NatureTirType.ponctuel ? 1 : 3)).clamp(
          1,
          400,
        );

    if (sel.nature == NatureTirType.zonal) {
      final l = sel.longueurZonaleM ?? sel.longueurM ?? 0.0;
      final p = sel.profondeurM ?? 0.0;
      final isSpecificSquare =
          sel.zonalMode == ZonalMode.force &&
          (sel.nbCoups ?? 0) == 8 &&
          l > 0 &&
          p > 0 &&
          (l - p).abs() <= 1.0 &&
          const <double>[
            100.0,
            150.0,
            200.0,
          ].any((size) => (l - size).abs() <= 1.0);

      if (isSpecificSquare) {
        final int nbSalves = (sel.lineairePar ?? 1).clamp(1, 3);
        return (baseCoups * nbSalves).clamp(1, 9999);
      }

      return baseCoups;
    }

    if (sel.nature == NatureTirType.ponctuel) {
      final int count = piecesCount <= 0 ? 1 : piecesCount;
      return (baseCoups * count).clamp(1, 9999);
    }

    final int par = (sel.lineairePar ?? 1).clamp(1, 12);
    return (baseCoups * par).clamp(1, 9999);
  }

  Map<String, int> _buildEquitableDistribution({
    required List<String> pieces,
    required int totalCoups,
  }) {
    if (pieces.isEmpty || totalCoups <= 0) {
      return <String, int>{};
    }

    return doctrinalRepartition(
      totalCoups: totalCoups,
      piecesOrdered: pieces,
      maxPerPiece: 9999,
    );
  }

  void applyNatureSelectionAndAutoDistribute(NatureTirSelection sel) {
    _notifier.clearResult();

    if (sel.nature == NatureTirType.ponctuel) {
      final cleanSel = sel.copyWith(
        nbCoups: sel.nbCoups ?? 1,
        lineairePar: 1,
        longueurM: 0.0,
        longueurZonaleM: 0.0,
        profondeurM: 0.0,
      );

      final int nbCoups = (cleanSel.nbCoups ?? 1).clamp(1, 400);

      _notifier.setNatureSelection(cleanSel);
      _notifier.setAutrePiecesEnabled(false);
      _notifier.setSelectedLinearRoles(const <String>[]);
      _notifier.setCoupsParPieceByPiece(<String, int>{'PD': nbCoups});
      return;
    }

    final pieces = <String>[
      'PD',
      for (final ps in _state.piecesSoutien) ps.nom,
    ];

    final int totalCoups = _computeTotalCoupsForSelection(
      sel: sel,
      piecesCount: pieces.length,
    );

    final repartition = _buildEquitableDistribution(
      pieces: pieces,
      totalCoups: totalCoups,
    );

    final bool useSeveralPieces =
        _state.piecesSoutien.isNotEmpty && totalCoups > 1;

    _notifier.setNatureSelection(sel);
    _notifier.setAutrePiecesEnabled(useSeveralPieces);
    _notifier.setCoupsParPieceByPiece(repartition);
  }

  Future<void> calculer({
    required BuildContext context,
    required TextEditingController xCtrl,
    required TextEditingController yCtrl,
    required TextEditingController zCtrl,
    required TextEditingController zoneCtrl,
    required TextEditingController latCtrl,
    required TextEditingController lonCtrl,
    required TextEditingController altCtrl,
    required TextEditingController distCtrl,
    required TextEditingController azCtrl,
    required TextEditingController altObjCtrl,
    required TextEditingController xObjCtrl,
    required TextEditingController yObjCtrl,
    required TextEditingController zObjCtrl,
    required TextEditingController latPieceDegCtrl,
    required TextEditingController deltaAltMetCtrl,
    TextEditingController? obsXCtrl,
    TextEditingController? obsYCtrl,
    TextEditingController? obsZCtrl,
    TextEditingController? obsDistCtrl,
    TextEditingController? obsAzCtrl,
    TextEditingController? obsAltObjCtrl,
    TextEditingController? obsXObjCtrl,
    TextEditingController? obsYObjCtrl,
    TextEditingController? obsZObjCtrl,
    bool forceOecl = false,
  }) async {
    if (_state.busy) return;

    final swTotal = Stopwatch()..start();
    final swCalc = Stopwatch();

    _notifier
      ..setBusy(true)
      ..clearResult();

    final traceTs = DateTime.now();
    final traceId = traceTs.microsecondsSinceEpoch.toString();

    final uiRaw = _snapshotUiRaw(
      xCtrl: xCtrl,
      yCtrl: yCtrl,
      zCtrl: zCtrl,
      zoneCtrl: zoneCtrl,
      latCtrl: latCtrl,
      lonCtrl: lonCtrl,
      altCtrl: altCtrl,
      distCtrl: distCtrl,
      azCtrl: azCtrl,
      altObjCtrl: altObjCtrl,
      xObjCtrl: xObjCtrl,
      yObjCtrl: yObjCtrl,
      zObjCtrl: zObjCtrl,
      forceOecl: forceOecl,
    );

    FireRequest? normalizedRequest;
    TirCompletOutput? computedOutput;
    String? errorStr;

    try {
      final request = FireRequestMapper.fromControllerInputs(
        header: _header,
        tirState: _state,
        xCtrl: xCtrl,
        yCtrl: yCtrl,
        zCtrl: zCtrl,
        zoneCtrl: zoneCtrl,
        latCtrl: latCtrl,
        lonCtrl: lonCtrl,
        altCtrl: altCtrl,
        distCtrl: distCtrl,
        azCtrl: azCtrl,
        altObjCtrl: altObjCtrl,
        xObjCtrl: xObjCtrl,
        yObjCtrl: yObjCtrl,
        zObjCtrl: zObjCtrl,
        obsXCtrl: obsXCtrl,
        obsYCtrl: obsYCtrl,
        obsZCtrl: obsZCtrl,
        obsDistCtrl: obsDistCtrl,
        obsAzCtrl: obsAzCtrl,
        obsAltObjCtrl: obsAltObjCtrl,
        obsXObjCtrl: obsXObjCtrl,
        obsYObjCtrl: obsYObjCtrl,
        obsZObjCtrl: obsZObjCtrl,
        forceOecl: forceOecl,
      );

      normalizedRequest = request;

      if (_traceEnabled) {
        _tracePrintJsonLine({
          'kind': 'A',
          'id': traceId,
          'ts': traceTs.toIso8601String(),
          'A': _snapshotABloc(request),
        });
      }

      await _securityService.verifyExecutionAllowed();

      swCalc.start();
      final TirCompletOutput output = await _usecase.run(request);
      swCalc.stop();

      if (kDebugMode) {
        debugPrint(
          '[APPUI PERF] calc=${swCalc.elapsedMicroseconds} µs '
          '(${(swCalc.elapsedMicroseconds / 1000).toStringAsFixed(3)} ms)',
        );
      }

      computedOutput = output;

      _applyTirCompletOutput(
        output,
        request: request,
        latPieceDegCtrl: latPieceDegCtrl,
        deltaAltMetCtrl: deltaAltMetCtrl,
      );
    } catch (e, st) {
      errorStr = e.toString();

      if (kDebugMode) {
        debugPrint('[CALC_TRACE] error=$e\n$st');
      }

      final msg = e.toString();

      if (msg.contains('HorsPortee')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Range outside firing area.')),
          );
        }
        return;
      }

      rethrow;
    } finally {
      swTotal.stop();

      if (kDebugMode) {
        debugPrint(
          '[APPUI PERF] total=${swTotal.elapsedMicroseconds} µs '
          '(${(swTotal.elapsedMicroseconds / 1000).toStringAsFixed(3)} ms)',
        );
      }

      if (_traceEnabled) {
        _tracePrintJsonLine({
          'kind': 'calc_trace',
          'id': traceId,
          'ts': traceTs.toIso8601String(),
          'uiRaw': uiRaw,
          if (normalizedRequest != null)
            'input': _snapshotInputNormalized(normalizedRequest),
          if (computedOutput != null)
            'output': _snapshotOutputSafe(computedOutput),
          if (errorStr != null) 'error': errorStr,
        });
      }

      _notifier.setBusy(false);
    }
  }

  void _applyTirCompletOutput(
    TirCompletOutput output, {
    required FireRequest request,
    required TextEditingController latPieceDegCtrl,
    required TextEditingController deltaAltMetCtrl,
  }) {
    if (output.resultatPrincipal == null) {
      if (kDebugMode) {
        debugPrint(
          '[CALC_TRACE] TirCompletOutput received without resultatPrincipal '
          '(niveauBLocal=${output.niveauBLocal}, '
          'siteBLocalM=${output.siteBLocalM}).',
        );
      }
      return;
    }

    _notifier.setResult(
      result: output.resultatPrincipal!,
      request: request,
      output: output,
      niveauBLocal: output.niveauBLocal.toDouble(),
      siteBLocalM: output.siteBLocalM.toDouble(),
      latitudePieceDeg: output.latitudePieceDeg.toDouble(),
      deltaAltMet: output.deltaAltMet.toDouble(),
    );

    latPieceDegCtrl.text = output.latitudePieceDeg.toStringAsFixed(6);
    deltaAltMetCtrl.text = output.deltaAltMet.toStringAsFixed(0);
  }

  Future<void> handleMasseChanged(BuildContext context, bool enabled) async {
    if (!enabled) {
      _notifier.setMasseEnabled(false);
      return;
    }

    final value = await showCarreauxDialog(
      context: context,
      dark: _header.dark,
      initialCarreaux: _state.carreaux,
    );

    if (value == null) {
      _notifier.setMasseEnabled(false);
      return;
    }

    _notifier
      ..setCarreaux(value)
      ..setMasseEnabled(true);
  }

  Future<void> handleTirSimilaireChanged(
    BuildContext context,
    bool enabled, {
    TextEditingController? distanceCtrl,
  }) async {
    if (!enabled) {
      _notifier.setTirSimilaireEnabled(false);
      return;
    }

    final s = _state;
    final systeme = _header.systeme;

    if (systeme == Systeme.mo81M252) {
      if (_header.typeTir != TypeTir.appui ||
          !BalistiqueMo81M252AppuiService.supportsMunition(
            _header.m252MunitionFamily,
          )) {
        _notifier.setTirSimilaireEnabled(false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Powder-temperature correction is available only for '
                'M252 Part 6 / CH3 support fire.',
              ),
            ),
          );
        }
        return;
      }

      final currentTemperatureC = await showMo81PowderTemperatureDialog(
        context: context,
        dark: _header.dark,
        charge: BalistiqueMo81M252AppuiService.charge,
        referenceTemperatureC:
            BalistiqueMo81M252AppuiService.referencePowderTemperatureC,
        initialTemperatureC:
            s.tAct ??
            BalistiqueMo81M252AppuiService.referencePowderTemperatureC,
        initialUnit: PowderTemperatureUnit.fahrenheit,
      );

      if (currentTemperatureC == null) {
        _notifier.setTirSimilaireEnabled(false);
        return;
      }

      _notifier.setTirSimilaireMo81M252(
        temperaturePoudreActuelleC: currentTemperatureC,
      );

      if (kDebugMode) {
        debugPrint(
          '[M252 POWDER TEMPERATURE] '
          'charge=${BalistiqueMo81M252AppuiService.charge} '
          'reference=${BalistiqueMo81M252AppuiService.referencePowderTemperatureF.toStringAsFixed(1)}°F '
          'current=${currentTemperatureC.toStringAsFixed(1)}°C',
        );
      }
      return;
    }

    if (systeme == Systeme.mo81Lrr) {
      final TypeMunition? munition =
          s.typeMunition ??
          munitionParDefautPour(systeme: systeme, typeTir: _header.typeTir);

      if (munition == null) {
        _notifier.setTirSimilaireEnabled(false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('MO81 LLR: no munition selected.')),
          );
        }
        return;
      }

      if (_header.typeTir == TypeTir.eclairant &&
          munition != TypeMunition.oecl81F1 &&
          munition != TypeMunition.oecl81F3 &&
          munition != TypeMunition.oeclIr81F2) {
        _notifier.setTirSimilaireEnabled(false);

        if (kDebugMode) {
          debugPrint(
            '[MO81 LLR SIMILAR FIRE] ignored: '
            'illuminating munition not connected ($munition)',
          );
        }

        return;
      }

      late final String charge;
      Mo81LlrChargeChoice? autoChoice;

      if (s.forcerCharge && s.chargeForcee != null) {
        charge = Mo81LlrInitialConditions.normalizeCharge(
          s.chargeForcee.toString(),
        );
      } else {
        final distanceM = _d(distanceCtrl?.text);

        if (distanceM == null || distanceM <= 0) {
          _notifier.setTirSimilaireEnabled(false);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'MO81 LLR: provide the target distance before '
                  'activating similar fire.',
                ),
              ),
            );
          }
          return;
        }

        try {
          autoChoice = await Mo81LlrChargeSelector.selectForDistance(
            distanceM: distanceM,
            munition: munition,
            verbose: kDebugMode,
          );
          charge = autoChoice.charge;

          if (kDebugMode) {
            debugPrint(
              '[MO81 LLR SIMILAR FIRE] '
              'munition=$munition '
              'selection D=${distanceM.toStringAsFixed(1)} m '
              '=> $charge '
              'elevation=${autoChoice.hausseMil.toStringAsFixed(2)} mil',
            );
          }
        } catch (e) {
          _notifier.setTirSimilaireEnabled(false);
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(e.toString())));
          }
          return;
        }
      }

      late final double v0Reference;

      try {
        v0Reference = Mo81LlrInitialConditions.v0ForMunitionAndCharge(
          munition,
          charge,
        );
      } catch (e) {
        _notifier.setTirSimilaireEnabled(false);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
        return;
      }

      if (!context.mounted) {
        _notifier.setTirSimilaireEnabled(false);
        return;
      }

      final double? tempActuelle = await showMo81PowderTemperatureDialog(
        context: context,
        dark: _header.dark,
        charge: charge,
        referenceTemperatureC: Mo81LlrInitialConditions.temperatureReferenceC,
        initialTemperatureC:
            s.tAct ?? Mo81LlrInitialConditions.temperatureReferenceC,
      );

      if (tempActuelle == null) {
        _notifier.setTirSimilaireEnabled(false);
        return;
      }

      _notifier.setTirSimilaireMo81Llr(
        tempPoudreActuelleC: tempActuelle,
        v0ReferenceMps: v0Reference,
      );

      if (kDebugMode) {
        debugPrint(
          '[MO81 LLR SIMILAR FIRE] '
          'munition=$munition '
          'charge=$charge '
          'V0ref=${v0Reference.toStringAsFixed(1)} m/s '
          'Tref=${Mo81LlrInitialConditions.temperatureReferenceC.toStringAsFixed(0)}°C '
          'Tact=${tempActuelle.toStringAsFixed(1)}°C',
        );
      }

      return;
    }

    final TypeMunition? tirSimMunition =
        s.typeMunition ??
        munitionParDefautPour(systeme: systeme, typeTir: _header.typeTir);

    final FuseeCompatibility tirSimCompatibility = fuseeCompatibilityPour(
      systeme: systeme,
      typeTir: _header.typeTir,
      munition: tirSimMunition,
    );

    final TypeFusee tirSimInitialFusee = tirSimCompatibility.normalise(
      s.simFusee ?? tirSimCompatibility.reference,
    );

    final double? initialV0TirSim = systeme == Systeme.mo120 ? null : s.v0Prev;

    // Les systèmes MO81 ne possèdent pas de réglage « carreaux » utilisable
    // par le moteur. Le dialogue de tir similaire reste cependant utile pour
    // saisir ses données ; on fixe alors sa valeur actuelle au lieu d'appeler
    // SystemeX.carreauxPlage, qui lève volontairement une exception pour MO81.
    final int currentCarreaux = s.simCarreaux.clamp(1, 8);
    final (int, int) carreauxRange = switch (systeme) {
      Systeme.caesar => (1, 8),
      Systeme.mepac || Systeme.mo120 => (1, 3),
      Systeme.mo81M252 || Systeme.mo81Lrr => (currentCarreaux, currentCarreaux),
    };

    if (kDebugMode) {
      debugPrint(
        '[SIMILAR FIRE INPUT] '
        'systeme=$systeme '
        'state.v0Prev=${s.v0Prev} '
        'initialV0=$initialV0TirSim '
        'tPrev=${s.tPrev} '
        'tAct=${s.tAct} '
        'carreauxRange=${carreauxRange.$1}-${carreauxRange.$2}',
      );
    }

    final res = await showTirSimilaireDialog(
      context: context,
      dark: _header.dark,
      initialCarreaux: s.simCarreaux,
      initialFusee: tirSimInitialFusee,
      fuseesDisponibles: tirSimCompatibility.autorisees,
      initialTPrev: s.tPrev,
      initialTAct: s.tAct,
      initialV0: initialV0TirSim,
      minCarreaux: carreauxRange.$1,
      maxCarreaux: carreauxRange.$2,
    );

    if (kDebugMode) {
      debugPrint(
        '[SIMILAR FIRE OUTPUT] '
        'systeme=$systeme '
        'v0Prev=${res?.v0Prev} '
        'tPrev=${res?.tPrev} '
        'tAct=${res?.tAct}',
      );
    }

    if (res == null) {
      _notifier.setTirSimilaireEnabled(false);
      return;
    }

    final double? validatedV0 = res.v0Prev;
    if (validatedV0 != null && (!validatedV0.isFinite || validatedV0 <= 0.0)) {
      _notifier.setTirSimilaireEnabled(false);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Previous V0 invalid.')));
      }
      return;
    }

    _notifier.setTirSimilaireValues(
      carreaux: res.carreaux,
      fusee: res.fusee,
      tPrev: res.tPrev,
      tAct: res.tAct,
      v0: validatedV0,
    );

    final updated = _state;
    final TypeMunition? munition =
        updated.typeMunition ??
        munitionParDefautPour(systeme: systeme, typeTir: updated.typeTir);

    final compatibility = fuseeCompatibilityPour(
      systeme: systeme,
      typeTir: updated.typeTir,
      munition: munition,
    );

    final TypeFusee fuseeProposee = compatibility.normalise(res.fusee);
    final TypeFusee fuseeCourante = compatibility.normalise(updated.fusee);

    if (!compatibility.estVerrouillee &&
        fuseeProposee != fuseeCourante &&
        context.mounted) {
      final picked = await showFuseeDialog(
        context: context,
        dark: _header.dark,
        initial: fuseeProposee,
        fuseesAutorisees: compatibility.autorisees,
      );

      if (picked != null) {
        _notifier.setFusee(picked);
      }
    }
  }

  Future<void> handleMeteoChanged(
    BuildContext context,
    bool enabled, {
    required TextEditingController zCtrl,
    required TextEditingController deltaAltMetCtrl,
  }) async {
    if (!enabled) {
      _notifier.clearMeteo();
      deltaAltMetCtrl.text = '';
      return;
    }

    final header = ref.read(tirHeaderProvider);

    final res = await showMeteoPickerDialog(
      context: context,
      dark: header.dark,
    );

    if (res == null) {
      _notifier.clearMeteo();
      return;
    }

    _notifier.setMeteoLoaded(
      fileName: res.fileName,
      rows: res.rows,
      stationAltM: res.stationAltM?.toDouble(),
    );

    syncDeltaAltFromFields(zCtrl: zCtrl, deltaAltMetCtrl: deltaAltMetCtrl);
  }

  Future<void> handleForcerChargeChanged(
    BuildContext context,
    bool enabled,
  ) async {
    if (!enabled) {
      _notifier.clearChargeForcee();
      return;
    }

    final picked = await showChargeDialog(
      context: context,
      dark: _header.dark,
      initialCharge: _state.chargeForcee,
    );

    if (picked == null) {
      _notifier.clearChargeForcee();
      return;
    }

    _notifier.setChargeForcee(picked);
  }

  void addPieceSoutien() {
    final s = _state;
    if (s.piecesSoutien.length >= 7) return;

    final idx = s.piecesSoutien.length + 1;
    _notifier.addPieceSoutien(
      PieceSoutien(nom: 'PS$idx', distanceM: 300, azimutMil: 1200),
    );

    final updatedState = _state;
    final sel = updatedState.natureSelection;

    if (updatedState.natureEnabled && sel != null) {
      applyNatureSelectionAndAutoDistribute(sel);
    }
  }

  void removeLastPieceSoutien() {
    final s = _state;
    if (s.piecesSoutien.isEmpty) return;

    _notifier.removeLastPieceSoutien();

    final updatedState = _state;
    final sel = updatedState.natureSelection;

    if (updatedState.natureEnabled && sel != null) {
      applyNatureSelectionAndAutoDistribute(sel);
    } else {
      _notifier.setAutrePiecesEnabled(updatedState.piecesSoutien.isNotEmpty);
    }
  }

  void initPiecesSoutienOffsetsFromPD({
    required double distancePD,
    required double azimutPD,
  }) {
    final s = _state;
    if (s.piecesSoutien.isEmpty) return;

    final updated = <PieceSoutien>[];

    for (final ps in s.piecesSoutien) {
      updated.add(
        ps.copyWith(
          distanceM: ps.distanceM == 0 ? distancePD : ps.distanceM,
          azimutMil: ps.azimutMil == 0 ? azimutPD : ps.azimutMil,
        ),
      );
    }

    _notifier.setPiecesSoutien(updated);
  }
}
