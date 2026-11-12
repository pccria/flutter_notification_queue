import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cross-Queue Slot Relocation (FSM-02)', () {
    late NotificationController controller;

    setUp(() {
      controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'right_channel',
            position: QueuePosition.topRight,
            defaultDismissDuration: null,
          ),
          const NotificationChannel(
            name: 'left_channel',
            position: QueuePosition.topLeft,
            defaultDismissDuration: null,
          ),
        },
        queues: {
          NotificationQueue(
            position: QueuePosition.topRight,
            dragBehavior: ReorderAndRelocate.to(
              positions: {QueuePosition.topLeft},
            ),
          ),
        },
      );
    });

    tearDown(() {
      controller.dispose();
    });

    Widget buildApp() => MaterialApp(
          builder: (final context, final child) => NotificationScope(
            controller: controller,
            child: child!,
          ),
          home: const Scaffold(
            body: SizedBox.expand(),
          ),
        );

    testWidgets(
      'Synchronous moveWidget transfers notification to specific target slot',
      (final tester) async {
        final events = <NotificationEvent>[];
        final sub = controller.events.listen(events.add);
        addTearDown(sub.cancel);

        await tester.pumpWidget(buildApp());

        // Dispatch 2 notifications into topLeft
        final leftCard0 = NotificationWidget(
          id: 'left_0',
          message: 'Left Card 0',
          channelName: 'left_channel',
          coordinator: controller.coordinator,
        )..show();

        final leftCard1 = NotificationWidget(
          id: 'left_1',
          message: 'Left Card 1',
          channelName: 'left_channel',
          coordinator: controller.coordinator,
        )..show();

        // Dispatch 1 notification into topRight
        final rightCard = NotificationWidget(
          id: 'right_dragged',
          message: 'Right Dragged Card',
          channelName: 'right_channel',
          coordinator: controller.coordinator,
        )..show();

        await tester.pumpAndSettle();

        // Move rightCard directly into slot 1 of topLeft
        // (between left_0 and left_1)
        final migrated = controller.coordinator?.moveWidget(
          rightCard,
          toPosition: QueuePosition.topLeft,
          targetIndex: 1,
        );

        await tester.pumpAndSettle();

        expect(migrated, isNotNull);
        expect(migrated!.queue.position, equals(QueuePosition.topLeft));

        // Verify event
        final relocatedEvents = events.whereType<NotificationRelocated>();
        expect(relocatedEvents, isNotEmpty);
        final ev = relocatedEvents.first;
        expect(ev.from, equals(QueuePosition.topRight));
        expect(ev.to, equals(QueuePosition.topLeft));
        expect(ev.toIndex, equals(1));
        expect(ev.notification.id, equals('right_dragged'));

        // Verify active notifications in topLeft
        final leftKey =
            controller.coordinator?.getWidgetKey(QueuePosition.topLeft);
        final leftState = leftKey?.currentState;
        expect(leftState, isNotNull);
        final activeInLeft = leftState!.activeNotifications;
        expect(activeInLeft.length, equals(3));
        expect(activeInLeft[0].id, equals(leftCard0.id));
        expect(activeInLeft[1].id, equals('right_dragged'));
        expect(activeInLeft[2].id, equals(leftCard1.id));

        // Verify active notifications in topRight (unmounted or empty)
        final rightKey =
            controller.coordinator?.getWidgetKey(QueuePosition.topRight);
        final rightState = rightKey?.currentState;
        expect(rightState?.activeNotifications ?? [], isEmpty);
      },
    );

    testWidgets(
      'insertAt gracefully evicts lowest-priority card when maxStack reached',
      (final tester) async {
        final capacityController = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'capped_channel',
              position: QueuePosition.topLeft,
            ),
          },
          queues: {
            const NotificationQueue(
              position: QueuePosition.topLeft,
              maxStackSize: 2,
            ),
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: NotificationScope(
              controller: capacityController,
              child: const Scaffold(body: Text('Capped Test')),
            ),
          ),
        );

        final highCard = NotificationWidget(
          id: 'card_high',
          message: 'High Priority Card',
          channelName: 'capped_channel',
          priority: NotificationPriority.high,
          coordinator: capacityController.coordinator,
        )..show();

        final lowCard = NotificationWidget(
          id: 'card_low',
          message: 'Low Priority Card',
          channelName: 'capped_channel',
          priority: NotificationPriority.low,
          coordinator: capacityController.coordinator,
        )..show();

        await tester.pumpAndSettle();

        final queueKey =
            capacityController.coordinator?.getWidgetKey(QueuePosition.topLeft);
        final state = queueKey?.currentState;
        expect(state, isNotNull);
        expect(state!.activeNotifications.length, equals(2));

        // Now insert a critical card at index 0 into full queue
        final incomingCritical = NotificationWidget(
          id: 'card_critical',
          message: 'Critical Incoming Card',
          channelName: 'capped_channel',
          priority: NotificationPriority.critical,
          coordinator: capacityController.coordinator,
        );

        state.insertAt(incomingCritical, targetIndex: 0);
        await tester.pumpAndSettle();

        // High priority and critical cards should be active, low priority card
        // demoted to pending
        final active = state.activeNotifications;
        expect(active.length, equals(2));
        expect(active[0].id, equals('card_critical'));
        expect(active[1].id, equals(highCard.id));

        final pending = state.pendingNotifications;
        expect(pending.length, equals(1));
        expect(pending[0].id, equals(lowCard.id));

        capacityController.dispose();
      },
    );

    testWidgets(
      'Remote queue previews gap when previewExternalDrop is invoked',
      (final tester) async {
        await tester.pumpWidget(buildApp());

        NotificationWidget(
          id: 'item_1',
          message: 'Remote Card 1',
          channelName: 'left_channel',
          coordinator: controller.coordinator,
        ).show();

        NotificationWidget(
          id: 'item_2',
          message: 'Remote Card 2',
          channelName: 'left_channel',
          coordinator: controller.coordinator,
        ).show();

        await tester.pumpAndSettle();

        final leftKey =
            controller.coordinator?.getWidgetKey(QueuePosition.topLeft);
        final state = leftKey?.currentState;
        expect(state, isNotNull);
        expect(state!.externalDragGap.value, isNull);

        // Preview external drop at slot 1 with card height 80
        state.previewExternalDrop(targetIndex: 1, incomingHeight: 80);
        await tester.pump();

        expect(state.externalDragGap.value, isNotNull);
        expect(state.externalDragGap.value!.target, equals(1));
        expect(state.externalDragGap.value!.height, equals(80.0));

        // Clear external drop preview
        state.clearExternalDrop();
        await tester.pump();

        expect(state.externalDragGap.value, isNull);
      },
    );

    testWidgets(
      'Full drag gesture across queues previews slot gap and drops '
      'card into slot',
      (final tester) async {
        final events = <NotificationEvent>[];
        final sub = controller.events.listen(events.add);
        addTearDown(sub.cancel);

        await tester.pumpWidget(buildApp());

        // Dispatch 2 notifications into topLeft
        final left0 = NotificationWidget(
          id: 'left_0',
          message: 'Left Card 0',
          channelName: 'left_channel',
          coordinator: controller.coordinator,
        )..show();

        final left1 = NotificationWidget(
          id: 'left_1',
          message: 'Left Card 1',
          channelName: 'left_channel',
          coordinator: controller.coordinator,
        )..show();

        // Dispatch 1 notification into topRight
        final rightCard = NotificationWidget(
          id: 'right_dragged',
          message: 'Right Dragged Card',
          channelName: 'right_channel',
          coordinator: controller.coordinator,
        )..show();

        await tester.pumpAndSettle();

        final rightFinder = find.text('Right Dragged Card');
        final left0Finder = find.text('Left Card 0');
        final left1Finder = find.text('Left Card 1');

        expect(rightFinder, findsOneWidget);
        expect(left0Finder, findsOneWidget);
        expect(left1Finder, findsOneWidget);

        final rightPos = tester.getCenter(rightFinder);
        final left0Pos = tester.getCenter(left0Finder);
        final left1Pos = tester.getCenter(left1Finder);

        // Target between left0 and left1
        final dropTargetPos = Offset(
          left0Pos.dx,
          (left0Pos.dy + left1Pos.dy) / 2,
        );

        // Start drag on rightCard
        final gesture = await tester.startGesture(rightPos);
        await tester.pump(const Duration(milliseconds: 100));

        // Move slightly to break the drag slop and initiate the drag
        await gesture.moveBy(const Offset(-20, -20));
        await tester.pump();

        // Drag out towards topLeft landing zone
        await gesture.moveTo(dropTargetPos);
        await tester.pump();

        // Check if gap preview is active on topLeft
        final leftKey =
            controller.coordinator?.getWidgetKey(QueuePosition.topLeft);
        final leftState = leftKey?.currentState;
        expect(leftState, isNotNull);
        expect(leftState!.externalDragGap.value, isNotNull);
        expect(leftState.externalDragGap.value!.target, equals(1));

        // Release drop
        await gesture.up();
        await tester.pumpAndSettle();

        // Verify card relocated into slot 1
        expect(leftState.activeNotifications.length, equals(3));
        expect(leftState.activeNotifications[0].id, equals(left0.id));
        expect(leftState.activeNotifications[1].id, equals(rightCard.id));
        expect(leftState.activeNotifications[2].id, equals(left1.id));

        // Verify gap cleared after drop
        expect(leftState.externalDragGap.value, isNull);

        // Verify NotificationRelocated event
        final relocatedEvents = events.whereType<NotificationRelocated>();
        expect(relocatedEvents, isNotEmpty);
        final ev = relocatedEvents.first;
        expect(ev.from, equals(QueuePosition.topRight));
        expect(ev.to, equals(QueuePosition.topLeft));
        expect(ev.toIndex, equals(1));
      },
    );

    testWidgets(
      'Mounted queue renders gap surface for middle and tail slots',
      (final tester) async {
        await tester.pumpWidget(buildApp());

        NotificationWidget(
          id: 'left_0',
          message: 'Left Card 0',
          channelName: 'left_channel',
          coordinator: controller.coordinator,
        ).show();
        NotificationWidget(
          id: 'left_1',
          message: 'Left Card 1',
          channelName: 'left_channel',
          coordinator: controller.coordinator,
        ).show();
        await tester.pumpAndSettle();

        final leftState = controller.coordinator
            ?.getWidgetKey(QueuePosition.topLeft)
            .currentState;
        expect(leftState, isNotNull);

        // Middle slot (index 1)
        leftState!.previewExternalDrop(
          targetIndex: 1,
          incomingHeight: 72,
          progress: 0.85,
          pointer: const Offset(100, 120),
        );
        await tester.pump();
        expect(
          find.bySemanticsLabel('Drop slot for incoming notification'),
          findsOneWidget,
        );

        // Tail slot (index == visibleCount == 2)
        leftState.previewExternalDrop(
          targetIndex: 2,
          incomingHeight: 72,
          progress: 0.90,
          pointer: const Offset(100, 220),
        );
        await tester.pump();
        expect(
          find.bySemanticsLabel('Drop slot for incoming notification'),
          findsOneWidget,
        );

        leftState.clearExternalDrop();
        await tester.pump();
        expect(
          find.bySemanticsLabel('Drop slot for incoming notification'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Full remote queue flags eviction candidate during external hover',
      (final tester) async {
        final fullController = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'full_left',
              position: QueuePosition.topLeft,
              defaultDismissDuration: null,
            ),
          },
          queues: {
            const NotificationQueue(
              position: QueuePosition.topLeft,
              maxStackSize: 2,
            ),
          },
        );
        addTearDown(fullController.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: fullController,
              child: child!,
            ),
            home: const Scaffold(body: SizedBox.expand()),
          ),
        );

        NotificationWidget(
          id: 'high_card',
          message: 'High',
          channelName: 'full_left',
          priority: NotificationPriority.high,
          coordinator: fullController.coordinator,
        ).show();
        NotificationWidget(
          id: 'low_card',
          message: 'Low',
          channelName: 'full_left',
          priority: NotificationPriority.low,
          coordinator: fullController.coordinator,
        ).show();
        await tester.pumpAndSettle();

        final state = fullController.coordinator
            ?.getWidgetKey(QueuePosition.topLeft)
            .currentState;
        expect(state, isNotNull);

        state!.previewExternalDrop(
          targetIndex: 0,
          incomingHeight: 72,
          progress: 0.6,
        );
        await tester.pump();

        expect(state.externalDragFeedback.value?.evictedId, equals('low_card'));

        state.clearExternalDrop();
        await tester.pump();
        expect(state.externalDragFeedback.value, isNull);
      },
    );

    testWidgets(
      'Unmounted target shows landing dock during ReorderAndRelocate drag',
      (final tester) async {
        await tester.pumpWidget(buildApp());

        // Only topRight has a notification; topLeft is completely unmounted.
        NotificationWidget(
          id: 'right_only',
          message: 'Right Card',
          channelName: 'right_channel',
          coordinator: controller.coordinator,
        ).show();
        await tester.pumpAndSettle();

        final rightFinder = find.text('Right Card');
        final startPos = tester.getCenter(rightFinder);

        final gesture = await tester.startGesture(startPos);
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.moveBy(const Offset(-20, 0));
        await tester.pump();

        // Escape home container into open space
        await gesture.moveTo(const Offset(400, 300));
        await tester.pump();

        // Expect on-location Top Left landing dock label
        expect(find.bySemanticsLabel('Top Left drop zone'), findsOneWidget);

        // Drag into the topLeft dock area (y ~ 50, x ~ 120)
        await gesture.moveTo(const Offset(120, 50));
        await tester.pump();
        expect(find.text('Drop · Top Left'), findsOneWidget);

        // Release and verify card relocated to topLeft cleanly
        await gesture.up();
        await tester.pumpAndSettle();

        final leftState = controller.coordinator
            ?.getWidgetKey(QueuePosition.topLeft)
            .currentState;
        expect(leftState?.activeNotifications.length, equals(1));
      },
    );

    testWidgets(
      'ReorderAndRelocate updates FSM once per pointer frame (no legacy '
      'intermediate states)',
      (final tester) async {
        await tester.pumpWidget(buildApp());

        NotificationWidget(
          id: 'r_card',
          message: 'Right Card',
          channelName: 'right_channel',
          coordinator: controller.coordinator,
        ).show();
        await tester.pumpAndSettle();

        final cardElement = tester.element(find.text('Right Card'));
        final dragState =
            cardElement.findAncestorStateOfType<DraggableTransitionsState>();
        expect(dragState, isNotNull);

        final seenStates = <GestureState>[];
        void listener() {
          seenStates.add(dragState!.fsm.value);
        }

        dragState!.fsm.addListener(listener);
        addTearDown(() => dragState.fsm.removeListener(listener));

        final startPos = tester.getCenter(find.text('Right Card'));
        final gesture = await tester.startGesture(startPos);
        await tester.pump(const Duration(milliseconds: 100));

        seenStates.clear();
        // First movement breaks drag slop (emits GestureLifted + first
        // GestureRearranging, with zero legacy Reordering/Relocating states).
        await gesture.moveBy(const Offset(-25, 0));
        await tester.pump();
        expect(
          seenStates,
          everyElement(anyOf(isA<GestureLifted>(), isA<GestureRearranging>())),
        );

        // Subsequent drag frames emit a single GestureRearranging transition.
        seenStates.clear();
        await gesture.moveBy(const Offset(-20, 0));
        await tester.pump();

        expect(seenStates.length, equals(1));
        expect(seenStates.single, isA<GestureRearranging>());

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Dynamic Z-axis brings hovered mounted target queue to front cleanly',
      (final tester) async {
        final multiController = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'top_right_ch',
              position: QueuePosition.topRight,
              defaultDismissDuration: null,
            ),
            const NotificationChannel(
              name: 'center_left_ch',
              position: QueuePosition.centerLeft,
              defaultDismissDuration: null,
            ),
            const NotificationChannel(
              name: 'center_right_ch',
              position: QueuePosition.centerRight,
              defaultDismissDuration: null,
            ),
          },
          queues: {
            NotificationQueue(
              position: QueuePosition.topRight,
              dragBehavior: ReorderAndRelocate.to(
                positions: {
                  QueuePosition.centerLeft,
                  QueuePosition.centerRight,
                },
              ),
            ),
          },
        );
        addTearDown(multiController.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: multiController,
              child: child!,
            ),
            home: const Scaffold(body: SizedBox.expand()),
          ),
        );

        NotificationWidget(
          id: 'cl_1',
          message: 'Center Left Card',
          channelName: 'center_left_ch',
          coordinator: multiController.coordinator,
        ).show();
        NotificationWidget(
          id: 'cr_1',
          message: 'Center Right Card',
          channelName: 'center_right_ch',
          coordinator: multiController.coordinator,
        ).show();
        NotificationWidget(
          id: 'tr_1',
          message: 'Drag Source Card',
          channelName: 'top_right_ch',
          coordinator: multiController.coordinator,
        ).show();
        await tester.pumpAndSettle();

        final clCenter = tester.getCenter(find.text('Center Left Card'));
        final trCenter = tester.getCenter(find.text('Drag Source Card'));

        final gesture = await tester.startGesture(trCenter);
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.moveBy(const Offset(-20, 0));
        await tester.pump();

        // Initially centerLeft is NOT the topmost active queue. Dragging over
        // centerLeft brings it to the top of activeQueues and focus.
        await gesture.moveTo(clCenter);
        await tester.pump();

        final coord = multiController.coordinator!;
        expect(
          coord.interactionFocus.value?.target,
          equals(QueuePosition.centerLeft),
        );
        expect(
          coord.activeQueues.value.keys.last,
          equals(QueuePosition.centerLeft),
        );

        await gesture.up();
        await tester.pumpAndSettle();

        expect(coord.interactionFocus.value, isNull);
        final clState =
            coord.getWidgetKey(QueuePosition.centerLeft).currentState;
        expect(clState?.activeNotifications.length, equals(2));
      },
    );

    testWidgets(
      'RelocationTargets promotes hovered intersecting dock to top z-order',
      (final tester) async {
        final fsm = GestureStateMachine(
          initialBehavior: Relocate.to(
            {QueuePosition.centerLeft, QueuePosition.centerRight},
          ),
          initialPosition: QueuePosition.topRight,
        );
        addTearDown(fsm.dispose);

        fsm
          ..lift(
            pointerStart: const Offset(300, 50),
            cardRect: const Rect.fromLTWH(100, 10, 260, 76),
            containerRect: const Rect.fromLTWH(100, 10, 260, 76),
          )
          ..update(
            delta: const Offset(0, 250),
            globalPosition: const Offset(150, 300),
            hoveredQueuePosition: QueuePosition.centerLeft,
            progress: 0.9,
          );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RelocationTargets(
                currentPosition: QueuePosition.topRight,
                targets: const {
                  QueuePosition.centerLeft,
                  QueuePosition.centerRight,
                },
                screenSize: const Size(400, 700),
                gestureState: fsm,
                threshold: 80,
                dockRects: const {
                  QueuePosition.centerLeft: Rect.fromLTWH(20, 260, 240, 80),
                  QueuePosition.centerRight: Rect.fromLTWH(140, 260, 240, 80),
                },
              ),
            ),
          ),
        );
        await tester.pump();

        // centerLeft is targeted so its Positioned wrapper must appear AFTER
        // centerRight inside Stack.children (highest z-order).
        final stack = tester.widget<Stack>(find.byType(Stack).first);
        final keys = stack.children.map((final w) => w.key).toList();
        expect(
          keys,
          equals([
            const ValueKey('dock_centerRight'),
            const ValueKey('dock_centerLeft'),
          ]),
        );

        // Now hover centerRight instead; stack paint order flips!
        fsm.update(
          delta: const Offset(100, 0),
          globalPosition: const Offset(250, 300),
          hoveredQueuePosition: QueuePosition.centerRight,
          progress: 0.9,
        );
        await tester.pump();

        final updatedStack = tester.widget<Stack>(find.byType(Stack).first);
        final updatedKeys =
            updatedStack.children.map((final w) => w.key).toList();
        expect(
          updatedKeys,
          equals([
            const ValueKey('dock_centerLeft'),
            const ValueKey('dock_centerRight'),
          ]),
        );
      },
    );

    testWidgets(
      'Ctrl+Enter or Cmd+Enter does not dismiss focused card as userTap',
      (final tester) async {
        final events = <NotificationEvent>[];
        final sub = controller.events.listen(events.add);
        addTearDown(sub.cancel);

        await tester.pumpWidget(buildApp());

        final card = NotificationWidget(
          id: 'focus_card',
          message: 'Keyboard Modifier Test',
          channelName: 'right_channel',
          permanent: true,
          coordinator: controller.coordinator,
        )..show();

        await tester.pumpAndSettle();
        expect(find.text('Keyboard Modifier Test'), findsOneWidget);

        // Focus the card
        final state = card.key.currentState;
        expect(state, isNotNull);
        state!.requestFocus();
        await tester.pump();
        expect(state.isFocused, isTrue);

        // Send Ctrl + Enter (app shortcut combo, e.g. Fire Draft)
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        // Card MUST NOT be dismissed by Ctrl+Enter!
        expect(find.text('Keyboard Modifier Test'), findsOneWidget);
        expect(
          events.whereType<NotificationDismissed>().where(
                (final e) =>
                    e.notification.id == 'focus_card' &&
                    e.reason == DismissReason.userTap,
              ),
          isEmpty,
        );

        // Plain Enter without modifiers SHOULD trigger tap to dismiss
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(find.text('Keyboard Modifier Test'), findsNothing);
        expect(
          events.whereType<NotificationDismissed>().where(
                (final e) =>
                    e.notification.id == 'focus_card' &&
                    e.reason == DismissReason.userTap,
              ),
          hasLength(1),
        );
      },
    );

    testWidgets(
      'Filling main queue does not dismiss relocated notifications '
      'with userTap',
      (final tester) async {
        final multiController = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'main',
              position: QueuePosition.bottomCenter,
              defaultDismissDuration: null,
            ),
          },
          queues: {
            NotificationQueue(
              position: QueuePosition.bottomCenter,
              maxStackSize: 3,
              dragBehavior: ReorderAndRelocate.to(
                positions: {
                  QueuePosition.centerLeft,
                  QueuePosition.centerRight,
                  QueuePosition.bottomLeft,
                },
              ),
            ),
          },
        );
        addTearDown(multiController.dispose);

        final events = <NotificationEvent>[];
        final sub = multiController.events.listen(events.add);
        addTearDown(sub.cancel);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: multiController,
              child: child!,
            ),
            home: const Scaffold(
              body: SizedBox.expand(),
            ),
          ),
        );

        // 1. Relocate notifications to centerLeft
        final cardRelocated1 = NotificationWidget(
          id: 'relocated_1',
          message: 'Relocated 1',
          channelName: 'main',
          permanent: true,
          coordinator: multiController.coordinator,
        )..show();
        await tester.pumpAndSettle();

        multiController.coordinator!.moveWidget(
          cardRelocated1,
          toPosition: QueuePosition.centerLeft,
        );
        await tester.pumpAndSettle();

        final cardRelocated2 = NotificationWidget(
          id: 'relocated_2',
          message: 'Relocated 2',
          channelName: 'main',
          permanent: true,
          coordinator: multiController.coordinator,
        )..show();
        await tester.pumpAndSettle();

        multiController.coordinator!.moveWidget(
          cardRelocated2,
          toPosition: QueuePosition.centerLeft,
        );
        await tester.pumpAndSettle();

        expect(find.text('Relocated 1'), findsOneWidget);
        expect(find.text('Relocated 2'), findsOneWidget);

        // 2. Dispatch 3 permanent notifications to bottomCenter to fill it
        for (int i = 0; i < 3; i++) {
          NotificationWidget(
            id: 'bottom_$i',
            message: 'Bottom Card $i',
            channelName: 'main',
            permanent: true,
            coordinator: multiController.coordinator,
          ).show();
          await tester.pumpAndSettle();
        }

        // Verify bottomCenter is full with 3 cards
        expect(find.text('Bottom Card 0'), findsOneWidget);
        expect(find.text('Bottom Card 1'), findsOneWidget);
        expect(find.text('Bottom Card 2'), findsOneWidget);

        // Verify centerLeft cards are still present
        expect(find.text('Relocated 1'), findsOneWidget);
        expect(find.text('Relocated 2'), findsOneWidget);

        // Tap on bottom center card
        await tester.tap(find.text('Bottom Card 2'));
        await tester.pumpAndSettle();

        // Relocated cards in centerLeft must NOT be dismissed!
        expect(find.text('Relocated 1'), findsOneWidget);
        expect(find.text('Relocated 2'), findsOneWidget);
        expect(
          events.whereType<NotificationDismissed>().where(
                (final e) =>
                    (e.notification.id == 'relocated_1' ||
                        e.notification.id == 'relocated_2') &&
                    e.reason == DismissReason.userTap,
              ),
          isEmpty,
        );
      },
    );

    testWidgets(
      'Relocate gesture plugin relocates to remote queue as whole container '
      'without slot splitting',
      (final tester) async {
        final relocateController = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'right',
              position: QueuePosition.topRight,
              defaultDismissDuration: null,
            ),
            const NotificationChannel(
              name: 'left',
              position: QueuePosition.topLeft,
              defaultDismissDuration: null,
            ),
          },
          queues: {
            NotificationQueue(
              position: QueuePosition.topRight,
              dragBehavior: Relocate.to({QueuePosition.topLeft}),
            ),
          },
        );
        addTearDown(relocateController.dispose);

        final events = <NotificationEvent>[];
        final sub = relocateController.events.listen(events.add);
        addTearDown(sub.cancel);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: relocateController,
              child: child!,
            ),
            home: const Scaffold(
              body: SizedBox.expand(),
            ),
          ),
        );

        // Dispatch 2 notifications into topLeft
        NotificationWidget(
          id: 'tl_0',
          message: 'TopLeft 0',
          channelName: 'left',
          coordinator: relocateController.coordinator,
        ).show();
        NotificationWidget(
          id: 'tl_1',
          message: 'TopLeft 1',
          channelName: 'left',
          coordinator: relocateController.coordinator,
        ).show();
        await tester.pumpAndSettle();

        // Dispatch 1 notification into topRight
        NotificationWidget(
          id: 'tr_drag',
          message: 'Drag Me',
          channelName: 'right',
          coordinator: relocateController.coordinator,
        ).show();
        await tester.pumpAndSettle();

        final dragCardFinder = find.text('Drag Me');
        expect(dragCardFinder, findsOneWidget);

        final tlKey =
            relocateController.coordinator!.getWidgetKey(QueuePosition.topLeft);

        // Start dragging 'Drag Me'
        final gesture =
            await tester.startGesture(tester.getCenter(dragCardFinder));
        await tester.pump(const Duration(milliseconds: 100));

        // Break touch slop to initiate drag
        await gesture.moveBy(const Offset(-20, -20));
        await tester.pump();

        // Move over topLeft container between card 0 and card 1
        final tl0Center = tester.getCenter(find.text('TopLeft 0'));
        final tl1Center = tester.getCenter(find.text('TopLeft 1'));
        final midGap = Offset(
          tl0Center.dx,
          (tl0Center.dy + tl1Center.dy) / 2.0,
        );

        await gesture.moveTo(midGap);
        await tester.pump();

        // Verify remote slot gap is NOT opened on topLeft queue (whole-queue
        // container targeting)
        final tlState = tlKey.currentState;
        expect(tlState?.externalDragGap.value, isNull);

        // Verify destination queue receives container hover feedback
        expect(tlState?.externalDragFeedback.value, isNotNull);
        expect(tlState?.externalDragFeedback.value?.progress, greaterThan(0.0));

        // Drop card into the topLeft queue
        await gesture.up();
        await tester.pumpAndSettle();

        // Verify hover feedback is cleared upon drop
        expect(tlState?.externalDragFeedback.value, isNull);

        // Verify Drag Me is now in topLeft queue (appended/sorted by target
        // queue)
        final activeInTl = tlState?.activeNotifications;
        expect(activeInTl?.length, equals(3));
        expect(activeInTl?[0].id, equals('tl_0'));
        expect(activeInTl?[1].id, equals('tl_1'));
        expect(activeInTl?[2].id, equals('tr_drag'));

        // Verify NotificationRelocated event was emitted
        expect(
          events.whereType<NotificationRelocated>().where(
                (final e) =>
                    e.notification.id == 'tr_drag' &&
                    e.to == QueuePosition.topLeft &&
                    e.toIndex == null,
              ),
          hasLength(1),
        );
      },
    );

    testWidgets(
      'Relocate gesture plugin does NOT reorder within home queue',
      (final tester) async {
        final homeRelocateController = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'right',
              position: QueuePosition.topRight,
              defaultDismissDuration: null,
            ),
          },
          queues: {
            NotificationQueue(
              position: QueuePosition.topRight,
              dragBehavior: Relocate.to({QueuePosition.topLeft}),
            ),
          },
        );
        addTearDown(homeRelocateController.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: homeRelocateController,
              child: child!,
            ),
            home: const Scaffold(
              body: SizedBox.expand(),
            ),
          ),
        );

        // Dispatch 2 notifications into topRight
        NotificationWidget(
          id: 'card_0',
          message: 'First Card',
          channelName: 'right',
          coordinator: homeRelocateController.coordinator,
        ).show();
        NotificationWidget(
          id: 'card_1',
          message: 'Second Card',
          channelName: 'right',
          coordinator: homeRelocateController.coordinator,
        ).show();
        await tester.pumpAndSettle();

        final trKey = homeRelocateController.coordinator!
            .getWidgetKey(QueuePosition.topRight);
        final trState = trKey.currentState;

        // Drag 'First Card' downwards within the home container
        final firstFinder = find.text('First Card');
        final secondFinder = find.text('Second Card');
        final gesture = await tester.startGesture(
          tester.getCenter(firstFinder),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Break touch slop downwards inside home container
        await gesture.moveBy(const Offset(0, 25));
        await tester.pump();

        // Move to the second card, still inside home container
        final secondCenter = tester.getCenter(secondFinder);
        await gesture.moveTo(secondCenter);
        await tester.pump();

        // Verify NO in-queue reorder drag gap is opened
        expect(trState?.reorderDragState.value, isNull);

        // Release inside home container
        await gesture.up();
        await tester.pumpAndSettle();

        // Verify order has NOT changed: First Card is still at index 0
        final activeInTr = trState?.activeNotifications;
        expect(activeInTr?.length, equals(2));
        expect(activeInTr?[0].id, equals('card_0'));
        expect(activeInTr?[1].id, equals('card_1'));
      },
    );
  });
}
