import 'dart:async';

/// Owns one subscription to a purchase event stream for the app lifetime.
class SharedPurchaseStreamListener<T> {
  StreamSubscription<T>? _subscription;
  void Function(Object error)? _errorHandler;

  bool get isListening => _subscription != null;

  void ensureListening({
    required Stream<T> stream,
    required Future<void> Function(T event) onEvent,
    required void Function(Object error) onError,
    required void Function() onDone,
  }) {
    if (_subscription != null) return;
    _errorHandler = onError;

    late final StreamSubscription<T> subscription;
    subscription = stream.listen(
      (event) => unawaited(_dispatch(event, onEvent, onError)),
      onError: (Object error, StackTrace stackTrace) {
        _reportError(error, onError);
      },
      onDone: () {
        if (identical(_subscription, subscription)) {
          _subscription = null;
          _errorHandler = null;
          try {
            onDone();
          } catch (error) {
            _reportError(error, onError);
          }
        }
      },
      cancelOnError: false,
    );
    _subscription = subscription;
  }

  Future<void> _dispatch(
    T event,
    Future<void> Function(T event) onEvent,
    void Function(Object error) onError,
  ) async {
    try {
      await onEvent(event);
    } catch (error) {
      _reportError(error, onError);
    }
  }

  void _reportError(Object error, void Function(Object error) onError) {
    try {
      onError(error);
    } catch (_) {
      // A UI callback must not break the shared StoreKit listener.
    }
  }

  Future<void> cancel() async {
    final subscription = _subscription;
    final onError = _errorHandler;
    _subscription = null;
    _errorHandler = null;
    try {
      await subscription?.cancel();
    } catch (error) {
      if (onError != null) _reportError(error, onError);
    }
  }
}
