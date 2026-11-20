import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue_example/studio/bloc/notification_bloc.dart';
import 'package:flutter_notification_queue_example/studio/bloc/setup_bloc.dart';
import 'package:flutter_notification_queue_example/studio/bloc/studio_bloc.dart';
import 'package:flutter_notification_queue_example/studio/studio_theme.dart';
import 'package:flutter_notification_queue_example/studio/widgets/overlay/studio_overlay_host.dart';
import 'package:flutter_notification_queue_example/studio/widgets/overlay/zone_frame.dart';
import 'package:flutter_notification_queue_example/studio/widgets/overlay/zone_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Zone Layout Geometry Unit Tests', () {
    test('computeZoneRects produces full rect in single mode with 1 window',
        () {
      final rects = computeZoneRects(
        totalSize: const Size(1200, 800),
        isSplit: false,
        windowCount: 1,
        activeWindowId: 'win_1',
      );

      expect(rects.mode, equals(OverlayLayoutMode.single));
      expect(rects.zoneA, equals(const Rect.fromLTWH(0, 0, 1200, 800)));
      expect(rects.zoneB, isNull);
    });

    test(
        'computeZoneRects holds inactive zone offscreen in single mode with '
        '2 windows', () {
      // win_1 active
      final rects1 = computeZoneRects(
        totalSize: const Size(1200, 800),
        isSplit: false,
        windowCount: 2,
        activeWindowId: 'win_1',
      );
      expect(rects1.zoneA, equals(const Rect.fromLTWH(0, 0, 1200, 800)));
      expect(rects1.zoneB!.left, lessThan(-10000));

      // win_2 active
      final rects2 = computeZoneRects(
        totalSize: const Size(1200, 800),
        isSplit: false,
        windowCount: 2,
        activeWindowId: 'win_2',
      );
      expect(rects2.zoneA.left, lessThan(-10000));
      expect(rects2.zoneB, equals(const Rect.fromLTWH(0, 0, 1200, 800)));
    });

    test(
        'computeZoneRects divides horizontally on landscape screens '
        '(width >= height)', () {
      final rects = computeZoneRects(
        totalSize: const Size(1200, 800),
        isSplit: true,
        windowCount: 2,
        activeWindowId: 'win_1',
      );

      expect(rects.mode, equals(OverlayLayoutMode.splitHorizontal));
      expect(rects.zoneA, equals(const Rect.fromLTWH(0, 0, 600, 800)));
      expect(rects.zoneB, equals(const Rect.fromLTWH(600, 0, 600, 800)));
    });

    test(
        'computeZoneRects divides vertically on portrait screens '
        '(width < height)', () {
      final rects = computeZoneRects(
        totalSize: const Size(400, 800),
        isSplit: true,
        windowCount: 2,
        activeWindowId: 'win_1',
      );

      expect(rects.mode, equals(OverlayLayoutMode.splitVertical));
      expect(rects.zoneA, equals(const Rect.fromLTWH(0, 0, 400, 400)));
      expect(rects.zoneB, equals(const Rect.fromLTWH(0, 400, 400, 400)));
    });
  });

  group('StudioOverlayHost Widget Tests', () {
    testWidgets(
      'Mounts primary zone, adds secondary, and toggles split view',
      (final tester) async {
        final setupBloc = SetupBloc();
        final notificationBloc = NotificationBloc(setupBloc: setupBloc);
        final studioBloc = StudioBloc();

        addTearDown(() {
          notificationBloc.close();
          setupBloc.close();
          studioBloc.close();
        });

        await tester.binding.setSurfaceSize(const Size(1200, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: setupBloc),
              BlocProvider.value(value: notificationBloc),
              BlocProvider.value(value: studioBloc),
            ],
            child: MaterialApp(
              theme: StudioTheme.dark(),
              home: const Scaffold(
                body: StudioOverlayHost(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially 1 zone mounted
        expect(find.byKey(const ValueKey('hud_zone_win_1')), findsOneWidget);
        expect(find.byKey(const ValueKey('hud_zone_win_2')), findsNothing);
        expect(find.byType(ZoneFrame), findsOneWidget);

        // Add Scope B
        setupBloc.add(const AddVirtualWindow());
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('hud_zone_win_2')), findsOneWidget);
        expect(find.byType(ZoneFrame), findsNWidgets(2));

        // Switch to Split View
        studioBloc.add(const ToggleSplitView(enabled: true));
        await tester.pumpAndSettle();

        // Both frames visible and positioned side-by-side
        final zoneFrames = find.byType(ZoneFrame);
        expect(zoneFrames, findsNWidgets(2));

        final rectA = tester.getRect(zoneFrames.first);
        final rectB = tester.getRect(zoneFrames.last);

        // Horizontal split on 1200 width
        expect(rectA.left, equals(0));
        expect(rectA.width, equals(600));
        expect(rectB.left, equals(600));
        expect(rectB.width, equals(600));
      },
    );

    testWidgets(
      'Scope switching isolates notifications without persistence or leakage',
      (final tester) async {
        final setupBloc = SetupBloc();
        final notificationBloc = NotificationBloc(setupBloc: setupBloc);
        final studioBloc = StudioBloc();

        addTearDown(() {
          notificationBloc.close();
          setupBloc.close();
          studioBloc.close();
        });

        await tester.binding.setSurfaceSize(const Size(1200, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: setupBloc),
              BlocProvider.value(value: notificationBloc),
              BlocProvider.value(value: studioBloc),
            ],
            child: MaterialApp(
              theme: StudioTheme.dark(),
              home: const Scaffold(
                body: StudioOverlayHost(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Add Scope B
        setupBloc.add(const AddVirtualWindow());
        await tester.pumpAndSettle();

        // Switch active to win_1
        setupBloc.add(const SelectActiveWindow('win_1'));
        await tester.pumpAndSettle();

        // Fire notification into Scope A
        final win1 = setupBloc.getWindow('win_1')!;
        win1.controller.show(
          const AppNotification(
            title: 'Scope A Dedicated Notice',
            message: 'Active in Alpha',
            channelName: 'system',
            dismissDuration: Duration(seconds: 10),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Notice for Scope A is on screen
        final posNotifA1 =
            tester.getTopLeft(find.text('Scope A Dedicated Notice'));
        expect(posNotifA1.dx, greaterThanOrEqualTo(0));
        expect(posNotifA1.dx, lessThan(1200));

        // Switch to Scope B in Single Mode
        setupBloc.add(const SelectActiveWindow('win_2'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Notice for Scope A is held offscreen — NOT persisting on screen
        final posNotifA2 =
            tester.getTopLeft(find.text('Scope A Dedicated Notice'));
        expect(posNotifA2.dx, lessThan(-10000));

        // Fire notification into Scope B
        final win2 = setupBloc.getWindow('win_2')!;
        win2.controller.show(
          const AppNotification(
            title: 'Scope B Dedicated Notice',
            message: 'Active in Beta',
            channelName: 'orders',
            dismissDuration: Duration(seconds: 10),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Notice for Scope B is on screen
        final posNotifB =
            tester.getTopLeft(find.text('Scope B Dedicated Notice'));
        expect(posNotifB.dx, greaterThanOrEqualTo(0));
        expect(posNotifB.dx, lessThan(1200));

        // Switch back to Scope A: Scope A's notice returns to screen,
        // Scope B's notice is held offscreen
        setupBloc.add(const SelectActiveWindow('win_1'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final posNotifA3 =
            tester.getTopLeft(find.text('Scope A Dedicated Notice'));
        expect(posNotifA3.dx, greaterThanOrEqualTo(0));
        expect(posNotifA3.dx, lessThan(1200));

        final posNotifB2 =
            tester.getTopLeft(find.text('Scope B Dedicated Notice'));
        expect(posNotifB2.dx, lessThan(-10000));
      },
    );
  });
}
