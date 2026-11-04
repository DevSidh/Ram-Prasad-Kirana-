import 'dart:async';

/// Serializes admitted scans/actions without debouncing or coalescing them.
/// Each caller receives its own result; a failed action never poisons the tail.
class OrderedWorkQueue {
  Future<void> _tail = Future<void>.value();
  int _pending = 0;
  bool _closed = false;

  int get pending => _pending;

  Future<T> run<T>(Future<T> Function() action) {
    if (_closed) return Future<T>.error(StateError('Queue is closed.'));
    _pending++;
    final result = _tail.then((_) {
      if (_closed) throw StateError('Queue is closed.');
      return action();
    });
    _tail = result
        .then<void>((_) {}, onError: (Object _, StackTrace __) {})
        .whenComplete(() => _pending--);
    return result;
  }

  /// Already-running work completes normally; queued actions do not start.
  void close() => _closed = true;
}
