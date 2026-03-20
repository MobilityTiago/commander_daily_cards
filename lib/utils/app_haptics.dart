import 'package:flutter/services.dart';

abstract final class AppHaptics {
  static void selection() {
    HapticFeedback.selectionClick();
  }

  static void confirm() {
    HapticFeedback.mediumImpact();
  }

  static void longPress() {
    HapticFeedback.heavyImpact();
  }
}