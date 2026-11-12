import 'package:flutter/widgets.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QueueGeometrySnapshot - Gap Anchors', () {
    test('computes anchors correctly for VerticalDirection.down', () {
      const containerRect = Rect.fromLTWH(100, 100, 300, 260);
      const cardRects = [
        Rect.fromLTWH(100, 100, 300, 80),
        Rect.fromLTWH(100, 190, 300, 80),
        Rect.fromLTWH(100, 280, 300, 80),
      ];

      final anchors = QueueGeometrySnapshot.computeGapAnchors(
        containerRect: containerRect,
        cardRects: cardRects,
        verticalDirection: VerticalDirection.down,
        cardSpacing: 10,
      );

      expect(anchors.length, equals(4));
      expect(anchors[0].dy, equals(100.0)); // Top of card 0
      expect(anchors[1].dy, equals(185.0)); // Gap between 0 and 1
      expect(anchors[2].dy, equals(275.0)); // Gap between 1 and 2
      expect(anchors[3].dy, equals(360.0)); // Bottom of card 2
      for (final a in anchors) {
        expect(a.dx, equals(250.0)); // Center X
      }
    });

    test('computes anchors correctly for VerticalDirection.up', () {
      const containerRect = Rect.fromLTWH(100, 100, 300, 260);
      const cardRects = [
        Rect.fromLTWH(100, 280, 300, 80), // Index 0 at bottom
        Rect.fromLTWH(100, 190, 300, 80), // Index 1 in middle
        Rect.fromLTWH(100, 100, 300, 80), // Index 2 at top
      ];

      final anchors = QueueGeometrySnapshot.computeGapAnchors(
        containerRect: containerRect,
        cardRects: cardRects,
        verticalDirection: VerticalDirection.up,
        cardSpacing: 10,
      );

      expect(anchors.length, equals(4));
      expect(anchors[0].dy, equals(360.0)); // Bottom of card 0
      expect(anchors[1].dy, equals(275.0)); // Gap between 0 and 1
      expect(anchors[2].dy, equals(185.0)); // Gap between 1 and 2
      expect(anchors[3].dy, equals(100.0)); // Top of card 2
    });

    test('returns container center when cardRects is empty', () {
      const containerRect = Rect.fromLTWH(50, 50, 200, 100);
      final anchors = QueueGeometrySnapshot.computeGapAnchors(
        containerRect: containerRect,
        cardRects: [],
        verticalDirection: VerticalDirection.down,
        cardSpacing: 10,
      );

      expect(anchors.length, equals(1));
      expect(anchors[0], equals(containerRect.center));
    });
  });

  group('resolveTarget - Hysteresis & Multi-Queue Resolution', () {
    const homePos = QueuePosition.topRight;
    const remotePos = QueuePosition.topLeft;

    const homeSnapshot = QueueGeometrySnapshot(
      position: homePos,
      containerRect: Rect.fromLTWH(600, 20, 300, 260),
      cardRects: [
        Rect.fromLTWH(600, 20, 300, 80),
        Rect.fromLTWH(600, 110, 300, 80),
      ],
      gapAnchors: [
        Offset(750, 20),
        Offset(750, 105),
        Offset(750, 190),
      ],
      verticalDirection: VerticalDirection.down,
      cardSpacing: 10,
      maxStackSize: 5,
    );

    const remoteSnapshot = QueueGeometrySnapshot(
      position: remotePos,
      containerRect: Rect.fromLTWH(20, 20, 300, 260),
      cardRects: [
        Rect.fromLTWH(20, 20, 300, 80),
        Rect.fromLTWH(20, 110, 300, 80),
      ],
      gapAnchors: [
        Offset(170, 20),
        Offset(170, 105),
        Offset(170, 190),
      ],
      verticalDirection: VerticalDirection.down,
      cardSpacing: 10,
      maxStackSize: 5,
    );

    final snapshots = {
      homePos: homeSnapshot,
      remotePos: remoteSnapshot,
    };

    test('resolves home SlotTarget when pointer is inside home container', () {
      final target = resolveTarget(
        pointer: const Offset(700, 140),
        homePosition: homePos,
        snapshots: snapshots,
        previousTarget: const NoTarget(),
      );

      expect(target, isA<SlotTarget>());
      final slot = target as SlotTarget;
      expect(slot.position, equals(homePos));
      expect(slot.gapIndex, equals(1));
    });

    test('preserves home SlotTarget via hysteresis when slightly outside', () {
      // 20px to the left of homeContainer (600 - 20 = 580)
      // Within escapeThreshold = 48
      final target = resolveTarget(
        pointer: const Offset(580, 100),
        homePosition: homePos,
        snapshots: snapshots,
        previousTarget: const SlotTarget(
          position: homePos,
          gapIndex: 1,
          progress: 1.0,
        ),
        escapeThreshold: 48,
      );

      expect(target, isA<SlotTarget>());
      final slot = target as SlotTarget;
      expect(slot.position, equals(homePos));
    });

    test(
      'breaks home hysteresis and returns NoTarget when beyond threshold',
      () {
        // 60px to the left of homeContainer (600 - 60 = 540)
        // Beyond escapeThreshold = 48
        final target = resolveTarget(
          pointer: const Offset(540, 100),
          homePosition: homePos,
          snapshots: snapshots,
          previousTarget: const SlotTarget(
            position: homePos,
            gapIndex: 1,
            progress: 1.0,
          ),
          escapeThreshold: 48,
        );

        expect(target, isA<NoTarget>());
      },
    );

    test('resolves remote SlotTarget when hovering over remote container', () {
      final target = resolveTarget(
        pointer: const Offset(150, 25), // Near gap 0 of remote queue
        homePosition: homePos,
        snapshots: snapshots,
        previousTarget: const NoTarget(),
      );

      expect(target, isA<SlotTarget>());
      final slot = target as SlotTarget;
      expect(slot.position, equals(remotePos));
      expect(slot.gapIndex, equals(0));
    });

    test('resolves QueueTarget for empty remote queue', () {
      const emptyPos = QueuePosition.bottomCenter;
      const emptySnapshot = QueueGeometrySnapshot(
        position: emptyPos,
        containerRect: Rect.fromLTWH(300, 500, 200, 100),
        cardRects: [],
        gapAnchors: [Offset(400, 550)],
        verticalDirection: VerticalDirection.down,
        cardSpacing: 10,
        maxStackSize: 3,
      );

      final multiSnapshots = {
        ...snapshots,
        emptyPos: emptySnapshot,
      };

      final target = resolveTarget(
        pointer: const Offset(400, 550),
        homePosition: homePos,
        snapshots: multiSnapshots,
        previousTarget: const NoTarget(),
      );

      expect(target, anyOf(isA<SlotTarget>(), isA<QueueTarget>()));
    });

    test('applies midpoint gravity well to prevent remote gap flicker', () {
      // remote gaps: 0 at y=20, 1 at y=105, 2 at y=190. Midpoint(0,1) = 62.5.
      // At y=66 (3.5px past midpoint toward gap 1), gravity well keeps gap 0.
      final sticky = resolveTarget(
        pointer: const Offset(150, 66),
        homePosition: homePos,
        snapshots: snapshots,
        previousTarget: const SlotTarget(
          position: remotePos,
          gapIndex: 0,
          progress: 0.5,
        ),
      );

      expect(sticky, isA<SlotTarget>());
      expect((sticky as SlotTarget).gapIndex, equals(0));

      // At y=72 (9.5px past midpoint > 7px half-well), switches to gap 1.
      final switched = resolveTarget(
        pointer: const Offset(150, 72),
        homePosition: homePos,
        snapshots: snapshots,
        previousTarget: const SlotTarget(
          position: remotePos,
          gapIndex: 0,
          progress: 0.5,
        ),
      );

      expect(switched, isA<SlotTarget>());
      expect((switched as SlotTarget).gapIndex, equals(1));
    });

    test(
      'keeps remote SlotTarget alive across tail expansion and exit hysteresis',
      () {
        // remote container bottom is 20 + 260 = 280.
        // With incomingHeight=80 + spacing=10, tail bounds reach 370 when
        // previously locked on remotePos.
        final expanded = resolveTarget(
          pointer: const Offset(150, 320),
          homePosition: homePos,
          snapshots: snapshots,
          previousTarget: const SlotTarget(
            position: remotePos,
            gapIndex: 2,
            progress: 0.5,
          ),
          incomingHeight: 80.0,
        );

        expect(expanded, isA<SlotTarget>());
        expect((expanded as SlotTarget).position, equals(remotePos));
      },
    );

    test('resolves QueueTarget inside candidateDockRects with progress', () {
      const dockRect = Rect.fromLTWH(20, 520, 260, 76);
      final target = resolveTarget(
        pointer: const Offset(180, 558),
        homePosition: homePos,
        snapshots: const {},
        previousTarget: const NoTarget(),
        candidatePositions: const {QueuePosition.bottomLeft},
        candidateDockRects: const {QueuePosition.bottomLeft: dockRect},
        screenSize: const Size(800, 600),
      );

      expect(target, isA<QueueTarget>());
      final qTarget = target as QueueTarget;
      expect(qTarget.position, equals(QueuePosition.bottomLeft));
      expect(qTarget.progress, greaterThanOrEqualTo(0.72));
    });

    test(
      'resolveCandidateDockRects partitions crowded horizontal bands cleanly',
      () {
        final rects = resolveCandidateDockRects(
          homePosition: QueuePosition.topRight,
          candidatePositions: const {
            QueuePosition.centerLeft,
            QueuePosition.centerRight,
            QueuePosition.topLeft,
            QueuePosition.topCenter,
          },
          screenSize: const Size(380, 720),
          cardSize: const Size(290, 76),
        );

        final cLeft = rects[QueuePosition.centerLeft]!;
        final cRight = rects[QueuePosition.centerRight]!;
        expect(cLeft.overlaps(cRight), isFalse);
        expect(cLeft.right + 8.0, lessThanOrEqualTo(cRight.left));

        final tLeft = rects[QueuePosition.topLeft]!;
        final tCenter = rects[QueuePosition.topCenter]!;
        expect(tLeft.overlaps(tCenter), isFalse);
      },
    );

    test(
      'resolveCandidateDockRects avoids overlapping mounted non-empty stacks',
      () {
        const blocker = QueueGeometrySnapshot(
          position: QueuePosition.topLeft,
          containerRect: Rect.fromLTWH(20, 20, 280, 180),
          cardRects: [
            Rect.fromLTWH(20, 20, 280, 80),
            Rect.fromLTWH(20, 110, 280, 80),
          ],
          gapAnchors: [Offset(160, 20), Offset(160, 105), Offset(160, 190)],
          verticalDirection: VerticalDirection.down,
          cardSpacing: 10,
          maxStackSize: 3,
        );

        final rects = resolveCandidateDockRects(
          homePosition: QueuePosition.bottomRight,
          candidatePositions: const {
            QueuePosition.topLeft,
            QueuePosition.topCenter,
          },
          screenSize: const Size(400, 720),
          cardSize: const Size(280, 76),
          mountedSnapshots: const {QueuePosition.topLeft: blocker},
        );

        final topCenterDock = rects[QueuePosition.topCenter]!;
        expect(topCenterDock.overlaps(blocker.containerRect), isFalse);
        expect(
          topCenterDock.top,
          greaterThanOrEqualTo(blocker.containerRect.bottom),
        );
      },
    );

    test(
      'picks nearest dock center in intersecting regions regardless of '
      'Set order',
      () {
        const overlappingDocks = {
          QueuePosition.centerLeft: Rect.fromLTWH(20, 260, 240, 80),
          QueuePosition.centerRight: Rect.fromLTWH(140, 260, 240, 80),
        };

        // Inside overlap [140..260], x=220 is much closer to centerRight center
        // (260) than centerLeft center (140).
        final rightPick = resolveTarget(
          pointer: const Offset(220, 300),
          homePosition: QueuePosition.topRight,
          snapshots: const {},
          previousTarget: const NoTarget(),
          candidatePositions: const {
            QueuePosition.centerLeft,
            QueuePosition.centerRight,
          },
          candidateDockRects: overlappingDocks,
          screenSize: const Size(400, 700),
        );
        expect(rightPick, isA<QueueTarget>());
        expect(
          (rightPick as QueueTarget).position,
          equals(QueuePosition.centerRight),
        );

        // Moving left to x=150 picks centerLeft.
        final leftPick = resolveTarget(
          pointer: const Offset(150, 300),
          homePosition: QueuePosition.topRight,
          snapshots: const {},
          previousTarget: const NoTarget(),
          candidatePositions: const {
            QueuePosition.centerLeft,
            QueuePosition.centerRight,
          },
          candidateDockRects: overlappingDocks,
          screenSize: const Size(400, 700),
        );
        expect(leftPick, isA<QueueTarget>());
        expect(
          (leftPick as QueueTarget).position,
          equals(QueuePosition.centerLeft),
        );
      },
    );

    test(
      'overlapping home and remote mounted stacks avoid premature theft',
      () {
        const centerHome = QueueGeometrySnapshot(
          position: QueuePosition.centerLeft,
          containerRect: Rect.fromLTWH(20, 240, 240, 140),
          cardRects: [Rect.fromLTWH(20, 240, 240, 80)],
          gapAnchors: [Offset(140, 240), Offset(140, 320)],
          verticalDirection: VerticalDirection.down,
          cardSpacing: 10,
          maxStackSize: 3,
        );
        const centerRemote = QueueGeometrySnapshot(
          position: QueuePosition.centerRight,
          containerRect: Rect.fromLTWH(140, 240, 240, 140),
          cardRects: [Rect.fromLTWH(140, 240, 240, 80)],
          gapAnchors: [Offset(260, 240), Offset(260, 320)],
          verticalDirection: VerticalDirection.down,
          cardSpacing: 10,
          maxStackSize: 3,
        );

        // At x=160 inside the overlap, centerHome center is 140 vs
        // centerRemote 260, so home keeps focus cleanly.
        final stayHome = resolveTarget(
          pointer: const Offset(160, 280),
          homePosition: QueuePosition.centerLeft,
          snapshots: const {
            QueuePosition.centerLeft: centerHome,
            QueuePosition.centerRight: centerRemote,
          },
          previousTarget: const SlotTarget(
            position: QueuePosition.centerLeft,
            gapIndex: 0,
            progress: 1.0,
          ),
        );
        expect(stayHome, isA<SlotTarget>());
        expect(
          (stayHome as SlotTarget).position,
          equals(QueuePosition.centerLeft),
        );

        // Dragging right to x=250 hands off cleanly to centerRight.
        final handOff = resolveTarget(
          pointer: const Offset(250, 280),
          homePosition: QueuePosition.centerLeft,
          snapshots: const {
            QueuePosition.centerLeft: centerHome,
            QueuePosition.centerRight: centerRemote,
          },
          previousTarget: const SlotTarget(
            position: QueuePosition.centerLeft,
            gapIndex: 0,
            progress: 1.0,
          ),
        );
        expect(handOff, isA<SlotTarget>());
        expect(
          (handOff as SlotTarget).position,
          equals(QueuePosition.centerRight),
        );
      },
    );
  });
}
