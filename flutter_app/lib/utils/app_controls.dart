import 'dart:io';
import 'package:flutter/services.dart';

class AppControls {
  static const MethodChannel _ch = MethodChannel('app/control');

  static Future<void> moveToBackground() async {
    if (!Platform.isAndroid) return; // iOS not supported
    try {
      await _ch.invokeMethod('moveTaskToBack');
    } catch (_) {
      // no-op
    }
  }
}

