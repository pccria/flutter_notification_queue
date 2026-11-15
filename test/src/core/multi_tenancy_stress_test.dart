import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Multi-Tenancy 1:1 Attachment & Isolation Invariants (v0.7.x)', () {
    testWidgets('enforces strict 1:1 attachment invariant (cannot bind 1:N)',
        (final tester) async {
      final controller = NotificationController(
        queues: {const NotificationQueue(position: QueuePosition.topCenter)},
        channels: {
          const NotificationChannel(
            name: 'default',
            position: QueuePosition.topCenter,
          ),
        },
      );
      addTearDown(controller.dispose);

      // Attaching one controller to two scopes simultaneously must fail.
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              Expanded(
                child: NotificationScope(
                  controller: controller,
                  child: const Text('Scope 1'),
                ),
              ),
              Expanded(
                child: NotificationScope(
                  controller: controller,
                  child: const Text('Scope 2'),
                ),
              ),
            ],
          ),
        ),
      );

      final dynamic error = tester.takeException();
      expect(error, isA<AssertionError>());
      expect(
        error.toString(),
        contains('A controller may only be used with one scope at a time'),
      );
    });

    testWidgets('unmounting scope cleanly detaches controller for reuse',
        (final tester) async {
      final controller = NotificationController(
        queues: {const NotificationQueue(position: QueuePosition.topCenter)},
        channels: {
          const NotificationChannel(
            name: 'default',
            position: QueuePosition.topCenter,
          ),
        },
      );
      addTearDown(controller.dispose);

      bool mountScope = true;
      late StateSetter setScopeState;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (final context, final setState) {
              setScopeState = setState;
              if (mountScope) {
                return NotificationScope(
                  controller: controller,
                  child: const Text('Scope Mounted'),
                );
              }
              return const Text('Scope Unmounted');
            },
          ),
        ),
      );

      expect(controller.isAttached, isTrue);
      expect(find.text('Scope Mounted'), findsOneWidget);

      // Unmount scope
      setScopeState(() => mountScope = false);
      await tester.pumpAndSettle();

      expect(controller.isAttached, isFalse);
      expect(find.text('Scope Unmounted'), findsOneWidget);

      // Remount scope with same controller
      setScopeState(() => mountScope = true);
      await tester.pumpAndSettle();

      expect(controller.isAttached, isTrue);
      expect(find.text('Scope Mounted'), findsOneWidget);
    });
  });

  group('Multi-Tenant Stress Tests: Stasis, Events & Registry Isolation', () {
    late NotificationController controllerA;
    late NotificationController controllerB;

    setUp(() {
      controllerA = NotificationController(
        queues: {
          const NotificationQueue(
            position: QueuePosition.topCenter,
            maxStackSize: 3,
          ),
          const NotificationQueue(
            position: QueuePosition.bottomRight,
            maxStackSize: 3,
          ),
        },
        channels: {
          const NotificationChannel(
            name: 'default',
            position: QueuePosition.topCenter,
            defaultDismissDuration: Duration(seconds: 3),
          ),
        },
      );

      controllerB = NotificationController(
        queues: {
          const NotificationQueue(
            position: QueuePosition.topCenter,
            maxStackSize: 3,
          ),
          const NotificationQueue(
            position: QueuePosition.bottomRight,
            maxStackSize: 3,
          ),
        },
        channels: {
          const NotificationChannel(
            name: 'default',
            position: QueuePosition.topCenter,
            defaultDismissDuration: Duration(seconds: 3),
          ),
        },
      );
    });

    tearDown(() {
      controllerA.dispose();
      controllerB.dispose();
    });

    Widget buildSplitViewportHarness({
      final bool mountB = true,
      final Widget Function(BuildContext, NotificationController)? builderA,
      final Widget Function(BuildContext, NotificationController)? builderB,
    }) =>
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Expanded(
                  child: ClipRect(
                    child: Overlay(
                      initialEntries: [
                        OverlayEntry(
                          builder: (final context) => NotificationScope(
                            controller: controllerA,
                            useRootOverlay: false,
                            child: builderA != null
                                ? builderA(context, controllerA)
                                : const Center(child: Text('Workspace A')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (mountB)
                  Expanded(
                    child: ClipRect(
                      child: Overlay(
                        initialEntries: [
                          OverlayEntry(
                            builder: (final context) => NotificationScope(
                              controller: controllerB,
                              useRootOverlay: false,
                              child: builderB != null
                                  ? builderB(context, controllerB)
                                  : const Center(child: Text('Workspace B')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );

    testWidgets(
      'stasis isolation: pauseQueue on A does NOT halt B timers',
      (final tester) async {
        await tester.binding.setSurfaceSize(const Size(1400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildSplitViewportHarness());
        await tester.pumpAndSettle();

        expect(controllerA.isAttached, isTrue);
        expect(controllerB.isAttached, isTrue);

        // Dispatch notifications with 3s dismiss duration into both
        controllerA.show(
          const AppNotification(
            id: 'notif_a',
            title: 'Card A',
            message: 'Workspace A message',
            dismissDuration: Duration(seconds: 3),
          ),
        );
        controllerB.show(
          const AppNotification(
            id: 'notif_b',
            title: 'Card B',
            message: 'Workspace B message',
            dismissDuration: Duration(seconds: 3),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Card A'), findsOneWidget);
        expect(find.text('Card B'), findsOneWidget);

        // Put Workspace A's queue into stasis
        controllerA.pauseQueue(QueuePosition.topCenter);
        await tester.pump();

        expect(controllerA.isQueuePaused(QueuePosition.topCenter), isTrue);
        expect(controllerB.isQueuePaused(QueuePosition.topCenter), isFalse);

        // Advance 4s — Card B should dismiss, Card A should remain frozen
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        expect(find.text('Card A'), findsOneWidget);
        expect(find.text('Card B'), findsNothing);

        // Resume Workspace A's queue
        controllerA.resumeQueue(QueuePosition.topCenter);
        await tester.pump();

        expect(controllerA.isQueuePaused(QueuePosition.topCenter), isFalse);

        // Advance remaining time — Card A should now dismiss
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        expect(find.text('Card A'), findsNothing);
      },
    );

    testWidgets(
      'event isolation: controllerA & B stream strictly isolated events',
      (final tester) async {
        await tester.binding.setSurfaceSize(const Size(1400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildSplitViewportHarness());
        await tester.pumpAndSettle();

        final eventsA = <NotificationEvent>[];
        final eventsB = <NotificationEvent>[];

        final subA = controllerA.events.listen(eventsA.add);
        final subB = controllerB.events.listen(eventsB.add);
        addTearDown(subA.cancel);
        addTearDown(subB.cancel);

        // Rapidly dispatch 20 notifications into A and 20 into B
        for (int i = 0; i < 20; i++) {
          controllerA.show(
            AppNotification(
              id: 'a_$i',
              title: 'A $i',
              message: 'Message from A $i',
              permanent: true,
            ),
          );
          controllerB.show(
            AppNotification(
              id: 'b_$i',
              title: 'B $i',
              message: 'Message from B $i',
              permanent: true,
            ),
          );
        }

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Interleave dismissals and pinning
        controllerA.pin(const AppNotification(id: 'a_0', message: ''));
        controllerB.pin(const AppNotification(id: 'b_0', message: ''));
        controllerA.dismiss(const AppNotification(id: 'a_1', message: ''));
        controllerB.dismiss(const AppNotification(id: 'b_1', message: ''));

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Verify that every notification event in eventsA refers to 'a_'
        expect(eventsA, isNotEmpty);
        for (final event in eventsA) {
          final notifId = event.notification?.id;
          if (notifId != null) {
            expect(
              notifId.startsWith('a_'),
              isTrue,
              reason: 'Event ${event.runtimeType} with ID $notifId '
                  'leaked into eventsA',
            );
          }
        }

        // Verify that every notification event in eventsB refers to 'b_'
        expect(eventsB, isNotEmpty);
        for (final event in eventsB) {
          final notifId = event.notification?.id;
          if (notifId != null) {
            expect(
              notifId.startsWith('b_'),
              isTrue,
              reason: 'Event ${event.runtimeType} with ID $notifId '
                  'leaked into eventsB',
            );
          }
        }
      },
    );

    testWidgets(
      'teardown safety: unmounting B disposes cleanly, A unaffected',
      (final tester) async {
        await tester.binding.setSurfaceSize(const Size(1400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        bool mountB = true;
        late StateSetter setHarnessState;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (final context, final setState) {
              setHarnessState = setState;
              return buildSplitViewportHarness(mountB: mountB);
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(controllerA.isAttached, isTrue);
        expect(controllerB.isAttached, isTrue);

        // Dispatch notifications into both
        controllerA.show(
          const AppNotification(
            id: 'stay_a',
            title: 'Card in A',
            message: 'Lives forever',
            permanent: true,
          ),
        );
        controllerB.show(
          const AppNotification(
            id: 'temp_b',
            title: 'Card in B',
            message: 'Will be unmounted',
            permanent: true,
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Card in A'), findsOneWidget);
        expect(find.text('Card in B'), findsOneWidget);

        // Unmount Workspace B
        setHarnessState(() => mountB = false);
        await tester.pumpAndSettle();

        expect(controllerB.isAttached, isFalse);
        expect(find.text('Card in B'), findsNothing);
        expect(find.text('Card in A'), findsOneWidget);

        // Workspace A continues operating flawlessly
        controllerA.show(
          const AppNotification(
            id: 'stay_a_2',
            title: 'Second Card in A',
            message: 'Dispatched after B unmounted',
            permanent: true,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Second Card in A'), findsOneWidget);

        // Dismiss in Workspace A
        controllerA.dismissAll();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Card in A'), findsNothing);
        expect(find.text('Second Card in A'), findsNothing);
      },
    );

    testWidgets(
      'drag isolation: dragging in A across boundary never affects B',
      (final tester) async {
        await tester.binding.setSurfaceSize(const Size(1400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final eventsB = <NotificationEvent>[];
        final subB = controllerB.events.listen(eventsB.add);
        addTearDown(subB.cancel);

        await tester.pumpWidget(buildSplitViewportHarness());
        await tester.pumpAndSettle();

        controllerA.show(
          const AppNotification(
            id: 'drag_a',
            title: 'Draggable Card A',
            message: 'In workspace A',
            permanent: true,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final cardFinder = find.text('Draggable Card A');
        expect(cardFinder, findsOneWidget);

        final startPos = tester.getCenter(cardFinder);
        // Start dragging card in Workspace A
        final gesture = await tester.startGesture(startPos);
        await tester.pump(const Duration(milliseconds: 100));

        // Drag pointer deep into Workspace B territory (x = 1100, y = 300)
        await gesture.moveTo(const Offset(1100, 300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Release pointer
        await gesture.up();
        await tester.pump();
        await tester.pumpAndSettle();

        // Workspace B must NEVER have received any relocation/reception events
        expect(eventsB, isEmpty);
      },
    );

    testWidgets(
      'high-throughput stress test: 100 concurrent dispatches',
      (final tester) async {
        await tester.binding.setSurfaceSize(const Size(1400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildSplitViewportHarness());
        await tester.pumpAndSettle();

        // Concurrently dispatch 50 notifications into A and 50 into B
        for (int i = 0; i < 50; i++) {
          final priority = switch (i % 4) {
            0 => NotificationPriority.low,
            1 => NotificationPriority.normal,
            2 => NotificationPriority.high,
            _ => NotificationPriority.critical,
          };

          controllerA.show(
            AppNotification(
              id: 'burst_a_$i',
              title: 'Burst A $i',
              message: 'Message $i',
              priority: priority,
              permanent: true,
            ),
          );
          controllerB.show(
            AppNotification(
              id: 'burst_b_$i',
              title: 'Burst B $i',
              message: 'Message $i',
              priority: priority,
              permanent: true,
            ),
          );
        }

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Interleave rapid mutative actions
        controllerA.pauseQueue(QueuePosition.topCenter);
        await tester.pump();
        controllerB.pin(const AppNotification(id: 'burst_b_49', message: ''));
        controllerA.dismissAll();
        controllerB.resumeQueue(QueuePosition.topCenter);

        await tester.pump();
        await tester.pumpAndSettle();

        // Calling dismissAll on A dismissed active notifications, promoting
        // pending notifications from the backlog.
        final activeA = controllerA.coordinator?.activeNotifications ?? [];
        expect(activeA.length, equals(3));
        expect(controllerA.isQueuePaused(QueuePosition.topCenter), isTrue);

        // Now calling dismissAll with clearBacklog: true completely flushes
        // both active items and the remaining pending backlog.
        controllerA.dismissAll(clearBacklog: true);
        await tester.pump();
        await tester.pumpAndSettle();
        final activeACleared =
            controllerA.coordinator?.activeNotifications ?? [];
        expect(activeACleared, isEmpty);

        // Controller B was not paused and its active slots remain intact.
        final activeB = controllerB.coordinator?.activeNotifications ?? [];
        expect(activeB.length, equals(3));
        expect(controllerB.isQueuePaused(QueuePosition.topCenter), isFalse);
      },
    );

    testWidgets(
      'local overlay bounding: useRootOverlay: false binds to local viewport',
      (final tester) async {
        await tester.binding.setSurfaceSize(const Size(1400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildSplitViewportHarness());
        await tester.pumpAndSettle();

        controllerA.show(
          const AppNotification(
            id: 'local_a',
            title: 'Local to A',
            message: 'In workspace A',
            permanent: true,
          ),
        );
        controllerB.show(
          const AppNotification(
            id: 'local_b',
            title: 'Local to B',
            message: 'In workspace B',
            permanent: true,
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final cardAFinder = find.text('Local to A');
        final cardBFinder = find.text('Local to B');
        expect(cardAFinder, findsOneWidget);
        expect(cardBFinder, findsOneWidget);

        // Get centers of both cards
        final centerA = tester.getCenter(cardAFinder);
        final centerB = tester.getCenter(cardBFinder);

        // Screen width is 1400:
        // Card A must be on the left half of the screen (dx < 700)
        // Card B must be on the right half of the screen (dx > 700)
        expect(centerA.dx, lessThan(700.0));
        expect(centerB.dx, greaterThan(700.0));
      },
    );
  });
}
