// Debouncer utility — reusable across the app.
//
// Usage:
//   final _debouncer = Debouncer(Duration(milliseconds: 250));
//   _debouncer.call(() { /* work to debounce */ });
//   await _debouncer.runOnce(() async => await asyncWork());
//
// Remember to dispose when no longer needed: _debouncer.dispose();
import 'dart:async';
import 'package:flutter/foundation.dart';

class Debouncer {
  final Duration delay;
  Timer? _timer;
  VoidCallback? _pendingSyncAction;
  FutureOr<dynamic> Function()? _pendingAsyncAction;

  Debouncer([this.delay = const Duration(milliseconds: 250)]);

  /// Schedule a synchronous [action] to run after [delay].
  /// Subsequent calls reset the timer.
  void call(VoidCallback action) {
    _pendingSyncAction = action;
    _timer?.cancel();
    _timer = Timer(delay, () {
      final a = _pendingSyncAction;
      _pendingSyncAction = null;
      try {
        a?.call();
      } catch (e, st) {
        if (kDebugMode) debugPrint('Debouncer.call error: $e\n$st');
      }
    });
  }

  /// Schedule an async [action] to run after [delay] and return its result.
  /// If called again before execution, the previous scheduled action is cancelled.
  Future<T?> runOnce<T>(FutureOr<T> Function() action) {
    _pendingAsyncAction = action;
    final completer = Completer<T?>();
    _timer?.cancel();
    _timer = Timer(delay, () async {
      final a = _pendingAsyncAction;
      _pendingAsyncAction = null;
      if (a == null) {
        completer.complete(null);
        return;
      }
      try {
        final result = await a();
        if (!completer.isCompleted) completer.complete(result);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
        if (kDebugMode) debugPrint('Debouncer.runOnce error: $e\n$st');
      }
    });
    return completer.future;
  }

  /// Cancel any pending scheduled action.
  void cancel() {
    _pendingSyncAction = null;
    _pendingAsyncAction = null;
    _timer?.cancel();
    _timer = null;
  }

  /// Immediately execute pending action (if any) and cancel timer.
  /// For async pending action, returns its result.
  Future<T?> flush<T>() async {
    if (_timer == null) return null;
    final sync = _pendingSyncAction;
    final asyncAct = _pendingAsyncAction;
    cancel();
    if (asyncAct != null) {
      try {
        return await asyncAct() as T?;
      } catch (e, st) {
        if (kDebugMode) debugPrint('Debouncer.flush error: $e\n$st');
        rethrow;
      }
    } else if (sync != null) {
      try {
        sync();
      } catch (e, st) {
        if (kDebugMode) debugPrint('Debouncer.flush error: $e\n$st');
      }
    }
    return null;
  }

  /// Dispose resources.
  void dispose() => cancel();
}
