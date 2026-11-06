import 'dart:async';
import 'package:flutter/foundation.dart';

/// A coalesced refresh signal, never a second source of stock or sales data.
class InventoryChanges {
  static final revision = ValueNotifier<int>(0);
  static bool _scheduled = false;
  static void notify() {
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      revision.value++;
    });
  }
}
