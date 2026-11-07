import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('F-08: L-Shaped Unified Corner Bars', () {
    testWidgets(
      'renders _UnifiedCornerZone and single idle handle for corner zones',
      (final tester) async {
        final pointerNotifier = ValueNotifier<OffsetPair?>(
          const OffsetPair(
            local: Offset.zero,
            global: Offset(400, 300), // Center of screen (idle)
          ),
        );
        addTearDown(pointerNotifier.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: DismissalTargets(
                  screenSize: const Size(800, 600),
                  threshold: 80,
                  zones: const [
                    TopEdgeDropZone(isNatural: true),
                    RightEdgeDropZone(isNatural: true),
                  ],
                  pointerPositionNotifier: pointerNotifier,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Idle state: renders single corner idle handle without ClipPath
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
        expect(find.byType(ClipPath), findsNothing);

        // Move into corner engagement zone (distance < 80)
        pointerNotifier.value = const OffsetPair(
          local: Offset.zero,
          global: Offset(750, 50),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Engagement state: renders unified L-bar ClipPath and single apex icon
        expect(find.byType(ClipPath), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'renders separate _PositionedZones when zones are parallel side edges',
      (final tester) async {
        final pointerNotifier = ValueNotifier<OffsetPair?>(
          const OffsetPair(
            local: Offset.zero,
            global: Offset(400, 300),
          ),
        );
        addTearDown(pointerNotifier.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: DismissalTargets(
                  screenSize: const Size(800, 600),
                  threshold: 80,
                  zones: const [
                    LeftEdgeDropZone(),
                    RightEdgeDropZone(),
                  ],
                  pointerPositionNotifier: pointerNotifier,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Two side edges each render an idle handle
        expect(find.byIcon(Icons.close_rounded), findsNWidgets(2));
      },
    );

    testWidgets(
      'stretches corner L-bar and activates hit state when dragged into corner',
      (final tester) async {
        final pointerNotifier = ValueNotifier<OffsetPair?>(
          const OffsetPair(
            local: Offset.zero,
            global: Offset(780, 20), // Inside top-right corner zone (< 80)
          ),
        );
        addTearDown(pointerNotifier.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: DismissalTargets(
                  screenSize: const Size(800, 600),
                  threshold: 80,
                  zones: const [
                    TopEdgeDropZone(isNatural: true),
                    RightEdgeDropZone(isNatural: true),
                  ],
                  pointerPositionNotifier: pointerNotifier,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Apex close icon is visible during hit/stretching
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
        expect(find.byType(ClipPath), findsOneWidget);
      },
    );

    testWidgets(
      'supports all 4 corners: topLeft, topRight, bottomLeft, bottomRight',
      (final tester) async {
        const corners = [
          [TopEdgeDropZone(), LeftEdgeDropZone()],
          [TopEdgeDropZone(), RightEdgeDropZone()],
          [BottomEdgeDropZone(), LeftEdgeDropZone()],
          [BottomEdgeDropZone(), RightEdgeDropZone()],
        ];

        for (final cornerZones in corners) {
          final pointerNotifier = ValueNotifier<OffsetPair?>(
            const OffsetPair(
              local: Offset.zero,
              global: Offset(400, 300),
            ),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 800,
                  height: 600,
                  child: DismissalTargets(
                    screenSize: const Size(800, 600),
                    threshold: 80,
                    zones: cornerZones,
                    pointerPositionNotifier: pointerNotifier,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          // Exactly one idle handle / apex icon per corner configuration
          expect(find.byIcon(Icons.close_rounded), findsOneWidget);
          pointerNotifier.dispose();
        }
      },
    );
  });
}
