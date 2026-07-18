import 'package:flutter/material.dart';

class MapInteractionController {
  MapInteractionController._();
  static final instance = MapInteractionController._();

  final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);
  int _locks = 0;

  void acquire() {
    _locks++;
    if (enabled.value) enabled.value = false;
  }

  void release() {
    if (_locks > 0) _locks--;
    if (_locks == 0 && !enabled.value) enabled.value = true;
  }

  Future<T> runLocked<T>(Future<T> Function() fn) async {
    acquire();
    try {
      return await fn();
    } finally {
      release();
    }
  }
}
