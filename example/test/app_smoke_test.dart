import 'package:flutter/material.dart';
import 'package:flutter_notification_queue_example/main.dart';
import 'package:flutter_notification_queue_example/studio/widgets/overlay/studio_overlay_host.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sizes = [
    Size(1920, 1080),
    Size(1280, 800),
    Size(1024, 768),
    Size(800, 600),
    Size(400, 800),
  ];

  for (final size in sizes) {
    testWidgets('NFQStudioApp smoke test on $size', (final tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const NFQStudioApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // StudioOverlayHost is mounted in the widget tree
      expect(find.byType(StudioOverlayHost), findsOneWidget);

      // Try firing preview draft
      final fireDraft = find.text('FIRE DRAFT');
      final fireShort = find.text('FIRE');
      if (fireDraft.evaluate().isNotEmpty) {
        await tester.tap(fireDraft.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      } else if (fireShort.evaluate().isNotEmpty) {
        await tester.tap(fireShort.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Add Scope B if button is visible
      final addScope = find.text('+ Scope B');
      if (addScope.evaluate().isNotEmpty) {
        await tester.tap(addScope.first, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Switch to Workspace B (Beta) tab if found
        final win2Text = find.text('Workspace B (Beta)');
        if (win2Text.evaluate().isNotEmpty) {
          await tester.tap(win2Text.first, warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        }

        // Try toggling split view if button is found
        final splitBtn = find.text('Split View');
        if (splitBtn.evaluate().isNotEmpty) {
          await tester.tap(splitBtn.first, warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        }
      }
    });
  }
}
