import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';

/// Interactive Multi-Tenant Split-Viewport Stage for Studio.
///
/// Demonstrates and validates the **1:1 multi-tenancy model** active in
/// v0.7.x:
/// - **Dual Independent Workspaces**: Workspace A and Workspace B side by
///   side.
/// - **Dedicated 1:1 Controllers**: Each workspace mounts its own
///   [NotificationController] and [NotificationScope(useRootOverlay: false)].
/// - **Stasis Isolation**: Pausing queue in Workspace A freezes its timers
///   without affecting Workspace B timers.
/// - **Event Isolation**: `controller.events` stream exclusively events
///   originating from that workspace.
/// - **Teardown Safety**: Unmounting Workspace B disposes its coordinator
///   cleanly with 0 orphan tickers while Workspace A continues operating
///   smoothly.
class MultiTenantSplitViewportStage extends StatefulWidget {
  const MultiTenantSplitViewportStage({
    super.key,
    this.onClose,
  });

  /// Optional callback to dismiss the stage when used inside a modal or dialog.
  final VoidCallback? onClose;

  @override
  State<MultiTenantSplitViewportStage> createState() =>
      _MultiTenantSplitViewportStageState();
}

class _MultiTenantSplitViewportStageState
    extends State<MultiTenantSplitViewportStage> {
  late NotificationController _controllerA;
  late NotificationController _controllerB;

  StreamSubscription<NotificationEvent>? _subA;
  StreamSubscription<NotificationEvent>? _subB;

  final List<NotificationEvent> _eventsA = <NotificationEvent>[];
  final List<NotificationEvent> _eventsB = <NotificationEvent>[];

  bool _isMountedA = true;
  bool _isMountedB = true;

  bool _isPausedA = false;
  bool _isPausedB = false;

  int _burstCounterA = 0;
  int _burstCounterB = 0;

  @override
  void initState() {
    super.initState();
    _initControllerA();
    _initControllerB();
  }

  void _initControllerA() {
    _controllerA = NotificationController(
      queues: {
        const NotificationQueue(
          position: QueuePosition.topCenter,
          maxStackSize: 4,
        ),
        const NotificationQueue(
          position: QueuePosition.bottomLeft,
          maxStackSize: 3,
        ),
      },
      channels: {
        const NotificationChannel(
          name: 'alpha_info',
          description: 'Workspace A Info',
          position: QueuePosition.topCenter,
          defaultDismissDuration: Duration(seconds: 4),
        ),
        const NotificationChannel(
          name: 'alpha_alert',
          description: 'Workspace A Critical Alert',
          position: QueuePosition.topCenter,
          defaultDismissDuration: null,
        ),
        const NotificationChannel(
          name: 'alpha_task',
          description: 'Workspace A Background Tasks',
          position: QueuePosition.bottomLeft,
          defaultDismissDuration: Duration(seconds: 6),
        ),
      },
    );

    _subA?.cancel();
    _subA = _controllerA.events.listen((final event) {
      if (mounted) {
        setState(() {
          _eventsA.insert(0, event);
          if (_eventsA.length > 30) {
            _eventsA.removeLast();
          }
        });
      }
    });
  }

  void _initControllerB() {
    _controllerB = NotificationController(
      queues: {
        const NotificationQueue(
          position: QueuePosition.topCenter,
          maxStackSize: 4,
        ),
        const NotificationQueue(
          position: QueuePosition.bottomRight,
          maxStackSize: 3,
        ),
      },
      channels: {
        const NotificationChannel(
          name: 'beta_info',
          description: 'Workspace B Info',
          position: QueuePosition.topCenter,
          defaultDismissDuration: Duration(seconds: 4),
        ),
        const NotificationChannel(
          name: 'beta_alert',
          description: 'Workspace B Critical Alert',
          position: QueuePosition.topCenter,
          defaultDismissDuration: null,
        ),
        const NotificationChannel(
          name: 'beta_task',
          description: 'Workspace B Background Tasks',
          position: QueuePosition.bottomRight,
          defaultDismissDuration: Duration(seconds: 6),
        ),
      },
    );

    _subB?.cancel();
    _subB = _controllerB.events.listen((final event) {
      if (mounted) {
        setState(() {
          _eventsB.insert(0, event);
          if (_eventsB.length > 30) {
            _eventsB.removeLast();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _subA?.cancel();
    _subB?.cancel();
    _controllerA.dispose();
    _controllerB.dispose();
    super.dispose();
  }

  void _toggleMountA() {
    setState(() {
      _isMountedA = !_isMountedA;
      if (!_isMountedA) {
        _subA?.cancel();
        _controllerA.dispose();
      } else {
        _initControllerA();
      }
    });
  }

  void _toggleMountB() {
    setState(() {
      _isMountedB = !_isMountedB;
      if (!_isMountedB) {
        _subB?.cancel();
        _controllerB.dispose();
      } else {
        _initControllerB();
      }
    });
  }

  void _toggleStasisA() {
    if (!_isMountedA) {
      return;
    }
    setState(() {
      _isPausedA = !_isPausedA;
      if (_isPausedA) {
        _controllerA.pauseQueue(QueuePosition.topCenter);
      } else {
        _controllerA.resumeQueue(QueuePosition.topCenter);
      }
    });
  }

  void _toggleStasisB() {
    if (!_isMountedB) {
      return;
    }
    setState(() {
      _isPausedB = !_isPausedB;
      if (_isPausedB) {
        _controllerB.pauseQueue(QueuePosition.topCenter);
      } else {
        _controllerB.resumeQueue(QueuePosition.topCenter);
      }
    });
  }

  void _fireNotificationA({
    required final String channelName,
    required final String title,
    required final String message,
    final bool permanent = false,
    final Duration? dismissDuration,
  }) {
    if (!_isMountedA) {
      return;
    }
    _burstCounterA++;
    _controllerA.show(
      AppNotification(
        id: 'alpha_$_burstCounterA',
        title: title,
        message: message,
        channelName: channelName,
        permanent: permanent,
        dismissDuration: dismissDuration,
        accentColor: const Color(0xFF38BDF8),
      ),
    );
  }

  void _fireNotificationB({
    required final String channelName,
    required final String title,
    required final String message,
    final bool permanent = false,
    final Duration? dismissDuration,
  }) {
    if (!_isMountedB) {
      return;
    }
    _burstCounterB++;
    _controllerB.show(
      AppNotification(
        id: 'beta_$_burstCounterB',
        title: title,
        message: message,
        channelName: channelName,
        permanent: permanent,
        dismissDuration: dismissDuration,
        accentColor: const Color(0xFFA855F7),
      ),
    );
  }

  void _fireConcurrentBurst() {
    if (_isMountedA) {
      for (var i = 1; i <= 3; i++) {
        Future.delayed(Duration(milliseconds: 150 * i), () {
          if (mounted && _isMountedA) {
            _fireNotificationA(
              channelName: 'alpha_info',
              title: 'Workspace A: Task #$i',
              message: 'Concurrently dispatched into Tenant A',
              dismissDuration: const Duration(seconds: 4),
            );
          }
        });
      }
    }

    if (_isMountedB) {
      for (var i = 1; i <= 3; i++) {
        Future.delayed(Duration(milliseconds: 150 * i), () {
          if (mounted && _isMountedB) {
            _fireNotificationB(
              channelName: 'beta_info',
              title: 'Workspace B: Task #$i',
              message: 'Concurrently dispatched into Tenant B',
              dismissDuration: const Duration(seconds: 4),
            );
          }
        });
      }
    }
  }

  void _runStasisStressTest() {
    if (!_isMountedA || !_isMountedB) {
      return;
    }
    // Pause queue in Workspace A
    if (!_isPausedA) {
      _toggleStasisA();
    }
    // Ensure Workspace B is running freely
    if (_isPausedB) {
      _toggleStasisB();
    }

    _fireNotificationA(
      channelName: 'alpha_info',
      title: 'Workspace A (Stasis Frozen)',
      message: 'Queue paused: auto-dismiss timer is held indefinitely.',
      dismissDuration: const Duration(seconds: 4),
    );

    _fireNotificationB(
      channelName: 'beta_info',
      title: 'Workspace B (Freely Ticking)',
      message: 'Queue active: will dismiss automatically after 4 seconds.',
      dismissDuration: const Duration(seconds: 4),
    );
  }

  void _dismissAll() {
    if (_isMountedA) {
      _controllerA.dismissAll(clearBacklog: true);
    }
    if (_isMountedB) {
      _controllerB.dismissAll(clearBacklog: true);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Bar ──
          _buildStageHeader(context, colorScheme, isDark),

          // ── Dual Workspaces ──
          Expanded(
            child: LayoutBuilder(
              builder: (final context, final constraints) {
                final isWide = constraints.maxWidth >= 900;
                if (isWide) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _buildWorkspaceViewport(
                            tenantId: 'Tenant A',
                            title: 'Workspace A (Alpha)',
                            accentColor: const Color(0xFF38BDF8),
                            isMounted: _isMountedA,
                            isPaused: _isPausedA,
                            controller: _isMountedA ? _controllerA : null,
                            events: _eventsA,
                            onToggleMount: _toggleMountA,
                            onToggleStasis: _toggleStasisA,
                            onFireInfo: () => _fireNotificationA(
                              channelName: 'alpha_info',
                              title: 'Build Complete',
                              message: '312 unit tests passed in 1.4s',
                              dismissDuration: const Duration(seconds: 4),
                            ),
                            onFireWarning: () => _fireNotificationA(
                              channelName: 'alpha_task',
                              title: 'Background Sync',
                              message: 'Synchronizing cache to local replica',
                              dismissDuration: const Duration(seconds: 6),
                            ),
                            onFireAlert: () => _fireNotificationA(
                              channelName: 'alpha_alert',
                              title: 'Alpha Critical Incident',
                              message: 'Database connection retry exhausted',
                              permanent: true,
                            ),
                            onFireBurst: () {
                              for (var i = 1; i <= 3; i++) {
                                Future.delayed(
                                  Duration(milliseconds: 150 * i),
                                  () => _fireNotificationA(
                                    channelName: 'alpha_info',
                                    title: 'Burst Alpha #$i',
                                    message: 'High-frequency message $i',
                                    dismissDuration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            },
                            onDismissAll: () =>
                                _controllerA.dismissAll(clearBacklog: true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildWorkspaceViewport(
                            tenantId: 'Tenant B',
                            title: 'Workspace B (Beta)',
                            accentColor: const Color(0xFFA855F7),
                            isMounted: _isMountedB,
                            isPaused: _isPausedB,
                            controller: _isMountedB ? _controllerB : null,
                            events: _eventsB,
                            onToggleMount: _toggleMountB,
                            onToggleStasis: _toggleStasisB,
                            onFireInfo: () => _fireNotificationB(
                              channelName: 'beta_info',
                              title: 'Order Settled',
                              message: 'Invoice #4029 marked paid (\$240.00)',
                              dismissDuration: const Duration(seconds: 4),
                            ),
                            onFireWarning: () => _fireNotificationB(
                              channelName: 'beta_task',
                              title: 'Analytics Export',
                              message: 'Exporting 50k ledger events to CSV',
                              dismissDuration: const Duration(seconds: 6),
                            ),
                            onFireAlert: () => _fireNotificationB(
                              channelName: 'beta_alert',
                              title: 'Beta Security Alert',
                              message: 'Unrecognized login token detected',
                              permanent: true,
                            ),
                            onFireBurst: () {
                              for (var i = 1; i <= 3; i++) {
                                Future.delayed(
                                  Duration(milliseconds: 150 * i),
                                  () => _fireNotificationB(
                                    channelName: 'beta_info',
                                    title: 'Burst Beta #$i',
                                    message: 'High-frequency message $i',
                                    dismissDuration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            },
                            onDismissAll: () =>
                                _controllerB.dismissAll(clearBacklog: true),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Narrow layout
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ListView(
                    children: [
                      SizedBox(
                        height: 520,
                        child: _buildWorkspaceViewport(
                          tenantId: 'Tenant A',
                          title: 'Workspace A (Alpha)',
                          accentColor: const Color(0xFF38BDF8),
                          isMounted: _isMountedA,
                          isPaused: _isPausedA,
                          controller: _isMountedA ? _controllerA : null,
                          events: _eventsA,
                          onToggleMount: _toggleMountA,
                          onToggleStasis: _toggleStasisA,
                          onFireInfo: () => _fireNotificationA(
                            channelName: 'alpha_info',
                            title: 'Build Complete',
                            message: '312 unit tests passed in 1.4s',
                            dismissDuration: const Duration(seconds: 4),
                          ),
                          onFireWarning: () => _fireNotificationA(
                            channelName: 'alpha_task',
                            title: 'Background Sync',
                            message: 'Synchronizing cache to local replica',
                            dismissDuration: const Duration(seconds: 6),
                          ),
                          onFireAlert: () => _fireNotificationA(
                            channelName: 'alpha_alert',
                            title: 'Alpha Critical Incident',
                            message: 'Database connection retry exhausted',
                            permanent: true,
                          ),
                          onFireBurst: () {
                            for (var i = 1; i <= 3; i++) {
                              Future.delayed(
                                Duration(milliseconds: 150 * i),
                                () => _fireNotificationA(
                                  channelName: 'alpha_info',
                                  title: 'Burst Alpha #$i',
                                  message: 'High-frequency message $i',
                                  dismissDuration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                          onDismissAll: () =>
                              _controllerA.dismissAll(clearBacklog: true),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 520,
                        child: _buildWorkspaceViewport(
                          tenantId: 'Tenant B',
                          title: 'Workspace B (Beta)',
                          accentColor: const Color(0xFFA855F7),
                          isMounted: _isMountedB,
                          isPaused: _isPausedB,
                          controller: _isMountedB ? _controllerB : null,
                          events: _eventsB,
                          onToggleMount: _toggleMountB,
                          onToggleStasis: _toggleStasisB,
                          onFireInfo: () => _fireNotificationB(
                            channelName: 'beta_info',
                            title: 'Order Settled',
                            message: 'Invoice #4029 marked paid (\$240.00)',
                            dismissDuration: const Duration(seconds: 4),
                          ),
                          onFireWarning: () => _fireNotificationB(
                            channelName: 'beta_task',
                            title: 'Analytics Export',
                            message: 'Exporting 50k ledger events to CSV',
                            dismissDuration: const Duration(seconds: 6),
                          ),
                          onFireAlert: () => _fireNotificationB(
                            channelName: 'beta_alert',
                            title: 'Beta Security Alert',
                            message: 'Unrecognized login token detected',
                            permanent: true,
                          ),
                          onFireBurst: () {
                            for (var i = 1; i <= 3; i++) {
                              Future.delayed(
                                Duration(milliseconds: 150 * i),
                                () => _fireNotificationB(
                                  channelName: 'beta_info',
                                  title: 'Burst Beta #$i',
                                  message: 'High-frequency message $i',
                                  dismissDuration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                          onDismissAll: () =>
                              _controllerB.dismissAll(clearBacklog: true),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageHeader(
    final BuildContext context,
    final ColorScheme colorScheme,
    final bool isDark,
  ) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.15),
            ),
          ),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.splitscreen_rounded,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'MULTI-TENANT SPLIT-VIEWPORT STAGE',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '1:1 COUPLING INVARIANT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF10B981),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Concurrent controller isolation, independent '
                      'stasis tokens, and zero static singletons',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fire Both Concurrent Action
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text(
                    'FIRE BOTH',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _fireConcurrentBurst,
                ),
                const SizedBox(width: 6),

                // Stasis Stress Test Action
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.hourglass_empty_rounded, size: 15),
                  label: const Text(
                    'STASIS TEST',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _runStasisStressTest,
                ),
                const SizedBox(width: 6),

                // Dismiss All
                IconButton(
                  tooltip: 'Dismiss All Notifications in Both Workspaces',
                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: _dismissAll,
                ),

                if (widget.onClose != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Close Split Stage',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onClose,
                  ),
                ],
              ],
            ),
          ],
        ),
      );

  Widget _buildWorkspaceViewport({
    required final String tenantId,
    required final String title,
    required final Color accentColor,
    required final bool isMounted,
    required final bool isPaused,
    required final NotificationController? controller,
    required final List<NotificationEvent> events,
    required final VoidCallback onToggleMount,
    required final VoidCallback onToggleStasis,
    required final VoidCallback onFireInfo,
    required final VoidCallback onFireWarning,
    required final VoidCallback onFireAlert,
    required final VoidCallback onFireBurst,
    required final VoidCallback onDismissAll,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMounted
              ? accentColor.withValues(alpha: 0.35)
              : colorScheme.outlineVariant.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Simulated Desktop Window Titlebar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Row(
              children: [
                // Mac-style Window Traffic Lights
                InkWell(
                  onTap: onToggleMount,
                  borderRadius: BorderRadius.circular(6),
                  child: Tooltip(
                    message: isMounted
                        ? 'Teardown Viewport (Dispose Controller)'
                        : 'Mount Viewport (Initialize Controller)',
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isMounted
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: isMounted ? onToggleStasis : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Tooltip(
                    message: isPaused
                        ? 'Resume Queue Timers'
                        : 'Freeze Queue Timers (Stasis)',
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isMounted
                            ? (isPaused
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFEAB308))
                            : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: isMounted ? onDismissAll : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Tooltip(
                    message: 'Dismiss All in Workspace',
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isMounted
                            ? const Color(0xFF10B981)
                            : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Title & Identity
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isMounted
                        ? colorScheme.onSurface
                        : colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const Spacer(),

                // Status Pill: Active vs Unmounted
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isMounted
                        ? accentColor.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isMounted ? '1:1 ACTIVE' : 'UNMOUNTED',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isMounted ? accentColor : Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Stasis Pill
                if (isMounted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPaused
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                          : const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isPaused ? 'STASIS FROZEN' : 'TICKING',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isPaused
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981),
                      ),
                    ),
                  ),
                const SizedBox(width: 6),

                // Event count badge
                if (isMounted)
                  Text(
                    '${events.length} events',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),

          // ── Viewport Control Actions Strip ──
          if (isMounted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1A2234) : const Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.12),
                  ),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ActionChip(
                      label: '+ Info',
                      icon: Icons.info_outline,
                      color: accentColor,
                      onTap: onFireInfo,
                    ),
                    const SizedBox(width: 6),
                    _ActionChip(
                      label: '+ Task',
                      icon: Icons.sync_rounded,
                      color: const Color(0xFF10B981),
                      onTap: onFireWarning,
                    ),
                    const SizedBox(width: 6),
                    _ActionChip(
                      label: '+ Alert',
                      icon: Icons.shield_outlined,
                      color: const Color(0xFFEF4444),
                      onTap: onFireAlert,
                    ),
                    const SizedBox(width: 6),
                    _ActionChip(
                      label: '+ Burst',
                      icon: Icons.auto_awesome_motion_rounded,
                      color: const Color(0xFFEC4899),
                      onTap: onFireBurst,
                    ),
                    const SizedBox(width: 6),
                    _ActionChip(
                      label: isPaused ? 'Resume' : 'Pause Stasis',
                      icon: isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: const Color(0xFFF59E0B),
                      onTap: onToggleStasis,
                    ),
                    const SizedBox(width: 6),
                    _ActionChip(
                      label: 'Clear',
                      icon: Icons.clear_all_rounded,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      onTap: onDismissAll,
                    ),
                  ],
                ),
              ),
            ),

          // ── Viewport Canvas Surface ──
          Expanded(
            child: isMounted && controller != null
                ? ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(10),
                    ),
                    child: Overlay(
                      initialEntries: [
                        OverlayEntry(
                          builder: (final context) => NotificationScope(
                            controller: controller,
                            useRootOverlay: false,
                            child: _WorkspaceSurface(
                              tenantId: tenantId,
                              accentColor: accentColor,
                              events: events,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildUnmountedPlaceholder(
                    context,
                    title,
                    colorScheme,
                    onToggleMount,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnmountedPlaceholder(
    final BuildContext context,
    final String title,
    final ColorScheme colorScheme,
    final VoidCallback onRemount,
  ) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.power_off_rounded,
                  size: 32,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$title Unmounted',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Controller & coordinator detached and disposed cleanly.\n'
                'Zero orphan tickers or stream memory leaks.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('REMOUNT VIEWPORT'),
                onPressed: onRemount,
              ),
            ],
          ),
        ),
      );
}

class _WorkspaceSurface extends StatelessWidget {
  const _WorkspaceSurface({
    required this.tenantId,
    required this.accentColor,
    required this.events,
  });

  final String tenantId;
  final Color accentColor;
  final List<NotificationEvent> events;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      ),
      child: Stack(
        children: [
          // Background Watermark / Grid
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.05 : 0.03,
              child: CustomPaint(
                painter: _GridPainter(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),

          // Central Diagnostics Card
          Align(
            alignment: Alignment.center,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tenantId.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Isolated Scope: Local Overlay Bounded\n'
                    'Drag targets & stasis tokens strictly scoped to this '
                    'viewport',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Mini Real-Time Event Log at the bottom of the viewport
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Container(
              height: 100,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.stream_rounded,
                        size: 11,
                        color: accentColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ISOLATED EVENT STREAM',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: accentColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${events.length} events recorded',
                        style: TextStyle(
                          fontSize: 9,
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: events.isEmpty
                        ? Center(
                            child: Text(
                              'Awaiting notifications...',
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: events.length > 5 ? 5 : events.length,
                            itemBuilder: (final context, final index) {
                              final event = events[index];
                              final notif = event.notification;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 1),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getEventColor(event)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        event.runtimeType.toString(),
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                          color: _getEventColor(event),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        notif != null
                                            ? '${notif.title ?? notif.message}'
                                                ' (${notif.id})'
                                            : event.toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _getEventColor(final NotificationEvent event) {
    if (event is NotificationQueued) {
      return const Color(0xFF38BDF8);
    }
    if (event is NotificationUpdated) {
      return const Color(0xFF10B981);
    }
    if (event is NotificationDismissed) {
      return const Color(0xFFEF4444);
    }
    if (event is NotificationPinned) {
      return const Color(0xFFF59E0B);
    }
    if (event is NotificationSnoozed) {
      return const Color(0xFFA855F7);
    }
    if (event is NotificationRelocated) {
      return const Color(0xFF06B6D4);
    }
    return const Color(0xFF64748B);
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.color});
  final Color color;

  @override
  void paint(final Canvas canvas, final Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant final _GridPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// Dialog launcher for the Multi-Tenant Split-Viewport Stage.
class MultiTenantSplitViewportDialog extends StatelessWidget {
  const MultiTenantSplitViewportDialog({super.key});

  /// Displays the Multi-Tenant Split-Viewport Stage in a responsive modal
  /// dialog.
  static Future<void> show(final BuildContext context) => showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (final context) => const MultiTenantSplitViewportDialog(),
      );

  @override
  Widget build(final BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1400,
            maxHeight: 900,
          ),
          child: MultiTenantSplitViewportStage(
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      );
}
