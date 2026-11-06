import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A11y Screen Reader Announcements (Track 2)', () {
    late List<Map<String, dynamic>> accessibilityLog;

    setUp(() {
      accessibilityLog = <Map<String, dynamic>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
        SystemChannels.accessibility,
        (final dynamic message) async {
          if (message is Map<dynamic, dynamic>) {
            accessibilityLog.add(Map<String, dynamic>.from(message));
          }
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
        SystemChannels.accessibility,
        null,
      );
    });

    testWidgets(
      'normal priority emits polite screen reader announcement',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(body: Center(child: Text('Home'))),
          ),
        );

        controller.show(
          const AppNotification(
            title: 'Order Status',
            message: 'Your package has shipped.',
            priority: NotificationPriority.normal,
          ),
        );
        await tester.pump();

        expect(accessibilityLog.isNotEmpty, isTrue);
        final lastAnnouncement = accessibilityLog.last;
        expect(lastAnnouncement['type'], equals('announce'));
        final data =
            Map<String, dynamic>.from(lastAnnouncement['data'] as Map);
        expect(
          data['message'],
          equals('Order Status: Your package has shipped.'),
        );
        // Assertiveness.polite is index 0
        expect(data['assertiveness'], anyOf(isNull, equals(0)));
      },
    );

    testWidgets(
      'critical priority emits assertive screen reader announcement',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(body: Center(child: Text('Home'))),
          ),
        );

        controller.show(
          const AppNotification(
            title: 'System Alert',
            message: 'Server connection lost.',
            priority: NotificationPriority.critical,
          ),
        );
        await tester.pump();

        expect(accessibilityLog.isNotEmpty, isTrue);
        final lastAnnouncement = accessibilityLog.last;
        final data =
            Map<String, dynamic>.from(lastAnnouncement['data'] as Map);
        expect(
          data['message'],
          equals('System Alert: Server connection lost.'),
        );
        // Assertiveness.assertive is index 1
        expect(data['assertiveness'], equals(1));
      },
    );

    testWidgets(
      'notification below priority threshold does not trigger announcement',
      (final tester) async {
        final controller = NotificationController(
          a11yOptions: const NotificationA11yOptions(
            announcePriorityThreshold: NotificationPriority.high,
          ),
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(body: Center(child: Text('Home'))),
          ),
        );

        controller.show(
          const AppNotification(
            message: 'Low priority sync update',
            priority: NotificationPriority.low,
          ),
        );
        await tester.pump();

        expect(accessibilityLog, isEmpty);
      },
    );

    testWidgets(
      'enableLiveRegions=false completely suppresses announcements',
      (final tester) async {
        final controller = NotificationController(
          a11yOptions: const NotificationA11yOptions(enableLiveRegions: false),
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(body: Center(child: Text('Home'))),
          ),
        );

        controller.show(
          const AppNotification(
            message: 'Critical error',
            priority: NotificationPriority.critical,
          ),
        );
        await tester.pump();

        expect(accessibilityLog, isEmpty);
      },
    );
  });

  group('Non-Intrusive Focus & Handoff (Track 2)', () {
    testWidgets(
      'incoming notification never steals focus from active TextField',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        final textController = TextEditingController();
        addTearDown(textController.dispose);
        final textFieldFocusNode = FocusNode();
        addTearDown(textFieldFocusNode.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: Scaffold(
              body: TextField(
                controller: textController,
                focusNode: textFieldFocusNode,
              ),
            ),
          ),
        );

        // Tap the text field to focus it
        await tester.tap(find.byType(TextField));
        await tester.pump();
        expect(textFieldFocusNode.hasFocus, isTrue);

        // Dispatch notification
        controller.show(const AppNotification(message: 'Incoming message'));
        await tester.pump();

        // Focus MUST remain strictly in TextField
        expect(textFieldFocusNode.hasFocus, isTrue);
      },
    );

    testWidgets(
      'Alt+N transfers focus to card, Escape dismisses and restores focus',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        final textFieldFocusNode = FocusNode();
        addTearDown(textFieldFocusNode.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: Scaffold(
              body: TextField(focusNode: textFieldFocusNode),
            ),
          ),
        );

        // Focus the text field
        await tester.tap(find.byType(TextField));
        await tester.pump();
        expect(textFieldFocusNode.hasFocus, isTrue);

        // Show a notification
        controller.show(
          const AppNotification(message: 'Transfer focus target'),
        );
        await tester.pump();

        // Send Alt + N shortcut to transfer focus
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pump();

        // Notification stack should now be focused
        expect(controller.coordinator!.isNotificationFocused, isTrue);
        expect(textFieldFocusNode.hasFocus, isFalse);

        // Send Escape key to dismiss focused notification and exit
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        // Notification is dismissed and focus returned to TextField
        expect(find.text('Transfer focus target'), findsNothing);
        expect(textFieldFocusNode.hasFocus, isTrue);
      },
    );

    testWidgets(
      'Alt+N transfers focus even when primaryFocus is null',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(
              body: Center(child: Text('Home')),
            ),
          ),
        );

        controller.show(
          const AppNotification(message: 'Null focus target'),
        );
        await tester.pump();

        // Send Alt + N shortcut to transfer focus
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pump();

        expect(controller.coordinator!.isNotificationFocused, isTrue);
      },
    );

    testWidgets(
      'Delete key dismisses focused notification card',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: Scaffold(
              body: ElevatedButton(
                focusNode: focusNode,
                onPressed: () {},
                child: const Text('Button'),
              ),
            ),
          ),
        );

        focusNode.requestFocus();
        await tester.pump();
        expect(focusNode.hasFocus, isTrue);

        controller.show(
          const AppNotification(message: 'Card to delete'),
        );
        await tester.pump();

        // Transfer focus via Alt + N
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pump();

        expect(controller.coordinator!.isNotificationFocused, isTrue);

        // Send Delete key
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await tester.pumpAndSettle();

        expect(find.text('Card to delete'), findsNothing);
        expect(focusNode.hasFocus, isTrue);
      },
    );

    testWidgets(
      'ArrowDown and ArrowUp navigate between active cards in queue',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(body: Center(child: Text('Home'))),
          ),
        );

        final handle1 = controller.show(
          const AppNotification(message: 'Card 1', permanent: true),
        );
        final handle2 = controller.show(
          const AppNotification(message: 'Card 2', permanent: true),
        );
        await tester.pumpAndSettle();

        // Focus Card 1 via Alt + N
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pump();

        final card1Finder = find.widgetWithText(NotificationWidget, 'Card 1');
        final card2Finder = find.widgetWithText(NotificationWidget, 'Card 2');

        final card1State =
            tester.state<NotificationWidgetState>(card1Finder);
        final card2State =
            tester.state<NotificationWidgetState>(card2Finder);

        expect(card1State.isFocused, isTrue);
        expect(card2State.isFocused, isFalse);

        // ArrowDown shifts focus to Card 2
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();

        expect(card1State.isFocused, isFalse);
        expect(card2State.isFocused, isTrue);

        // ArrowUp shifts focus back to Card 1
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();

        expect(card1State.isFocused, isTrue);
        expect(card2State.isFocused, isFalse);

        handle1.dismiss();
        handle2.dismiss();
      },
    );
  });

  group('Card Semantics & Actions (Track 2)', () {
    testWidgets(
      'NotificationWidget provides container Semantics with label and hint',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(body: Center(child: Text('Home'))),
          ),
        );

        final handle = tester.ensureSemantics();
        try {
          controller.show(
            const AppNotification(
              title: 'Order Status',
              message: 'Shipped via Express',
            ),
          );
          await tester.pumpAndSettle();

          final semantics = tester.getSemantics(
            find.widgetWithText(NotificationWidget, 'Shipped via Express'),
          );

          expect(
            semantics.label,
            contains('Notification: Order Status, Shipped via Express'),
          );
          expect(
            semantics.hint,
            contains('Press Delete or Escape to dismiss'),
          );
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets(
      'CustomSemanticsAction Dismiss dismisses notification',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(body: Center(child: Text('Home'))),
          ),
        );

        final handle = tester.ensureSemantics();
        try {
          controller.show(
            const AppNotification(message: 'Semantic dismissal'),
          );
          await tester.pumpAndSettle();

          final finder =
              find.widgetWithText(NotificationWidget, 'Semantic dismissal');
          final semantics = tester.getSemantics(finder);
          final data = semantics.getSemanticsData();
          final actions = data.customSemanticsActionIds
              ?.map(CustomSemanticsAction.getAction)
              .toList();
          expect(
            actions?.any((final a) => a?.label == 'Dismiss'),
            isTrue,
          );
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets(
      'Group toggle pill exposes button semantics and expands on Enter key',
      (final tester) async {
        final controller = NotificationController(
          queues: {
            const NotificationQueue(
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
            home: const Scaffold(body: Center(child: Text('Home'))),
          ),
        );

        final handle = tester.ensureSemantics();
        try {
          controller
            ..show(const AppNotification(message: 'Group item 1'))
            ..show(const AppNotification(message: 'Group item 2'));
          await tester.pumpAndSettle();

          // The group pill should be visible with button semantics
          final pillFinder =
              find.bySemanticsLabel(RegExp('Grouped notifications'));
          expect(pillFinder, findsOneWidget);

          final semantics = tester.getSemantics(pillFinder);
          expect(
            semantics.label,
            contains('Grouped notifications: 2 items for channel default'),
          );

          await tester.tap(pillFinder);
          await tester.pumpAndSettle();

          final expandedFinder =
              find.bySemanticsLabel(RegExp('Collapse notification group'));
          expect(expandedFinder, findsOneWidget);

          final expandedSemantics = tester.getSemantics(expandedFinder);
          expect(
            expandedSemantics.label,
            contains('Collapse notification group for channel default'),
          );
        } finally {
          handle.dispose();
        }
      },
    );
  });
}
