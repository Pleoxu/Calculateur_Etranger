// lib/presentation/fire/services/message_pd_report_capture.dart

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class MessagePdCapturedMaps {
  const MessagePdCapturedMaps({
    this.battery,
    this.global,
    this.impact,
    this.red,
  });

  final Uint8List? battery;
  final Uint8List? global;
  final Uint8List? impact;
  final Uint8List? red;
}

class MessagePdReportCapture {
  final GlobalKey batteryMapKey = GlobalKey();
  final GlobalKey globalMapKey = GlobalKey();
  final GlobalKey impactMapKey = GlobalKey();
  final GlobalKey redMapKey = GlobalKey();

  Future<MessagePdCapturedMaps> captureAll() async {
    await WidgetsBinding.instance.endOfFrame;

    return MessagePdCapturedMaps(
      battery: await _capture(batteryMapKey),
      global: await _capture(globalMapKey),
      impact: await _capture(impactMapKey),
      red: await _capture(redMapKey),
    );
  }

  Future<Uint8List?> _capture(GlobalKey key) async {
    final context = key.currentContext;
    if (context == null) return null;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;

    // Ne pas lire debugNeedsPaint ici :
    // en iOS profile, cet accès peut lever un LateInitializationError.
    // On attend simplement la fin de frame avant la capture.
    await WidgetsBinding.instance.endOfFrame;

    final image = await renderObject.toImage(pixelRatio: 2.0);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}
