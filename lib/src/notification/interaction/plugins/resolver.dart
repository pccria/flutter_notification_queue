part of 'plugins.dart';

/// Extension defining the resolution mapping from behavior configuration models
/// to their visual and operational execution plugins.
///
/// Keeps the data models inside `lib/src/behaviors/` completely pure and
/// decoupled from visual plugin assets and dependencies.
extension QueueNotificationBehaviorResolver on QueueNotificationBehavior {
  /// Resolves the corresponding UI gesture plugin for this configuration.
  NotificationGesturePlugin resolvePlugin() => switch (this) {
        final Dismiss behavior => DismissGesturePlugin(behavior: behavior),
        final Relocate behavior => RelocateGesturePlugin(behavior: behavior),
        final Reorder behavior => ReorderGesturePlugin(behavior: behavior),
        final ReorderAndRelocate behavior => ReorderRelocateGesturePlugin(
            behavior: behavior,
          ),
        final Snooze behavior => SnoozeGesturePlugin(behavior: behavior),
        final Pin behavior => PinGesturePlugin(behavior: behavior),
        final CustomAction behavior => CustomActionGesturePlugin(
            behavior: behavior,
          ),
        Disabled() => throw UnsupportedError('Disabled behavior has no plugin'),
      };
}
