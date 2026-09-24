import 'dart:async';

extension SwitchMapStream<T> on Stream<T> {
  /// Maps each event to a stream and follows only the latest one, cancelling
  /// the previous inner subscription.
  ///
  /// Use this instead of [Stream.asyncExpand] over Firestore `snapshots()`:
  /// asyncExpand waits for the inner stream to finish, and a snapshot listener
  /// never finishes, so later outer events (a changed doc, a new user) are
  /// queued forever.
  Stream<R> switchMap<R>(Stream<R> Function(T value) mapper) {
    late final StreamController<R> controller;
    StreamSubscription<T>? outerSub;
    StreamSubscription<R>? innerSub;
    bool outerDone = false;

    void closeIfDone() {
      if (outerDone && innerSub == null && !controller.isClosed) {
        controller.close();
      }
    }

    controller = StreamController<R>(
      sync: true,
      onListen: () {
        outerSub = listen(
          (T value) {
            final StreamSubscription<R>? previous = innerSub;
            innerSub = null;
            previous?.cancel();
            late final StreamSubscription<R> current;
            current = mapper(value).listen(
              controller.add,
              onError: controller.addError,
              onDone: () {
                if (identical(innerSub, current)) {
                  innerSub = null;
                  closeIfDone();
                }
              },
            );
            innerSub = current;
          },
          onError: controller.addError,
          onDone: () {
            outerDone = true;
            closeIfDone();
          },
        );
      },
      onPause: () {
        outerSub?.pause();
        innerSub?.pause();
      },
      onResume: () {
        outerSub?.resume();
        innerSub?.resume();
      },
      onCancel: () async {
        final StreamSubscription<R>? inner = innerSub;
        innerSub = null;
        await Future.wait(<Future<void>>[
          if (inner != null) inner.cancel(),
          if (outerSub != null) outerSub!.cancel(),
        ]);
      },
    );
    return controller.stream;
  }
}
