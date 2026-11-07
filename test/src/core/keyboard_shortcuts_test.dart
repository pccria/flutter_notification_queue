import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Keyboard Shortcuts Tests', () {
    late NotificationController controller;

    setUp(() {
      controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'test_channel',
            position: QueuePosition.topRight,
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

    Widget buildApp() => MaterialApp(
          builder: (final context, final child) => NotificationScope(
            controller: controller,
            child: child!,
          ),
          home: const Scaffold(
            body: Center(child: Text('App Home')),
          ),
        );

    testWidgets('Esc key dismisses only the newest notification',
        (final tester) async {
      await tester.pumpWidget(buildApp());

      NotificationWidget(
        id: 'n1',
        message: 'First Notification',
        channelName: 'test_channel',
        coordinator: controller.coordinator,
      ).show();

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      NotificationWidget(
        id: 'n2',
        message: 'Second Notification',
        channelName: 'test_channel',
        coordinator: controller.coordinator,
      ).show();

      await tester.pumpAndSettle();

      expect(find.text('First Notification'), findsOneWidget);
      expect(find.text('Second Notification'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Second Notification'), findsNothing);
      expect(find.text('First Notification'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('First Notification'), findsNothing);
    });

    testWidgets('Shift + Esc key dismisses all active notifications',
        (final tester) async {
      await tester.pumpWidget(buildApp());

      NotificationWidget(
        id: 'n1',
        message: 'First Notification',
        channelName: 'test_channel',
        coordinator: controller.coordinator,
      ).show();

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      NotificationWidget(
        id: 'n2',
        message: 'Second Notification',
        channelName: 'test_channel',
        coordinator: controller.coordinator,
      ).show();

      await tester.pumpAndSettle();

      expect(find.text('First Notification'), findsOneWidget);
      expect(find.text('Second Notification'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(find.text('First Notification'), findsNothing);
      expect(find.text('Second Notification'), findsNothing);
    });
  });
}
