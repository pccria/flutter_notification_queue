import 'package:flutter/material.dart';
import 'package:flutter_notification_queue_example/studio/studio_theme.dart';
import 'package:flutter_notification_queue_example/studio/widgets/multi_tenant_stage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Studio Multi-Tenant Split-Viewport Stage Widget Tests', () {
    testWidgets(
      'renders dual workspaces side-by-side with window chrome and diagnostics',
      (final tester) async {
        await tester.binding.setSurfaceSize(const Size(1400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: StudioTheme.dark(),
            home: const Scaffold(
              body: MultiTenantSplitViewportStage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Header Title
        expect(
          find.text('MULTI-TENANT SPLIT-VIEWPORT STAGE'),
          findsOneWidget,
        );
        expect(find.text('1:1 COUPLING INVARIANT'), findsOneWidget);

        // Dual Workspaces
        expect(find.text('Workspace A (Alpha)'), findsOneWidget);
        expect(find.text('Workspace B (Beta)'), findsOneWidget);

        // Status Badges
        expect(find.text('1:1 ACTIVE'), findsNWidgets(2));
        expect(find.text('TICKING'), findsNWidgets(2));

        // Viewport Actions
        expect(find.text('+ Info'), findsNWidgets(2));
        expect(find.text('+ Alert'), findsNWidgets(2));
      },
    );

    testWidgets(
      'dispatching into Workspace A displays card and logs event in A only',
      (final tester) async {
        await tester.binding.setSurfaceSize(const Size(1400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: StudioTheme.dark(),
            home: const Scaffold(
              body: MultiTenantSplitViewportStage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap '+ Info' in Workspace A (first occurrence)
        final fireInfoA = find.text('+ Info').first;
        await tester.tap(fireInfoA);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Card should appear with title 'Build Complete'
        expect(find.text('Build Complete'), findsOneWidget);

        // Workspace A event stream should record events
        expect(find.text('1 events recorded'), findsOneWidget);
        expect(find.text('Awaiting notifications...'), findsOneWidget);
      },
    );

    testWidgets(
      'stasis toggle freezes Workspace A queue without affecting B',
      (final tester) async {
        await tester.binding.setSurfaceSize(const Size(1400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: StudioTheme.dark(),
            home: const Scaffold(
              body: MultiTenantSplitViewportStage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap 'Pause Stasis' in Workspace A
        final pauseA = find.text('Pause Stasis').first;
        await tester.tap(pauseA);
        await tester.pump();

        // Workspace A shows 'STASIS FROZEN' and button toggles to 'Resume'
        expect(find.text('STASIS FROZEN'), findsOneWidget);
        expect(find.text('TICKING'), findsOneWidget);
        expect(find.text('Resume'), findsOneWidget);

        // Resume Stasis in Workspace A
        await tester.tap(find.text('Resume'));
        await tester.pump();

        expect(find.text('TICKING'), findsNWidgets(2));
        expect(find.text('Pause Stasis'), findsNWidgets(2));
      },
    );

    testWidgets(
      'teardown unmounts Workspace B cleanly and allows instant remount',
      (final tester) async {
        await tester.binding.setSurfaceSize(const Size(1400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: StudioTheme.dark(),
            home: const Scaffold(
              body: MultiTenantSplitViewportStage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Red traffic light dots (close/unmount)
        final unmountButtons = find.byTooltip(
          'Teardown Viewport (Dispose Controller)',
        );
        expect(unmountButtons, findsNWidgets(2));

        // Unmount Workspace B (the second one)
        await tester.tap(unmountButtons.last);
        await tester.pumpAndSettle();

        // Workspace B is unmounted
        expect(find.text('UNMOUNTED'), findsOneWidget);
        expect(find.text('Workspace B (Beta) Unmounted'), findsOneWidget);
        expect(find.text('REMOUNT VIEWPORT'), findsOneWidget);

        // Workspace A is still 1:1 ACTIVE
        expect(find.text('1:1 ACTIVE'), findsOneWidget);

        // Remount Workspace B
        await tester.tap(find.text('REMOUNT VIEWPORT'));
        await tester.pumpAndSettle();

        expect(find.text('1:1 ACTIVE'), findsNWidgets(2));
        expect(find.text('Workspace B (Beta)'), findsOneWidget);
      },
    );

    testWidgets(
      'MultiTenantSplitViewportDialog displays modal dialog and '
      'dismisses cleanly',
      (final tester) async {
        await tester.binding.setSurfaceSize(const Size(1400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: StudioTheme.dark(),
            home: Scaffold(
              body: Builder(
                builder: (final context) => ElevatedButton(
                  onPressed: () => MultiTenantSplitViewportDialog.show(context),
                  child: const Text('OPEN DIALOG'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('OPEN DIALOG'));
        await tester.pumpAndSettle();

        expect(
          find.text('MULTI-TENANT SPLIT-VIEWPORT STAGE'),
          findsOneWidget,
        );

        // Close stage via close button in header
        final closeBtn = find.byTooltip('Close Split Stage');
        expect(closeBtn, findsOneWidget);
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();

        expect(
          find.text('MULTI-TENANT SPLIT-VIEWPORT STAGE'),
          findsNothing,
        );
      },
    );
  });
}
