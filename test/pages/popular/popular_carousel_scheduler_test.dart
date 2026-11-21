import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/popular/popular_carousel_scheduler.dart';

void main() {
  group('PopularCarouselScheduler', () {
    testWidgets('cycles 3 rows round-robin with single active animation', (
      t,
    ) async {
      final controllers = _createControllers(3);
      addTearDown(() => _disposeAll(controllers));
      await _pumpRows(t, controllers, const [true, true, true]);

      final steps = [120.0, 80.0, 150.0];
      final scheduler = PopularCarouselScheduler(
        controllers: controllers,
        stepExtent: (i) => steps[i],
        idleInterval: const Duration(seconds: 2),
        animationDuration: const Duration(milliseconds: 400),
      );
      addTearDown(scheduler.dispose);

      scheduler.start();
      await t.pump(const Duration(seconds: 2));
      await t.pump(const Duration(milliseconds: 200));
      scheduler.start();

      expect(controllers[0].offset, greaterThan(0));
      expect(controllers[0].offset, lessThan(120));
      expect(controllers[1].offset, 0);
      expect(controllers[2].offset, 0);
      expect(controllers[1].position.isScrollingNotifier.value, isFalse);
      expect(controllers[2].position.isScrollingNotifier.value, isFalse);

      await t.pump(const Duration(milliseconds: 250));
      await t.pump();
      expect(controllers[0].offset, closeTo(120, 0.5));

      await _advanceCycle(t);
      expect(controllers[1].offset, closeTo(80, 0.5));

      await _advanceCycle(t);
      expect(controllers[2].offset, closeTo(150, 0.5));

      await _advanceCycle(t);
      expect(controllers[0].offset, closeTo(240, 0.5));
    });

    testWidgets('skips unattached and non-scrollable rows', (t) async {
      final controllers = _createControllers(3);
      addTearDown(() => _disposeAll(controllers));
      await _pumpRows(t, [controllers[1], controllers[2]], const [false, true]);

      final scheduler = PopularCarouselScheduler(
        controllers: controllers,
        stepExtent: (_) => 110,
        idleInterval: const Duration(seconds: 1),
        animationDuration: const Duration(milliseconds: 300),
      );
      addTearDown(scheduler.dispose);

      scheduler.start();
      await _advanceCycle(t, idle: 1, anim: 350);
      expect(controllers[0].hasClients, isFalse);
      expect(controllers[1].offset, 0);
      expect(controllers[2].offset, closeTo(110, 0.5));

      await _advanceCycle(t, idle: 1, anim: 350);
      expect(controllers[2].offset, closeTo(220, 0.5));
    });

    testWidgets('handles empty controllers, zero extent and invalid steps', (
      t,
    ) async {
      final emptyScheduler = PopularCarouselScheduler(
        controllers: const [],
        stepExtent: (_) => 100,
      );
      emptyScheduler.start();
      await t.pump(const Duration(seconds: 5));
      emptyScheduler.pause();
      emptyScheduler.resume();
      emptyScheduler.stop();
      emptyScheduler.dispose();

      final controllers = _createControllers(2);
      addTearDown(() => _disposeAll(controllers));
      await _pumpRows(t, controllers, const [true, false]);

      final badSteps = [-10.0, double.nan];
      final scheduler = PopularCarouselScheduler(
        controllers: controllers,
        stepExtent: (i) => badSteps[i],
        idleInterval: const Duration(seconds: 1),
      );
      addTearDown(scheduler.dispose);

      scheduler.start();
      await t.pump(const Duration(seconds: 3));
      expect(controllers[0].offset, 0);
      expect(controllers[1].offset, 0);
      expect(t.takeException(), isNull);
    });

    testWidgets('halts mid-animation on pause and resumes cleanly', (t) async {
      final controllers = _createControllers(2);
      addTearDown(() => _disposeAll(controllers));
      await _pumpRows(t, controllers, const [true, true]);

      final scheduler = PopularCarouselScheduler(
        controllers: controllers,
        stepExtent: (_) => 140,
        idleInterval: const Duration(seconds: 2),
        animationDuration: const Duration(milliseconds: 500),
      );
      addTearDown(scheduler.dispose);

      scheduler.start();
      await t.pump(const Duration(seconds: 2));
      await t.pump(const Duration(milliseconds: 200));
      final pausedOffset = controllers[0].offset;
      expect(pausedOffset, greaterThan(0));
      expect(pausedOffset, lessThan(140));

      scheduler.pause();
      scheduler.pause();
      await t.pump(const Duration(seconds: 3));
      expect(controllers[0].offset, closeTo(pausedOffset, 0.5));
      expect(controllers[1].offset, 0);

      scheduler.resume();
      scheduler.resume();
      await _advanceCycle(t, idle: 2, anim: 550);
      expect(controllers[1].offset, closeTo(140, 0.5));
    });

    testWidgets('stop resets order, dispose stays silent and keeps ownership', (
      t,
    ) async {
      final controllers = _createControllers(2);
      await _pumpRows(t, controllers, const [true, true]);

      final scheduler = PopularCarouselScheduler(
        controllers: controllers,
        stepExtent: (_) => 100,
        idleInterval: const Duration(seconds: 1),
        animationDuration: const Duration(milliseconds: 300),
      );

      scheduler.start();
      await _advanceCycle(t, idle: 1, anim: 350);
      expect(controllers[0].offset, closeTo(100, 0.5));

      scheduler.stop();
      scheduler.resume();
      await t.pump(const Duration(seconds: 3));
      expect(controllers[1].offset, 0);

      scheduler.start();
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(milliseconds: 120));
      final midOffset = controllers[0].offset;
      expect(midOffset, greaterThan(100));

      scheduler.dispose();
      scheduler.dispose();
      scheduler.start();
      scheduler.resume();
      scheduler.pause();
      scheduler.stop();
      await t.pump(const Duration(seconds: 4));
      expect(controllers[0].offset, closeTo(midOffset, 0.5));
      expect(controllers[1].offset, 0);

      await t.pumpWidget(const SizedBox.shrink());
      expect(() => _disposeAll(controllers), returnsNormally);
    });

    testWidgets('handles reach-end via callback or smooth rewind', (t) async {
      final controllers = _createControllers(2);
      addTearDown(() => _disposeAll(controllers));
      await _pumpRows(t, controllers, const [true, true]);

      controllers[0].jumpTo(controllers[0].position.maxScrollExtent);
      final reached = <int>[];
      final customEnd = PopularCarouselScheduler(
        controllers: [controllers[0]],
        stepExtent: (_) => 120,
        idleInterval: const Duration(seconds: 1),
        animationDuration: const Duration(milliseconds: 300),
        onReachEnd: (idx, c) async {
          reached.add(idx);
          c.jumpTo(0);
        },
      );
      addTearDown(customEnd.dispose);

      customEnd.start();
      await _advanceCycle(t, idle: 1, anim: 350);
      expect(reached, [0]);
      expect(controllers[0].offset, 0);
      customEnd.stop();

      controllers[1].jumpTo(controllers[1].position.maxScrollExtent);
      final rewindEnd = PopularCarouselScheduler(
        controllers: [controllers[1]],
        stepExtent: (_) => 120,
        idleInterval: const Duration(seconds: 1),
        animationDuration: const Duration(milliseconds: 400),
      );
      addTearDown(rewindEnd.dispose);

      rewindEnd.start();
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(milliseconds: 200));
      expect(controllers[1].offset, greaterThan(0));
      expect(
        controllers[1].offset,
        lessThan(controllers[1].position.maxScrollExtent),
      );
      await t.pump(const Duration(milliseconds: 250));
      await t.pump();
      expect(controllers[1].offset, 0);
    });
  });
}

List<ScrollController> _createControllers(int count) =>
    List.generate(count, (_) => ScrollController());

void _disposeAll(List<ScrollController> controllers) {
  for (final c in controllers) {
    c.dispose();
  }
}

Future<void> _advanceCycle(
  WidgetTester t, {
  int idle = 2,
  int anim = 450,
}) async {
  await t.pump(Duration(seconds: idle));
  await t.pump(Duration(milliseconds: anim));
  await t.pump();
}

Future<void> _pumpRows(
  WidgetTester t,
  List<ScrollController> controllers,
  List<bool> scrollable,
) async {
  await t.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 240,
          height: controllers.length * 70.0,
          child: Column(
            children: [
              for (var i = 0; i < controllers.length; i++)
                SizedBox(
                  height: 70,
                  child: ListView.builder(
                    controller: controllers[i],
                    scrollDirection: Axis.horizontal,
                    itemCount: scrollable[i] ? 12 : 1,
                    itemBuilder: (_, _) =>
                        const SizedBox(width: 90, height: 60),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
