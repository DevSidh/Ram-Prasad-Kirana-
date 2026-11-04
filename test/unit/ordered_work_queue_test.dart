import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/services/ordered_work_queue.dart';

void main() {
  test('rapid repeated scans retain order and repetitions', () async {
    final queue = OrderedWorkQueue();
    final gate = Completer<void>();
    final processed = <int>[];
    final futures = List.generate(
        100,
        (i) => queue.run(() async {
              if (i == 0) await gate.future;
              processed.add(i % 7);
              return i;
            }));
    expect(queue.pending, 100);
    gate.complete();
    expect(await Future.wait(futures), List.generate(100, (i) => i));
    expect(processed, List.generate(100, (i) => i % 7));
  });
  test('a failed lookup does not drop later scans', () async {
    final queue = OrderedWorkQueue();
    final first = queue.run<int>(() async => throw const FormatException());
    final second = queue.run<int>(() async => 2);
    await expectLater(first, throwsFormatException);
    expect(await second, 2);
  });
  test('disposal cancels queued actions without starting UI work', () async {
    final queue = OrderedWorkQueue();
    final gate = Completer<void>();
    final first = queue.run(() => gate.future);
    await Future<void>.delayed(Duration.zero);
    var called = false;
    final second = queue.run(() async {
      called = true;
    });
    final check = expectLater(second, throwsStateError);
    queue.close();
    gate.complete();
    await first;
    await check;
    expect(called, isFalse);
  });
}
