import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_notification_queue_example/studio/bloc/notification_bloc.dart';
import 'package:flutter_notification_queue_example/studio/bloc/setup_bloc.dart';
import 'package:flutter_notification_queue_example/studio/bloc/studio_bloc.dart';
import 'package:flutter_notification_queue_example/studio/panels/configurator_panel.dart';
import 'package:flutter_notification_queue_example/studio/studio_theme.dart';
import 'package:flutter_notification_queue_example/studio/widgets/quick_fire_cockpit.dart';
import 'package:flutter_notification_queue_example/studio/widgets/virtual_stage_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Virtual Window Stage Architecture Tests', () {
    test('SetupBloc initializes with primary window and allows multi-window',
        () async {
      final setupBloc = SetupBloc();
      addTearDown(setupBloc.close);

      expect(setupBloc.state.windows.length, equals(1));
      expect(setupBloc.state.activeWindowId, equals('win_1'));
      expect(setupBloc.state.activeWindow.title, equals('Workspace A (Alpha)'));

      // Add secondary window
      setupBloc.add(const AddVirtualWindow());
      await pumpEventQueue();
      expect(setupBloc.state.windows.length, equals(2));
      expect(setupBloc.state.windows.containsKey('win_2'), isTrue);
      expect(setupBloc.state.activeWindowId, equals('win_2'));

      // Switch active window back to win_1
      setupBloc.add(const SelectActiveWindow('win_1'));
      await pumpEventQueue();
      expect(setupBloc.state.activeWindowId, equals('win_1'));

      // Toggle stasis on win_2
      setupBloc.add(const ToggleWindowStasis('win_2'));
      await pumpEventQueue();
      expect(setupBloc.state.windows['win_2']!.isPaused, isTrue);
      expect(setupBloc.state.windows['win_1']!.isPaused, isFalse);

      // Remove win_2
      setupBloc.add(const RemoveVirtualWindow('win_2'));
      await pumpEventQueue();
      expect(setupBloc.state.windows.length, equals(1));
      expect(setupBloc.state.activeWindowId, equals('win_1'));
    });

    testWidgets(
      'VirtualStageCanvas renders primary window, adds secondary, and '
      'switches focus',
      (final tester) async {
        final setupBloc = SetupBloc();
        final notificationBloc = NotificationBloc(setupBloc: setupBloc);
        final studioBloc = StudioBloc();

        addTearDown(() {
          notificationBloc.close();
          setupBloc.close();
          studioBloc.close();
        });

        await tester.binding.setSurfaceSize(const Size(1400, 900));
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
              builder: (final context, final child) {
                StudioTheme.update(context);
                return child!;
              },
              home: const Scaffold(
                body: VirtualStageCanvas(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initial State: 1 Window rendered
        expect(find.text('1 WIN'), findsOneWidget);
        expect(find.text('Workspace A (Alpha)'), findsWidgets);
        expect(find.text('EDITING'), findsOneWidget);
        expect(find.text('+ Win 2'), findsOneWidget);

        // 2. Tap '+ Win 2' to add secondary window
        await tester.tap(find.text('+ Win 2'));
        await tester.pumpAndSettle();

        expect(find.text('2 WINS'), findsOneWidget);
        expect(find.text('Workspace B (Beta)'), findsWidgets);

        // 3. Focus Window 1
        final win1Title = find.text('Workspace A (Alpha)').first;
        await tester.tap(win1Title);
        await tester.pumpAndSettle();

        expect(setupBloc.state.activeWindowId, equals('win_1'));

        // 4. Tap Local Ping in active window
        final pingBtn = find.text('Ping').first;
        await tester.tap(pingBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining('Ping from Workspace A'), findsOneWidget);
      },
    );

    testWidgets(
      'QuickFireCockpit displays target selector when 2 windows exist',
      (final tester) async {
        final setupBloc = SetupBloc();
        final notificationBloc = NotificationBloc(setupBloc: setupBloc);
        final studioBloc = StudioBloc();

        addTearDown(() {
          notificationBloc.close();
          setupBloc.close();
          studioBloc.close();
        });

        await tester.binding.setSurfaceSize(const Size(1400, 900));
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
              builder: (final context, final child) {
                StudioTheme.update(context);
                return child!;
              },
              home: const Scaffold(
                body: Column(
                  children: [
                    QuickFireCockpit(),
                    Expanded(child: VirtualStageCanvas()),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially 1 window: no target dropdown, but '+ Window' is present
        expect(find.text('+ Window'), findsOneWidget);

        // Add secondary window via '+ Window' chip
        await tester.tap(find.text('+ Window'));
        await tester.pumpAndSettle();

        // Target dropdown should be present
        expect(find.textContaining('Target:'), findsOneWidget);
        expect(find.text('Close Win 2', skipOffstage: false), findsOneWidget);

        // Open target selector popup
        await tester.tap(find.textContaining('Target:'));
        await tester.pumpAndSettle();

        expect(find.text('Broadcast to Both (1 & 2)'), findsOneWidget);
        expect(find.text('Window 1 (Primary)'), findsWidgets);
        expect(find.text('Window 2 (Secondary)'), findsWidgets);
      },
    );

    testWidgets(
      'ConfiguratorPanel workspace switcher and stage tabs switch active '
      'window',
      (final tester) async {
        final setupBloc = SetupBloc();
        final notificationBloc = NotificationBloc(setupBloc: setupBloc);
        final studioBloc = StudioBloc();

        addTearDown(() {
          notificationBloc.close();
          setupBloc.close();
          studioBloc.close();
        });

        await tester.binding.setSurfaceSize(const Size(1400, 900));
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
              builder: (final context, final child) {
                StudioTheme.update(context);
                return child!;
              },
              home: const Scaffold(
                body: Row(
                  children: [
                    SizedBox(width: 450, child: ConfiguratorPanel()),
                    Expanded(child: VirtualStageCanvas()),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially 1 window: no workspace switcher banner
        expect(
          find.text('TARGET VIEWPORT CONFIGURATION'),
          findsNothing,
        );

        // Add secondary window via stage header
        await tester.tap(find.text('+ Win 2'));
        await tester.pumpAndSettle();

        // Workspace switcher should now be visible in ConfiguratorPanel
        expect(
          find.text('TARGET VIEWPORT CONFIGURATION'),
          findsOneWidget,
        );
        expect(setupBloc.state.activeWindowId, equals('win_2'));

        // Stage header shows Win 1 and Win 2 tabs
        expect(find.text('Win 1'), findsOneWidget);
        expect(find.text('Win 2'), findsOneWidget);

        // Switch to Win 1 via Stage header tab
        await tester.tap(find.text('Win 1'));
        await tester.pumpAndSettle();
        expect(setupBloc.state.activeWindowId, equals('win_1'));

        // Switch back to Win 2 via ConfiguratorPanel workspace switcher
        final win2WorkspaceTab =
            find.widgetWithText(InkWell, 'Workspace B (Beta)');
        await tester.tap(win2WorkspaceTab.first);
        await tester.pumpAndSettle();
        expect(setupBloc.state.activeWindowId, equals('win_2'));
      },
    );

    testWidgets(
      'Virtual window stasis and unmount/remount controls operate '
      'independently',
      (final tester) async {
        final setupBloc = SetupBloc();
        final notificationBloc = NotificationBloc(setupBloc: setupBloc);
        final studioBloc = StudioBloc();

        addTearDown(() {
          notificationBloc.close();
          setupBloc.close();
          studioBloc.close();
        });

        await tester.binding.setSurfaceSize(const Size(1400, 900));
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
              builder: (final context, final child) {
                StudioTheme.update(context);
                return child!;
              },
              home: const Scaffold(
                body: VirtualStageCanvas(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Add Window 2
        await tester.tap(find.text('+ Win 2'));
        await tester.pumpAndSettle();

        // 1. Stasis test on Window 2
        final pauseButtons = find.byTooltip('Pause Queue Timers (Stasis)');
        expect(pauseButtons, findsNWidgets(2));

        // Tap pause on Window 2 (the second one)
        await tester.tap(pauseButtons.last);
        await tester.pumpAndSettle();

        expect(setupBloc.state.windows['win_2']!.isPaused, isTrue);
        expect(setupBloc.state.windows['win_1']!.isPaused, isFalse);

        // Resume Window 2
        final resumeButton = find.byTooltip('Resume Queue Timers');
        expect(resumeButton, findsOneWidget);
        await tester.tap(resumeButton);
        await tester.pumpAndSettle();

        expect(setupBloc.state.windows['win_2']!.isPaused, isFalse);

        // 2. Unmount test on Window 1
        final unmountButton = find.byTooltip('Unmount Surface');
        expect(unmountButton, findsOneWidget);
        await tester.tap(unmountButton);
        await tester.pumpAndSettle();

        expect(setupBloc.state.windows['win_1']!.isMounted, isFalse);
        expect(
          find.text('Workspace A (Alpha) Unmounted'),
          findsOneWidget,
        );

        // Remount Window 1
        await tester.tap(find.text('Remount Surface'));
        await tester.pumpAndSettle();

        expect(setupBloc.state.windows['win_1']!.isMounted, isTrue);
        expect(
          find.text('Workspace A (Alpha) Unmounted'),
          findsNothing,
        );
      },
    );
  });
}
