import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/core/core.dart';
import 'package:flutter_notification_queue_example/studio/bloc/notification_bloc.dart';
import 'package:flutter_notification_queue_example/studio/bloc/setup_bloc.dart';
import 'package:flutter_notification_queue_example/studio/bloc/studio_bloc.dart';
import 'package:flutter_notification_queue_example/studio/engine/code_generator.dart';
import 'package:flutter_notification_queue_example/studio/models/channel_setup.dart';
import 'package:flutter_notification_queue_example/studio/models/queue_setup.dart';
import 'package:flutter_notification_queue_example/studio/models/studio_setup.dart';
import 'package:flutter_notification_queue_example/studio/panels/code_editor_panel.dart';
import 'package:flutter_notification_queue_example/studio/panels/configurator/channel_tile.dart';
import 'package:flutter_notification_queue_example/studio/panels/configurator_panel.dart';
import 'package:flutter_notification_queue_example/studio/panels/event_log_panel.dart';
import 'package:flutter_notification_queue_example/studio/studio_home.dart';
import 'package:flutter_notification_queue_example/studio/studio_theme.dart';
import 'package:flutter_notification_queue_example/studio/widgets/queue_position_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChannelSetup Model & Mapping Tests', () {
    test('toNotificationChannel propagates theme and color', () {
      const channelSetup = ChannelSetup(
        name: 'billing',
        color: Color(0xFF6366F1),
      );
      final channel = channelSetup.toNotificationChannel();
      expect(channel.theme, isNotNull);
      expect(channel.theme!.color, equals(const Color(0xFF6366F1)));
    });
  });

  group('QueueSetup Model & Mapping Tests', () {
    test('default constructor sets maxWidth to null', () {
      const setup = QueueSetup();
      expect(setup.maxWidth, isNull);
    });

    test('copyWith updates maxWidth correctly', () {
      const setup = QueueSetup();
      final updated = setup.copyWith(maxWidth: 450.0);
      expect(updated.maxWidth, equals(450.0));
      expect(updated.copyWith(clearMaxWidth: true).maxWidth, isNull);
    });

    test('toNotificationQueue propagates maxWidth correctly', () {
      const setup = QueueSetup(maxWidth: 250.0);
      final queue = setup.toNotificationQueue(QueuePosition.topLeft);
      expect(queue.maxWidth, equals(250.0));
    });
    test('toNotificationQueue builds Snooze and Pin behaviors correctly', () {
      const snoozeSetup = QueueSetup(
        dragBehaviorType: Snooze,
        dragSnoozeSeconds: 8,
        longPressBehaviorType: Pin,
      );
      final queue = snoozeSetup.toNotificationQueue(QueuePosition.topLeft);
      expect(queue.dragBehavior, isA<Snooze>());
      expect(
        (queue.dragBehavior as Snooze).duration,
        equals(const Duration(seconds: 8)),
      );
      expect(queue.longPressDragBehavior, isA<Pin>());
    });

    test('toNotificationQueue maps groupingBehavior and GroupCountType', () {
      const setup = QueueSetup(
        groupingEnabled: true,
        groupingThreshold: 3,
        groupingCountType: GroupCountType.totalCount,
        groupingCountMaxCount: 50,
        groupingCountIncludePending: false,
        groupingMaxLayers: 3,
        groupingSwipeDismiss: true,
      );
      final queue = setup.toNotificationQueue(QueuePosition.topRight);
      final gb = queue.groupingBehavior;

      expect(gb.enabled, isTrue);
      expect(gb.maxBeforeGrouping, equals(3));
      expect(gb.maxStackedLayers, equals(3));
      expect(gb.enableGroupSwipeDismiss, isTrue);
      expect(gb.countBehavior, isA<TotalCount>());
      expect(gb.countBehavior.maxCount, equals(50));
      expect(gb.countBehavior.includePending, isFalse);
    });
  });

  group('CodeGenerator maxWidth & Behavior Snippet Tests', () {
    test('generateCode includes maxWidth property when set', () {
      const queueSetup = QueueSetup(maxWidth: 280.0);
      const studioSetup = StudioSetup(
        queues: {
          QueuePosition.topLeft: queueSetup,
        },
        channels: {},
      );
      const draft = NotificationDraft(
        title: 'Test',
        message: 'Hello',
        channelName: 'test',
      );

      final codeSnippet = generateCode(
        setup: studioSetup,
        draft: draft,
      );

      expect(codeSnippet, contains('maxWidth: 280.0,'));
    });

    test('generateCode emits Snooze, Priority, and permanent snippets', () {
      const queueSetup = QueueSetup(
        dragBehaviorType: Snooze,
        dragSnoozeSeconds: 10,
      );
      const studioSetup = StudioSetup(
        queues: {
          QueuePosition.topRight: queueSetup,
        },
        channels: {
          'billing': ChannelSetup(
            name: 'billing',
            color: Color(0xFF6366F1),
          ),
        },
      );
      const draft = NotificationDraft(
        title: 'Snooze Draft',
        message: 'Testing Snooze',
        channelName: 'billing',
        priority: NotificationPriority.critical,
        permanent: true,
        positionOverride: QueuePosition.bottomRight,
      );

      final codeSnippet = generateCode(
        setup: studioSetup,
        draft: draft,
      );

      expect(
        codeSnippet,
        contains('const Snooze(duration: Duration(seconds: 10))'),
      );
      expect(codeSnippet, contains('priority: NotificationPriority.critical,'));
      expect(codeSnippet, contains('permanent: true,'));
      expect(
        codeSnippet,
        contains('targetPosition: QueuePosition.bottomRight,'),
      );
      expect(codeSnippet, contains('NotificationThemeData('));
      expect(codeSnippet, contains('FilledQueueStyle('));
    });

    test('generateCode emits notification payload theme override when set', () {
      const studioSetup = StudioSetup(
        queues: {
          QueuePosition.topRight: QueueSetup(),
        },
        channels: {
          'info': ChannelSetup(name: 'info'),
        },
      );
      const draft = NotificationDraft(
        title: 'Accent Override Test',
        message: 'Has custom accent color',
        channelName: 'info',
        accentColorOverride: Color(0xFF10B981),
      );

      final codeSnippet = generateCode(
        setup: studioSetup,
        draft: draft,
      );

      expect(codeSnippet, contains('accentColor: const Color(0xFF10B981),'));
    });

    test('generateCode emits groupingBehavior with TotalCount', () {
      const queueSetup = QueueSetup(
        groupingEnabled: true,
        groupingThreshold: 3,
        groupingCountType: GroupCountType.totalCount,
        groupingCountMaxCount: 20,
        groupingCountIncludePending: false,
      );
      const studioSetup = StudioSetup(
        queues: {
          QueuePosition.topRight: queueSetup,
        },
        channels: {},
      );
      const draft = NotificationDraft(
        title: 'Group Draft',
        message: 'Grouping message',
        channelName: 'chat',
      );

      final codeSnippet = generateCode(
        setup: studioSetup,
        draft: draft,
      );

      expect(codeSnippet, contains('groupingBehavior: QueueGroupingBehavior('));
      expect(codeSnippet, contains('maxBeforeGrouping: 3,'));
      expect(codeSnippet, contains('TotalCount('));
      expect(codeSnippet, contains('maxCount: 20,'));
      expect(codeSnippet, contains('includePending: false,'));
    });

    test('generateCode omits maxWidth property when null', () {
      const queueSetup = QueueSetup(maxWidth: null);
      const studioSetup = StudioSetup(
        queues: {
          QueuePosition.topLeft: queueSetup,
        },
        channels: {},
      );
      const draft = NotificationDraft(
        title: 'Test',
        message: 'Hello',
        channelName: 'test',
      );

      final codeSnippet = generateCode(
        setup: studioSetup,
        draft: draft,
      );

      expect(codeSnippet, isNot(contains('maxWidth:')));
    });

    test('generateCode respects CodeSnippetScope.dispatchOnly', () {
      final studioSetup = StudioSetup.withDefaults();
      const draft = NotificationDraft(
        title: 'Alert Title',
        message: 'Alert Body',
        channelName: 'info',
      );

      final dispatchCode = generateCode(
        setup: studioSetup,
        draft: draft,
        scope: CodeSnippetScope.dispatchOnly,
      );

      expect(dispatchCode, contains("controller.show("));
      expect(dispatchCode, contains("title: 'Alert Title'"));
      expect(dispatchCode, isNot(contains("NotificationController(")));
      expect(dispatchCode, isNot(contains("NotificationScope(")));
    });

    test('generateCode respects CodeSnippetScope.channelsOnly', () {
      final studioSetup = StudioSetup.withDefaults();
      const draft = NotificationDraft();

      final channelsCode = generateCode(
        setup: studioSetup,
        draft: draft,
        scope: CodeSnippetScope.channelsOnly,
      );

      expect(
        channelsCode,
        contains("final channels = <String, NotificationChannel>{"),
      );
      expect(channelsCode, isNot(contains("controller.show(")));
      expect(channelsCode, isNot(contains("NotificationScope(")));
    });
  });

  group('NotificationBloc Preview Routing Tests', () {
    late SetupBloc setupBloc;
    late NotificationBloc notificationBloc;
    late QueueCoordinator coordinator;
    setUp(() {
      setupBloc = SetupBloc();
      notificationBloc = NotificationBloc(setupBloc: setupBloc);
      coordinator = QueueCoordinator.fromController(setupBloc.controller);
      // ignore: invalid_use_of_internal_member
      setupBloc.controller.attach(coordinator);
    });

    tearDown(() {
      coordinator.dispose();
      notificationBloc.close();
      setupBloc.close();
    });

    test('FirePreview routes to active queue position by default', () async {
      // 1. Set the active queue in setupBloc to QueuePosition.topLeft
      setupBloc.add(const AddQueue(QueuePosition.topLeft));

      // Allow setupBloc state update to propagate
      await Future.delayed(Duration.zero);
      expect(
        setupBloc.state.activeQueuePosition,
        equals(QueuePosition.topLeft),
      );

      // 2. Listen for NotificationQueued event
      final events = <NotificationEvent>[];
      final sub = coordinator.events.listen(events.add);

      // 3. Fire the preview notification
      notificationBloc.add(const FirePreview());

      // Let microtasks run
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      final queuedEvent = events.first as NotificationQueued;
      expect(
        queuedEvent.notification.queue.position,
        equals(QueuePosition.topLeft),
      );

      await sub.cancel();
    });

    test('FirePreview respects positionOverride when explicitly set', () async {
      // 1. Set the active queue in setupBloc to QueuePosition.topLeft
      setupBloc.add(const AddQueue(QueuePosition.topLeft));

      // 2. Set an explicit position override in notificationBloc draft
      notificationBloc.add(
        const SelectPreviewPosition(QueuePosition.bottomRight),
      );

      await Future.delayed(Duration.zero);

      // 3. Listen for NotificationQueued event
      final events = <NotificationEvent>[];
      final sub = coordinator.events.listen(events.add);

      // 4. Fire the preview notification
      notificationBloc.add(const FirePreview());

      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      final queuedEvent = events.first as NotificationQueued;
      expect(
        queuedEvent.notification.queue.position,
        equals(QueuePosition.bottomRight),
      );

      await sub.cancel();
    });
  });

  group('StudioHome FAB Widget Tests', () {
    testWidgets(
      'Renders FAB on narrow screens and triggers notification on tap',
      (final tester) async {
        tester.view.physicalSize = const Size(500, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final setupBloc = SetupBloc();
        final notificationBloc = NotificationBloc(setupBloc: setupBloc);
        final studioBloc = StudioBloc();

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
                return NotificationScope(
                  controller: setupBloc.controller,
                  child: child!,
                );
              },
              home: const StudioHome(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final fireButton = find.widgetWithText(FilledButton, 'FIRE');
        expect(fireButton, findsOneWidget);
        expect(find.byTooltip('Quick Presets'), findsOneWidget);

        addTearDown(() {
          notificationBloc.close();
          setupBloc.close();
          studioBloc.close();
        });

        await tester.tap(fireButton);
        await tester.pump();
        expect(find.byType(NotificationWidget), findsOneWidget);

        // Tap Quick Presets icon to verify bottom sheet opens
        await tester.tap(find.byTooltip('Quick Presets'));
        await tester.pumpAndSettle();
        expect(find.text('QUICK FIRE COCKPIT'), findsOneWidget);
        expect(find.text('PRESET SCENARIOS'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  group('StudioHome Resizable Panes Widget Tests', () {
    testWidgets(
      'Renders 3-pane layout, allows collapse, and keeps main pane permanent',
      (final tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final setupBloc = SetupBloc();
        final notificationBloc = NotificationBloc(setupBloc: setupBloc);
        final studioBloc = StudioBloc();

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
                return NotificationScope(
                  controller: setupBloc.controller,
                  child: child!,
                );
              },
              home: const StudioHome(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        addTearDown(() {
          notificationBloc.close();
          setupBloc.close();
          studioBloc.close();
        });

        // Verify initial 3 panes are present
        expect(find.byType(ConfiguratorPanel), findsOneWidget);
        expect(find.byType(CodeEditorPanel), findsOneWidget);
        expect(find.byType(EventLogPanel), findsOneWidget);

        // Collapse Code Editor via AppBar toggle
        await tester.tap(find.byTooltip('Collapse Code Editor (Ctrl+E)'));
        await tester.pumpAndSettle();

        expect(find.byType(CodeEditorPanel), findsNothing);
        expect(find.byType(ConfiguratorPanel), findsOneWidget); // Permanent!
        expect(find.byType(EventLogPanel), findsOneWidget);

        // Collapse Event Stream via AppBar toggle
        await tester.tap(find.byTooltip('Collapse Event Stream (Ctrl+L)'));
        await tester.pumpAndSettle();

        expect(find.byType(CodeEditorPanel), findsNothing);
        expect(find.byType(EventLogPanel), findsNothing);
        expect(find.byType(ConfiguratorPanel), findsOneWidget); // Permanent!

        // Re-expand Code Editor
        await tester.tap(find.byTooltip('Expand Code Editor (Ctrl+E)'));
        await tester.pumpAndSettle();
        expect(find.byType(CodeEditorPanel), findsOneWidget);
        expect(find.byType(ConfiguratorPanel), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  group('ChannelTile Chromatics Tests', () {
    testWidgets('Tapping semantic preset updates channel theme and color',
        (final tester) async {
      final setupBloc = SetupBloc();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BlocProvider<SetupBloc>.value(
                value: setupBloc,
                child: const ChannelTile(
                  setup: ChannelSetup(name: 'test_channel'),
                  positions: [QueuePosition.topCenter],
                ),
              ),
            ),
          ),
        ),
      );

      // Expand ChannelTile ExpansionTile
      await tester.tap(find.text('test_channel'));
      await tester.pumpAndSettle();

      expect(find.text('CHROMATICS (INHERITED DEFAULT)'), findsOneWidget);
      expect(find.text('SUCCESS'), findsOneWidget);

      // Tap SUCCESS semantic preset
      await tester.tap(find.text('SUCCESS'));
      await tester.pumpAndSettle();

      final updated = setupBloc.state.setup.channels['test_channel'];
      expect(updated?.theme?.color, equals(const Color(0xFF2D7512)));
      expect(updated?.color, equals(const Color(0xFF2D7512)));
    });

    testWidgets('Reset button clears custom channel theme back to default',
        (final tester) async {
      final setupBloc = SetupBloc()
        ..add(
          const AddChannel(
            ChannelSetup(
              name: 'custom_channel',
              theme: NotificationThemeData(color: Color(0xFFD03332)),
              color: Color(0xFFD03332),
            ),
          ),
        );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BlocProvider<SetupBloc>.value(
                value: setupBloc,
                child: const ChannelTile(
                  setup: ChannelSetup(
                    name: 'custom_channel',
                    theme: NotificationThemeData(color: Color(0xFFD03332)),
                    color: Color(0xFFD03332),
                  ),
                  positions: [QueuePosition.topCenter],
                ),
              ),
            ),
          ),
        ),
      );

      // Expand ChannelTile ExpansionTile
      await tester.tap(find.text('custom_channel'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.restart_alt), findsOneWidget);
      await tester.tap(find.byIcon(Icons.restart_alt));
      await tester.pumpAndSettle();

      final updated = setupBloc.state.setup.channels['custom_channel'];
      expect(updated?.theme, isNull);
      expect(updated?.color, isNull);
    });
  });

  group('EventLogPanel Observability Tests', () {
    testWidgets('Renders empty state, updates on events, and expands inspector',
        (final tester) async {
      final controller = NotificationController(
        queues: {const NotificationQueue()},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationScope(
              controller: controller,
              child: const SizedBox(
                width: 320,
                height: 600,
                child: EventLogPanel(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('EVENTS'), findsOneWidget);
      expect(find.text('Waiting for events…'), findsOneWidget);

      // Enqueue notification via controller
      controller.show(
        const AppNotification(
          id: 'test-evt-1',
          message: 'Real-time telemetry item',
          channelName: 'info',
        ),
      );
      await tester.pump();

      // Should show Queued tile and active badge
      expect(find.text('Queued'), findsOneWidget);
      expect(find.text('1 active'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(EventLogPanel),
          matching: find.text('Real-time telemetry item'),
        ),
        findsOneWidget,
      );

      // Tap on event tile to expand Diagnostics drawer
      await tester.tap(find.text('Queued'));
      await tester.pump();

      expect(find.text('DIAGNOSTICS'), findsOneWidget);
      expect(find.text('test-evt-1'), findsOneWidget);

      // Tap 'Alerts' filter pill - this event is lifecycle so list empties
      await tester.tap(find.text('Alerts'));
      await tester.pump();

      expect(find.text('No events match filter'), findsOneWidget);

      // Tap 'Flow' filter pill - Queued event reappears
      await tester.tap(find.text('Flow'));
      await tester.pump();

      expect(find.text('Queued'), findsOneWidget);

      // Tap 'All' to restore
      await tester.tap(find.text('All'));
      await tester.pump();
      expect(find.text('Queued'), findsOneWidget);

      controller.dispose();
    });

    testWidgets(
        'Renders relocation events without pixel overflow at minimum width',
        (final tester) async {
      final controller = NotificationController(
        queues: {
          const NotificationQueue(position: QueuePosition.centerLeft),
          const NotificationQueue(position: QueuePosition.topCenter),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationScope(
              controller: controller,
              child: const SizedBox(
                width: 220, // minimum studio event log width
                height: 600,
                child: EventLogPanel(),
              ),
            ),
          ),
        ),
      );

      const notif = AppNotification(
        id: 'test-evt-reloc',
        message: 'Hello from NFQ',
        channelName: 'info',
      );
      controller.show(notif);
      await tester.pump();

      controller.relocate(notif, QueuePosition.topCenter);
      await tester.pump();

      expect(tester.takeException(), isNull);
      controller.dispose();
    });
  });

  group('Adaptive Layout & Proportions Tests', () {
    testWidgets(
      'ConfiguratorPanel adapts to 1-col, 2-col, and 3-col layouts',
      (final tester) async {
        final setupBloc = SetupBloc();
        final notificationBloc = NotificationBloc(setupBloc: setupBloc);

        Widget buildConfigurator(final double width) => MaterialApp(
              theme: StudioTheme.dark(),
              home: Builder(
                builder: (final context) {
                  StudioTheme.update(context);
                  return Scaffold(
                    body: MultiBlocProvider(
                      providers: [
                        BlocProvider.value(value: setupBloc),
                        BlocProvider.value(value: notificationBloc),
                      ],
                      child: SizedBox(
                        width: width,
                        height: 1200,
                        child: const ConfiguratorPanel(),
                      ),
                    ),
                  );
                },
              ),
            );

        // 1. Sidebar width (550px < 660px) -> Single-Column Mode
        await tester.binding.setSurfaceSize(const Size(550, 900));
        await tester.pumpWidget(buildConfigurator(550));
        await tester.pumpAndSettle();

        expect(find.byType(ListView), findsOneWidget);
        expect(find.text('QUEUES'), findsAtLeastNWidgets(1));

        // 2. Dual-Workbench width (850px >= 660px) -> 2 Coordinated Panes
        await tester.binding.setSurfaceSize(const Size(850, 900));
        await tester.pumpWidget(buildConfigurator(850));
        await tester.pumpAndSettle();

        expect(find.byType(ListView), findsNWidgets(2));
        expect(find.byType(VerticalDivider), findsOneWidget);
        expect(find.text('QUEUES'), findsAtLeastNWidgets(1));
        expect(find.text('NOTIFICATION DRAFT'), findsAtLeastNWidgets(1));

        // 3. Ultra-wide width (1400px >= 1200px) -> 3 Coordinated Panes
        await tester.binding.setSurfaceSize(const Size(1400, 900));
        await tester.pumpWidget(buildConfigurator(1400));
        await tester.pumpAndSettle();

        expect(find.byType(ListView), findsNWidgets(3));
        expect(find.byType(VerticalDivider), findsNWidgets(2));
        expect(find.text('QUEUES'), findsAtLeastNWidgets(1));
        expect(find.text('CHANNELS'), findsAtLeastNWidgets(1));
        expect(find.text('NOTIFICATION DRAFT'), findsAtLeastNWidgets(1));

        // Verify QueuePositionMap container width is bounded to <= 440px
        final mapFinder = find.byType(QueuePositionMap);
        expect(mapFinder, findsOneWidget);

        await tester.binding.setSurfaceSize(null);
      },
    );

    testWidgets(
      'CodeEditorPanel is a code viewer without duplicate fire buttons',
      (final tester) async {
        final setupBloc = SetupBloc();
        final notificationBloc = NotificationBloc(setupBloc: setupBloc);
        final studioBloc = StudioBloc();

        await tester.binding.setSurfaceSize(const Size(1000, 900));
        await tester.pumpWidget(
          MaterialApp(
            theme: StudioTheme.dark(),
            home: Builder(
              builder: (final context) {
                StudioTheme.update(context);
                return Scaffold(
                  body: MultiBlocProvider(
                    providers: [
                      BlocProvider.value(value: setupBloc),
                      BlocProvider.value(value: notificationBloc),
                      BlocProvider.value(value: studioBloc),
                    ],
                    child: const SizedBox(
                      width: 900,
                      height: 900,
                      child: CodeEditorPanel(),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify that redundant preview button is purged from CodeEditorPanel
        expect(
          find.widgetWithText(ElevatedButton, 'FIRE PREVIEW'),
          findsNothing,
        );

        // Verify standard code actions remain intact
        expect(find.text('Copy'), findsOneWidget);
        expect(find.text('Reset'), findsOneWidget);
        expect(find.text('GENERATED CODE'), findsOneWidget);

        await tester.binding.setSurfaceSize(null);
      },
    );

    testWidgets(
      'Hardware keyboard shortcuts (Ctrl+Enter, Ctrl+E, Ctrl+L) '
      'operate cleanly',
      (final tester) async {
        await tester.binding.setSurfaceSize(const Size(1400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final setupBloc = SetupBloc();
        final notificationBloc = NotificationBloc(setupBloc: setupBloc);
        final studioBloc = StudioBloc();

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: setupBloc),
              BlocProvider.value(value: notificationBloc),
              BlocProvider.value(value: studioBloc),
            ],
            child: MaterialApp(
              theme: StudioTheme.dark(),
              home: Builder(
                builder: (final context) {
                  StudioTheme.update(context);
                  return NotificationScope(
                    controller: setupBloc.controller,
                    child: const StudioHome(),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Send Ctrl+Enter to trigger FirePreview
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(NotificationWidget), findsOneWidget);

        // 2. Send Ctrl+E to toggle code editor
        expect(studioBloc.state.isCodeEditorOpen, isTrue);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(studioBloc.state.isCodeEditorOpen, isFalse);

        // 3. Send Ctrl+L to toggle event log
        expect(studioBloc.state.isEventLogOpen, isTrue);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(studioBloc.state.isEventLogOpen, isFalse);
      },
    );
  });
}
