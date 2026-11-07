import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('F-07: Desktop Context Menu Support', () {
    testWidgets(
      'secondary tap (right-click) opens default context menu',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NotificationScope(
                controller: controller,
                child: const Center(child: Text('App Content')),
              ),
            ),
          ),
        );

        controller.show(
          const AppNotification(
            id: 'test-1',
            title: 'Test Title',
            message: 'Right-click me',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Right-click me'), findsOneWidget);
        expect(find.text('Pin'), findsNothing);

        // Secondary tap (right-click)
        await tester.tap(
          find.text('Right-click me'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        // Default menu items should be visible
        expect(find.text('Pin'), findsOneWidget);
        expect(find.text('Snooze'), findsOneWidget);
        expect(find.text('Copy Message'), findsOneWidget);
        expect(find.text('Dismiss'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Pin in context menu pins the notification',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NotificationScope(
                controller: controller,
                child: const Center(child: Text('App Content')),
              ),
            ),
          ),
        );

        controller.show(
          const AppNotification(
            id: 'test-pin',
            message: 'Pinnable notification',
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.text('Pinnable notification'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pin'));
        await tester.pumpAndSettle();

        final coordinator = controller.coordinator!;
        expect(coordinator.activeNotifications.first.isPinned, isTrue);
      },
    );

    testWidgets(
      'tapping Snooze in context menu snoozes the notification',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NotificationScope(
                controller: controller,
                child: const Center(child: Text('App Content')),
              ),
            ),
          ),
        );

        controller.show(
          const AppNotification(
            id: 'test-snooze',
            message: 'Snooze me',
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.text('Snooze me'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Snooze'));
        await tester.pumpAndSettle();

        final coordinator = controller.coordinator!;
        expect(coordinator.activeNotifications, isEmpty);
      },
    );

    testWidgets(
      'tapping Copy Message copies text to Clipboard',
      (final tester) async {
        String? copiedText;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          SystemChannels.platform,
          (final methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              copiedText = (methodCall.arguments
                  as Map<dynamic, dynamic>)['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        final controller = NotificationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NotificationScope(
                controller: controller,
                child: const Center(child: Text('App Content')),
              ),
            ),
          ),
        );

        controller.show(
          const AppNotification(
            id: 'test-copy',
            message: 'Text to copy',
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.text('Text to copy'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Copy Message'));
        await tester.pumpAndSettle();

        expect(copiedText, equals('Text to copy'));
      },
    );

    testWidgets(
      'notification with action renders action option in context menu',
      (final tester) async {
        var actionInvoked = false;
        final controller = NotificationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NotificationScope(
                controller: controller,
                child: const Center(child: Text('App Content')),
              ),
            ),
          ),
        );

        controller.show(
          AppNotification(
            id: 'test-action',
            message: 'Has action',
            action: NotificationAction.button(
              label: 'Undo Action',
              onPressed: () {
                actionInvoked = true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.text('Has action'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        expect(find.text('Undo Action'), findsWidgets);

        await tester.tap(find.text('Undo Action').last);
        await tester.pumpAndSettle();

        expect(actionInvoked, isTrue);
      },
    );

    testWidgets(
      'tapping Dismiss in context menu dismisses notification',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NotificationScope(
                controller: controller,
                child: const Center(child: Text('App Content')),
              ),
            ),
          ),
        );

        controller.show(
          const AppNotification(
            id: 'test-dismiss',
            message: 'Dismiss me',
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.text('Dismiss me'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Dismiss'));
        await tester.pumpAndSettle();

        expect(find.text('Dismiss me'), findsNothing);
      },
    );

    testWidgets(
      'Shift+F10 opens context menu when card has focus',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NotificationScope(
                controller: controller,
                child: const Center(child: Text('App Content')),
              ),
            ),
          ),
        );

        controller.show(
          const AppNotification(
            id: 'test-kbd',
            message: 'Keyboard focus card',
          ),
        );
        await tester.pumpAndSettle();

        // Transfer focus to notification stack (Alt + N)
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pumpAndSettle();

        // Press Shift + F10
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.f10);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();

        // Context menu items should appear
        expect(find.text('Copy Message'), findsOneWidget);
        expect(find.text('Dismiss'), findsOneWidget);
      },
    );

    testWidgets(
      'custom contextMenuBuilder overrides default menu items',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NotificationScope(
                controller: controller,
                child: const Center(child: Text('App Content')),
              ),
            ),
          ),
        );

        controller.show(
          AppNotification(
            id: 'test-custom',
            message: 'Custom menu card',
            contextMenuBuilder: (final context, final notif, final ctrl) => [
              const PopupMenuItem<void>(
                child: Text('Custom Item 1'),
              ),
              const PopupMenuItem<void>(
                child: Text('Custom Item 2'),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.text('Custom menu card'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        expect(find.text('Custom Item 1'), findsOneWidget);
        expect(find.text('Custom Item 2'), findsOneWidget);
        expect(find.text('Pin'), findsNothing);
      },
    );

    testWidgets(
      'enableContextMenu: false suppresses context menu',
      (final tester) async {
        final controller = NotificationController(
          a11yOptions: const NotificationA11yOptions(
            enableContextMenu: false,
          ),
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NotificationScope(
                controller: controller,
                child: const Center(child: Text('App Content')),
              ),
            ),
          ),
        );

        controller.show(
          const AppNotification(
            id: 'test-disabled',
            message: 'No context menu',
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.text('No context menu'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        expect(find.text('Pin'), findsNothing);
        expect(find.text('Dismiss'), findsNothing);
      },
    );

    testWidgets(
      'opening context menu pauses auto-dismiss timer',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NotificationScope(
                controller: controller,
                child: const Center(child: Text('App Content')),
              ),
            ),
          ),
        );

        controller.show(
          const AppNotification(
            id: 'test-timer',
            message: 'Timed notification',
            dismissDuration: Duration(seconds: 3),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Right-click to open context menu
        await tester.tap(
          find.text('Timed notification'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        expect(find.text('Dismiss'), findsOneWidget);

        // Advance 2 seconds (beyond dismiss duration)
        await tester.pump(const Duration(seconds: 2));

        // Notification must still be alive because menu paused timer
        expect(find.text('Timed notification'), findsOneWidget);

        // Close menu by tapping barrier
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Now resume timer and wait for auto-dismiss
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        expect(find.text('Timed notification'), findsNothing);
      },
    );

    testWidgets(
      'context menu opens and functions when mounted in MaterialApp.builder',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(
              body: Center(child: Text('App Content')),
            ),
          ),
        );

        controller.show(
          const AppNotification(
            id: 'builder-card',
            message: 'Builder notification',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Builder notification'), findsOneWidget);
        expect(find.text('Pin'), findsNothing);

        // Secondary tap (right-click)
        await tester.tap(
          find.text('Builder notification'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        // Menu items should be visible
        expect(find.text('Pin'), findsOneWidget);
        expect(find.text('Snooze'), findsOneWidget);
        expect(find.text('Copy Message'), findsOneWidget);
        expect(find.text('Dismiss'), findsOneWidget);

        // Tapping Pin should pin the notification
        await tester.tap(find.text('Pin'));
        await tester.pumpAndSettle();

        final coordinator = controller.coordinator!;
        expect(coordinator.activeNotifications.first.isPinned, isTrue);
        expect(find.text('Pin'), findsNothing);
      },
    );

    testWidgets(
      'Shift+F10 opens context menu in MaterialApp.builder and '
      'Escape closes it',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(
              body: Center(child: Text('App Content')),
            ),
          ),
        );

        controller.show(
          const AppNotification(
            id: 'shortcut-builder',
            message: 'Shortcut notification',
          ),
        );
        await tester.pumpAndSettle();

        // Focus the notification card
        final focused = controller.coordinator!.focusFirstNotification();
        expect(focused, isTrue);
        await tester.pumpAndSettle();

        // Press Shift + F10
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.f10);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();

        expect(find.text('Dismiss'), findsOneWidget);

        // Escape key dismisses the context menu
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Dismiss'), findsNothing);
        expect(find.text('Shortcut notification'), findsOneWidget);
      },
    );

    testWidgets(
      'barrier tap closes context menu in MaterialApp.builder',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(
              body: Center(child: Text('App Content')),
            ),
          ),
        );

        controller.show(
          const AppNotification(
            id: 'barrier-builder',
            message: 'Barrier test',
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.text('Barrier test'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        expect(find.text('Dismiss'), findsOneWidget);

        // Tap outside the context menu
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.text('Dismiss'), findsNothing);
      },
    );

    testWidgets(
      'moving mouse outside notification card while context menu is open '
      'does not resume auto-dismiss timer',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NotificationScope(
                controller: controller,
                child: const Center(child: Text('App Content')),
              ),
            ),
          ),
        );

        controller.show(
          const AppNotification(
            id: 'mouse-exit-timer',
            message: 'Mouse exit timer test',
            dismissDuration: Duration(seconds: 3),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Right-click the notification card to open context menu
        await tester.tap(
          find.text('Mouse exit timer test'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        expect(find.text('Dismiss'), findsOneWidget);

        // Move the mouse off the notification card (e.g. to (10, 10))
        // This triggers MouseRegion.onExit
        final gesture =
            await tester.createGesture(kind: PointerDeviceKind.mouse);
        final cardCenter =
            tester.getCenter(find.text('Mouse exit timer test'));
        await gesture.addPointer(location: cardCenter);
        await gesture.moveTo(const Offset(10, 10));
        await tester.pump();

        // Advance 4 seconds (well beyond the 3-second dismissDuration)
        await tester.pump(const Duration(seconds: 4));

        // Notification must still be present because context menu is open!
        expect(find.text('Mouse exit timer test'), findsOneWidget);
        expect(find.text('Dismiss'), findsOneWidget);

        // Dismiss the context menu by tapping the barrier
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Now that the menu is closed, timer should resume and dismiss
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        expect(find.text('Mouse exit timer test'), findsNothing);
      },
    );

    testWidgets(
      'right-clicking card 2 while card 1 context menu is open '
      'immediately opens card 2 menu in a single click',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(
              body: Center(child: Text('App Content')),
            ),
          ),
        );

        controller.show(
          AppNotification(
            id: 'card-1',
            message: 'First Card',
            contextMenuBuilder: (final context, final notif, final c) => [
              const PopupMenuItem<void>(
                child: Text('Action For Card 1'),
              ),
            ],
          ),
        );
        controller.show(
          AppNotification(
            id: 'card-2',
            message: 'Second Card',
            contextMenuBuilder: (final context, final notif, final c) => [
              const PopupMenuItem<void>(
                child: Text('Action For Card 2'),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('First Card'), findsOneWidget);
        expect(find.text('Second Card'), findsOneWidget);

        // Right-click Card 1 to open Card 1's context menu
        await tester.tap(
          find.text('First Card'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        expect(find.text('Action For Card 1'), findsOneWidget);
        expect(find.text('Action For Card 2'), findsNothing);

        // Right-click Card 2 directly while Card 1's menu is open
        await tester.tap(
          find.text('Second Card'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        // Card 1 menu must be dismissed and Card 2 menu must be open!
        expect(find.text('Action For Card 1'), findsNothing);
        expect(find.text('Action For Card 2'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping outside overlay context menu dismisses menu and '
      'allows background interaction without swallowing click',
      (final tester) async {
        final controller = NotificationController();
        addTearDown(controller.dispose);

        var backgroundTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    backgroundTapped = true;
                  },
                  child: const Text('Background Button'),
                ),
              ),
            ),
          ),
        );

        controller.show(
          const AppNotification(
            id: 'menu-card',
            message: 'Card With Menu',
          ),
        );
        await tester.pumpAndSettle();

        // Right-click card to open menu
        await tester.tap(
          find.text('Card With Menu'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        expect(find.text('Dismiss'), findsOneWidget);
        expect(backgroundTapped, isFalse);

        // Tap the background button while the menu is open
        await tester.tap(find.text('Background Button'));
        await tester.pumpAndSettle();

        // Menu is dismissed and background button received the tap!
        expect(find.text('Dismiss'), findsNothing);
        expect(backgroundTapped, isTrue);
      },
    );
  });
}
