import 'package:flutter/widgets.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DismissEgress', () {
    const cardSize = Size(300, 80);

    group('DismissEgressHorizontal', () {
      const egress = DismissEgressHorizontal();

      test('allows horizontal swipes and rejects vertical vectors', () {
        expect(
          egress.allowsVector(const Offset(-100, 0), QueuePosition.topCenter),
          isTrue,
        );
        expect(
          egress.allowsVector(const Offset(100, 0), QueuePosition.topCenter),
          isTrue,
        );
        expect(
          egress.allowsVector(const Offset(0, -100), QueuePosition.topCenter),
          isFalse,
        );
        expect(
          egress.allowsVector(const Offset(0, 100), QueuePosition.topCenter),
          isFalse,
        );
      });

      test('respects allowLeft and allowRight flags', () {
        const leftOnly = DismissEgressHorizontal(allowRight: false);
        expect(
          leftOnly.allowsVector(const Offset(-50, 0), QueuePosition.centerLeft),
          isTrue,
        );
        expect(
          leftOnly.allowsVector(const Offset(50, 0), QueuePosition.centerLeft),
          isFalse,
        );

        const rightOnly = DismissEgressHorizontal(allowLeft: false);
        expect(
          rightOnly.allowsVector(
            const Offset(-50, 0),
            QueuePosition.centerLeft,
          ),
          isFalse,
        );
        expect(
          rightOnly.allowsVector(const Offset(50, 0), QueuePosition.centerLeft),
          isTrue,
        );
      });
    });

    group('DismissEgressNatural', () {
      const egress = DismissEgressNatural();

      test('allows upward egress for top positions and rejects downward', () {
        // topCenter
        expect(
          egress.allowsVector(const Offset(0, -50), QueuePosition.topCenter),
          isTrue,
        );
        expect(
          egress.allowsVector(const Offset(0, 50), QueuePosition.topCenter),
          isFalse,
        );

        // topLeft permits upward or leftward
        expect(
          egress.allowsVector(const Offset(0, -50), QueuePosition.topLeft),
          isTrue,
        );
        expect(
          egress.allowsVector(const Offset(-50, 0), QueuePosition.topLeft),
          isTrue,
        );
        expect(
          egress.allowsVector(const Offset(50, 0), QueuePosition.topLeft),
          isFalse,
        );
      });

      test('allows downward egress for bottom positions and rejects upward',
          () {
        // bottomCenter
        expect(
          egress.allowsVector(const Offset(0, 50), QueuePosition.bottomCenter),
          isTrue,
        );
        expect(
          egress.allowsVector(const Offset(0, -50), QueuePosition.bottomCenter),
          isFalse,
        );

        // bottomRight permits downward or rightward
        expect(
          egress.allowsVector(const Offset(0, 50), QueuePosition.bottomRight),
          isTrue,
        );
        expect(
          egress.allowsVector(const Offset(50, 0), QueuePosition.bottomRight),
          isTrue,
        );
        expect(
          egress.allowsVector(const Offset(-50, 0), QueuePosition.bottomRight),
          isFalse,
        );
      });

      test('allows outward egress for center-anchored queues', () {
        expect(
          egress.allowsVector(const Offset(-50, 0), QueuePosition.centerLeft),
          isTrue,
        );
        expect(
          egress.allowsVector(const Offset(50, 0), QueuePosition.centerLeft),
          isFalse,
        );

        expect(
          egress.allowsVector(const Offset(50, 0), QueuePosition.centerRight),
          isTrue,
        );
        expect(
          egress.allowsVector(const Offset(-50, 0), QueuePosition.centerRight),
          isFalse,
        );
      });
    });

    group('DismissEgressOutward', () {
      const egress = DismissEgressOutward();

      test('strictly permits swiping toward nearest screen edge', () {
        // Left queues swipe left only
        expect(
          egress.allowsVector(const Offset(-50, 0), QueuePosition.topLeft),
          isTrue,
        );
        expect(
          egress.allowsVector(const Offset(50, 0), QueuePosition.topLeft),
          isFalse,
        );
        expect(
          egress.allowsVector(const Offset(-50, 0), QueuePosition.centerLeft),
          isTrue,
        );
        expect(
          egress.allowsVector(const Offset(50, 0), QueuePosition.centerLeft),
          isFalse,
        );

        // Right queues swipe right only
        expect(
          egress.allowsVector(const Offset(50, 0), QueuePosition.topRight),
          isTrue,
        );
        expect(
          egress.allowsVector(const Offset(-50, 0), QueuePosition.topRight),
          isFalse,
        );

        // Center queues permit both
        expect(
          egress.allowsVector(const Offset(-50, 0), QueuePosition.topCenter),
          isTrue,
        );
        expect(
          egress.allowsVector(const Offset(50, 0), QueuePosition.topCenter),
          isTrue,
        );
      });
    });

    group('DismissEgressCross', () {
      const egress = DismissEgressCross();

      test('permits horizontal swipe AND natural vertical exit', () {
        // topCenter permits left, right, and up, but NOT down
        expect(
          egress.allowsVector(const Offset(-50, 0), QueuePosition.topCenter),
          isTrue,
        );
        expect(
          egress.allowsVector(const Offset(50, 0), QueuePosition.topCenter),
          isTrue,
        );
        expect(
          egress.allowsVector(const Offset(0, -50), QueuePosition.topCenter),
          isTrue,
        );
        expect(
          egress.allowsVector(const Offset(0, 50), QueuePosition.topCenter),
          isFalse,
        );

        // bottomCenter permits left, right, and down, but NOT up
        expect(
          egress.allowsVector(const Offset(-50, 0), QueuePosition.bottomCenter),
          isTrue,
        );
        expect(
          egress.allowsVector(const Offset(50, 0), QueuePosition.bottomCenter),
          isTrue,
        );
        expect(
          egress.allowsVector(const Offset(0, 50), QueuePosition.bottomCenter),
          isTrue,
        );
        expect(
          egress.allowsVector(const Offset(0, -50), QueuePosition.bottomCenter),
          isFalse,
        );
      });
    });

    group('DismissEgressAny', () {
      const egress = DismissEgressAny();

      test('permits egress in any direction with non-zero distance', () {
        expect(
          egress.allowsVector(const Offset(10, 10), QueuePosition.topCenter),
          isTrue,
        );
        expect(
          egress.allowsVector(
            const Offset(-10, -10),
            QueuePosition.bottomRight,
          ),
          isTrue,
        );
        expect(
          egress.allowsVector(Offset.zero, QueuePosition.topCenter),
          isFalse,
        );
      });
    });

    group('isCommit Evaluation', () {
      const egress = DismissEgressHorizontal();

      test('commits when relative distance exceeds 40% of card width', () {
        // 40% of 300px = 120px
        expect(
          egress.isCommit(
            offset: const Offset(125, 0),
            velocity: Velocity.zero,
            cardSize: cardSize,
            position: QueuePosition.topRight,
          ),
          isTrue,
        );

        // 35% of 300px = 105px (insufficient)
        expect(
          egress.isCommit(
            offset: const Offset(105, 0),
            velocity: Velocity.zero,
            cardSize: cardSize,
            position: QueuePosition.topRight,
          ),
          isFalse,
        );
      });

      test('commits on velocity fling even with negligible displacement', () {
        // Only 15px displacement, but 800px/s velocity
        expect(
          egress.isCommit(
            offset: const Offset(15, 0),
            velocity: const Velocity(pixelsPerSecond: Offset(800, 0)),
            cardSize: cardSize,
            position: QueuePosition.topRight,
            escapeVelocity: 600.0,
          ),
          isTrue,
        );

        // High velocity in disallowed direction is rejected
        expect(
          egress.isCommit(
            offset: const Offset(0, 15),
            velocity: const Velocity(pixelsPerSecond: Offset(0, 800)),
            cardSize: cardSize,
            position: QueuePosition.topRight,
            escapeVelocity: 600.0,
          ),
          isFalse,
        );
      });
    });

    group('Progress Calculation', () {
      const egress = DismissEgressHorizontal();

      test('calculates normalized progress along allowed vector', () {
        // Target is 300 * 0.40 = 120px
        expect(
          egress.calculateProgress(
            offset: const Offset(60, 0),
            cardSize: cardSize,
            position: QueuePosition.topRight,
          ),
          closeTo(0.5, 0.01),
        );

        expect(
          egress.calculateProgress(
            offset: const Offset(120, 0),
            cardSize: cardSize,
            position: QueuePosition.topRight,
          ),
          closeTo(1.0, 0.01),
        );

        // Disallowed direction yields 0.0 progress
        expect(
          egress.calculateProgress(
            offset: const Offset(0, 100),
            cardSize: cardSize,
            position: QueuePosition.topRight,
          ),
          0.0,
        );
      });
    });

    group('Viscous Damping & Rubber-Banding', () {
      test('dampAxis provides soft asymptotic bounds', () {
        expect(DismissEgress.dampAxis(0), 0.0);
        expect(DismissEgress.dampAxis(10), greaterThan(0.0));
        expect(DismissEgress.dampAxis(100), lessThanOrEqualTo(32.0));
        expect(DismissEgress.dampAxis(-100), greaterThanOrEqualTo(-32.0));
      });

      test('applyViscousDamping preserves allowed axis and damps forbidden',
          () {
        const egress = DismissEgressHorizontal();
        final result = egress.applyViscousDamping(
          const Offset(100, 50),
          QueuePosition.topCenter,
        );
        // Horizontal is 1:1
        expect(result.dx, 100.0);
        // Vertical is rubber-band damped
        expect(result.dy, lessThan(32.0));
        expect(result.dy, greaterThan(0.0));
      });
    });

    group('Backward Compatibility with Dismiss.zones', () {
      test('resolves effectiveEgress from legacy zones', () {
        const dismissWithSide = Dismiss(zones: DismissZone.sideEdges);
        expect(dismissWithSide.effectiveEgress, isA<DismissEgressHorizontal>());

        const dismissWithNatural = Dismiss(zones: DismissZone.naturalDirection);
        expect(dismissWithNatural.effectiveEgress, isA<DismissEgressNatural>());

        const modernDismiss = Dismiss(egress: DismissEgressOutward());
        expect(modernDismiss.effectiveEgress, isA<DismissEgressOutward>());
      });
    });
  });
}
