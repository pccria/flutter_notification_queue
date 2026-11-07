import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConfigurationManager', () {
    // 1. Constructor
    test('Constructor: Can be instantiated', () {
      final manager = ConfigurationManager();
      expect(manager, isA<ConfigurationManager>());
    });

    // 2. Zero-Config Initialization
    test(
        'Zero-Config Initialization: Uses standard defaults via '
        'NotificationController', () {
      final controller = NotificationController(
        queues: {const NotificationQueue(position: QueuePosition.topRight)},
      );
      final config = controller.configuration;

      expect(config.queues, isNotEmpty);
      expect(config.channels, isNotEmpty);

      // Verify Standard Channels
      expect(config.getChannel('success'), isNotNull);
      expect(config.getChannel('error'), isNotNull);

      // Verify Standard Queues
      expect(
        config.getQueue(QueuePosition.topRight).position,
        equals(
          QueuePosition.topRight,
        ),
      );
    });

    // 3. Default Configuration
    test(
        'ConfigurationManager Default Configuration: Returns'
        ' default queue and channel', () {
      final manager = ConfigurationManager();

      // Verify default queue logic (generates fallbacks)
      final queue = manager.getQueue(null);
      expect(
        queue.position,
        equals(
          QueuePosition.topCenter,
        ),
      );
      expect(queue.style, isA<FilledQueueStyle>());

      // Verify default channel logic
      final channel = manager.getChannel('default');
      expect(channel.name, equals('default'));
    });

    // 3. Custom Configuration
    test('Custom Configuration: Retains provided queues and channels', () {
      const customQueue = NotificationQueue(
        position: QueuePosition.topRight,
      );
      const customChannel = NotificationChannel(
        name: 'custom',
        position: QueuePosition.topRight,
      );

      final manager = ConfigurationManager(
        queues: {customQueue},
        channels: {customChannel},
      );

      expect(
        manager.getQueue(QueuePosition.topRight),
        equals(
          customQueue,
        ),
      );
      expect(
        manager.getChannel('custom'),
        equals(
          customChannel,
        ),
      );
    });

    // 4. Channel Resolution (Fallback)
    test('Channel Resolution: Falls back to first channel on miss', () {
      const c1 = NotificationChannel(name: 'one');
      const c2 = NotificationChannel(name: 'two');
      final manager = ConfigurationManager(channels: {c1, c2});

      expect(manager.getChannel('one'), equals(c1));
      expect(manager.getChannel('two'), equals(c2));

      // Fallback
      expect(
        manager.getChannel('unknown'),
        isA<NotificationChannel>()
            .having((final c) => c.name, 'name', 'default'),
      );
    });

    // 5. Queue Resolution (Stateless)
    test('Queue Resolution: Generates queues on fly (stateless)', () {
      final manager = ConfigurationManager(); // Defaults

      // Request a position that wasn't configured
      final q1 = manager.getQueue(QueuePosition.bottomRight);
      expect(q1, isA<NotificationQueue>());
      expect(q1.position, equals(QueuePosition.bottomRight));

      final q2 = manager.getQueue(QueuePosition.bottomRight);

      expect(q2.position, equals(q1.position));
      expect(q2.style.runtimeType, equals(q1.style.runtimeType));
    });
  });

  group('Relocation Groups', () {
    // 6. Self-Inclusion
    test('Self-Inclusion: Source position is added to Relocate targets', () {
      final relocateBehavior = Relocate<OnLongPress>.to(
        {QueuePosition.centerRight, QueuePosition.centerLeft},
      );
      final manager = ConfigurationManager(
        queues: {
          NotificationQueue(
            position: QueuePosition.topCenter,
            longPressDragBehavior: relocateBehavior,
          ),
        },
      );

      // After init, source position (topCenter) should be in the targets
      expect(
        relocateBehavior.positions,
        contains(QueuePosition.topCenter),
      );

      // Original targets should still be present
      expect(
        relocateBehavior.positions,
        containsAll(
          [
            QueuePosition.centerRight,
            QueuePosition.centerLeft,
          ],
        ),
      );

      // Should have 3 positions total
      expect(
        relocateBehavior.positions.length,
        equals(
          3,
        ),
      );

      // Manager should have the source queue
      expect(manager.queues, isNotEmpty);
    });

    // 7. Group Expansion
    test('Group Expansion: Sibling queues are created for all targets', () {
      final manager = ConfigurationManager(
        queues: {
          NotificationQueue(
            position: QueuePosition.topCenter,
            longPressDragBehavior: Relocate<OnLongPress>.to(
              {QueuePosition.centerRight, QueuePosition.centerLeft},
            ),
            style: const FilledQueueStyle(),
          ),
        },
      );

      // Should have 3 queues: topCenter + centerRight + centerLeft
      expect(manager.queues.length, equals(3));

      // Verify each sibling was created
      final centerRight = manager.getQueue(QueuePosition.centerRight);
      expect(centerRight.position, equals(QueuePosition.centerRight));

      final centerLeft = manager.getQueue(QueuePosition.centerLeft);
      expect(centerLeft.position, equals(QueuePosition.centerLeft));

      // Verify original queue remains
      final topCenter = manager.getQueue(QueuePosition.topCenter);
      expect(topCenter.position, equals(QueuePosition.topCenter));
    });

    // 8. Sibling queues inherit characteristics
    test('Group Expansion: Siblings inherit source queue characteristics', () {
      const sourceStyle = FilledQueueStyle(
        opacity: 0.5,
        elevation: 12,
      );

      final manager = ConfigurationManager(
        queues: {
          NotificationQueue(
            position: QueuePosition.topCenter,
            longPressDragBehavior: Relocate<OnLongPress>.to(
              {QueuePosition.bottomRight},
            ),
            style: sourceStyle,
            maxStackSize: 5,
            spacing: 10.0,
          ),
        },
      );

      // Sibling should inherit style
      final sibling = manager.getQueue(QueuePosition.bottomRight);
      expect(sibling.style.runtimeType, equals(sourceStyle.runtimeType));
      expect(sibling.maxStackSize, equals(5));
      expect(sibling.spacing, equals(10.0));
    });

    // 9. Transition forwarding
    test('Group Expansion: Siblings inherit transition', () {
      const sourceTransition = ScaleTransitionStrategy();

      final manager = ConfigurationManager(
        queues: {
          NotificationQueue(
            position: QueuePosition.topCenter,
            longPressDragBehavior: Relocate<OnLongPress>.to(
              {QueuePosition.bottomLeft},
            ),
            transition: sourceTransition,
          ),
        },
      );

      final sibling = manager.getQueue(QueuePosition.bottomLeft);
      expect(sibling.transition, isA<ScaleTransitionStrategy>());
    });

    // 10. Cross-Group Validation
    test('Cross-Group Validation: Throws on overlapping groups', () {
      expect(
        () => ConfigurationManager(
          queues: {
            NotificationQueue(
              position: QueuePosition.topCenter,
              longPressDragBehavior: Relocate<OnLongPress>.to(
                {QueuePosition.centerRight},
              ),
            ),
            NotificationQueue(
              position: QueuePosition.bottomCenter,
              longPressDragBehavior: Relocate<OnLongPress>.to(
                {QueuePosition.centerRight}, // overlap!
              ),
            ),
          },
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    // 11. Independent groups coexist
    test('Independent Groups: Two separate groups coexist without conflict',
        () {
      final manager = ConfigurationManager(
        queues: {
          NotificationQueue(
            position: QueuePosition.topCenter,
            longPressDragBehavior: Relocate<OnLongPress>.to(
              {QueuePosition.centerRight, QueuePosition.centerLeft},
            ),
          ),
          NotificationQueue(
            position: QueuePosition.bottomCenter,
            longPressDragBehavior: Relocate<OnLongPress>.to(
              {QueuePosition.topLeft},
            ),
          ),
        },
      );

      expect(manager.queues.length, equals(5));
    });

    // 12. No expansion for non-Relocate behaviors
    test('No Expansion: Dismiss/Disabled behaviors do not expand', () {
      final manager = ConfigurationManager(
        queues: {
          const NotificationQueue(
            position: QueuePosition.topCenter,
            dragBehavior: Dismiss(),
            longPressDragBehavior: Disabled(),
          ),
        },
      );

      expect(manager.queues.length, equals(1));
    });

    // 13. Cluster Invariance: Pre-configuring target queue is forbidden
    test('Cluster Invariance: Target queue cannot be independently configured',
        () {
      const customStyle = FilledQueueStyle(opacity: 0.9);

      expect(
        () => ConfigurationManager(
          queues: {
            NotificationQueue(
              position: QueuePosition.topCenter,
              longPressDragBehavior: Relocate<OnLongPress>.to(
                {QueuePosition.topRight},
              ),
              style: const FlatQueueStyle(),
            ),
            const NotificationQueue(
              position: QueuePosition.topRight,
              style: customStyle,
            ),
          },
        ),
        throwsArgumentError,
      );
    });

    // 14. Encapsulation & Immutability (A-04)
    test('Encapsulation: queues and channels sets are unmodifiable', () {
      final manager = ConfigurationManager(
        queues: {
          const NotificationQueue(position: QueuePosition.topCenter),
        },
        channels: {
          const NotificationChannel(name: 'initial'),
        },
      );

      expect(
        () => manager.queues.add(
          const NotificationQueue(position: QueuePosition.bottomCenter),
        ),
        throwsUnsupportedError,
      );

      expect(
        () => manager.channels.add(
          const NotificationChannel(name: 'mutated'),
        ),
        throwsUnsupportedError,
      );
    });

    test('Encapsulation: reconfigure safely updates immutable collections', () {
      final manager = ConfigurationManager(
        queues: {
          const NotificationQueue(position: QueuePosition.topCenter),
        },
        channels: {
          const NotificationChannel(name: 'initial'),
        },
        strictChannelLookup: false,
        maxHistoryEntries: 10,
      );

      expect(manager.queues.length, equals(1));
      expect(manager.queues.first.position, equals(QueuePosition.topCenter));

      manager.reconfigure(
        queues: {
          const NotificationQueue(position: QueuePosition.bottomRight),
        },
        channels: {
          const NotificationChannel(name: 'updated'),
        },
        strictChannelLookup: true,
        maxHistoryEntries: 50,
        a11yOptions: const NotificationA11yOptions(enableContextMenu: false),
      );

      expect(manager.queues.length, equals(1));
      expect(manager.queues.first.position, equals(QueuePosition.bottomRight));
      expect(manager.channels.length, equals(1));
      expect(manager.channels.first.name, equals('updated'));
      expect(manager.strictChannelLookup, isTrue);
      expect(manager.maxHistoryEntries, equals(50));
      expect(manager.a11yOptions.enableContextMenu, isFalse);

      // Verify unmodifiable after reconfigure as well
      expect(
        () => manager.queues.add(
          const NotificationQueue(position: QueuePosition.topLeft),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => manager.channels.add(
          const NotificationChannel(name: 'mutated_again'),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
