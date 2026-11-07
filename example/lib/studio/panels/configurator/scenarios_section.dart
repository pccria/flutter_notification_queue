import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';

import '../../bloc/setup_bloc.dart';
import '../../models/channel_setup.dart';
import '../../models/queue_setup.dart';
import '../../studio_theme.dart';

/// A curated set of one-click demo scenarios that showcase different FNQ
/// features in realistic use cases.
///
/// Each scenario fires a specific combination of notifications to demonstrate
/// a distinct feature set. They fire into whatever configuration is currently
/// active in the studio — no configuration change is needed.
class ScenariosSection extends StatelessWidget {
  const ScenariosSection({super.key});

  @override
  Widget build(final BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'One-click demos — fires into your current configuration.',
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: StudioTheme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 12),
          ..._scenarios.map(
            (final s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ScenarioTile(scenario: s),
            ),
          ),
        ],
      );
}

class _Scenario {
  const _Scenario({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onFire,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final void Function(BuildContext context) onFire;
}

// Fires with a short stagger to show stacking behaviour
void _stagger(
  final NotificationController scope,
  final List<AppNotification> notifications, [
  final Duration delay = const Duration(milliseconds: 600),
]) {
  for (var i = 0; i < notifications.length; i++) {
    final n = notifications[i];
    Future.delayed(delay * i, () => scope.show(n));
  }
}

final _scenarios = [
  // ── 1. System Health ──
  _Scenario(
    title: 'System Health',
    subtitle: 'Permanent error + timed warning — multi-position demo',
    icon: Icons.monitor_heart_outlined,
    color: const Color(0xFFEF4444),
    onFire: (final context) {
      _stagger(NotificationScope.of(context), [
        AppNotification(
          title: 'Service Degraded',
          message: 'Database connection pool exhausted. '
              'Manual intervention required.',
          channelName: 'error',
          dismissDuration: null, // permanent
          action: NotificationAction.button(
            label: 'DIAGNOSE',
            onPressed: () => debugPrint('[Scenario] Diagnose tapped'),
          ),
        ),
        const AppNotification(
          title: 'High Memory Usage',
          message: 'Instance is at 89% memory. Consider scaling up.',
          channelName: 'warning',
          dismissDuration: Duration(seconds: 8),
        ),
      ]);
    },
  ),

  // ── 2. Social Activity ──
  _Scenario(
    title: 'Social Activity',
    subtitle: '3 staggered notifications — tests maxStackSize overflow',
    icon: Icons.people_outline,
    color: const Color(0xFF38BDF8),
    onFire: (final context) {
      _stagger(
        NotificationScope.of(context),
        [
          const AppNotification(
            title: 'Alex liked your post',
            message: '"Beautiful sunset photo!"',
            channelName: 'info',
            dismissDuration: Duration(seconds: 4),
          ),
          AppNotification(
            title: 'Mia commented',
            message: '"This is stunning, where was this taken?"',
            channelName: 'info',
            dismissDuration: const Duration(seconds: 4),
            action: NotificationAction.button(
              label: 'REPLY',
              onPressed: () => debugPrint('[Scenario] Reply tapped'),
            ),
          ),
          const AppNotification(
            title: '5 new followers',
            message: 'Your account is trending in Photography.',
            channelName: 'info',
            dismissDuration: Duration(seconds: 5),
          ),
        ],
        const Duration(milliseconds: 400),
      );
    },
  ),

  // ── 3. File Sync Complete ──
  _Scenario(
    title: 'File Sync Complete',
    subtitle: 'Success with action button — bottomCenter queue',
    icon: Icons.cloud_done_outlined,
    color: const Color(0xFF22C55E),
    onFire: (final context) {
      NotificationScope.of(context).show(
        AppNotification(
          title: 'Sync Complete',
          message: '142 files synced to cloud. 2.3 GB transferred.',
          channelName: 'success',
          dismissDuration: const Duration(seconds: 6),
          action: NotificationAction.button(
            label: 'VIEW FILES',
            onPressed: () => debugPrint('[Scenario] View Files tapped'),
          ),
        ),
      );
    },
  ),

  // ── 4. Security Alert ──
  _Scenario(
    title: 'Security Alert',
    subtitle: 'TapToAct — permanent card, tap to review, manual dismiss',
    icon: Icons.security_outlined,
    color: const Color(0xFFF97316),
    onFire: (final context) {
      NotificationScope.of(context).show(
        AppNotification(
          title: '⚠ Unrecognised Sign-In Attempt',
          message: 'Login from Lagos, Nigeria · Chrome on Windows. '
              'Tap to review.',
          channelName: 'warning',
          dismissDuration: null,
          tapBehavior: TapToAct(
            onTap: () => debugPrint('[Scenario] Security alert tapped'),
            dismissOnAct: false,
          ),
        ),
      );
    },
  ),

  // ── 5. Notification Storm ──
  _Scenario(
    title: 'Notification Storm',
    subtitle: '10 rapid notifications — stress tests queue overflow',
    icon: Icons.bolt_outlined,
    color: const Color(0xFFA855F7),
    onFire: (final context) {
      final scope = NotificationScope.of(context);
      final channels = ['info', 'success', 'warning', 'error'];
      final messages = [
        ('Build #47 passed', 'All 312 tests green in 4.2s.'),
        ('PR Review Ready', 'feature/auth-refresh is ready to merge.'),
        ('Deploy triggered', 'Staging environment updating.'),
        ('Coverage dropped', 'Line coverage fell to 72%. Check new code.'),
        ('Disk alert', '/var/log is at 95% capacity.'),
        ('New comment', 'Jamie left feedback on your PR.'),
        ('Backup complete', 'Daily snapshot stored successfully.'),
        ('Rate limit warning', 'API at 80% of hourly quota.'),
        ('Cache cleared', 'CDN purge completed globally.'),
        ('Cert renewal', 'TLS certificate auto-renewed for 90 days.'),
      ];
      for (var i = 0; i < messages.length; i++) {
        final (title, message) = messages[i];
        Future.delayed(Duration(milliseconds: 250 * i), () {
          scope.show(
            AppNotification(
              title: title,
              message: message,
              channelName: channels[i % channels.length],
              dismissDuration: Duration(seconds: 4 + (i % 3)),
            ),
          );
        });
      }
    },
  ),

  // ── 6. TapBehavior Showcase ──
  _Scenario(
    title: 'Tap Behavior Showcase',
    subtitle:
        'All 4 tap behaviors — dismiss, expand, act, disabled — staggered',
    icon: Icons.touch_app_outlined,
    color: const Color(0xFF14B8A6),
    onFire: (final context) {
      _stagger(
        NotificationScope.of(context),
        [
          // 1 — TapToDismiss (explicit, same as default)
          const AppNotification(
            title: 'Tap → Dismiss',
            message: 'TapToDismiss: tap anywhere on this card to close it '
                'immediately.',
            channelName: 'info',
            dismissDuration: null,
            tapBehavior: TapToDismiss(),
          ),
          // 2 — TapToExpand
          const AppNotification(
            title: 'Tap → Expand',
            message:
                'TapToExpand: tap the card surface to toggle the full details '
                'panel. The entire card is now the expand affordance.',
            channelName: 'info',
            dismissDuration: null,
            tapBehavior: TapToExpand(),
          ),
          // 3 — TapToAct
          AppNotification(
            title: 'Tap → Act',
            message: 'TapToAct: tap fires a callback. '
                'Check the console for the log output.',
            channelName: 'success',
            dismissDuration: null,
            tapBehavior: TapToAct(
              onTap: () => debugPrint('[Showcase] TapToAct callback fired!'),
            ),
          ),
          // 4 — TapDisabled
          const AppNotification(
            title: 'Tap → Disabled',
            message: 'TapDisabled: tapping this card does nothing. '
                'Use the close button to dismiss.',
            channelName: 'warning',
            dismissDuration: null,
            tapBehavior: TapDisabled(),
          ),
        ],
        const Duration(milliseconds: 700),
      );
    },
  ),

  // ── 7. Sticky Alert (Permanent) ──
  _Scenario(
    title: 'Sticky Alert (Permanent)',
    subtitle: 'Permanent card — stays until action button tapped',
    icon: Icons.pin_drop_outlined,
    color: const Color(0xFFF59E0B),
    onFire: (final context) {
      final scope = NotificationScope.of(context);
      late final AppNotification notification;
      notification = AppNotification(
        title: 'CRITICAL SECURITY UPDATE',
        message: 'This notification is configured with permanent: true. '
            'It stays in place until explicitly dismissed or acknowledged.',
        channelName: 'error',
        permanent: true,
        action: NotificationAction.button(
          label: 'OK',
          onPressed: () {
            scope.dismiss(notification);
            debugPrint('[Scenario] Sticky Alert OK tapped');
          },
        ),
      );
      scope.show(notification);
    },
  ),

  // ── 8. Priority Triage Storm ──
  _Scenario(
    title: 'Priority Triage Storm',
    subtitle: 'Showcases priority-aware auto-sorting & preemption eviction',
    icon: Icons.sort_rounded,
    color: const Color(0xFFF43F5E),
    onFire: (final context) {
      final scope = NotificationScope.of(context);
      // 1. Enqueue 2 low priority notifications staggered
      _stagger(
        scope,
        [
          const AppNotification(
            title: 'Low Priority: Disk Cleanup',
            message: 'Background disk cleanup started.',
            channelName: 'info',
            priority: NotificationPriority.low,
            dismissDuration: Duration(seconds: 10),
          ),
          const AppNotification(
            title: 'Low Priority: Syncing Logs',
            message: 'Diagnostic log sync in progress.',
            channelName: 'info',
            priority: NotificationPriority.low,
            dismissDuration: Duration(seconds: 10),
          ),
        ],
        const Duration(milliseconds: 350),
      );

      // 2. Enqueue Normal priority notification that will auto-sort and push
      // to the front of pending queue
      Future.delayed(const Duration(milliseconds: 1000), () {
        scope.show(
          const AppNotification(
            title: 'Normal Priority: Package Update',
            message: 'System package updates available.',
            channelName: 'warning',
            priority: NotificationPriority.normal,
            dismissDuration: Duration(seconds: 6),
          ),
        );
      });

      // 3. Enqueue a Critical notification that will immediately evict the
      // lowest priority active notification
      Future.delayed(const Duration(milliseconds: 2000), () {
        scope.show(
          const AppNotification(
            title: 'CRITICAL: Database Offline!',
            message: 'Primary database connection lost! '
                'Evicting low priority tasks.',
            channelName: 'error',
            priority: NotificationPriority.critical,
            dismissDuration: Duration(seconds: 6),
          ),
        );
      });
    },
  ),

  // ── 9. Queue Collision Storm ──
  _Scenario(
    title: 'Queue Collision Storm',
    subtitle: 'Fires to topLeft, topCenter, & topRight. Stacks them '
        'vertically to avoid overlap on narrow screens.',
    icon: Icons.grid_view_rounded,
    color: const Color(0xFF6366F1),
    onFire: (final context) {
      final setupBloc = context.read<SetupBloc>();
      // Activate the three queues if not already configured
      if (!setupBloc.state.setup.queues.containsKey(QueuePosition.topLeft)) {
        setupBloc.add(const AddQueue(QueuePosition.topLeft));
      }
      if (!setupBloc.state.setup.queues.containsKey(QueuePosition.topCenter)) {
        setupBloc.add(const AddQueue(QueuePosition.topCenter));
      }
      if (!setupBloc.state.setup.queues.containsKey(QueuePosition.topRight)) {
        setupBloc.add(const AddQueue(QueuePosition.topRight));
      }

      final controller = NotificationScope.of(context);
      final items = [
        (
          const AppNotification(
            title: 'Top Left Queue',
            message: 'Fired into topLeft queue.',
            channelName: 'info',
            dismissDuration: Duration(seconds: 12),
          ),
          QueuePosition.topLeft,
        ),
        (
          const AppNotification(
            title: 'Top Center Queue',
            message: 'Fired into topCenter queue.',
            channelName: 'warning',
            dismissDuration: Duration(seconds: 12),
          ),
          QueuePosition.topCenter,
        ),
        (
          const AppNotification(
            title: 'Top Right Queue',
            message: 'Fired into topRight queue.',
            channelName: 'error',
            dismissDuration: Duration(seconds: 12),
          ),
          QueuePosition.topRight,
        ),
      ];
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        Future.delayed(
          Duration(milliseconds: 200 * i),
          () => controller.show(item.$1, targetPosition: item.$2),
        );
      }
    },
  ),

  // ── 10. Chat Burst (Single-Card Dismiss) ──
  _Scenario(
    title: 'Chat Burst (Grouping)',
    subtitle: '4 messages collapse into a bundle. Swipe the top card — '
        'only that one exits. The next hidden message surfaces automatically.',
    icon: Icons.mark_chat_unread_outlined,
    color: const Color(0xFF0EA5E9),
    onFire: (final context) {
      final scope = NotificationScope.of(context);
      final setupBloc = context.read<SetupBloc>();
      // Automatically configure topRight queue to have groupingEnabled = true
      final existingQueue =
          setupBloc.state.setup.queues[QueuePosition.topRight] ??
              const QueueSetup();
      setupBloc
        ..add(
          AddQueue(
            QueuePosition.topRight,
            existingQueue.copyWith(
              groupingEnabled: true,
              groupingThreshold: 2,
            ),
          ),
        )
        // Ensure 'chat' channel maps to topRight and is enabled
        ..add(
          const AddChannel(
            ChannelSetup(
              name: 'chat',
              description: 'Social Chat Messages',
              color: Color(0xFF0EA5E9),
              position: QueuePosition.topRight,
              dismissSeconds: 30,
              iconPreset: ChannelIconPreset.notification,
            ),
          ),
        );

      // Delay to ensure SetupBloc state is applied before
      // notifications are built
      Future.delayed(const Duration(milliseconds: 50), () {
        _stagger(
          scope,
          [
            const AppNotification(
              title: 'Alice',
              message: 'Hey, are you free this afternoon?',
              channelName: 'chat',
              dismissDuration: Duration(seconds: 30),
            ),
            const AppNotification(
              title: 'Alice',
              message: 'I have some updates on the design sprint.',
              channelName: 'chat',
              dismissDuration: Duration(seconds: 30),
            ),
            const AppNotification(
              title: 'Alice',
              message: 'The stakeholders moved the review to Friday!',
              channelName: 'chat',
              dismissDuration: Duration(seconds: 30),
            ),
            const AppNotification(
              title: 'Alice',
              message: 'Let me know if you need the deck beforehand.',
              channelName: 'chat',
              dismissDuration: Duration(seconds: 30),
            ),
          ],
          const Duration(milliseconds: 500),
        );
      });
    },
  ),

  // ── 11. Group Dismiss ──
  _Scenario(
    title: 'Group Dismiss',
    subtitle:
        'Fires a build logs burst to bottomLeft, then calls dismissGroup() '
        'after 3 s to clear the entire bundle at once via the explicit API.',
    icon: Icons.layers_clear_outlined,
    color: const Color(0xFF06B6D4),
    onFire: (final context) {
      final scope = NotificationScope.of(context);
      final setupBloc = context.read<SetupBloc>();
      // Automatically configure bottomLeft queue to have groupingEnabled = true
      final existingQueue =
          setupBloc.state.setup.queues[QueuePosition.bottomLeft] ??
              const QueueSetup();
      setupBloc
        ..add(
          AddQueue(
            QueuePosition.bottomLeft,
            existingQueue.copyWith(
              groupingEnabled: true,
              groupingThreshold: 2,
            ),
          ),
        )
        // Ensure 'system_tasks' channel maps to bottomLeft and is enabled
        ..add(
          const AddChannel(
            ChannelSetup(
              name: 'system_tasks',
              description: 'System Build Logs',
              color: Color(0xFF06B6D4),
              position: QueuePosition.bottomLeft,
              dismissSeconds: 60,
              iconPreset: ChannelIconPreset.info,
            ),
          ),
        );

      const groupKey = 'system_tasks';

      // Delay to ensure SetupBloc state is applied before
      // notifications are built
      Future.delayed(const Duration(milliseconds: 50), () {
        _stagger(
          scope,
          [
            const AppNotification(
              title: 'Bob',
              message: 'Build pipeline started.',
              channelName: groupKey,
              dismissDuration: Duration(seconds: 60),
            ),
            const AppNotification(
              title: 'Bob',
              message: 'Unit tests: all 312 passed.',
              channelName: groupKey,
              dismissDuration: Duration(seconds: 60),
            ),
            const AppNotification(
              title: 'Bob',
              message: 'Integration tests: passed.',
              channelName: groupKey,
              dismissDuration: Duration(seconds: 60),
            ),
            const AppNotification(
              title: 'Bob',
              message: '🚀 Deploy to staging complete.',
              channelName: groupKey,
              dismissDuration: Duration(seconds: 60),
            ),
          ],
          const Duration(milliseconds: 400),
        );

        // After the burst has settled, dismiss the whole bundle at once.
        Future.delayed(const Duration(seconds: 3), () {
          scope.dismissGroup(groupKey);
        });
      });
    },
  ),

  // ── 12. Group Count: Total Count & Backlog ──
  _Scenario(
    title: 'Group Count: Total Count & Backlog',
    subtitle: 'Queue limit 2, 5-message burst. TotalCount displays '
        'total volume (5) accounting for un-rendered pending backlog cards.',
    icon: Icons.filter_9_plus_outlined,
    color: const Color(0xFF8B5CF6),
    onFire: (final context) {
      final scope = NotificationScope.of(context);
      final setupBloc = context.read<SetupBloc>();
      final existingQueue =
          setupBloc.state.setup.queues[QueuePosition.topRight] ??
              const QueueSetup();
      setupBloc
        ..add(
          AddQueue(
            QueuePosition.topRight,
            existingQueue.copyWith(
              groupingEnabled: true,
              groupingThreshold: 2,
              maxStackSize: 2,
              groupingCountType: GroupCountType.totalCount,
              groupingCountIncludePending: true,
            ),
          ),
        )
        ..add(
          const AddChannel(
            ChannelSetup(
              name: 'chat',
              description: 'Social Chat Messages',
              color: Color(0xFF8B5CF6),
              position: QueuePosition.topRight,
              dismissSeconds: 45,
              iconPreset: ChannelIconPreset.notification,
            ),
          ),
        );

      Future.delayed(const Duration(milliseconds: 50), () {
        _stagger(
          scope,
          [
            for (var i = 1; i <= 5; i++)
              AppNotification(
                title: 'Alice',
                message: 'Burst message #$i',
                channelName: 'chat',
                dismissDuration: const Duration(seconds: 45),
              ),
          ],
          const Duration(milliseconds: 250),
        );
      });
    },
  ),

  // ── 13. Interactive Snooze & Return ──
  _Scenario(
    title: 'Interactive Snooze & Return',
    subtitle: 'Tap SNOOZE — programmatic snooze hides and resurfaces after 5s.',
    icon: Icons.snooze_rounded,
    color: const Color(0xFFFB7185),
    onFire: (final context) {
      final scope = NotificationScope.of(context);
      late final AppNotification notification;
      notification = AppNotification(
        title: 'Meeting in 15 Minutes',
        message: 'Product sync with mobile core team. Tap to snooze for 5s.',
        channelName: 'info',
        dismissDuration: const Duration(seconds: 25),
        action: NotificationAction.button(
          label: 'SNOOZE 5s',
          onPressed: () {
            scope.snooze(notification, const Duration(seconds: 5));
          },
        ),
      );
      scope.show(notification);
    },
  ),

  // ── 14. Pinned Critical Alert ──
  _Scenario(
    title: 'Pinned Critical Alert',
    subtitle: 'Sticky card — immune to swipe dismiss & timers until unpinned.',
    icon: Icons.push_pin_rounded,
    color: const Color(0xFFF59E0B),
    onFire: (final context) {
      final scope = NotificationScope.of(context);
      late final AppNotification notification;
      notification = AppNotification(
        title: '⚠ Active Security Incident',
        message: 'Locked in place by permanent intent. '
            'Tap to acknowledge & unlock.',
        channelName: 'warning',
        permanent: true,
        priority: NotificationPriority.critical,
        dismissDuration: null,
        action: NotificationAction.button(
          label: 'ACKNOWLEDGE & UNPIN',
          onPressed: () {
            scope
              ..unpin(notification)
              ..dismiss(notification);
          },
        ),
      );
      scope.show(notification);
    },
  ),

  // ── 15. Content Accent Tint (v0.5.0) ──
  _Scenario(
    title: 'Content Accent Tint',
    subtitle: 'AppNotification.accentColor — dynamic content-driven accent',
    icon: Icons.palette_outlined,
    color: const Color(0xFF8B5CF6),
    onFire: (final context) {
      NotificationScope.of(context).show(
        const AppNotification(
          title: 'Content Accent Override',
          message: 'Tints card accent without overriding channel typography.',
          channelName: 'info',
          accentColor: Color(0xFF8B5CF6),
          dismissDuration: Duration(seconds: 8),
        ),
      );
    },
  ),

  // ── 16. Contextual Dispatch Routing (v0.5.0) ──
  _Scenario(
    title: 'Contextual Dispatch Routing',
    subtitle: 'controller.show(..., targetPosition:) — dynamic corner override',
    icon: Icons.alt_route_rounded,
    color: const Color(0xFF06B6D4),
    onFire: (final context) {
      NotificationScope.of(context).show(
        const AppNotification(
          title: 'Dynamic Routing Override',
          message: 'Routed to bottomCenter via dispatch targetPosition!',
          channelName: 'info',
          dismissDuration: Duration(seconds: 6),
        ),
        targetPosition: QueuePosition.bottomCenter,
      );
    },
  ),
];

class _ScenarioTile extends StatelessWidget {
  const _ScenarioTile({required this.scenario});
  final _Scenario scenario;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = StudioTheme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => scenario.onFire(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: scenario.color.withValues(alpha: 0.2),
            ),
            color: scenario.color.withValues(alpha: 0.06),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: scenario.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  scenario.icon,
                  size: 16,
                  color: scenario.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      scenario.subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.play_arrow_rounded,
                size: 16,
                color: scenario.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
