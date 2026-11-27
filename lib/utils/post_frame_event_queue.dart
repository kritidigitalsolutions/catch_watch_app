import 'dart:collection';

typedef PostFrameScheduler = void Function(void Function() callback);

/// Deduplicates queued items by key and drains them once the app has a frame
/// boundary and the consumer is ready.
class PostFrameEventQueue<T> {
  final LinkedHashMap<String, T> _events = LinkedHashMap<String, T>();
  bool _drainScheduled = false;

  int get length => _events.length;

  void add(String key, T event) {
    _events[key] = event;
  }

  void scheduleDrain({
    required bool Function() isReady,
    required PostFrameScheduler schedulePostFrame,
    required void Function(T event) onEvent,
  }) {
    if (_events.isEmpty || _drainScheduled) return;
    _drainScheduled = true;
    schedulePostFrame(() {
      _drainScheduled = false;
      if (!isReady() || _events.isEmpty) return;

      final events = List<T>.of(_events.values);
      _events.clear();
      for (final event in events) {
        onEvent(event);
      }
    });
  }
}
