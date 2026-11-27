import 'dart:async';

import 'package:catch_watch/utils/iap_transaction_deduplicator.dart';
import 'package:catch_watch/utils/shared_purchase_stream_listener.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SharedPurchaseStreamListener', () {
    test('can be started during application startup', () async {
      var listenCount = 0;
      final stream = StreamController<int>.broadcast(
        onListen: () => listenCount++,
      );
      final listener = SharedPurchaseStreamListener<int>();

      listener.ensureListening(
        stream: stream.stream,
        onEvent: (_) async {},
        onError: (_) {},
        onDone: () {},
      );

      expect(listener.isListening, isTrue);
      expect(listenCount, 1);
      await listener.cancel();
      await stream.close();
    });

    test(
      'repeated screen initialization keeps one stream subscription',
      () async {
        var listenCount = 0;
        var eventCount = 0;
        final stream = StreamController<int>.broadcast(
          onListen: () => listenCount++,
        );
        final listener = SharedPurchaseStreamListener<int>();
        void initialize() => listener.ensureListening(
          stream: stream.stream,
          onEvent: (_) async => eventCount++,
          onError: (_) {},
          onDone: () {},
        );

        initialize();
        initialize();
        initialize();
        stream.add(1);
        await Future<void>.delayed(Duration.zero);

        expect(listenCount, 1);
        expect(eventCount, 1);
        await listener.cancel();
        await stream.close();
      },
    );

    test('duplicate stream events reach verification once', () async {
      const transactionKey = 'monthly|original-1|transaction-1';
      final deduplicator = IapTransactionDeduplicator();
      var verificationCount = 0;
      final stream = StreamController<String>.broadcast();
      final listener = SharedPurchaseStreamListener<String>();
      listener.ensureListening(
        stream: stream.stream,
        onEvent: (key) async {
          if (!deduplicator.tryStart(key)) return;
          verificationCount++;
          deduplicator.markVerified(key);
        },
        onError: (_) {},
        onDone: () {},
      );

      stream
        ..add(transactionKey)
        ..add(transactionKey);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(verificationCount, 1);
      await listener.cancel();
      await stream.close();
    });

    test(
      'stream errors are reported without canceling event delivery',
      () async {
        final stream = StreamController<int>.broadcast();
        final listener = SharedPurchaseStreamListener<int>();
        var errorCount = 0;
        var eventCount = 0;
        listener.ensureListening(
          stream: stream.stream,
          onEvent: (_) async => eventCount++,
          onError: (_) => errorCount++,
          onDone: () {},
        );

        stream
          ..addError(StateError('test error'))
          ..add(1);
        await Future<void>.delayed(Duration.zero);

        expect(errorCount, 1);
        expect(eventCount, 1);
        expect(listener.isListening, isTrue);
        await listener.cancel();
        await stream.close();
      },
    );

    test(
      'stream completion clears listener state and reports done once',
      () async {
        final stream = StreamController<int>.broadcast();
        final listener = SharedPurchaseStreamListener<int>();
        var doneCount = 0;
        listener.ensureListening(
          stream: stream.stream,
          onEvent: (_) async {},
          onError: (_) {},
          onDone: () => doneCount++,
        );

        await stream.close();
        await Future<void>.delayed(Duration.zero);

        expect(listener.isListening, isFalse);
        expect(doneCount, 1);
      },
    );
  });
}
