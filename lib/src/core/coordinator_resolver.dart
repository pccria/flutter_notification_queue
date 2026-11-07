part of 'core.dart';

/// A mixin providing unified resolution of the effective [QueueCoordinator].
///
/// Looks up `explicitCoordinator` first, then falls back to the ambient
/// [NotificationScope] in the widget tree. Throws a clear, actionable
/// [StateError] if no coordinator can be found.
@internal
mixin CoordinatorResolver<T extends StatefulWidget> on State<T> {
  /// Resolves the effective [QueueCoordinator].
  ///
  /// Throws a [StateError] specifying `callerName` if neither an explicit
  /// coordinator nor an ambient [NotificationScope] is present.
  QueueCoordinator resolveCoordinator({
    final QueueCoordinator? explicitCoordinator,
    final String? callerName,
  }) {
    final coordinator = explicitCoordinator ??
        NotificationScope.maybeCoordinatorOf(context);
    if (coordinator == null) {
      final name = callerName ?? widget.runtimeType.toString();
      throw StateError(
        'No QueueCoordinator available for $name. '
        'Ensure your app or test tree is wrapped in a NotificationScope or '
        'pass a coordinator explicitly.',
      );
    }
    return coordinator;
  }
}
