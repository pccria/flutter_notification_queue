@Tags(['golden'])
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(super.testFile, {this.tolerance = 0.005});

  final double tolerance;

  @override
  Future<bool> compare(final Uint8List imageBytes, final Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (!result.passed && result.diffPercent <= tolerance) {
      return true;
    }

    if (!result.passed) {
      final String error = await generateFailureOutput(result, golden, basedir);
      throw FlutterError(error);
    }
    return result.passed;
  }
}

void main() {
  setUpAll(() {
    if (goldenFileComparator is LocalFileComparator) {
      final testUrl = (goldenFileComparator as LocalFileComparator).basedir;
      goldenFileComparator = _TolerantGoldenComparator(
        testUrl.resolve('visual_regression_test.dart'),
        tolerance: 0.005,
      );
    }
  });

  group('FNQ Visual Regression Golden Tests', () {
    testWidgets('FlatQueueStyle Golden Test', (final tester) async {
      final controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'default',
            position: QueuePosition.topCenter,
            defaultDismissDuration: null,
          ),
        },
        queues: {
          const NotificationQueue(
            position: QueuePosition.topCenter,
            style: FlatQueueStyle(opacity: 0.9),
            maxStackSize: 2,
          ),
        },
      );
      addTearDown(controller.dispose);

      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          builder: (final context, final child) => NotificationScope(
            controller: controller,
            child: child!,
          ),
          home: const Scaffold(
            body: Center(
              child: Text('App Content'),
            ),
          ),
        ),
      );

      controller.show(
        const AppNotification(
          id: 'n1',
          title: 'Flat Notification',
          message: 'This is a flat queue style notification.',
          icon: Icon(Icons.info_outline, color: Colors.blue),
        ),
      );

      await tester.pump();
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await expectLater(
        find.byType(NotificationOverlay),
        matchesGoldenFile('goldens/flat_queue_style.png'),
      );
    });

    testWidgets('FilledQueueStyle Golden Test', (final tester) async {
      final controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'default',
            position: QueuePosition.topCenter,
            defaultDismissDuration: null,
            defaultColor: Colors.deepPurple,
          ),
        },
        queues: {
          const NotificationQueue(
            position: QueuePosition.topCenter,
            style: FilledQueueStyle(opacity: 0.95),
            maxStackSize: 2,
          ),
        },
      );
      addTearDown(controller.dispose);

      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          builder: (final context, final child) => NotificationScope(
            controller: controller,
            child: child!,
          ),
          home: const Scaffold(
            body: Center(
              child: Text('App Content'),
            ),
          ),
        ),
      );

      controller.show(
        const AppNotification(
          id: 'n1',
          title: 'Filled Notification',
          message: 'This is a filled queue style notification.',
          icon: Icon(Icons.star, color: Colors.white),
        ),
      );

      await tester.pump();
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await expectLater(
        find.byType(NotificationOverlay),
        matchesGoldenFile('goldens/filled_queue_style.png'),
      );
    });

    testWidgets('OutlinedQueueStyle Golden Test', (final tester) async {
      final controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'default',
            position: QueuePosition.topCenter,
            defaultDismissDuration: null,
            defaultColor: Colors.green,
          ),
        },
        queues: {
          const NotificationQueue(
            position: QueuePosition.topCenter,
            style: OutlinedQueueStyle(elevation: 0),
            maxStackSize: 2,
          ),
        },
      );
      addTearDown(controller.dispose);

      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          builder: (final context, final child) => NotificationScope(
            controller: controller,
            child: child!,
          ),
          home: const Scaffold(
            body: Center(
              child: Text('App Content'),
            ),
          ),
        ),
      );

      controller.show(
        const AppNotification(
          id: 'n1',
          title: 'Outlined Notification',
          message: 'This is an outlined queue style notification.',
          icon: Icon(Icons.check, color: Colors.green),
        ),
      );

      await tester.pump();
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await expectLater(
        find.byType(NotificationOverlay),
        matchesGoldenFile('goldens/outlined_queue_style.png'),
      );
    });

    testWidgets(
      'Anchoring TopRight vs BottomCenter Golden Test',
      (final tester) async {
        final controller = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'ch_tr',
              position: QueuePosition.topRight,
              defaultDismissDuration: null,
            ),
            const NotificationChannel(
              name: 'ch_bc',
              position: QueuePosition.bottomCenter,
              defaultDismissDuration: null,
            ),
          },
          queues: {
            const NotificationQueue(position: QueuePosition.topRight),
            const NotificationQueue(position: QueuePosition.bottomCenter),
          },
        );
        addTearDown(controller.dispose);

        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true),
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(
              body: Center(
                child: Text('App Content'),
              ),
            ),
          ),
        );

        controller.show(
          const AppNotification(
            id: 'n_tr',
            message: 'Top Right Queue Position',
            channelName: 'ch_tr',
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        controller.show(
          const AppNotification(
            id: 'n_bc',
            message: 'Bottom Center Queue Position',
            channelName: 'ch_bc',
          ),
        );

        await tester.pump();
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        await expectLater(
          find.byType(NotificationOverlay),
          matchesGoldenFile('goldens/queue_positions_anchoring.png'),
        );
      },
    );

    testWidgets('Notification Grouping Bundle Golden Test',
        (final tester) async {
      final controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'default',
            position: QueuePosition.topCenter,
            defaultDismissDuration: null,
            defaultColor: Colors.blue,
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

      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          builder: (final context, final child) => NotificationScope(
            controller: controller,
            child: child!,
          ),
          home: const Scaffold(
            body: Center(
              child: Text('App Content'),
            ),
          ),
        ),
      );

      controller.show(
        const AppNotification(
          id: 'n1',
          title: 'First Notification',
          message: 'This is the first notification in the group.',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      controller.show(
        const AppNotification(
          id: 'n2',
          title: 'Second Notification',
          message: 'This is the second notification in the group.',
        ),
      );

      await tester.pump();
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await expectLater(
        find.byType(NotificationOverlay),
        matchesGoldenFile('goldens/grouped_notification_bundle.png'),
      );
    });
  });
}
