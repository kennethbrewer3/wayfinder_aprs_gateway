import 'dart:async';
import 'dart:collection';

class RetryQueue {
  RetryQueue({
    required this.maxSize,
    required this.onFlush,
  });

  final int maxSize;
  final Future<bool> Function(Map<String, dynamic> payload) onFlush;

  final _queue = Queue<Map<String, dynamic>>();
  Timer? _timer;
  var _flushing = false;

  void start(Duration interval) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(flush()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void enqueue(Map<String, dynamic> payload) {
    if (_queue.length >= maxSize) {
      _queue.removeFirst();
    }
    _queue.addLast(Map<String, dynamic>.from(payload));
  }

  Future<void> flush() async {
    if (_flushing || _queue.isEmpty) return;

    _flushing = true;
    try {
      while (_queue.isNotEmpty) {
        final payload = _queue.first;
        final success = await onFlush(payload);
        if (!success) break;
        _queue.removeFirst();
      }
    } finally {
      _flushing = false;
    }
  }

  int get length => _queue.length;
}
