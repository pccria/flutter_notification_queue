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
  });
}
