import 'package:flutter/material.dart';
import 'package:flutter_notification_queue_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('NFQStudioApp full lifecycle smoke test across screen sizes',
      (final tester) async {
    final sizes = [
      const Size(1920, 1080),
      const Size(1280, 800),
      const Size(1024, 768),
      const Size(800, 600),
      const Size(400, 800),
    ];

    for (final size in sizes) {
      debugPrint('=== TESTING SIZE: $size ===');
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const NFQStudioApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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

      // Try toggling STAGE if button exists
      final stageButton = find.widgetWithText(InkWell, 'STAGE');
      if (stageButton.evaluate().isNotEmpty) {
        await tester.tap(stageButton.first, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // In stage, check for + Win 2
        final addWin2 = find.text('+ Win 2');
        if (addWin2.evaluate().isNotEmpty) {
          await tester.tap(addWin2.first, warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Try clicking Workspace B (Beta) to focus Window 2
          final win2Text = find.text('Workspace B (Beta)');
          if (win2Text.evaluate().isNotEmpty) {
            await tester.tap(win2Text.first, warnIfMissed: false);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          }
        }
      }

      // Reset widget tree for next size
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
