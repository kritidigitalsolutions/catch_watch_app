import 'package:catch_watch/utils/post_frame_event_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PostFrameEventQueue', () {
    test('keeps events queued until the verifier is registered', () {
      final queue = PostFrameEventQueue<String>();
      final scheduled = <void Function()>[];
      final dispatched = <String>[];
      var verifierRegistered = false;

      queue.add('transaction-1', 'purchase');
      queue.scheduleDrain(
        isReady: () => verifierRegistered,
        schedulePostFrame: scheduled.add,
        onEvent: dispatched.add,
      );

      expect(dispatched, isEmpty);
      scheduled.removeAt(0)();
      expect(dispatched, isEmpty);
      expect(queue.length, 1);

      verifierRegistered = true;
      queue.scheduleDrain(
        isReady: () => verifierRegistered,
        schedulePostFrame: scheduled.add,
        onEvent: dispatched.add,
      );
      expect(dispatched, isEmpty);
      scheduled.removeAt(0)();

      expect(dispatched, ['purchase']);
      expect(queue.length, 0);
    });

    test(
      'defers a drain scheduled during screen initialization until frame end',
      () {
        final queue = PostFrameEventQueue<String>();
        final scheduled = <void Function()>[];
        var isBuilding = true;
        var dispatchedDuringBuild = false;

        queue.add('transaction-1', 'purchase');
        queue.scheduleDrain(
          isReady: () => true,
          schedulePostFrame: scheduled.add,
          onEvent: (_) => dispatchedDuringBuild = isBuilding,
        );

        expect(dispatchedDuringBuild, isFalse);
        isBuilding = false;
        scheduled.single();

        expect(dispatchedDuringBuild, isFalse);
      },
    );

    test('deduplicates queued transaction keys', () {
      final queue = PostFrameEventQueue<String>();
      final scheduled = <void Function()>[];
      final dispatched = <String>[];
      queue
        ..add('transaction-1', 'first delivery')
        ..add('transaction-1', 'duplicate delivery');

      queue.scheduleDrain(
        isReady: () => true,
        schedulePostFrame: scheduled.add,
        onEvent: dispatched.add,
      );
      scheduled.single();

      expect(dispatched, ['duplicate delivery']);
    });
  });
}
