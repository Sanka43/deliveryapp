import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_delivery_app/core/utils/stream_switch_map.dart';

void main() {
  group('switchMap', () {
    test('follows the latest inner stream even if earlier ones never end',
        () async {
      // Mirrors auth user -> Firestore snapshots(): inner streams never close.
      final StreamController<String> outer = StreamController<String>();
      final Map<String, StreamController<int>> inners =
          <String, StreamController<int>>{
        'a': StreamController<int>(),
        'b': StreamController<int>(),
      };
      final List<int> seen = <int>[];
      final StreamSubscription<int> sub = outer.stream
          .switchMap((String key) => inners[key]!.stream)
          .listen(seen.add);

      outer.add('a');
      await pumpEventQueue();
      inners['a']!.add(1);
      await pumpEventQueue();

      outer.add('b');
      await pumpEventQueue();
      inners['b']!.add(2);
      await pumpEventQueue();

      expect(seen, <int>[1, 2]);
      expect(inners['a']!.hasListener, isFalse,
          reason: 'previous inner must be cancelled');

      await sub.cancel();
      expect(inners['b']!.hasListener, isFalse);
      expect(outer.hasListener, isFalse);
    });

    test('asyncExpand would have stalled on the same input', () async {
      final StreamController<String> outer = StreamController<String>();
      final StreamController<int> neverEnds = StreamController<int>();
      final List<int> seen = <int>[];
      final StreamSubscription<int> sub = outer.stream
          .asyncExpand((String key) =>
              key == 'a' ? neverEnds.stream : Stream<int>.value(2))
          .listen(seen.add);

      outer.add('a');
      outer.add('b');
      await pumpEventQueue();

      expect(seen, isEmpty);
      await sub.cancel();
    });

    test('forwards inner errors and keeps following new outer events',
        () async {
      final StreamController<int> outer = StreamController<int>();
      final List<Object> events = <Object>[];
      final StreamSubscription<int> sub = outer.stream
          .switchMap((int v) => v == 1
              ? Stream<int>.error(StateError('permission-denied'))
              : Stream<int>.value(v))
          .listen(events.add, onError: events.add);

      outer.add(1);
      await pumpEventQueue();
      outer.add(2);
      await pumpEventQueue();

      expect(events.first, isA<StateError>());
      expect(events.last, 2);
      await sub.cancel();
    });

    test('closes once outer and the active inner are both done', () async {
      final List<int> seen = <int>[];
      await Stream<int>.fromIterable(<int>[1, 2])
          .switchMap((int v) => Stream<int>.value(v * 10))
          .forEach(seen.add);
      expect(seen, contains(20));
    });
  });
}
