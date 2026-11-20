import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue_example/studio/bloc/notification_bloc.dart';
import 'package:flutter_notification_queue_example/studio/bloc/setup_bloc.dart';
import 'package:flutter_notification_queue_example/studio/bloc/studio_bloc.dart';
import 'package:flutter_notification_queue_example/studio/engine/code_generator.dart';
import 'package:flutter_notification_queue_example/studio/models/channel_setup.dart';
import 'package:flutter_notification_queue_example/studio/models/queue_setup.dart';
import 'package:flutter_notification_queue_example/studio/models/studio_setup.dart';
import 'package:flutter_notification_queue_example/studio/studio_theme.dart';
import 'package:flutter_notification_queue_example/studio/widgets/overlay/studio_overlay_host.dart';
import 'package:flutter_notification_queue_example/studio/widgets/quick_fire_cockpit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Studio Controls & Interactivity Tests', () {
    testWidgets('QuickFireCockpit fires presets and controls scopes',
        (final tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final setupBloc = SetupBloc();
      final notifBloc = NotificationBloc(setupBloc: setupBloc);
      final studioBloc = StudioBloc();
      addTearDown(() {
        setupBloc.close();
        notifBloc.close();
        studioBloc.close();
      });

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: setupBloc),
            BlocProvider.value(value: notifBloc),
            BlocProvider.value(value: studioBloc),
          ],
          child: MaterialApp(
            theme: StudioTheme.dark(),
            home: const Scaffold(
              body: Stack(
                children: [
                  Column(
                    children: [
                      QuickFireCockpit(),
                      Expanded(child: SizedBox.expand()),
                    ],
                  ),
                  StudioOverlayHost(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Verify Scope A is default
      expect(setupBloc.state.windows.length, equals(1));
      expect(setupBloc.state.activeWindowId, equals('win_1'));

      // 2. Fire single presets: Info, Success, Warning, Critical, Pinned
      for (final label in [
        'Info',
        'Success',
        'Warning',
        'Critical',
        'Pinned',
      ]) {
        final chip = find.text(label);
        expect(chip, findsOneWidget);
        await tester.tap(chip);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
      }

      // Verify notifications exist in active controller
      final ctrl = setupBloc.state.controller;
      expect(ctrl.activeNotifications.isNotEmpty, isTrue);

      // 3. Fire Burst 3x
      final burstChip = find.text('Burst 3x');
      expect(burstChip, findsOneWidget);
      await tester.tap(burstChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 4. Fire Group 4x
      final groupChip = find.text('Group 4x');
      expect(groupChip, findsOneWidget);
      await tester.tap(groupChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 5. Add Scope B via Cockpit Chip
      final addScopeB = find.text('+ Scope B');
      expect(addScopeB, findsOneWidget);
      await tester.tap(addScopeB);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(setupBloc.state.windows.length, equals(2));
      expect(studioBloc.state.isSplitView, isTrue);

      // 6. Close Scope B via Cockpit Chip (scroll cockpit horizontally)
      final cockpitScrollable = find.descendant(
        of: find.byType(QuickFireCockpit),
        matching: find.byType(Scrollable),
      );
      await tester.drag(cockpitScrollable, const Offset(-600, 0));
      await tester.pumpAndSettle();

      final closeScopeBFinder = find.text('Close Scope B');
      expect(closeScopeBFinder, findsOneWidget);
      await tester.tap(closeScopeBFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(setupBloc.state.windows.length, equals(1));
      expect(studioBloc.state.isSplitView, isFalse);
    });

    test('SetupBloc Queue and Channel CRUD operations maintain invariants',
        () async {
      final bloc = SetupBloc();
      addTearDown(bloc.close);

      // Add Queue
      bloc.add(
        const AddQueue(
          QueuePosition.bottomRight,
          QueueSetup(
            maxStackSize: 4,
            spacing: 12.0,
          ),
        ),
      );
      await pumpEventQueue();

      expect(
        bloc.state.setup.queues.containsKey(QueuePosition.bottomRight),
        isTrue,
      );
      expect(
        bloc.state.setup.queues[QueuePosition.bottomRight]?.maxStackSize,
        equals(4),
      );

      // Update Queue
      bloc.add(
        const UpdateQueue(
          QueuePosition.bottomRight,
          QueueSetup(
            maxStackSize: 7,
            spacing: 14.0,
          ),
        ),
      );
      await pumpEventQueue();

      expect(
        bloc.state.setup.queues[QueuePosition.bottomRight]?.maxStackSize,
        equals(7),
      );

      // Add Channel
      bloc.add(
        const AddChannel(
          ChannelSetup(
            name: 'telemetry',
            description: 'Live sensor telemetry',
            color: Color(0xFF10B981),
            position: QueuePosition.bottomRight,
          ),
        ),
      );
      await pumpEventQueue();

      expect(bloc.state.setup.channels.containsKey('telemetry'), isTrue);

      // Remove Channel
      bloc.add(const RemoveChannel('telemetry'));
      await pumpEventQueue();

      expect(bloc.state.setup.channels.containsKey('telemetry'), isFalse);

      // Remove Queue
      bloc.add(const RemoveQueue(QueuePosition.bottomRight));
      await pumpEventQueue();

      expect(
        bloc.state.setup.queues.containsKey(QueuePosition.bottomRight),
        isFalse,
      );
    });

    test('StudioBloc pane and view toggles operate smoothly', () async {
      final bloc = StudioBloc();
      addTearDown(bloc.close);

      expect(bloc.state.isCodeEditorOpen, isTrue);
      expect(bloc.state.isEventLogOpen, isTrue);
      expect(bloc.state.isSplitView, isFalse);

      bloc.add(const ToggleCodeEditor());
      await pumpEventQueue();
      expect(bloc.state.isCodeEditorOpen, isFalse);

      bloc.add(const ToggleEventLog());
      await pumpEventQueue();
      expect(bloc.state.isEventLogOpen, isFalse);

      bloc.add(const ToggleSplitView(enabled: true));
      await pumpEventQueue();
      expect(bloc.state.isSplitView, isTrue);

      bloc.add(const ToggleTheme());
      await pumpEventQueue();
      expect(bloc.state.themeMode, equals(ThemeMode.light));

      bloc.add(const ToggleTheme());
      await pumpEventQueue();
      expect(bloc.state.themeMode, equals(ThemeMode.dark));
    });

    test('CodeGenerator generates compliant code for all snippet scopes', () {
      final setup = StudioSetup.withDefaults();
      const draft = NotificationDraft(
        title: 'Validation Ping',
        message: 'Engine test payload',
        channelName: 'info',
        priority: NotificationPriority.high,
      );

      for (final scope in CodeSnippetScope.values) {
        final code = generateCode(
          setup: setup,
          draft: draft,
          scope: scope,
        );

        expect(code, isNotEmpty);
        expect(code, isNot(contains('null')));
      }
    });
  });
}
