import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Notification Grouping / Bundling (F-04)', () {
    test('QueueGroupingBehavior defaults and custom properties', () {
      const g = QueueGroupingBehavior(
        enabled: true,
        maxBeforeGrouping: 3,
        maxStackedLayers: 4,
        stackStepOffset: 8.0,
        stackScaleMultiplier: 0.08,
        enableGroupSwipeDismiss: true,
        groupDismissThreshold: 0.5,
      );
      expect(g.enabled, isTrue);
      expect(g.maxBeforeGrouping, equals(3));
      expect(g.maxStackedLayers, equals(4));
      expect(g.stackStepOffset, equals(8.0));
      expect(g.stackScaleMultiplier, equals(0.08));
      expect(g.enableGroupSwipeDismiss, isTrue);
      expect(g.groupDismissThreshold, equals(0.5));

      const gDefault = QueueGroupingBehavior();
      expect(gDefault.enabled, isFalse);
      expect(gDefault.maxBeforeGrouping, equals(2));
    });

    test('resolvedGroupKey fallback behavior', () {
      final n1 = NotificationWidget(
        message: 'No key',
        channelName: 'chat',
      );
      expect(n1.resolvedGroupKey, equals('chat'));

      final n2 = NotificationWidget(
        message: 'With key',
        channelName: 'chat',
        groupKey: 'custom_group',
      );
      expect(n2.resolvedGroupKey, equals('custom_group'));
    });

    testWidgets(
        'Scenario 1: Multi-Group Lifecycle - Grouping, Isolated '
        'Expansion/Collapse, Priority Triage/Overflow, and Programmatic '
        'Dismissal', (final tester) async {
      final controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'chat',
            position: QueuePosition.topRight,
            defaultDismissDuration: null,
          ),
          const NotificationChannel(
            name: 'system',
            position: QueuePosition.bottomLeft,
            defaultDismissDuration: null,
          ),
        },
        queues: {
          const NotificationQueue(
            position: QueuePosition.topRight,
            groupingBehavior: QueueGroupingBehavior(
              enabled: true,
              maxBeforeGrouping: 2,
            ),
            maxStackSize: 2,
          ),
          const NotificationQueue(
            position: QueuePosition.bottomLeft,
            groupingBehavior: QueueGroupingBehavior(
              enabled: true,
              maxBeforeGrouping: 2,
            ),
            maxStackSize: 2,
          ),
        },
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (final context, final child) => NotificationScope(
            controller: controller,
            child: child!,
          ),
          home: const Scaffold(body: Center(child: Text('App Home'))),
        ),
      );

      // 1. Enqueue single 'chat' notification (c1) to Top Right
      NotificationWidget(
        id: 'c1',
        message: 'Chat 1',
        channelName: 'chat',
        priority: NotificationPriority.low,
        coordinator: controller.coordinator,
      ).show();
      await tester.pumpAndSettle();

      // Verify c1 is active and visible as standard individual item.
      expect(find.text('Chat 1'), findsOneWidget);
      expect(find.text('+1'), findsNothing);

      // 2. Enqueue second 'chat' notification (c2) -> should activate
      // grouping automatically
      NotificationWidget(
        id: 'c2',
        message: 'Chat 2',
        channelName: 'chat',
        coordinator: controller.coordinator,
      ).show();
      await tester.pumpAndSettle();

      // Grouping activates itself once threshold (2) is met.
      // Chat 2 is the representative. Chat 1 is hidden. Badge
      // indication '+1' is visible.
      expect(find.text('Chat 2'), findsOneWidget);
      expect(find.text('Chat 1'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('chat')),
          matching: find.text('+1'),
        ),
        findsOneWidget,
      );

      // 3. Enqueue first 'system' notification (s1) to Bottom Left
      NotificationWidget(
        id: 's1',
        message: 'System 1',
        channelName: 'system',
        coordinator: controller.coordinator,
      ).show();
      await tester.pumpAndSettle();

      // Both queues are active concurrently. Sys 1 is visible at
      // bottom left; Chat 2 at top right.
      expect(find.text('Chat 2'), findsOneWidget);
      expect(find.text('System 1'), findsOneWidget);

      // 4. Enqueue second 'system' notification (s2) -> should activate
      // system grouping automatically
      NotificationWidget(
        id: 's2',
        message: 'System 2',
        channelName: 'system',
        coordinator: controller.coordinator,
      ).show();
      await tester.pumpAndSettle();

      // System grouping is activated.
      // Since bottomLeft is bottom-anchored, the oldest card (System 1)
      // is the representative.
      // System 1 is visible, System 2 is hidden. Badge '+1' is visible
      // at Bottom Left.
      expect(find.text('Chat 2'), findsOneWidget);
      expect(find.text('System 1'), findsOneWidget);
      expect(find.text('Chat 1'), findsNothing);
      expect(find.text('System 2'), findsNothing);
      expect(find.text('+1'), findsNWidgets(2));

      // 5. Expand 'chat' group at Top Right
      final chatGroupFinder = find.byKey(const ValueKey('chat'));
      await tester
          .tap(find.descendant(of: chatGroupFinder, matching: find.text('+1')));
      await tester.pumpAndSettle();

      // 'chat' group expanded: Chat 2, Chat 1 and Collapse button are visible.
      expect(find.text('Chat 2'), findsOneWidget);
      expect(find.text('Chat 1'), findsOneWidget);
      expect(
        find.descendant(
          of: chatGroupFinder,
          matching: find.text('Collapse'),
        ),
        findsOneWidget,
      );

      // 'system' group remains collapsed at Bottom Left: System 2 is
      // hidden, System 1 + badge is visible
      final systemGroupFinder = find.byKey(const ValueKey('system'));
      expect(find.text('System 1'), findsOneWidget);
      expect(find.text('System 2'), findsNothing);
      expect(
        find.descendant(
          of: systemGroupFinder,
          matching: find.text('+1'),
        ),
        findsOneWidget,
      );

      // 6. Enqueue critical 'chat' notification (c3) to trigger
      // topRight queue overflow (maxStackSize: 2)
      // Since queue has c1 (low) and c2 (normal), adding c3 (high)
      // should evict c1.
      NotificationWidget(
        id: 'c3',
        message: 'Chat 3',
        channelName: 'chat',
        priority: NotificationPriority.high,
        coordinator: controller.coordinator,
      ).show();
      await tester.pumpAndSettle();

      // Verify Chat 3 is visible, Chat 1 is evicted
      expect(find.text('Chat 3'), findsOneWidget);
      expect(find.text('Chat 1'), findsNothing);

      // 7. Collapse 'chat' group at Top Right
      await tester.tap(
        find.descendant(
          of: chatGroupFinder,
          matching: find.text('Collapse'),
        ),
      );
      await tester.pumpAndSettle();

      // Chat 3 is representative, Chat 2 is underneath
      expect(find.text('Chat 3'), findsOneWidget);
      expect(find.text('Chat 2'), findsNothing);

      // 8. Programmatic group dismissal for 'chat' queue
      controller.coordinator?.dismissGroup('chat');
      await tester.pumpAndSettle();

      // Chat notifications are gone, system group remains at Bottom Left
      expect(find.text('Chat 3'), findsNothing);
      expect(find.text('Chat 2'), findsNothing);
      expect(find.text('System 1'), findsOneWidget);

      // 9. Programmatic item dismissal on System 1 representative
      final s1Widget = NotificationWidget(
        id: 's1',
        message: 'System 1',
        channelName: 'system',
        coordinator: controller.coordinator,
      );
      final dismissFuture = s1Widget.dismiss();
      await tester.pumpAndSettle();
      await dismissFuture;

      // System 1 is gone, System 2 has surfaced and is now visible
      // at Bottom Left
      expect(find.text('System 1'), findsNothing);
      expect(find.text('System 2'), findsOneWidget);
    });

    testWidgets(
        'Scenario 2: Advanced Interactive Gestures - Drag-to-Peek, '
        'Swipe-to-Dismiss Config, and Expanded Swipe', (final tester) async {
      // Configuration with enableGroupSwipeDismiss = true on
      // Bottom Right Position
      final controller1 = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'chat',
            position: QueuePosition.bottomRight,
            defaultDismissDuration: null,
          ),
        },
        queues: {
          const NotificationQueue(
            position: QueuePosition.bottomRight,
            dragBehavior: Dismiss(),
            groupingBehavior: QueueGroupingBehavior(
              enabled: true,
              maxBeforeGrouping: 2,
              enableGroupSwipeDismiss: true,
            ),
          ),
        },
      );
      addTearDown(controller1.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (final context, final child) => NotificationScope(
            controller: controller1,
            child: child!,
          ),
          home: const Scaffold(body: Center(child: Text('App Home'))),
        ),
      );

      // Enqueue 2 notifications to bundle automatically on Bottom Right
      NotificationWidget(
        id: 'c1',
        message: 'Chat 1',
        channelName: 'chat',
        coordinator: controller1.coordinator,
      ).show();
      NotificationWidget(
        id: 'c2',
        message: 'Chat 2',
        channelName: 'chat',
        coordinator: controller1.coordinator,
      ).show();
      await tester.pumpAndSettle();

      // Bottom Right is bottom-anchored: oldest (Chat 1) is the representative
      expect(find.text('Chat 1'), findsOneWidget);
      expect(find.text('Chat 2'), findsNothing);

      // 1. Drag representative slightly to peek underneath
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Chat 1')));
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();

      // During drag: both Chat 1 and Chat 2 (peeked) are visible
      expect(find.text('Chat 2'), findsOneWidget);

      // Cancel drag
      await gesture.moveBy(const Offset(-50, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      // 2. Swipe to dismiss entire group (enableGroupSwipeDismiss = true)
      await tester.drag(find.text('Chat 1'), const Offset(300, 0));
      await tester.pumpAndSettle();

      // Both chat notifications dismissed
      expect(find.text('Chat 2'), findsNothing);
      expect(find.text('Chat 1'), findsNothing);

      // 3. Reconfigure with enableGroupSwipeDismiss = false on
      // Top Left Position
      final controller2 = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'chat',
            position: QueuePosition.topLeft,
            defaultDismissDuration: null,
          ),
        },
        queues: {
          const NotificationQueue(
            position: QueuePosition.topLeft,
            dragBehavior: Dismiss(),
            groupingBehavior: QueueGroupingBehavior(
              enabled: true,
              maxBeforeGrouping: 2,
              enableGroupSwipeDismiss: false,
            ),
          ),
        },
      );
      addTearDown(controller2.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (final context, final child) => NotificationScope(
            key: ValueKey(controller2),
            controller: controller2,
            child: child!,
          ),
          home: const Scaffold(body: Center(child: Text('App Home'))),
        ),
      );

      // Enqueue 3 notifications
      NotificationWidget(
        id: 'c1',
        message: 'Chat 1',
        channelName: 'chat',
        coordinator: controller2.coordinator,
      ).show();
      NotificationWidget(
        id: 'c2',
        message: 'Chat 2',
        channelName: 'chat',
        coordinator: controller2.coordinator,
      ).show();
      NotificationWidget(
        id: 'c3',
        message: 'Chat 3',
        channelName: 'chat',
        coordinator: controller2.coordinator,
      ).show();
      await tester.pumpAndSettle();

      // Top Left is top-anchored: newest (Chat 3) is the representative
      expect(find.text('Chat 3'), findsOneWidget);
      expect(find.text('Chat 2'), findsNothing);

      // 4. Swipe to dismiss representative (enableGroupSwipeDismiss = false)
      // Since it is topLeft, we swipe left (negative X offset) to dismiss
      await tester.drag(find.text('Chat 3'), const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Chat 3 is gone, Chat 2 surfaces, +1 badge visible
      // (Chat 2 & Chat 1 remain)
      expect(find.text('Chat 3'), findsNothing);
      expect(find.text('Chat 2'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('chat')),
          matching: find.text('+1'),
        ),
        findsOneWidget,
      );

      // 5. Expand remaining group
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('chat')),
          matching: find.text('+1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chat 2'), findsOneWidget);
      expect(find.text('Chat 1'), findsOneWidget);

      // 6. Swipe to dismiss one item in the expanded list (Chat 2)
      // Since it is topLeft, we swipe left (negative X offset) to dismiss
      await tester.drag(find.text('Chat 2'), const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Chat 2 is dismissed, Chat 1 remains visible.
      // Since only 1 notification remains, grouping controls are removed.
      expect(find.text('Chat 2'), findsNothing);
      expect(find.text('Chat 1'), findsOneWidget);
      expect(find.text('Collapse'), findsNothing);
      expect(find.text('+1'), findsNothing);
    });

    testWidgets(
      'Peek card under dragged representative remains in timer stasis and '
      'does not expire',
      (final tester) async {
        final controller = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'chat',
              position: QueuePosition.topCenter,
              defaultDismissDuration: Duration(seconds: 3),
            ),
          },
          queues: {
            const NotificationQueue(
              position: QueuePosition.topCenter,
              groupingBehavior: QueueGroupingBehavior(
                enabled: true,
                maxBeforeGrouping: 2,
              ),
            ),
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(body: Center(child: Text('App Home'))),
          ),
        );

        // Enqueue 2 notifications with 3-second auto-dismiss
        NotificationWidget(
          id: 'c1',
          message: 'Chat 1',
          channelName: 'chat',
          coordinator: controller.coordinator,
        ).show();
        await tester.pump();

        NotificationWidget(
          id: 'c2',
          message: 'Chat 2',
          channelName: 'chat',
          coordinator: controller.coordinator,
        ).show();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Top Left is top-anchored: newest (Chat 2) is the representative
        expect(find.text('Chat 2'), findsOneWidget);
        expect(find.text('Chat 1'), findsNothing);

        // 1. Drag representative inward to peek underneath (away from edge)
        final gesture =
            await tester.startGesture(tester.getCenter(find.text('Chat 2')));
        await gesture.moveBy(const Offset(40, 0));
        await tester.pump();

        // Chat 1 is rendered as peek card
        expect(find.text('Chat 1'), findsOneWidget);

        // 2. Advance time by 4s (longer than the 3s timeout) while holding drag
        await tester.pump(const Duration(seconds: 4));

        // Peek card must NOT have timed out — it remains in stasis!
        expect(find.text('Chat 1'), findsOneWidget);
        expect(find.text('Chat 2'), findsOneWidget);

        // 3. Cancel drag by snapping back
        await gesture.moveBy(const Offset(-40, 0));
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Stack returns to collapsed state: Chat 1 is dormant/hidden again
        expect(find.text('Chat 2'), findsOneWidget);
        expect(find.text('Chat 1'), findsNothing);

        // 4. Swipe to dismiss Chat 2 towards left screen edge
        await tester.drag(find.text('Chat 2'), const Offset(-400, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Chat 2 is dismissed; Chat 1 surfaces as the new representative
        expect(find.text('Chat 2'), findsNothing);
        expect(find.text('Chat 1'), findsOneWidget);

        // 5. Chat 1 should now run its dismiss timer fresh and expire after 3s
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('Chat 1'), findsOneWidget);

        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        expect(find.text('Chat 1'), findsNothing);
      },
    );

    testWidgets(
      'Expanded bundle pauses auto-dismiss timers when '
      'pauseTimersWhenExpanded is true',
      (final tester) async {
        final controller = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'alerts',
              position: QueuePosition.topRight,
              defaultDismissDuration: Duration(seconds: 3),
            ),
          },
          queues: {
            const NotificationQueue(
              position: QueuePosition.topRight,
              groupingBehavior: QueueGroupingBehavior(
                enabled: true,
                maxBeforeGrouping: 2,
                pauseTimersWhenExpanded: true,
              ),
            ),
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(body: Center(child: Text('App Home'))),
          ),
        );

        NotificationWidget(
          id: 'a1',
          message: 'Alert 1',
          channelName: 'alerts',
          coordinator: controller.coordinator,
        ).show();
        await tester.pump();

        NotificationWidget(
          id: 'a2',
          message: 'Alert 2',
          channelName: 'alerts',
          coordinator: controller.coordinator,
        ).show();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Expand the bundle
        final alertsGroupFinder = find.byKey(const ValueKey('alerts'));
        await tester.tap(
          find.descendant(
            of: alertsGroupFinder,
            matching: find.text('+1'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Alert 1'), findsOneWidget);
        expect(find.text('Alert 2'), findsOneWidget);

        // Advance 5 seconds while expanded
        await tester.pump(const Duration(seconds: 5));

        // Neither alert timed out while reading the expanded list
        expect(find.text('Alert 1'), findsOneWidget);
        expect(find.text('Alert 2'), findsOneWidget);

        // Collapse the bundle
        await tester.tap(
          find.descendant(
            of: alertsGroupFinder,
            matching: find.text('Collapse'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Alert 2 is top representative; Alert 1 is hidden
        expect(find.text('Alert 2'), findsOneWidget);
        expect(find.text('Alert 1'), findsNothing);

        // After collapsing, rep timer runs and expires after 3 seconds
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 350));

        // Alert 2 dismissed, Alert 1 surfaces
        expect(find.text('Alert 2'), findsNothing);
        expect(find.text('Alert 1'), findsOneWidget);

        // After another 3-4 seconds, Alert 1 times out as well
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(find.text('Alert 1'), findsNothing);
      },
    );

    testWidgets(
      'GroupCountBehavior.TotalCount renders total count in pill',
      (final tester) async {
        final controller = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'chat',
              position: QueuePosition.topRight,
              defaultDismissDuration: null,
            ),
          },
          queues: {
            const NotificationQueue(
              position: QueuePosition.topRight,
              groupingBehavior: QueueGroupingBehavior(
                enabled: true,
                maxBeforeGrouping: 2,
                countBehavior: TotalCount(),
              ),
              maxStackSize: 5,
            ),
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(body: Center(child: Text('App Home'))),
          ),
        );

        NotificationWidget(
          id: 'c1',
          title: 'Alice',
          message: 'Hello',
          channelName: 'chat',
          coordinator: controller.coordinator,
        ).show();
        await tester.pumpAndSettle();

        NotificationWidget(
          id: 'c2',
          title: 'Alice',
          message: 'How are you?',
          channelName: 'chat',
          coordinator: controller.coordinator,
        ).show();
        await tester.pumpAndSettle();

        // 2 items total: TotalCount should render '2', not '+1'
        expect(find.text('2'), findsOneWidget);
        expect(find.text('+1'), findsNothing);

        NotificationWidget(
          id: 'c3',
          title: 'Alice',
          message: 'See you',
          channelName: 'chat',
          coordinator: controller.coordinator,
        ).show();
        await tester.pumpAndSettle();

        // 3 items total: TotalCount should render '3'
        expect(find.text('3'), findsOneWidget);
        expect(find.text('+2'), findsNothing);
      },
    );

    testWidgets(
      'GroupCountBehavior includePending reflects backlog volume in pill',
      (final tester) async {
        final controller = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'chat',
              position: QueuePosition.topRight,
              defaultDismissDuration: null,
            ),
          },
          queues: {
            const NotificationQueue(
              position: QueuePosition.topRight,
              groupingBehavior: QueueGroupingBehavior(
                enabled: true,
                maxBeforeGrouping: 2,
                countBehavior: HiddenCount(includePending: true),
              ),
              maxStackSize: 2,
            ),
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(body: Center(child: Text('App Home'))),
          ),
        );

        for (int i = 1; i <= 5; i++) {
          NotificationWidget(
            id: 'm$i',
            title: 'Chat',
            message: 'Msg $i',
            channelName: 'chat',
            coordinator: controller.coordinator,
          ).show();
        }
        await tester.pumpAndSettle();

        // 5 items total: 2 active + 3 pending in backlog.
        // With includePending: true, hiddenCount is 5 - 1 = 4.
        expect(find.text('+4'), findsOneWidget);
      },
    );

    testWidgets(
      'GroupCountBehavior includePending: false ignores backlog items in count',
      (final tester) async {
        final controller = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'chat',
              position: QueuePosition.topRight,
              defaultDismissDuration: null,
            ),
          },
          queues: {
            const NotificationQueue(
              position: QueuePosition.topRight,
              groupingBehavior: QueueGroupingBehavior(
                enabled: true,
                maxBeforeGrouping: 2,
                countBehavior: HiddenCount(includePending: false),
              ),
              maxStackSize: 2,
            ),
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(body: Center(child: Text('App Home'))),
          ),
        );

        for (int i = 1; i <= 5; i++) {
          NotificationWidget(
            id: 'm$i',
            title: 'Chat',
            message: 'Msg $i',
            channelName: 'chat',
            coordinator: controller.coordinator,
          ).show();
        }
        await tester.pumpAndSettle();

        // 5 items total: 2 active + 3 pending in backlog.
        // With includePending: false, only active items count: 2 - 1 = 1.
        expect(find.text('+1'), findsOneWidget);
        expect(find.text('+4'), findsNothing);
      },
    );

    testWidgets(
      'GroupCountBehavior.NoCount suppresses number counter in pill',
      (final tester) async {
        final controller = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'chat',
              position: QueuePosition.topRight,
              defaultDismissDuration: null,
            ),
          },
          queues: {
            const NotificationQueue(
              position: QueuePosition.topRight,
              groupingBehavior: QueueGroupingBehavior(
                enabled: true,
                maxBeforeGrouping: 2,
                countBehavior: NoCount(),
              ),
              maxStackSize: 5,
            ),
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(body: Center(child: Text('App Home'))),
          ),
        );

        NotificationWidget(
          id: 'c1',
          title: 'Alice',
          message: 'Hello',
          channelName: 'chat',
          coordinator: controller.coordinator,
        ).show();
        await tester.pumpAndSettle();

        NotificationWidget(
          id: 'c2',
          title: 'Alice',
          message: 'How are you?',
          channelName: 'chat',
          coordinator: controller.coordinator,
        ).show();
        await tester.pumpAndSettle();

        // No count number should be present
        expect(find.text('+1'), findsNothing);
        expect(find.text('2'), findsNothing);
        // The title preview is still shown in the pill
        expect(find.text('Alice'), findsWidgets);
      },
    );

    testWidgets(
      'swiping a collapsed bundle with backlog items atomically purges '
      'both active and pending items, promoting other channels',
      (final tester) async {
        final controller = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'chat',
              position: QueuePosition.topRight,
              defaultDismissDuration: null,
            ),
            const NotificationChannel(
              name: 'system',
              position: QueuePosition.topRight,
              defaultDismissDuration: null,
            ),
          },
          queues: {
            const NotificationQueue(
              position: QueuePosition.topRight,
              maxStackSize: 2,
              dragBehavior: Dismiss(),
              groupingBehavior: QueueGroupingBehavior(
                enabled: true,
                maxBeforeGrouping: 2,
                enableGroupSwipeDismiss: true,
              ),
            ),
          },
        );
        addTearDown(controller.dispose);

        final events = <NotificationEvent>[];
        final sub = controller.events.listen(events.add);
        addTearDown(sub.cancel);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(body: Center(child: Text('App Home'))),
          ),
        );

        // 1. Enqueue 6 notifications in group 'chat'.
        // With maxStackSize: 2, cards c1 & c2 will be active, and
        // c3, c4, c5, c6 will sit in the pending backlog.
        for (int i = 1; i <= 6; i++) {
          NotificationWidget(
            id: 'c$i',
            title: 'Chat $i',
            message: 'Message $i',
            channelName: 'chat',
            coordinator: controller.coordinator,
          ).show();
        }
        await tester.pumpAndSettle();

        // 2. Also enqueue 1 notification in channel 'system', which waits
        // in backlog because chat took both active slots.
        NotificationWidget(
          id: 'sys1',
          title: 'System Alert',
          message: 'Battery Low',
          channelName: 'system',
          coordinator: controller.coordinator,
        ).show();
        await tester.pumpAndSettle();

        // Top-right queue shows top representative (Chat 2).
        expect(find.text('Chat 2'), findsOneWidget);
        expect(find.text('System Alert'), findsNothing);

        // 3. Swipe the collapsed chat bundle to dismiss it.
        await tester.drag(find.text('Chat 2'), const Offset(300, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // 4. Verify ALL 6 chat notifications are gone atomically.
        // None of c3..c6 should have been promoted.
        for (int i = 1; i <= 6; i++) {
          expect(find.text('Chat $i'), findsNothing);
        }

        // 5. Verify the pending 'system' notification was promoted into the
        // freed slot.
        expect(find.text('System Alert'), findsOneWidget);

        // 6. Verify event stream:
        // - Exactly 1 NotificationGroupDismissed for 'chat'
        final groupDismissedEvents =
            events.whereType<NotificationGroupDismissed>().toList();
        expect(groupDismissedEvents, hasLength(1));
        expect(groupDismissedEvents.first.groupKey, 'chat');

        // - Exactly 6 NotificationDismissed for c1..c6 with reason userSwipe
        final chatDismissed = events
            .whereType<NotificationDismissed>()
            .where((final e) => e.notification.channelName == 'chat')
            .toList();
        expect(chatDismissed, hasLength(6));
        final dismissedIds =
            chatDismissed.map((final e) => e.notification.id).toSet();
        expect(dismissedIds, {'c1', 'c2', 'c3', 'c4', 'c5', 'c6'});
        for (final e in chatDismissed) {
          expect(e.reason, DismissReason.userSwipe);
        }
      },
    );

    testWidgets(
      'controller.dismissGroup purges active and pending backlog items '
      'atomically with programmatic reason',
      (final tester) async {
        final controller = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'chat',
              position: QueuePosition.topRight,
              defaultDismissDuration: null,
            ),
          },
          queues: {
            const NotificationQueue(
              position: QueuePosition.topRight,
              maxStackSize: 2,
              groupingBehavior: QueueGroupingBehavior(
                enabled: true,
                maxBeforeGrouping: 2,
              ),
            ),
          },
        );
        addTearDown(controller.dispose);

        final events = <NotificationEvent>[];
        final sub = controller.events.listen(events.add);
        addTearDown(sub.cancel);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(body: Center(child: Text('App Home'))),
          ),
        );

        for (int i = 1; i <= 5; i++) {
          NotificationWidget(
            id: 'c$i',
            title: 'Chat $i',
            message: 'Message $i',
            channelName: 'chat',
            coordinator: controller.coordinator,
          ).show();
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        controller.dismissGroup('chat');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        for (int i = 1; i <= 5; i++) {
          expect(find.text('Chat $i'), findsNothing);
        }

        final groupEvents =
            events.whereType<NotificationGroupDismissed>().toList();
        expect(groupEvents, hasLength(1));
        expect(groupEvents.first.groupKey, 'chat');

        final itemEvents =
            events.whereType<NotificationDismissed>().toList();
        expect(itemEvents, hasLength(5));
        for (final e in itemEvents) {
          expect(e.reason, DismissReason.programmatic);
        }
      },
    );
  });
}
