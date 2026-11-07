import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationOverlay Integration', () {
    late NotificationController defaultController;

    setUp(() {
      defaultController = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'test_channel',
            position: QueuePosition.topRight,
            defaultIcon: Icon(Icons.check),
            defaultDismissDuration: null,
          ),
        },
        queues: {
          const NotificationQueue(position: QueuePosition.topRight),
        },
      );
    });

    tearDown(() {
      defaultController.dispose();
    });

    Widget buildApp({
      required final NotificationController controller,
      final Widget? child,
    }) =>
        MaterialApp(
          builder: (final context, final c) => NotificationScope(
            controller: controller,
            child: c!,
          ),
          home: Scaffold(
            body: Center(child: child ?? const Text('App Home')),
          ),
        );

    testWidgets('Shows notification via NotificationScope integration',
        (final tester) async {
      await tester.pumpWidget(buildApp(controller: defaultController));

      // Verify initial state
      expect(find.text('App Home'), findsOneWidget);
      expect(find.byType(NotificationWidget), findsNothing);

      // Show notification
      Offset? firstLocation;
      NotificationWidget(
        message: 'Overlay Test',
        channelName: 'test_channel',
        coordinator: defaultController.coordinator,
      ).show();

      await tester.pump(); // Start animation (enqueue)
      await tester.pump(); // Frame for adding post-frame callbacks if any

      // Verify it appears
      expect(find.text('Overlay Test'), findsOneWidget);
      expect(find.byType(NotificationWidget), findsOneWidget);

      firstLocation = tester.getCenter(find.text('Overlay Test'));
      expect(firstLocation, isNotNull);

      await tester.pumpAndSettle(); // Finish entry animation

      // Verify it stays
      expect(find.text('Overlay Test'), findsOneWidget);
    });

    testWidgets('Dismissal removes notification from overlay',
        (final tester) async {
      await tester.pumpWidget(buildApp(controller: defaultController));

      final notification = NotificationWidget(
        message: 'Dismiss Test',
        channelName: 'test_channel',
        coordinator: defaultController.coordinator,
      )..show();

      await tester.pumpAndSettle();
      expect(find.text('Dismiss Test'), findsOneWidget);

      final dismissFuture = notification.dismiss();
      await tester.pumpAndSettle();
      await dismissFuture;

      expect(find.text('Dismiss Test'), findsNothing);
      expect(find.byType(NotificationWidget), findsNothing);
    });

    testWidgets('Multiple notifications stack correctly', (final tester) async {
      await tester.pumpWidget(buildApp(controller: defaultController));

      NotificationWidget(
        message: 'First',
        channelName: 'test_channel',
        coordinator: defaultController.coordinator,
      ).show();
      await tester.pump();
      NotificationWidget(
        message: 'Second',
        channelName: 'test_channel',
        coordinator: defaultController.coordinator,
      ).show();
      await tester.pumpAndSettle();

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);

      final firstCenter = tester.getCenter(find.text('First'));
      final secondCenter = tester.getCenter(find.text('Second'));

      expect(firstCenter.dy, isNot(equals(secondCenter.dy)));
    });

    testWidgets('Overlapping adjacent queues are shifted to avoid collision',
        (final tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'left_chan',
            position: QueuePosition.topLeft,
            defaultDismissDuration: null,
          ),
          const NotificationChannel(
            name: 'center_chan',
            position: QueuePosition.topCenter,
            defaultDismissDuration: null,
          ),
        },
        queues: {
          const NotificationQueue(
            position: QueuePosition.topLeft,
            margin: EdgeInsets.all(10),
            spacing: 10,
          ),
          const NotificationQueue(
            position: QueuePosition.topCenter,
            margin: EdgeInsets.all(10),
            spacing: 10,
          ),
        },
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildApp(
          controller: controller,
          child: const Text('App'),
        ),
      );

      NotificationWidget(
        id: 'n_left',
        message: 'L',
        channelName: 'left_chan',
        coordinator: controller.coordinator,
      ).show();

      NotificationWidget(
        id: 'n_center',
        message: 'C',
        channelName: 'center_chan',
        coordinator: controller.coordinator,
      ).show();

      await tester.pumpAndSettle();

      expect(find.text('L'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);

      final leftPos = tester.getTopLeft(find.text('L'));
      final centerPos = tester.getTopLeft(find.text('C'));

      expect(centerPos.dy, greaterThan(leftPos.dy));
    });

    testWidgets(
        'Non-overlapping adjacent queues with custom maxWidth are not shifted',
        (final tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'left_chan',
            position: QueuePosition.topLeft,
            defaultDismissDuration: null,
          ),
          const NotificationChannel(
            name: 'center_chan',
            position: QueuePosition.topCenter,
            defaultDismissDuration: null,
          ),
        },
        queues: {
          const NotificationQueue(
            position: QueuePosition.topLeft,
            margin: EdgeInsets.all(10),
            spacing: 10,
            maxWidth: 200.0,
          ),
          const NotificationQueue(
            position: QueuePosition.topCenter,
            margin: EdgeInsets.all(10),
            spacing: 10,
            maxWidth: 200.0,
          ),
        },
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildApp(
          controller: controller,
          child: const Text('App'),
        ),
      );

      NotificationWidget(
        id: 'n_left',
        message: 'L',
        channelName: 'left_chan',
        coordinator: controller.coordinator,
      ).show();

      NotificationWidget(
        id: 'n_center',
        message: 'C',
        channelName: 'center_chan',
        coordinator: controller.coordinator,
      ).show();

      await tester.pumpAndSettle();

      expect(find.text('L'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);

      final leftPos = tester.getTopLeft(find.text('L'));
      final centerPos = tester.getTopLeft(find.text('C'));

      expect(centerPos.dy, equals(leftPos.dy));
    });

    testWidgets(
        'Overlapping adjacent bottom queues are shifted upward to '
        'avoid collision', (final tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'bottom_left_chan',
            position: QueuePosition.bottomLeft,
            defaultDismissDuration: null,
          ),
          const NotificationChannel(
            name: 'bottom_center_chan',
            position: QueuePosition.bottomCenter,
            defaultDismissDuration: null,
          ),
        },
        queues: {
          const NotificationQueue(
            position: QueuePosition.bottomLeft,
            margin: EdgeInsets.all(10),
            spacing: 10,
          ),
          const NotificationQueue(
            position: QueuePosition.bottomCenter,
            margin: EdgeInsets.all(10),
            spacing: 10,
          ),
        },
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildApp(
          controller: controller,
          child: const Text('App'),
        ),
      );

      NotificationWidget(
        id: 'n_left',
        message: 'L',
        channelName: 'bottom_left_chan',
        coordinator: controller.coordinator,
      ).show();

      NotificationWidget(
        id: 'n_center',
        message: 'C',
        channelName: 'bottom_center_chan',
        coordinator: controller.coordinator,
      ).show();

      await tester.pumpAndSettle();

      expect(find.text('L'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);

      final leftPos = tester.getTopLeft(find.text('L'));
      final centerPos = tester.getTopLeft(find.text('C'));

      expect(centerPos.dy, lessThan(leftPos.dy));
    });

    testWidgets(
        'Non-overlapping adjacent bottom queues with custom maxWidth '
        'are not shifted upward', (final tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'bottom_left_chan',
            position: QueuePosition.bottomLeft,
            defaultDismissDuration: null,
          ),
          const NotificationChannel(
            name: 'bottom_center_chan',
            position: QueuePosition.bottomCenter,
            defaultDismissDuration: null,
          ),
        },
        queues: {
          const NotificationQueue(
            position: QueuePosition.bottomLeft,
            margin: EdgeInsets.all(10),
            spacing: 10,
            maxWidth: 200.0,
          ),
          const NotificationQueue(
            position: QueuePosition.bottomCenter,
            margin: EdgeInsets.all(10),
            spacing: 10,
            maxWidth: 200.0,
          ),
        },
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildApp(
          controller: controller,
          child: const Text('App'),
        ),
      );

      NotificationWidget(
        id: 'n_left',
        message: 'L',
        channelName: 'bottom_left_chan',
        coordinator: controller.coordinator,
      ).show();

      NotificationWidget(
        id: 'n_center',
        message: 'C',
        channelName: 'bottom_center_chan',
        coordinator: controller.coordinator,
      ).show();

      await tester.pumpAndSettle();

      expect(find.text('L'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);

      final leftPos = tester.getTopLeft(find.text('L'));
      final centerPos = tester.getTopLeft(find.text('C'));

      expect(centerPos.dy, equals(leftPos.dy));
    });

    testWidgets(
        'Overlapping adjacent center queues are shifted downward to '
        'avoid collision', (final tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'center_left_chan',
            position: QueuePosition.centerLeft,
            defaultDismissDuration: null,
          ),
          const NotificationChannel(
            name: 'center_right_chan',
            position: QueuePosition.centerRight,
            defaultDismissDuration: null,
          ),
        },
        queues: {
          const NotificationQueue(
            position: QueuePosition.centerLeft,
            margin: EdgeInsets.all(10),
            spacing: 10,
          ),
          const NotificationQueue(
            position: QueuePosition.centerRight,
            margin: EdgeInsets.all(10),
            spacing: 10,
          ),
        },
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildApp(
          controller: controller,
          child: const Text('App'),
        ),
      );

      NotificationWidget(
        id: 'n_left',
        message: 'L',
        channelName: 'center_left_chan',
        coordinator: controller.coordinator,
      ).show();

      NotificationWidget(
        id: 'n_right',
        message: 'R',
        channelName: 'center_right_chan',
        coordinator: controller.coordinator,
      ).show();

      await tester.pumpAndSettle();

      expect(find.text('L'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);

      final leftPos = tester.getTopLeft(find.text('L'));
      final rightPos = tester.getTopLeft(find.text('R'));

      expect(rightPos.dy, greaterThan(leftPos.dy));
    });

    testWidgets(
        'Non-overlapping adjacent center queues with custom maxWidth '
        'are not shifted', (final tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'center_left_chan',
            position: QueuePosition.centerLeft,
            defaultDismissDuration: null,
          ),
          const NotificationChannel(
            name: 'center_right_chan',
            position: QueuePosition.centerRight,
            defaultDismissDuration: null,
          ),
        },
        queues: {
          const NotificationQueue(
            position: QueuePosition.centerLeft,
            margin: EdgeInsets.all(10),
            spacing: 10,
            maxWidth: 200.0,
          ),
          const NotificationQueue(
            position: QueuePosition.centerRight,
            margin: EdgeInsets.all(10),
            spacing: 10,
            maxWidth: 200.0,
          ),
        },
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildApp(
          controller: controller,
          child: const Text('App'),
        ),
      );

      NotificationWidget(
        id: 'n_left',
        message: 'L',
        channelName: 'center_left_chan',
        coordinator: controller.coordinator,
      ).show();

      NotificationWidget(
        id: 'n_right',
        message: 'R',
        channelName: 'center_right_chan',
        coordinator: controller.coordinator,
      ).show();

      await tester.pumpAndSettle();

      expect(find.text('L'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);

      final leftPos = tester.getTopLeft(find.text('L'));
      final rightPos = tester.getTopLeft(find.text('R'));

      expect(rightPos.dy, equals(leftPos.dy));
    });
  });
}
