import 'dart:async';

import '../../domain/radio/radio_position_message.dart';

abstract class RadioPositionProvider {
  Stream<RadioPositionMessage> get stream;

  Future<void> start();

  Future<void> stop();
}
