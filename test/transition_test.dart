import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';

class CustomTransition extends NotificationTransition {
  const CustomTransition();

  @override
  Widget build(
    final BuildContext context,
    final Animation<double> animation,
    final QueuePosition position,
    final Widget child,
  ) =>
      ScaleTransition(scale: animation, child: child);
}

void main() {
  testWidgets('NotificationWidget uses custom transition',
      (final tester) async {
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
          transition: CustomTransition(),
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
        home: const Scaffold(body: SizedBox()),
      ),
    );

    NotificationWidget(
      message: 'Test',
      coordinator: controller.coordinator,
    ).show();
    await tester.pump();
    await tester.pump();

    expect(
      find.ancestor(
        of: find.byType(NotificationWidget),
        matching: find.byType(ScaleTransition),
      ),
      findsAtLeastNWidgets(1),
    );

    expect(
      find.ancestor(
        of: find.byType(NotificationWidget),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );

    await tester.pumpAndSettle();
  });

  testWidgets('NotificationWidget uses default transition if not specified',
      (final tester) async {
    final controller = NotificationController(
      channels: {
        const NotificationChannel(
          name: 'default',
          position: QueuePosition.bottomCenter,
          defaultDismissDuration: null,
        ),
      },
      queues: {
        const NotificationQueue(position: QueuePosition.bottomCenter),
      },
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (final context, final child) => NotificationScope(
          controller: controller,
          child: child!,
        ),
        home: const Scaffold(body: SizedBox()),
      ),
    );

    NotificationWidget(
      message: 'Default',
      position: QueuePosition.bottomCenter,
      coordinator: controller.coordinator,
    ).show();
    await tester.pump();
    await tester.pump();

    expect(
      find.ancestor(
        of: find.byType(NotificationWidget),
        matching: find.byType(SlideTransition),
      ),
      findsOneWidget,
    );
  });

  testWidgets('NotificationWidget uses BuilderTransitionStrategy',
      (final tester) async {
    final controller = NotificationController(
      channels: {
        const NotificationChannel(
          name: 'default',
          position: QueuePosition.topCenter,
          defaultDismissDuration: null,
        ),
      },
      queues: {
        NotificationQueue(
          position: QueuePosition.topCenter,
          transition: BuilderTransitionStrategy(
            (
              final context,
              final animation,
              final position,
              final child,
            ) =>
                RotationTransition(turns: animation, child: child),
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
        home: const Scaffold(body: SizedBox()),
      ),
    );

    NotificationWidget(
      message: 'Builder',
      position: QueuePosition.topCenter,
      coordinator: controller.coordinator,
    ).show();
    await tester.pump();
    await tester.pump();

    expect(
      find.ancestor(
        of: find.byType(NotificationWidget),
        matching: find.byType(RotationTransition),
      ),
      findsOneWidget,
    );
  });
}
