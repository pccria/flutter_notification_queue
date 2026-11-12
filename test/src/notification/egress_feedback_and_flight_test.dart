import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/notification/interaction/gesture_state_machine.dart';
import 'package:flutter_notification_queue/src/notification/interaction/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EgressFeedbackOverlay Widget Tests', () {
    testWidgets('renders child and applies tilt and opacity transformations',
        (final tester) async {
      final fsm = GestureStateMachine(
        initialBehavior: const Dismiss(),
        initialPosition: QueuePosition.topCenter,
      )
        ..lift(
          pointerStart: Offset.zero,
          cardRect: const Rect.fromLTWH(0, 0, 300, 80),
          containerRect: const Rect.fromLTWH(0, 0, 300, 80),
        )
        ..update(
          delta: const Offset(60, 0),
          globalPosition: const Offset(60, 0),
          progress: 0.5,
          passedThreshold: false,
        );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EgressFeedbackOverlay(
                gestureState: fsm,
                behavior: const Dismiss(),
                position: QueuePosition.topCenter,
                child: const Text('Test Notification'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test Notification'), findsOneWidget);

      // Verify Transform exists and applies rotation and translation
      final transformFinder = find.byType(Transform);
      expect(transformFinder, findsWidgets);

      fsm.dispose();
    });

    testWidgets('honors enableTilt: false', (final tester) async {
      final fsm = GestureStateMachine(
        initialBehavior: const Dismiss(),
        initialPosition: QueuePosition.topCenter,
      )
        ..lift(
          pointerStart: Offset.zero,
          cardRect: const Rect.fromLTWH(0, 0, 300, 80),
          containerRect: const Rect.fromLTWH(0, 0, 300, 80),
        )
        ..update(
          delta: const Offset(100, 0),
          globalPosition: const Offset(100, 0),
          progress: 0.8,
          passedThreshold: false,
        );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EgressFeedbackOverlay(
                gestureState: fsm,
                behavior: const Dismiss(enableTilt: false),
                position: QueuePosition.topCenter,
                child: const Text('Test Notification'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test Notification'), findsOneWidget);
      fsm.dispose();
    });
  });

  group('EgressUnderlay Widget Tests', () {
    testWidgets('renders glyph and scales with progress', (final tester) async {
      final fsm = GestureStateMachine(
        initialBehavior: const Dismiss(),
        initialPosition: QueuePosition.topCenter,
      )
        ..lift(
          pointerStart: Offset.zero,
          cardRect: const Rect.fromLTWH(0, 0, 300, 80),
          containerRect: const Rect.fromLTWH(0, 0, 300, 80),
        )
        ..update(
          delta: const Offset(80, 0),
          globalPosition: const Offset(80, 0),
          progress: 0.7,
          passedThreshold: false,
        );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EgressUnderlay(
                gestureState: fsm,
                behavior: const Dismiss(),
                position: QueuePosition.topCenter,
                cardSize: const Size(300, 80),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Now pass threshold and verify pop state
      fsm.update(
        delta: const Offset(130, 0),
        globalPosition: const Offset(130, 0),
        progress: 1.1,
        passedThreshold: true,
      );
      await tester.pump();

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      fsm.dispose();
    });

    testWidgets('renders nothing when showUnderlay: false',
        (final tester) async {
      final fsm = GestureStateMachine(
        initialBehavior: const Dismiss(),
        initialPosition: QueuePosition.topCenter,
      )
        ..lift(
          pointerStart: Offset.zero,
          cardRect: const Rect.fromLTWH(0, 0, 300, 80),
          containerRect: const Rect.fromLTWH(0, 0, 300, 80),
        )
        ..update(
          delta: const Offset(100, 0),
          globalPosition: const Offset(100, 0),
          progress: 0.8,
          passedThreshold: true,
        );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EgressUnderlay(
                gestureState: fsm,
                behavior: const Dismiss(showUnderlay: false),
                position: QueuePosition.topCenter,
                cardSize: const Size(300, 80),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close_rounded), findsNothing);
      fsm.dispose();
    });
  });

  group('EgressFlightOverlay Widget Tests', () {
    testWidgets('animates off-screen and invokes onComplete',
        (final tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                EgressFlightOverlay(
                  startOffset: const Offset(100, 100),
                  velocity: const Velocity(pixelsPerSecond: Offset(1000, 0)),
                  cardSize: const Size(300, 80),
                  position: QueuePosition.topRight,
                  behavior: const Dismiss(),
                  onComplete: () {
                    completed = true;
                  },
                  child: const Text('Flying Card'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Flying Card'), findsOneWidget);
      expect(completed, isFalse);

      // Advance through the flight animation (180ms)
      await tester.pump(const Duration(milliseconds: 200));

      expect(completed, isTrue);
    });
  });

  group('Dismiss Cancel Timer Resumption Tests', () {
    testWidgets(
        'preserves and restores auto-dismiss timer when drag cancels out',
        (final tester) async {
      final controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'test_timer_channel',
            position: QueuePosition.topRight,
            defaultDismissDuration: null,
          ),
        },
        queues: {
          const NotificationQueue(
            position: QueuePosition.topRight,
            dragBehavior: Dismiss(),
          ),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          builder: (final context, final child) => NotificationScope(
            controller: controller,
            child: child!,
          ),
          home: const Scaffold(
            body: SizedBox.expand(),
          ),
        ),
      );

      controller.show(
        const AppNotification(
          id: 'cancel-timer-card',
          channelName: 'test_timer_channel',
          message: 'Drag cancel timer test',
          dismissDuration: Duration(seconds: 4),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final cardFinder = find.text('Drag cancel timer test');
      expect(cardFinder, findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Start drag and move slightly (well below dismiss threshold)
      final startPos = tester.getCenter(cardFinder);
      final gesture = await tester.startGesture(startPos);
      await tester.pump();

      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();

      // Release the gesture without committing egress dismissal
      await gesture.up();
      await tester.pump();

      // Pump frames for snap-back spring settling (active dismiss timer
      // ticker prevents pumpAndSettle)
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Verify progress indicator is STILL present and card has not been
      // dismissed
      expect(find.text('Drag cancel timer test'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Advance time past the remainder of the 4-second dismiss duration
      await tester.pump(const Duration(seconds: 4));
      // Settle the dismiss reverse animation
      await tester.pumpAndSettle();

      // Card must be dismissed upon timer timeout
      expect(find.text('Drag cancel timer test'), findsNothing);

      controller.dispose();
    });

    testWidgets('pauses timer across multiple repeated drag-and-cancel cycles',
        (final tester) async {
      final controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'test_repeat_channel',
            position: QueuePosition.topRight,
            defaultDismissDuration: null,
          ),
        },
        queues: {
          const NotificationQueue(
            position: QueuePosition.topRight,
            dragBehavior: Dismiss(),
          ),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          builder: (final context, final child) => NotificationScope(
            controller: controller,
            child: child!,
          ),
          home: const Scaffold(
            body: SizedBox.expand(),
          ),
        ),
      );

      controller.show(
        const AppNotification(
          id: 'repeat-drag-card',
          channelName: 'test_repeat_channel',
          message: 'Repeat drag timer test',
          dismissDuration: Duration(seconds: 4),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final cardFinder = find.text('Repeat drag timer test');
      expect(cardFinder, findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Advance 1 second: 3 seconds remaining
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Cycle 1: Start drag, hold for 2 seconds (timer paused!)
      var startPos = tester.getCenter(cardFinder);
      var gesture = await tester.startGesture(startPos);
      await tester.pump();
      await gesture.moveBy(const Offset(25, 0));
      await tester.pump();

      // Hold drag for 2 seconds while dragged
      await tester.pump(const Duration(seconds: 2));

      // Release drag
      await gesture.up();
      await tester.pump();

      // Settle snap-back
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Indicator still visible, card still alive because hold paused the timer
      expect(find.text('Repeat drag timer test'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Cycle 2: Start another drag, hold for another 2 seconds
      startPos = tester.getCenter(cardFinder);
      gesture = await tester.startGesture(startPos);
      await tester.pump();
      await gesture.moveBy(const Offset(-25, 0));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Release drag again
      await gesture.up();
      await tester.pump();

      // Settle snap-back
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Card must STILL be present even though total elapsed real time
      // is > 7 seconds
      expect(find.text('Repeat drag timer test'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Now let remaining unpaused time tick down (3 seconds)
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Finally times out
      expect(find.text('Repeat drag timer test'), findsNothing);

      controller.dispose();
    });
  });
}
