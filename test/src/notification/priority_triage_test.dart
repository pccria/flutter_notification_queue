// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationPriority unit tests', () {
    test('NotificationWidget priority fields store values correctly', () {
      final n = NotificationWidget(
        message: 'Priority test',
        priority: NotificationPriority.critical,
      );

      expect(n.priority, NotificationPriority.critical);
      expect(n.resolvedPriority, NotificationPriority.critical);
    });

    test('resolvedPriority falls back to channel default', () {
      final defaultChannel = NotificationChannel.defaultChannel();
      final nDefault = NotificationWidget(
        message: 'Default channel test',
        channelName: defaultChannel.name,
      );
      expect(nDefault.resolvedPriority, NotificationPriority.normal);

      final infoChannel = NotificationChannel.infoChannel();
      final nInfo = NotificationWidget(
        message: 'Info channel test',
        channelName: infoChannel.name,
      );
      expect(nInfo.resolvedPriority, NotificationPriority.low);

      final errorChannel = NotificationChannel.errorChannel();
      final nError = NotificationWidget(
        message: 'Error channel test',
        channelName: errorChannel.name,
      );
      expect(nError.resolvedPriority, NotificationPriority.high);
    });

    test('NotificationWidget custom priority override takes precedence', () {
      final n = NotificationWidget(
        message: 'Override test',
        channelName: 'info',
        priority: NotificationPriority.critical,
      );

      expect(n.resolvedPriority, NotificationPriority.critical);
    });

    test('copyToQueue preserves custom priority overrides', () {
      final n = NotificationWidget(
        message: 'Override test',
        priority: NotificationPriority.high,
      );

      final copy = n.copyToQueue(
        const NotificationQueue(position: QueuePosition.topRight),
      );

      expect(copy.priority, NotificationPriority.high);
      expect(copy.resolvedPriority, NotificationPriority.high);
    });
  });

  group('Priority Triage integration tests', () {
    late NotificationController controller;

    setUp(() {
      controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'test',
            position: QueuePosition.topRight,
            defaultPriority: NotificationPriority.normal,
            defaultDismissDuration: null,
          ),
          const NotificationChannel(
            name: 'high_ch',
            position: QueuePosition.topRight,
            defaultPriority: NotificationPriority.high,
            defaultDismissDuration: null,
          ),
          const NotificationChannel(
            name: 'low_ch',
            position: QueuePosition.topRight,
            defaultPriority: NotificationPriority.low,
            defaultDismissDuration: null,
          ),
        },
        queues: {
          const NotificationQueue(
            position: QueuePosition.topRight,
            maxStackSize: 2,
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
          home: const Scaffold(body: SizedBox.expand()),
        );

    testWidgets(
      'auto-sorting promotes high priority items ahead of low priority ones',
      (final tester) async {
        await tester.pumpWidget(buildApp());

        final low = NotificationWidget(
          id: 'low_auto',
          message: 'Low priority',
          channelName: 'low_ch',
          coordinator: controller.coordinator,
        );
        final high = NotificationWidget(
          id: 'high_auto',
          message: 'High priority',
          channelName: 'high_ch',
          coordinator: controller.coordinator,
        );

        low.show();
        high.show();

        await tester.pumpAndSettle();

        final extraLow = NotificationWidget(
          id: 'extra_low_auto',
          message: 'Extra Low priority',
          channelName: 'low_ch',
          coordinator: controller.coordinator,
        );

        extraLow.show();
        await tester.pumpAndSettle();

        expect(find.text('High priority'), findsOneWidget);
        expect(find.text('Low priority'), findsOneWidget);
        expect(find.text('Extra Low priority'), findsNothing);
      },
    );

    testWidgets(
      'critical notification evicts active low priority notification when full',
      (final tester) async {
        await tester.pumpWidget(buildApp());

        final firstLow = NotificationWidget(
          id: 'low_1',
          message: 'First Low',
          channelName: 'low_ch',
          coordinator: controller.coordinator,
        );
        final secondLow = NotificationWidget(
          id: 'low_2',
          message: 'Second Low',
          channelName: 'low_ch',
          coordinator: controller.coordinator,
        );

        firstLow.show();
        secondLow.show();
        await tester.pumpAndSettle();

        expect(find.text('First Low'), findsOneWidget);
        expect(find.text('Second Low'), findsOneWidget);

        final criticalAlert = NotificationWidget(
          id: 'high_1',
          message: 'Critical Alert',
          channelName: 'high_ch',
          coordinator: controller.coordinator,
        );

        criticalAlert.show();

        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Critical Alert'), findsOneWidget);
        expect(
          find.text('First Low').evaluate().length +
              find.text('Second Low').evaluate().length,
          1,
        );
      },
    );

    testWidgets(
      'evicted notification automatically resumes once '
      'critical alert is dismissed',
      (final tester) async {
        await tester.pumpWidget(buildApp());

        final firstLow = NotificationWidget(
          id: 'low_1_resume',
          message: 'First Low',
          channelName: 'low_ch',
          coordinator: controller.coordinator,
        );
        final secondLow = NotificationWidget(
          id: 'low_2_resume',
          message: 'Second Low',
          channelName: 'low_ch',
          coordinator: controller.coordinator,
        );

        firstLow.show();
        secondLow.show();
        await tester.pumpAndSettle();

        final criticalAlert = NotificationWidget(
          id: 'high_1_resume',
          message: 'Critical Alert',
          channelName: 'high_ch',
          coordinator: controller.coordinator,
        );
        criticalAlert.show();
        await tester.pump();
        await tester.pumpAndSettle();

        final dismissFuture = criticalAlert.dismiss();
        await tester.pump();
        await tester.pumpAndSettle();
        await dismissFuture;

        expect(find.text('Critical Alert'), findsNothing);
        expect(find.text('First Low'), findsOneWidget);
        expect(find.text('Second Low'), findsOneWidget);
      },
    );
  });
}
