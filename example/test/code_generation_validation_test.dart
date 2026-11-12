import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue_example/'
    'studio/bloc/notification_bloc.dart';
import 'package:flutter_notification_queue_example/'
    'studio/engine/code_generator.dart';
import 'package:flutter_notification_queue_example/'
    'studio/models/channel_setup.dart';
import 'package:flutter_notification_queue_example/'
    'studio/models/queue_setup.dart';
import 'package:flutter_notification_queue_example/'
    'studio/models/studio_setup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CodeGenerator - Scopes & Version Headers', () {
    test(
        'fullSetup includes version header, controller, and scope instructions',
        () {
      final setup = StudioSetup.withDefaults();
      const draft = NotificationDraft(
        title: 'Release Notification',
        message: 'Ready for release',
        channelName: 'info',
      );

      final code = generateCode(
        setup: setup,
        draft: draft,
        scope: CodeSnippetScope.fullSetup,
      );

      expect(
        code,
        contains(
          '// NFQ Studio — Generated Code (v${NotificationController.version})',
        ),
      );
      expect(code, contains('final controller = NotificationController('));
      expect(code, contains('queues: {'));
      expect(code, contains('channels: {'));
      expect(code, contains('NotificationScope('));
      expect(code, contains('controller.show('));
      expect(code, contains("title: 'Release Notification'"));
    });

    test('fullSetup emits maxHistoryEntries when non-zero and omits when zero',
        () {
      const zeroHistorySetup = StudioSetup(
        queues: {},
        channels: {},
        maxHistoryEntries: 0,
      );
      const withHistorySetup = StudioSetup(
        queues: {},
        channels: {},
        maxHistoryEntries: 100,
      );
      const draft = NotificationDraft();

      final codeZero = generateCode(
        setup: zeroHistorySetup,
        draft: draft,
        scope: CodeSnippetScope.fullSetup,
      );
      final codeWith = generateCode(
        setup: withHistorySetup,
        draft: draft,
        scope: CodeSnippetScope.fullSetup,
      );

      expect(codeZero, isNot(contains('maxHistoryEntries:')));
      expect(codeWith, contains('maxHistoryEntries: 100,'));
    });

    test('dispatchOnly emits only controller.show call', () {
      final setup = StudioSetup.withDefaults();
      const draft = NotificationDraft(
        title: 'Only Dispatch',
        message: 'Testing dispatchOnly scope',
        channelName: 'alerts',
      );

      final code = generateCode(
        setup: setup,
        draft: draft,
        scope: CodeSnippetScope.dispatchOnly,
      );

      expect(code, startsWith('controller.show('));
      expect(code, contains("title: 'Only Dispatch'"));
      expect(code, isNot(contains('NotificationController(')));
      expect(code, isNot(contains('NotificationScope(')));
      expect(code, isNot(contains('final channels =')));
      expect(code, isNot(contains('final queues =')));
    });

    test('channelsOnly emits Set of NotificationChannel without controller',
        () {
      const setup = StudioSetup(
        queues: {},
        channels: {
          'chat': ChannelSetup(name: 'chat', description: 'Chat messages'),
        },
      );
      const draft = NotificationDraft();

      final code = generateCode(
        setup: setup,
        draft: draft,
        scope: CodeSnippetScope.channelsOnly,
      );

      expect(code, contains('final channels = <NotificationChannel>{'));
      expect(code, contains("name: 'chat'"));
      expect(code, contains("description: 'Chat messages'"));
      expect(code, isNot(contains('controller.show(')));
      expect(code, isNot(contains('NotificationController(')));
    });

    test('queuesOnly emits Set of NotificationQueue without controller', () {
      const setup = StudioSetup(
        queues: {
          QueuePosition.bottomLeft: QueueSetup(maxStackSize: 4),
        },
        channels: {},
      );
      const draft = NotificationDraft();

      final code = generateCode(
        setup: setup,
        draft: draft,
        scope: CodeSnippetScope.queuesOnly,
      );

      expect(code, contains('final queues = <NotificationQueue>{'));
      expect(code, contains('position: QueuePosition.bottomLeft,'));
      expect(code, contains('maxStackSize: 4,'));
      expect(code, isNot(contains('controller.show(')));
      expect(code, isNot(contains('NotificationController(')));
    });
  });

  group('CodeGenerator - Drag & LongPress Behaviors', () {
    test('emits Dismiss with all DismissZone variants', () {
      for (final zone in DismissZone.values) {
        final setup = StudioSetup(
          queues: {
            QueuePosition.topCenter: QueueSetup(dragDismissZone: zone),
          },
          channels: const {},
        );
        final code = generateCode(
          setup: setup,
          draft: const NotificationDraft(),
          scope: CodeSnippetScope.queuesOnly,
        );

        expect(
          code,
          contains(
            'dragBehavior: const Dismiss(zones: DismissZone.${zone.name}),',
          ),
        );
      }
    });

    test('emits Snooze and Pin behaviors', () {
      const setup = StudioSetup(
        queues: {
          QueuePosition.topRight: QueueSetup(
            dragBehaviorType: Snooze,
            dragSnoozeSeconds: 15,
            longPressBehaviorType: Pin,
          ),
        },
        channels: {},
      );
      final code = generateCode(
        setup: setup,
        draft: const NotificationDraft(),
        scope: CodeSnippetScope.queuesOnly,
      );

      expect(
        code,
        contains(
          'dragBehavior: const Snooze(duration: Duration(seconds: 15)),',
        ),
      );
      expect(code, contains('longPressDragBehavior: const Pin(),'));
    });

    test('emits Relocate.to with targets and permanent flag', () {
      const setup = StudioSetup(
        queues: {
          QueuePosition.topCenter: QueueSetup(
            dragBehaviorType: Relocate,
            relocateTargets: {
              QueuePosition.bottomLeft,
              QueuePosition.bottomRight,
            },
            relocatePermanent: true,
          ),
        },
        channels: {},
      );
      final code = generateCode(
        setup: setup,
        draft: const NotificationDraft(),
        scope: CodeSnippetScope.queuesOnly,
      );

      expect(
        code,
        contains(
          'Relocate.to({QueuePosition.bottomLeft, '
          'QueuePosition.bottomRight}, permanent: true)',
        ),
      );
    });

    test('emits Relocate error comment when targets are empty', () {
      const setup = StudioSetup(
        queues: {
          QueuePosition.topCenter: QueueSetup(
            dragBehaviorType: Relocate,
            relocateTargets: {},
          ),
        },
        channels: {},
      );
      final code = generateCode(
        setup: setup,
        draft: const NotificationDraft(),
        scope: CodeSnippetScope.queuesOnly,
      );

      expect(
        code,
        contains(
          'Relocate.to({}) // ERROR: Relocation targets must not be empty!',
        ),
      );
    });

    test('emits ReorderAndRelocate.to with targets and permanent flag', () {
      const setup = StudioSetup(
        queues: {
          QueuePosition.topCenter: QueueSetup(
            dragBehaviorType: ReorderAndRelocate,
            relocateTargets: {QueuePosition.bottomCenter},
            relocatePermanent: true,
          ),
        },
        channels: {},
      );
      final code = generateCode(
        setup: setup,
        draft: const NotificationDraft(),
        scope: CodeSnippetScope.queuesOnly,
      );

      expect(code, contains('ReorderAndRelocate.to('));
      expect(code, contains('positions: {QueuePosition.bottomCenter},'));
      expect(code, contains('permanent: true,'));
    });

    test('emits Reorder and Disabled behaviors', () {
      const setup = StudioSetup(
        queues: {
          QueuePosition.topCenter: QueueSetup(
            dragBehaviorType: Reorder,
            longPressBehaviorType: Disabled,
          ),
        },
        channels: {},
      );
      final code = generateCode(
        setup: setup,
        draft: const NotificationDraft(),
        scope: CodeSnippetScope.queuesOnly,
      );

      expect(code, contains('dragBehavior: const Reorder(),'));
      expect(code, contains('longPressDragBehavior: const Disabled(),'));
    });
  });

  group('CodeGenerator - Tap & Close Button Behaviors', () {
    test('omits tapBehavior for TapToDismiss (default)', () {
      const setup = StudioSetup(
        queues: {
          QueuePosition.topCenter: QueueSetup(
            tapBehaviorType: TapToDismiss,
          ),
        },
        channels: {},
      );
      final code = generateCode(
        setup: setup,
        draft: const NotificationDraft(),
        scope: CodeSnippetScope.queuesOnly,
      );

      expect(code, isNot(contains('tapBehavior:')));
    });

    test('emits tapBehavior for TapToExpand, TapToAct, and TapDisabled', () {
      for (final type in [TapToExpand, TapToAct, TapDisabled]) {
        final setup = StudioSetup(
          queues: {
            QueuePosition.topCenter: QueueSetup(tapBehaviorType: type),
          },
          channels: const {},
        );
        final code = generateCode(
          setup: setup,
          draft: const NotificationDraft(),
          scope: CodeSnippetScope.queuesOnly,
        );

        if (type == TapToExpand) {
          expect(code, contains('tapBehavior: const TapToExpand(),'));
        } else if (type == TapToAct) {
          expect(code, contains('tapBehavior: TapToAct(onTap: () {}),'));
        } else if (type == TapDisabled) {
          expect(code, contains('tapBehavior: const TapDisabled(),'));
        }
      }
    });

    test('emits closeButtonBehavior variants', () {
      for (final type in [AlwaysVisible, VisibleOnHover, Hidden]) {
        final setup = StudioSetup(
          queues: {
            QueuePosition.topCenter: QueueSetup(
              closeButtonBehaviorType: type,
            ),
          },
          channels: const {},
        );
        final code = generateCode(
          setup: setup,
          draft: const NotificationDraft(),
          scope: CodeSnippetScope.queuesOnly,
        );

        if (type == AlwaysVisible) {
          expect(
            code,
            contains('closeButtonBehavior: const AlwaysVisible(),'),
          );
        } else if (type == VisibleOnHover) {
          expect(
            code,
            contains('closeButtonBehavior: const VisibleOnHover(),'),
          );
        } else if (type == Hidden) {
          expect(
            code,
            contains('closeButtonBehavior: const Hidden(),'),
          );
        }
      }
    });
  });

  group('CodeGenerator - Queue Grouping', () {
    test('omits groupingBehavior when groupingEnabled is false', () {
      const setup = StudioSetup(
        queues: {
          QueuePosition.topCenter: QueueSetup(groupingEnabled: false),
        },
        channels: {},
      );
      final code = generateCode(
        setup: setup,
        draft: const NotificationDraft(),
        scope: CodeSnippetScope.queuesOnly,
      );

      expect(code, isNot(contains('groupingBehavior:')));
    });

    test(
      'emits default const HiddenCount() when maxCount=9 and includePending',
      () {
        const setup = StudioSetup(
          queues: {
            QueuePosition.topCenter: QueueSetup(
              groupingEnabled: true,
              groupingCountType: GroupCountType.hiddenCount,
              groupingCountMaxCount: 9,
              groupingCountIncludePending: true,
            ),
          },
          channels: {},
        );
        final code = generateCode(
          setup: setup,
          draft: const NotificationDraft(),
          scope: CodeSnippetScope.queuesOnly,
        );

        expect(code, contains('groupingBehavior: QueueGroupingBehavior('));
        expect(code, contains('countBehavior: const HiddenCount(),'));
      },
    );

    test('emits custom HiddenCount when maxCount or includePending differs',
        () {
      const setup = StudioSetup(
        queues: {
          QueuePosition.topCenter: QueueSetup(
            groupingEnabled: true,
            groupingCountType: GroupCountType.hiddenCount,
            groupingCountMaxCount: 5,
            groupingCountIncludePending: false,
          ),
        },
        channels: {},
      );
      final code = generateCode(
        setup: setup,
        draft: const NotificationDraft(),
        scope: CodeSnippetScope.queuesOnly,
      );

      expect(code, contains('const HiddenCount('));
      expect(code, contains('maxCount: 5,'));
      expect(code, contains('includePending: false,'));
    });

    test('emits default const TotalCount() and custom TotalCount', () {
      const defaultTotalSetup = StudioSetup(
        queues: {
          QueuePosition.topCenter: QueueSetup(
            groupingEnabled: true,
            groupingCountType: GroupCountType.totalCount,
            groupingCountMaxCount: 9,
            groupingCountIncludePending: true,
          ),
        },
        channels: {},
      );
      const customTotalSetup = StudioSetup(
        queues: {
          QueuePosition.topCenter: QueueSetup(
            groupingEnabled: true,
            groupingCountType: GroupCountType.totalCount,
            groupingCountMaxCount: 99,
            groupingCountIncludePending: true,
          ),
        },
        channels: {},
      );

      final codeDefault = generateCode(
        setup: defaultTotalSetup,
        draft: const NotificationDraft(),
        scope: CodeSnippetScope.queuesOnly,
      );
      final codeCustom = generateCode(
        setup: customTotalSetup,
        draft: const NotificationDraft(),
        scope: CodeSnippetScope.queuesOnly,
      );

      expect(codeDefault, contains('countBehavior: const TotalCount(),'));
      expect(codeCustom, contains('countBehavior: const TotalCount('));
      expect(codeCustom, contains('maxCount: 99,'));
    });

    test('emits const NoCount() for GroupCountType.noCount', () {
      const setup = StudioSetup(
        queues: {
          QueuePosition.topCenter: QueueSetup(
            groupingEnabled: true,
            groupingCountType: GroupCountType.noCount,
          ),
        },
        channels: {},
      );
      final code = generateCode(
        setup: setup,
        draft: const NotificationDraft(),
        scope: CodeSnippetScope.queuesOnly,
      );

      expect(code, contains('countBehavior: const NoCount(),'));
    });

    test('emits custom threshold, layers, and swipe dismiss', () {
      const setup = StudioSetup(
        queues: {
          QueuePosition.topCenter: QueueSetup(
            groupingEnabled: true,
            groupingThreshold: 5,
            groupingMaxLayers: 4,
            groupingSwipeDismiss: true,
          ),
        },
        channels: {},
      );
      final code = generateCode(
        setup: setup,
        draft: const NotificationDraft(),
        scope: CodeSnippetScope.queuesOnly,
      );

      expect(code, contains('maxBeforeGrouping: 5,'));
      expect(code, contains('maxStackedLayers: 4,'));
      expect(code, contains('enableGroupSwipeDismiss: true,'));
    });
  });

  group('CodeGenerator - Channel Configurations', () {
    test('emits channel position, dismissDuration, and disabled flag', () {
      const setup = StudioSetup(
        queues: {},
        channels: {
          'quiet': ChannelSetup(
            name: 'quiet',
            position: QueuePosition.bottomRight,
            dismissSeconds: 12,
            enabled: false,
          ),
        },
      );
      final code = generateCode(
        setup: setup,
        draft: const NotificationDraft(),
        scope: CodeSnippetScope.channelsOnly,
      );

      expect(code, contains("name: 'quiet',"));
      expect(code, contains('position: QueuePosition.bottomRight,'));
      expect(
        code,
        contains(
          'defaultDismissDuration: const Duration(seconds: 12),',
        ),
      );
      expect(code, contains('enabled: false,'));
    });

    test('emits const Icon with correct preset names', () {
      final presets = {
        ChannelIconPreset.info: 'info',
        ChannelIconPreset.success: 'check_circle',
        ChannelIconPreset.warning: 'warning',
        ChannelIconPreset.error: 'error',
        ChannelIconPreset.notification: 'notifications',
      };

      for (final entry in presets.entries) {
        final setup = StudioSetup(
          queues: const {},
          channels: {
            'c': ChannelSetup(name: 'c', iconPreset: entry.key),
          },
        );
        final code = generateCode(
          setup: setup,
          draft: const NotificationDraft(),
          scope: CodeSnippetScope.channelsOnly,
        );

        expect(
          code,
          contains('defaultIcon: const Icon(Icons.${entry.value}),'),
        );
      }
    });

    test('emits NotificationThemeData with color token', () {
      const setup = StudioSetup(
        queues: {},
        channels: {
          'custom': ChannelSetup(
            name: 'custom',
            color: Color(0xFFEF4444),
          ),
        },
      );
      final code = generateCode(
        setup: setup,
        draft: const NotificationDraft(),
        scope: CodeSnippetScope.channelsOnly,
      );

      expect(code, contains('theme: const NotificationThemeData('));
      expect(code, contains('color: Color(0xFFEF4444),'));
    });
  });

  group('CodeGenerator - Draft & Dispatch Payloads', () {
    test('emits NotificationAction.button for button actionStyle', () {
      const draft = NotificationDraft(
        actionStyle: NotificationActionStyle.button,
        actionLabel: 'UNDO',
      );
      final code = generateCode(
        setup: const StudioSetup(queues: {}, channels: {}),
        draft: draft,
        scope: CodeSnippetScope.dispatchOnly,
      );

      expect(code, contains('action: NotificationAction.button('));
      expect(code, contains("label: 'UNDO',"));
      expect(code, contains('onPressed: () {},'));
    });

    test('emits TapToAct for onTap actionStyle', () {
      const draft = NotificationDraft(
        actionStyle: NotificationActionStyle.onTap,
      );
      final code = generateCode(
        setup: const StudioSetup(queues: {}, channels: {}),
        draft: draft,
        scope: CodeSnippetScope.dispatchOnly,
      );

      expect(code, contains('tapBehavior: TapToAct('));
      expect(code, contains('onTap: () {},'));
      expect(code, isNot(contains('NotificationAction.onTap')));
    });

    test(
      'emits priority, permanent, accentColor, dismissDuration, '
      'positionOverride',
      () {
        const draft = NotificationDraft(
          title: 'Draft Details',
          message: 'Comprehensive draft payload',
          channelName: 'priority_channel',
          priority: NotificationPriority.critical,
          permanent: true,
          accentColorOverride: Color(0xFF8B5CF6),
          dismissSeconds: 8,
          positionOverride: QueuePosition.topRight,
        );
        final code = generateCode(
          setup: const StudioSetup(queues: {}, channels: {}),
          draft: draft,
          scope: CodeSnippetScope.dispatchOnly,
        );

        expect(code, contains('priority: NotificationPriority.critical,'));
        expect(code, contains('permanent: true,'));
        expect(code, contains('accentColor: const Color(0xFF8B5CF6),'));
        expect(
          code,
          contains('dismissDuration: const Duration(seconds: 8),'),
        );
        expect(code, contains('targetPosition: QueuePosition.topRight,'));
      },
    );
  });

  group('CodeGenerator - Dart Syntax & Semantic Verification', () {
    test(
      'all generated snippets pass dart analyze with 0 errors',
      () async {
        const setup = StudioSetup(
          queues: {
            QueuePosition.topCenter: QueueSetup(
              dragBehaviorType: Relocate,
              relocateTargets: {QueuePosition.bottomCenter},
              relocatePermanent: true,
              tapBehaviorType: TapToExpand,
              groupingEnabled: true,
              groupingThreshold: 3,
              groupingCountType: GroupCountType.totalCount,
              groupingCountMaxCount: 50,
              groupingCountIncludePending: false,
            ),
          },
          channels: {
            'alerts': ChannelSetup(
              name: 'alerts',
              description: 'Critical system alerts',
              color: Color(0xFFE11D48),
              position: QueuePosition.topCenter,
              dismissSeconds: 10,
              iconPreset: ChannelIconPreset.warning,
            ),
          },
          maxHistoryEntries: 200,
        );

        const draft = NotificationDraft(
          title: 'System Alert',
          message: 'Cluster memory usage exceeds threshold',
          channelName: 'alerts',
          priority: NotificationPriority.critical,
          permanent: true,
          actionStyle: NotificationActionStyle.button,
          actionLabel: 'ACKNOWLEDGE',
          accentColorOverride: Color(0xFFBE123C),
          dismissSeconds: 15,
          positionOverride: QueuePosition.topCenter,
        );

        final fullCode = generateCode(
          setup: setup,
          draft: draft,
          scope: CodeSnippetScope.fullSetup,
        );

        final channelsCode = generateCode(
          setup: setup,
          draft: draft,
          scope: CodeSnippetScope.channelsOnly,
        );

        final queuesCode = generateCode(
          setup: setup,
          draft: draft,
          scope: CodeSnippetScope.queuesOnly,
        );

        // Construct a valid standalone Dart file incorporating snippets.
        const pkgImport =
            'package:flutter_notification_queue/flutter_notification_queue.dart';
        final testDartFile = StringBuffer()
          ..writeln(
            '// ignore_for_file: unused_local_variable, '
            'prefer_const_constructors, cascade_invocations, '
            'lines_longer_than_80_chars',
          )
          ..writeln("import 'package:flutter/material.dart';")
          ..writeln("import '$pkgImport';")
          ..writeln()
          ..writeln('void generatedCodeTestHarness() {')
          ..writeln('  // --- 1. Full Setup Snippet ---')
          ..writeln(fullCode)
          ..writeln('  // --- 2. Channels Only Snippet ---')
          ..writeln(channelsCode)
          ..writeln('  // --- 3. Queues Only Snippet ---')
          ..writeln(queuesCode)
          ..writeln('}')
          ..writeln();

        final tempFile = File('test/temp_codegen_harness.dart');
        await tempFile.writeAsString(testDartFile.toString());

        const snapDart = '/home/ono/snap/flutter/common/flutter/bin/dart';
        final dartExe = File(snapDart).existsSync()
            ? snapDart
            : Platform.resolvedExecutable;

        try {
          final result = await Process.run(
            dartExe,
            ['analyze', tempFile.path],
          );

          expect(
            result.exitCode,
            equals(0),
            reason: 'dart analyze failed on generated code:\n'
                '${result.stdout}\n${result.stderr}',
          );
        } finally {
          if (tempFile.existsSync()) {
            await tempFile.delete();
          }
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
