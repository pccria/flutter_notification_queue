import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Live Updates & Handle Ergonomics (Track 1)', () {
    testWidgets(
      'in-place mutation updates message and title without remounting',
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

        final handle = controller.show(
          const AppNotification(
            id: 'progress-task',
            title: 'Download',
            message: 'Progress: 10%',
            permanent: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Download'), findsOneWidget);
        expect(find.text('Progress: 10%'), findsOneWidget);

        final updated = handle.update(
          title: 'Download Complete',
          message: 'Progress: 100%',
        );
        expect(updated, isTrue);
        await tester.pump();

        expect(find.text('Download Complete'), findsOneWidget);
        expect(find.text('Progress: 100%'), findsOneWidget);
        expect(find.text('Progress: 10%'), findsNothing);
      },
    );

    testWidgets(
      'NotificationHandle.updateWith transforms payload and preserves key',
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

        final handle = controller.show(
          const AppNotification(message: 'Step 1: Init', permanent: true),
        );
        await tester.pumpAndSettle();
        expect(find.text('Step 1: Init'), findsOneWidget);

        final updated = handle.updateWith(
          (final curr) => curr.copyWith(message: 'Step 2: Processing'),
        );
        expect(updated, isTrue);
        await tester.pump();

        expect(find.text('Step 2: Processing'), findsOneWidget);
        expect(find.text('Step 1: Init'), findsNothing);
      },
    );

    testWidgets(
      'timer continues on resetTimer: false and resets on resetTimer: true',
      (final tester) async {
        final controller = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'timed',
              defaultDismissDuration: Duration(seconds: 4),
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

        // 1. Test resetTimer: false (continues original countdown)
        final handle1 = controller.show(
          const AppNotification(
            id: 'timer-1',
            channelName: 'timed',
            message: 'Timed Msg 1',
          ),
        );
        await tester.pump();
        expect(find.text('Timed Msg 1'), findsOneWidget);

        // Advance 2 seconds midway through 4 second duration
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('Timed Msg 1'), findsOneWidget);

        handle1.update(message: 'Timed Msg 1 Updated', resetTimer: false);
        await tester.pump();
        expect(find.text('Timed Msg 1 Updated'), findsOneWidget);

        // Advance 2.2 seconds (total > 4s) -> should dismiss
        await tester.pump(const Duration(milliseconds: 2200));
        await tester.pumpAndSettle();
        expect(find.text('Timed Msg 1 Updated'), findsNothing);

        // 2. Test resetTimer: true (restarts countdown)
        final handle2 = controller.show(
          const AppNotification(
            id: 'timer-2',
            channelName: 'timed',
            message: 'Timed Msg 2',
          ),
        );
        await tester.pump();
        expect(find.text('Timed Msg 2'), findsOneWidget);

        // Advance 2 seconds
        await tester.pump(const Duration(seconds: 2));

        // Update with resetTimer: true -> resets back to 4 seconds
        handle2.update(message: 'Timed Msg 2 Reset', resetTimer: true);
        await tester.pump();
        expect(find.text('Timed Msg 2 Reset'), findsOneWidget);

        // Advance 2.5 seconds -> still visible because 4s restarted!
        await tester.pump(const Duration(milliseconds: 2500));
        expect(find.text('Timed Msg 2 Reset'), findsOneWidget);

        // Advance another 2 seconds -> now dismisses
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.text('Timed Msg 2 Reset'), findsNothing);
      },
    );

    testWidgets(
      'showAsync transitions loading to success and dismisses after duration',
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

        final completer = Completer<String>();
        controller.showAsync<String>(
          completer.future,
          loading: const AppNotification(message: 'Uploading document...'),
          onSuccess: (final fileId) => AppNotification(
            message: 'File saved: $fileId',
            dismissDuration: const Duration(seconds: 3),
          ),
          onError: (final err, final _) => const AppNotification(
            message: 'Upload failed',
          ),
        );
        await tester.pump();

        expect(find.text('Uploading document...'), findsOneWidget);

        // Advance 10 seconds — loading is permanent, should never dismiss
        await tester.pump(const Duration(seconds: 10));
        expect(find.text('Uploading document...'), findsOneWidget);

        // Complete the future
        completer.complete('doc_456');
        await tester.pump();
        await tester.pump();

        expect(find.text('File saved: doc_456'), findsOneWidget);
        expect(find.text('Uploading document...'), findsNothing);

        // Auto-dismiss countdown is now active (3 seconds)
        await tester.pump(const Duration(milliseconds: 3200));
        await tester.pumpAndSettle();
        expect(find.text('File saved: doc_456'), findsNothing);
      },
    );

    testWidgets(
      'showAsync transitions loading to error on future rejection',
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

        final completer = Completer<String>();
        controller.showAsync<String>(
          completer.future,
          loading: const AppNotification(message: 'Saving record...'),
          onSuccess: (final _) => const AppNotification(message: 'Success'),
          onError: (final err, final _) => AppNotification(
            message: 'Error occurred: $err',
            permanent: true,
          ),
        );
        await tester.pump();

        expect(find.text('Saving record...'), findsOneWidget);

        completer.completeError('Database timeout');
        await tester.pump();

        expect(find.text('Error occurred: Database timeout'), findsOneWidget);
        expect(find.text('Saving record...'), findsNothing);
      },
    );

    testWidgets(
      'updating pending backlog card updates content prior to promotion',
      (final tester) async {
        final controller = NotificationController(
          queues: {
            const NotificationQueue(
              maxStackSize: 1,
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

        final handle1 = controller.show(
          const AppNotification(message: 'Active Slot 1', permanent: true),
        );
        final handle2 = controller.show(
          const AppNotification(
            id: 'pending-card',
            message: 'Pending Original',
            permanent: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Active Slot 1'), findsOneWidget);
        expect(find.text('Pending Original'), findsNothing);

        // Mutate card while it is waiting in pending backlog
        final updated = handle2.update(message: 'Pending Mutated');
        expect(updated, isTrue);

        // Dismiss the active card to trigger backlog promotion
        handle1.dismiss();
        await tester.pumpAndSettle();

        // Pending card should now be promoted with updated content!
        expect(find.text('Pending Mutated'), findsOneWidget);
        expect(find.text('Pending Original'), findsNothing);
      },
    );

    testWidgets(
      'NotificationUpdated event is emitted on in-place update',
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

        NotificationUpdated? receivedEvent;
        final sub = controller.events
            .where((final event) => event is NotificationUpdated)
            .cast<NotificationUpdated>()
            .listen((final event) {
          receivedEvent = event;
        });
        addTearDown(sub.cancel);

        final handle = controller.show(
          const AppNotification(message: 'Initial Status', permanent: true),
        );
        await tester.pumpAndSettle();

        handle.update(message: 'New Status');
        await tester.pump();

        expect(receivedEvent, isNotNull);
        expect(receivedEvent!.notification.message, equals('New Status'));
        expect(
          receivedEvent!.oldNotification.message,
          equals('Initial Status'),
        );
      },
    );
  });
}
