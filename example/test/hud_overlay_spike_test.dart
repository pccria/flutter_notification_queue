import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HUD Overlay Pass-Through & Scoping Spike Tests', () {
    testWidgets(
      'Overlay allows pass-through taps on main UI when no notification is hit',
      (final tester) async {
        var buttonTapped = false;
        final controller = NotificationController(
          queues: {
            const NotificationQueue(
              position: QueuePosition.topCenter,
            ),
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  // Layer 0: Main Interactive UI
                  Center(
                    child: ElevatedButton(
                      onPressed: () => buttonTapped = true,
                      child: const Text('Target Button'),
                    ),
                  ),

                  // Layer 1: Transparent Notification Scope
                  Positioned.fill(
                    child: NotificationScope(
                      controller: controller,
                      useRootOverlay: false,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the button behind the transparent notification overlay
        await tester.tap(find.text('Target Button'));
        await tester.pump();

        expect(buttonTapped, isTrue);
      },
    );

    testWidgets(
      'Notification cards receive taps while background remains pass-through',
      (final tester) async {
        var bgTapped = false;
        var notifActionTapped = false;

        final controller = NotificationController(
          queues: {
            const NotificationQueue(
              position: QueuePosition.topCenter,
            ),
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  // Layer 0: Main Interactive UI
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => bgTapped = true,
                      child: Container(
                        color: Colors.blue.shade900,
                        alignment: Alignment.bottomCenter,
                        child: const Text('Background Layer'),
                      ),
                    ),
                  ),

                  // Layer 1: Transparent Notification Scope
                  Positioned.fill(
                    child: NotificationScope(
                      controller: controller,
                      useRootOverlay: false,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Fire a notification with an action
        controller.show(
          AppNotification(
            title: 'Test Notification',
            message: 'Checking hit tests',
            channelName: 'default',
            dismissDuration: const Duration(seconds: 10),
            action: NotificationAction.button(
              label: 'CLICK ME',
              onPressed: () => notifActionTapped = true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 1. Tap on the notification action button
        final actionBtn = find.text('CLICK ME');
        expect(actionBtn, findsOneWidget);
        await tester.tap(actionBtn);
        await tester.pump();

        expect(notifActionTapped, isTrue);
        expect(bgTapped, isFalse);

        // 2. Tap on the background layer outside the notification
        await tester.tap(find.text('Background Layer'));
        await tester.pump();

        expect(bgTapped, isTrue);
      },
    );

    testWidgets(
      'Two bounded zones side-by-side operate independently without scope '
      'leakage',
      (final tester) async {
        final ctrlA = NotificationController(
          queues: {
            const NotificationQueue(position: QueuePosition.topCenter),
          },
        );
        final ctrlB = NotificationController(
          queues: {
            const NotificationQueue(position: QueuePosition.topCenter),
          },
        );
        addTearDown(() {
          ctrlA.dispose();
          ctrlB.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  const Center(child: Text('Underlying Screen Content')),

                  // Zone A (Left Half)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 300,
                    child: NotificationScope(
                      key: const ValueKey('zone_a'),
                      controller: ctrlA,
                      useRootOverlay: false,
                      child: const SizedBox.expand(),
                    ),
                  ),

                  // Zone B (Right Half)
                  Positioned(
                    left: 300,
                    top: 0,
                    bottom: 0,
                    width: 300,
                    child: NotificationScope(
                      key: const ValueKey('zone_b'),
                      controller: ctrlB,
                      useRootOverlay: false,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Fire in A
        ctrlA.show(
          const AppNotification(
            title: 'Notice for Scope A',
            message: 'In left zone',
            channelName: 'default',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Fire in B
        ctrlB.show(
          const AppNotification(
            title: 'Notice for Scope B',
            message: 'In right zone',
            channelName: 'default',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Notice for Scope A'), findsOneWidget);
        expect(find.text('Notice for Scope B'), findsOneWidget);

        // Verify physical bounds: Notice for Scope A is in left half (x < 300)
        final posA = tester.getTopLeft(find.text('Notice for Scope A'));
        expect(posA.dx, lessThan(300));

        // Notice for Scope B is in right half (x >= 300)
        final posB = tester.getTopLeft(find.text('Notice for Scope B'));
        expect(posB.dx, greaterThanOrEqualTo(300));
      },
    );

    testWidgets(
      'Hidden zone placed offscreen stays attached safely and is not on screen',
      (final tester) async {
        final ctrlA = NotificationController(
          queues: {
            const NotificationQueue(position: QueuePosition.topCenter),
          },
        );
        final ctrlB = NotificationController(
          queues: {
            const NotificationQueue(position: QueuePosition.topCenter),
          },
        );
        addTearDown(() {
          ctrlA.dispose();
          ctrlB.dispose();
        });

        var showA = true;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (final context, final setState) => MaterialApp(
              home: Scaffold(
                body: Stack(
                  children: [
                    ElevatedButton(
                      onPressed: () => setState(() => showA = !showA),
                      child: const Text('Toggle Active Scope'),
                    ),
                    Positioned(
                      left: showA ? 0 : -99999,
                      top: showA ? 0 : -99999,
                      width: 800,
                      height: 600,
                      child: NotificationScope(
                        key: const ValueKey('scope_a'),
                        controller: ctrlA,
                        useRootOverlay: false,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Positioned(
                      left: !showA ? 0 : -99999,
                      top: !showA ? 0 : -99999,
                      width: 800,
                      height: 600,
                      child: NotificationScope(
                        key: const ValueKey('scope_b'),
                        controller: ctrlB,
                        useRootOverlay: false,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(ctrlA.isAttached, isTrue);
        expect(ctrlB.isAttached, isTrue);

        // Fire in A while visible
        ctrlA.show(
          const AppNotification(
            title: 'Scope A Card',
            message: 'Hello A',
            channelName: 'default',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // When visible, Scope A card is on screen (x >= 0 and x < 800)
        final posA1 = tester.getTopLeft(find.text('Scope A Card'));
        expect(posA1.dx, greaterThanOrEqualTo(0));
        expect(posA1.dx, lessThan(800));

        // Switch to B
        await tester.tap(find.text('Toggle Active Scope'));
        await tester.pumpAndSettle();

        // Scope A is now offscreen! (x < -10000)
        final posA2 = tester.getTopLeft(find.text('Scope A Card'));
        expect(posA2.dx, lessThan(-10000));

        // Fire in B while visible
        ctrlB.show(
          const AppNotification(
            title: 'Scope B Card',
            message: 'Hello B',
            channelName: 'default',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Scope B is on screen
        final posB = tester.getTopLeft(find.text('Scope B Card'));
        expect(posB.dx, greaterThanOrEqualTo(0));
        expect(posB.dx, lessThan(800));

        // Switch back to A: Scope A is back on screen, Scope B is offscreen
        await tester.tap(find.text('Toggle Active Scope'));
        await tester.pumpAndSettle();

        final posA3 = tester.getTopLeft(find.text('Scope A Card'));
        expect(posA3.dx, greaterThanOrEqualTo(0));
        expect(posA3.dx, lessThan(800));

        final posB2 = tester.getTopLeft(find.text('Scope B Card'));
        expect(posB2.dx, lessThan(-10000));
      },
    );
  });
}
