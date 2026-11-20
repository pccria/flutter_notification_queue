import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_notification_queue_example/studio/bloc/notification_bloc.dart';
import 'package:flutter_notification_queue_example/studio/bloc/setup_bloc.dart';
import 'package:flutter_notification_queue_example/studio/bloc/studio_bloc.dart';
import 'package:flutter_notification_queue_example/studio/panels/configurator/scenarios_section.dart';
import 'package:flutter_notification_queue_example/studio/studio_theme.dart';
import 'package:flutter_notification_queue_example/studio/widgets/overlay/studio_overlay_host.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Studio Scenarios Comprehensive Execution Tests', () {
    testWidgets(
      'All 17 predefined demo scenarios execute cleanly without exceptions',
      (final tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final setupBloc = SetupBloc();
        final notificationBloc = NotificationBloc(setupBloc: setupBloc);
        final studioBloc = StudioBloc();
        addTearDown(() {
          setupBloc.close();
          notificationBloc.close();
          studioBloc.close();
        });

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
                body: Stack(
                  children: [
                    SingleChildScrollView(
                      padding: EdgeInsets.all(20),
                      child: ScenariosSection(),
                    ),
                    StudioOverlayHost(),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Find all scenario play icons
        final playIcons = find.byIcon(Icons.play_arrow_rounded);
        expect(playIcons, findsWidgets);
        final scenarioCount = playIcons.evaluate().length;
        expect(scenarioCount, equals(17));

        // Trigger each scenario sequentially and verify no assertion or crash
        for (var i = 0; i < scenarioCount; i++) {
          final target = playIcons.at(i);
          await tester.ensureVisible(target);
          await tester.tap(target, warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Advance time to allow queued timers to complete
        await tester.pump(const Duration(seconds: 10));
      },
    );

    testWidgets(
      'Scenario 17 (Multi-Scope HUD Isolation) splits view and isolates scopes',
      (final tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final setupBloc = SetupBloc();
        final studioBloc = StudioBloc();
        addTearDown(() {
          setupBloc.close();
          studioBloc.close();
        });

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: setupBloc),
              BlocProvider.value(value: studioBloc),
            ],
            child: MaterialApp(
              theme: StudioTheme.dark(),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: ScenariosSection(),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Locate Scenario 17 tile
        final scenario17Tile = find.text('Multi-Scope HUD Isolation');
        expect(scenario17Tile, findsOneWidget);

        await tester.ensureVisible(scenario17Tile);
        await tester.tap(scenario17Tile);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // SetupBloc now has 2 windows
        expect(setupBloc.state.windows.length, equals(2));
        expect(setupBloc.state.windows.containsKey('win_1'), isTrue);
        expect(setupBloc.state.windows.containsKey('win_2'), isTrue);

        // StudioBloc has isSplitView enabled
        expect(studioBloc.state.isSplitView, isTrue);
      },
    );
  });
}
