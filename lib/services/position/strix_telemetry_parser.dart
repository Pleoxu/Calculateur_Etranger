// lib/services/position/strix_telemetry_parser.dart
import 'dart:typed_data';

class StrixRoverPosition {
  final double latitude;
  final double longitude;
  final double altitudeMslMeters;
  final int fixType;
  final int satellitesUsed;
  final int carrierSolution;
  final double pdop;

  const StrixRoverPosition({
    required this.latitude,
    required this.longitude,
    required this.altitudeMslMeters,
    required this.fixType,
    required this.satellitesUsed,
    required this.carrierSolution,
    required this.pdop,
  });

  bool get hasValidPosition =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      fixType != 0;
}

class StrixTelemetryParser {
  static const int sync1 = 0xAA;
  static const int sync2 = 0x55;
  static const int v8PayloadLength = 247;

  final List<int> _buffer = <int>[];

  List<StrixRoverPosition> addBytes(List<int> bytes) {
    if (bytes.isNotEmpty) _buffer.addAll(bytes);
    final out = <StrixRoverPosition>[];

    while (true) {
      final syncIndex = _findSync();
      if (syncIndex < 0) {
        if (_buffer.isNotEmpty && _buffer.last == sync1) {
          _buffer
            ..clear()
            ..add(sync1);
        } else {
          _buffer.clear();
        }
        break;
      }

      if (syncIndex > 0) _buffer.removeRange(0, syncIndex);
      if (_buffer.length < 4) break;

      final length = _buffer[2] | (_buffer[3] << 8);
      if (length < 1 || length > 256) {
        _buffer.removeAt(0);
        continue;
      }

      final totalLength = 4 + length + 2;
      if (_buffer.length < totalLength) break;

      final frame = Uint8List.fromList(_buffer.sublist(0, totalLength));
      _buffer.removeRange(0, totalLength);

      final payload = Uint8List.sublistView(frame, 4, 4 + length);
      if (payload.isEmpty) continue;

      final crcReceived = frame[4 + length] | (frame[5 + length] << 8);
      if (crcReceived != _crc16CcittFalse(payload)) continue;

      if (payload[0] != 8 || length != v8PayloadLength) continue;

      final pos = _decodeV8Rover(payload);
      if (pos != null && pos.hasValidPosition) out.add(pos);
    }

    return out;
  }

  void reset() => _buffer.clear();

  int _findSync() {
    for (var i = 0; i + 1 < _buffer.length; i++) {
      if (_buffer[i] == sync1 && _buffer[i + 1] == sync2) return i;
    }
    return -1;
  }

  StrixRoverPosition? _decodeV8Rover(Uint8List payload) {
    if (payload.length != v8PayloadLength) return null;
    final bd = ByteData.sublistView(payload);

    return StrixRoverPosition(
      latitude: bd.getFloat32(59, Endian.little),
      longitude: bd.getFloat32(63, Endian.little),
      altitudeMslMeters: bd.getFloat32(67, Endian.little),
      fixType: bd.getUint8(83),
      satellitesUsed: bd.getUint8(84),
      carrierSolution: bd.getUint8(85),
      pdop: bd.getUint16(86, Endian.little) / 100.0,
    );
  }

  int _crc16CcittFalse(Uint8List data) {
    var crc = 0xFFFF;
    for (final byte in data) {
      crc ^= byte << 8;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 0x8000) != 0
            ? ((crc << 1) ^ 0x1021) & 0xFFFF
            : (crc << 1) & 0xFFFF;
      }
    }
    return crc;
  }
}
