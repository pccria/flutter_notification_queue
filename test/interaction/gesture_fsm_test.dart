// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpringPhysicsConfiguration Tests', () {
    test('Default and Preset Spring Physics Configuration values', () {
      const config = SpringPhysicsConfiguration();
      expect(config.mass, equals(1.0));
      expect(config.stiffness, equals(180.0));
      expect(config.damping, equals(15.0));

      const premium = SpringPhysicsConfiguration.premium();
      expect(premium.mass, equals(1.0));
      expect(premium.stiffness, equals(220.0));
      expect(premium.damping, equals(18.0));

      const stiff = SpringPhysicsConfiguration.stiff();
      expect(stiff.mass, equals(0.8));
      expect(stiff.stiffness, equals(300.0));
      expect(stiff.damping, equals(25.0));

      const gentle = SpringPhysicsConfiguration.gentle();
      expect(gentle.mass, equals(1.2));
      expect(gentle.stiffness, equals(120.0));
      expect(gentle.damping, equals(12.0));
    });

    test('SpringDescription conversion', () {
      const premium = SpringPhysicsConfiguration.premium();
      final description = premium.toSpringDescription();
      expect(description.mass, equals(1.0));
      expect(description.stiffness, equals(220.0));
      expect(description.damping, equals(18.0));
    });

    test('Assertions on negative and invalid bounds', () {
      expect(
        () => SpringPhysicsConfiguration(mass: 0.0),
        throwsAssertionError,
      );
      expect(
        () => SpringPhysicsConfiguration(stiffness: -10.0),
        throwsAssertionError,
      );
      expect(
        () => SpringPhysicsConfiguration(damping: -5.0),
        throwsAssertionError,
      );
    });

    test('Equality and toString comparison', () {
      const c1 =
          SpringPhysicsConfiguration(mass: 1.0, stiffness: 200, damping: 20);
      const c2 =
          SpringPhysicsConfiguration(mass: 1.0, stiffness: 200, damping: 20);
      const c3 =
          SpringPhysicsConfiguration(mass: 1.5, stiffness: 200, damping: 20);

      expect(c1, equals(c2));
      expect(c1.hashCode, equals(c2.hashCode));
      expect(c1, isNot(equals(c3)));
      expect(c1.toString(), contains('mass: 1.0'));
    });
  });

  group('GestureStateMachine Lifecycle & Transitions Tests', () {
    test('Initial idle state', () {
      final fsm = GestureStateMachine(
        initialBehavior: const Dismiss(),
        initialPosition: QueuePosition.topRight,
      );

      expect(fsm.value, equals(GestureState.idle));
      expect(fsm.pointerPosition, isNull);
      fsm.dispose();
    });

    test('Lift action updates state and coordinates', () {
      final fsm = GestureStateMachine(
        initialBehavior: const Dismiss(),
        initialPosition: QueuePosition.topRight,
      );

      const startPos = Offset(100.0, 150.0);
      const bounds = Rect.fromLTWH(80.0, 130.0, 300.0, 80.0);

      fsm.lift(pointerStart: startPos, widgetRect: bounds);

      expect(fsm.value, equals(GestureState.lifted));
      expect(fsm.pointerPosition, equals(startPos));
      fsm.dispose();
    });

    test('Dismiss behavior FSM updates tracking', () {
      final fsm = GestureStateMachine(
        initialBehavior: const Dismiss(),
        initialPosition: QueuePosition.topRight,
      );

      fsm
        ..lift(
          pointerStart: const Offset(100.0, 150.0),
          widgetRect: const Rect.fromLTWH(80.0, 130.0, 300.0, 80.0),
        )
        ..update(
          delta: const Offset(10.0, 0.0),
          globalPosition: const Offset(110.0, 150.0),
        );

      expect(fsm.value, equals(GestureState.reordering));
      expect(fsm.pointerPosition, equals(const Offset(110.0, 150.0)));
      fsm.dispose();
    });

    test('Relocate behavior FSM updates tracking', () {
      final fsm = GestureStateMachine(
        initialBehavior: Relocate<OnDrag>.to({QueuePosition.topLeft}),
        initialPosition: QueuePosition.topRight,
      );

      fsm
        ..lift(
          pointerStart: const Offset(100.0, 150.0),
          widgetRect: const Rect.fromLTWH(80.0, 130.0, 300.0, 80.0),
        )
        ..update(
          delta: const Offset(10.0, 20.0),
          globalPosition: const Offset(110.0, 170.0),
        );

      expect(fsm.value, equals(GestureState.relocating));
      fsm.dispose();
    });

    test('Reorder behavior FSM updates tracking', () {
      final fsm = GestureStateMachine(
        initialBehavior: const Reorder(),
        initialPosition: QueuePosition.topRight,
      );

      fsm
        ..lift(
          pointerStart: const Offset(100.0, 150.0),
          widgetRect: const Rect.fromLTWH(80.0, 130.0, 300.0, 80.0),
        )
        ..update(
          delta: const Offset(0.0, 20.0),
          globalPosition: const Offset(100.0, 170.0),
        );

      expect(fsm.value, equals(GestureState.reordering));
      fsm.dispose();
    });

    test('ReorderAndRelocate boundary escape logic', () {
      final fsm = GestureStateMachine(
        initialBehavior: ReorderAndRelocate<OnDrag>.to(
          positions: {QueuePosition.topLeft},
          escapeThresholdInPixels: 50,
        ),
        initialPosition: QueuePosition.topRight,
        escapeThreshold: 50.0,
      );

      // Widget is at Rect.fromLTWH(100, 100, 200, 50)
      // Expanded boundary (inflated by 50) is Rect.fromLTWH(50, 50, 300, 150)
      fsm
        ..lift(
          pointerStart: const Offset(200.0, 125.0),
          widgetRect: const Rect.fromLTWH(100.0, 100.0, 200.0, 50.0),
        )

        // Update inside boundary: stays in reordering
        ..update(
          delta: const Offset(10.0, 10.0),
          globalPosition: const Offset(210.0, 135.0),
        );
      expect(fsm.value, equals(GestureState.reordering));

      // Update outside boundary (e.g. globalPosition X = 360, Y = 125)
      fsm.update(
        delta: const Offset(150.0, 0.0),
        globalPosition: const Offset(360.0, 125.0),
      );
      expect(fsm.value, equals(GestureState.relocating));

      // Drift back inside boundary (X = 200, Y = 125)
      fsm.update(
        delta: const Offset(-160.0, 0.0),
        globalPosition: const Offset(200.0, 125.0),
      );
      expect(fsm.value, equals(GestureState.reordering));

      fsm.dispose();
    });

    test('Settle and Reset transitions', () {
      final fsm = GestureStateMachine(
        initialBehavior: const Dismiss(),
        initialPosition: QueuePosition.topRight,
      );

      fsm
        ..lift(
          pointerStart: const Offset(100.0, 150.0),
          widgetRect: const Rect.fromLTWH(80.0, 130.0, 300.0, 80.0),
        )
        ..settle();
      expect(fsm.value, equals(GestureState.settling));

      fsm.reset();
      expect(fsm.value, equals(GestureState.idle));
      expect(fsm.pointerPosition, isNull);
      fsm.dispose();
    });

    test('Active scale transitions', () {
      final fsm = GestureStateMachine(
        initialBehavior: const Dismiss(),
        initialPosition: QueuePosition.topRight,
      );

      expect(fsm.getActiveScale(1.1), equals(1.0));

      fsm.lift(
        pointerStart: const Offset(100.0, 150.0),
        widgetRect: const Rect.fromLTWH(80.0, 130.0, 300.0, 80.0),
      );
      expect(fsm.getActiveScale(1.1), equals(1.02));

      fsm.update(
        delta: const Offset(10.0, 0.0),
        globalPosition: const Offset(110.0, 150.0),
      );
      expect(fsm.getActiveScale(1.1), equals(1.1));

      fsm.dispose();
    });
  });
}
