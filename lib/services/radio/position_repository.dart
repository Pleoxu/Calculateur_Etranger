import 'package:calculateur_etranger/domain/radio/radio_position_message.dart';

class PositionRepository {
  final Map<String, RadioPositionMessage> _positions = {};

  void update(RadioPositionMessage msg) {
    final id = msg.id.trim().toUpperCase();
    final previous = _positions[id];

    if (previous != null && msg.timestamp.isBefore(previous.timestamp)) {
      return;
    }

    _positions[id] = msg;
  }

  void updateAll(Iterable<RadioPositionMessage> messages) {
    for (final msg in messages) {
      update(msg);
    }
  }

  RadioPositionMessage? getById(String id) {
    return _positions[id.trim().toUpperCase()];
  }

  RadioPositionMessage? get pd {
    return _positions['PD'];
  }

  List<RadioPositionMessage> get ps {
    final list =
        _positions.values.where((p) => p.type == RadioNodeType.ps).toList();

    list.sort((a, b) => _pieceOrder(a.id).compareTo(_pieceOrder(b.id)));
    return list;
  }

  List<RadioPositionMessage> get all {
    final list = _positions.values.toList();
    list.sort((a, b) => _pieceOrder(a.id).compareTo(_pieceOrder(b.id)));
    return list;
  }

  bool get hasPd => pd != null;

  bool get hasSupportPieces => ps.isNotEmpty;

  bool isEmpty() => _positions.isEmpty;

  void clear() {
    _positions.clear();
  }

  static int _pieceOrder(String id) {
    final normalized = id.trim().toUpperCase();
    if (normalized == 'PD') return 0;

    final match = RegExp(r'^PS(\d+)$').firstMatch(normalized);
    if (match == null) return 999;

    return int.tryParse(match.group(1) ?? '') ?? 999;
  }
}
