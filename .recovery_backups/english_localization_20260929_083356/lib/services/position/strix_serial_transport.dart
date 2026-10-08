// lib/services/position/strix_serial_transport.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

class StrixSerialTransport {
  StrixSerialTransport({
    this.preferredPort = '/dev/cu.usbserial-B003L0V8',
    this.baudRate = 115200,
  });

  final String preferredPort;
  final int baudRate;

  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _sub;

  final StreamController<List<int>> _controller =
      StreamController<List<int>>.broadcast();

  Stream<List<int>> get bytes => _controller.stream;

  bool get isOpen => _port?.isOpen == true;

  List<String> get availablePorts => SerialPort.availablePorts;

  Future<void> start() async {
    // Démarrage idempotent : si le STRIX est déjà ouvert, on conserve
    // le reader natif existant au lieu de fermer/réouvrir le port.
    if (isOpen && _reader != null && _sub != null) {
      debugPrint('[STRIX USB] déjà connecté — réutilisation du port');
      return;
    }

    final ports = SerialPort.availablePorts;
    debugPrint('[STRIX USB] ports=$ports');

    final portName = _selectPort(ports);
    if (portName == null) {
      throw StateError(
        'STRIX : aucun port USB série trouvé. '
        'Ports détectés: ${ports.join(', ')}',
      );
    }

    final port = SerialPort(portName);
    _port = port;

    if (!port.openRead()) {
      final err = SerialPort.lastError;
      port.dispose();
      _port = null;
      throw StateError('STRIX : ouverture impossible $portName : $err');
    }

    final config = SerialPortConfig()
      ..baudRate = baudRate
      ..bits = 8
      ..parity = SerialPortParity.none
      ..stopBits = 1
      ..setFlowControl(SerialPortFlowControl.none);

    try {
      port.config = config;
    } finally {
      config.dispose();
    }

    final reader = SerialPortReader(port);
    _reader = reader;

    _sub = reader.stream.listen(
      (Uint8List data) {
        if (!_controller.isClosed && data.isNotEmpty) {
          _controller.add(data);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[STRIX USB] erreur lecture: $error');
        if (!_controller.isClosed) {
          _controller.addError(error, stackTrace);
        }
      },
      cancelOnError: false,
    );

    debugPrint(
      '[STRIX USB] connecté port=$portName '
      'baud=$baudRate 8N1',
    );
  }

  String? _selectPort(List<String> ports) {
    if (ports.contains(preferredPort)) return preferredPort;

    for (final p in ports) {
      final lower = p.toLowerCase();
      if (lower.contains('usbserial') || lower.contains('usbmodem')) {
        return p;
      }
    }

    return null;
  }

  /// Fermeture physique du transport.
  ///
  /// À réserver à la destruction finale du coordinateur. Pendant l'utilisation
  /// normale, le bouton "GPS off" doit uniquement détacher les abonnements
  /// applicatifs et laisser ce reader ouvert.
  Future<void> stop() async {
    final sub = _sub;
    _sub = null;
    if (sub != null) {
      await sub.cancel();
    }

    final reader = _reader;
    _reader = null;
    reader?.close();

    final port = _port;
    _port = null;

    if (port != null) {
      if (port.isOpen) {
        port.close();
      }
      port.dispose();
    }

    debugPrint('[STRIX USB] transport fermé');
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
