// lib/services/radio/radio_import_service.dart

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:calculateur_etranger/domain/radio/radio_position_message.dart';

import 'package:calculateur_etranger/presentation/fire/models/piece_soutien.dart';

import 'package:calculateur_etranger/services/radio/position_repository.dart';
import 'package:calculateur_etranger/services/radio/radio_position_mapper.dart';

import 'package:calculateur_etranger/services/simulation/radio_position_simulator.dart';

class RadioImportService {
  final RadioPositionSimulator simulator;
  final PositionRepository repository;
  final RadioPositionMapper mapper;

  RadioImportService({
    required this.simulator,
    required this.repository,
    required this.mapper,
  });

  StreamSubscription<RadioPositionMessage>? _sub;

  Future<List<PieceSoutien>> importSimulation() async {
    repository.clear();

    _sub = simulator.stream.listen((msg) {
      repository.update(msg);

      debugPrint(
        '[RADIO RX] '
        'id=${msg.id} '
        'type=${msg.type.name} '
        'x=${msg.x} '
        'y=${msg.y} '
        'z=${msg.z}',
      );
    });

    await simulator.start();

    await Future.delayed(const Duration(milliseconds: 100));

    final pd = repository.pd;

    if (pd == null) {
      throw StateError('[RADIO] PD absente');
    }

    final pieces = mapper.toPiecesSoutien(pd: pd, supports: repository.ps);

    debugPrint('[RADIO IMPORT] pieces=${pieces.length}');

    return pieces;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await simulator.stop();
  }
}
