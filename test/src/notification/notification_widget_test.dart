import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationWidget', () {
    late NotificationController controller;

    setUp(() {
      controller = NotificationController(
        channels: {
          NotificationChannel.defaultChannel(),
          const NotificationChannel(
            name: 'test_channel',
            position: QueuePosition.topRight,
            defaultIcon: Icon(Icons.abc),
            defaultDismissDuration: null,
          ),
        },
        queues: {
          const NotificationQueue(position: QueuePosition.topRight),
        },
      );
    });

    tearDown(() {
      controller.dispose();
    });

    Widget buildApp({required final Widget child}) => MaterialApp(
          builder: (final context, final c) => NotificationScope(
            controller: controller,
            child: c!,
          ),
          home: Scaffold(body: child),
        );

    testWidgets('Renders basic content (message, icon)', (final tester) async {
      final notification = NotificationWidget(
        message: 'Hello World',
        channelName: 'test_channel',
        configuration: controller.configuration,
        coordinator: controller.coordinator,
      );

      await tester.pumpWidget(buildApp(child: notification));

      await tester.pumpAndSettle();

      expect(find.text('Hello World'), findsOneWidget);
      expect(find.byIcon(Icons.abc), findsOneWidget);
    });

    testWidgets('Renders title when provided', (final tester) async {
      final notification = NotificationWidget(
        title: 'My Title',
        message: 'My Message',
        channelName: 'test_channel',
        configuration: controller.configuration,
        coordinator: controller.coordinator,
      );

      await tester.pumpWidget(buildApp(child: notification));

      await tester.pumpAndSettle();

      expect(find.text('My Title'), findsOneWidget);
      expect(find.text('My Message'), findsOneWidget);
    });

    testWidgets('Expand button toggles message maxLines', (final tester) async {
      final longMessage = List.generate(20, (final i) => 'Word $i').join(' ');
      final notification = NotificationWidget(
        message: longMessage,
        channelName: 'test_channel',
        configuration: controller.configuration,
        coordinator: controller.coordinator,
      );

      await tester.pumpWidget(buildApp(child: notification));

      await tester.pumpAndSettle();

      final expandButton = find.byIcon(Icons.expand_more);
      expect(expandButton, findsOneWidget);

      await tester.tap(expandButton);
      await tester.pump();

      expect(find.byIcon(Icons.expand_less), findsOneWidget);
    });

    testWidgets('Action button is rendered and clickable',
        (final tester) async {
      bool actionClicked = false;
      final notification = NotificationWidget(
        message: 'Action Test',
        channelName: 'test_channel',
        action: NotificationAction.button(
          label: 'Click Me',
          onPressed: () => actionClicked = true,
        ),
        configuration: controller.configuration,
        coordinator: controller.coordinator,
      );

      await tester.pumpWidget(buildApp(child: notification));

      await tester.pumpAndSettle();

      expect(find.text('Click Me'), findsOneWidget);

      await tester.tap(find.text('Click Me'));
      await tester.pump();

      expect(actionClicked, isTrue);

      await tester.pumpAndSettle();
    });

    testWidgets('Tapping title expands and collapses the notification',
        (final tester) async {
      final notification = NotificationWidget(
        title: 'Clickable Header',
        message: 'Message Content',
        channelName: 'test_channel',
        configuration: controller.configuration,
        coordinator: controller.coordinator,
      );

      await tester.pumpWidget(buildApp(child: notification));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsNothing);

      // Tap on title text: expands
      await tester.tap(find.text('Clickable Header'));
      await tester.pump();

      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsNothing);

      // Tap on title text again: collapses
      await tester.tap(find.text('Clickable Header'));
      await tester.pump();

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsNothing);
    });

    testWidgets('Title tap expands even when TapToDismiss is active on card',
        (final tester) async {
      final notification = NotificationWidget(
        title: 'Safe Header',
        message: 'Body Message',
        channelName: 'test_channel',
        tapBehavior: const TapToDismiss(),
        configuration: controller.configuration,
        coordinator: controller.coordinator,
      );

      await tester.pumpWidget(buildApp(child: notification));
      await tester.pumpAndSettle();

      // Tap header title: expands, does not dismiss
      await tester.tap(find.text('Safe Header'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_less), findsOneWidget);

      // Tapping chevron collapses
      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('Close button has dimension 36 and triggers dismiss',
        (final tester) async {
      final notification = NotificationWidget(
        title: 'Close Test',
        message: 'Dismiss me',
        channelName: 'test_channel',
        configuration: controller.configuration,
        coordinator: controller.coordinator,
      );

      await tester.pumpWidget(buildApp(child: notification));
      await tester.pumpAndSettle();

      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);

      // Verify the close button container size is 36x36
      final closeButtonBox = find.ancestor(
        of: closeButton,
        matching: find.byType(SizedBox),
      );
      final size = tester.getSize(closeButtonBox.first);
      expect(size.width, equals(36.0));
      expect(size.height, equals(36.0));

      await tester.tap(closeButton);
      await tester.pump();
      await tester.pumpAndSettle();
    });
  });
}
