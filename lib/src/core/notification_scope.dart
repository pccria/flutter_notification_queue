part of 'core.dart';

/// Top-level scope widget binding a [NotificationController] to the Flutter
/// widget tree.
///
/// Wraps its [child] with a [_NotificationScopeData] inherited widget and a
/// [NotificationOverlay] surface using the controller's [QueueCoordinator].
///
/// Usage:
/// ```dart
/// MaterialApp(
///   builder: (context, child) => NotificationScope(
///     controller: notificationController,
///     child: child!,
///   ),
/// );
/// ```
class NotificationScope extends StatefulWidget {
  const NotificationScope({
    required this.controller,
    required this.child,
    super.key,
  });

  /// The notification controller driving this scope.
  final NotificationController controller;

  /// The child widget subtree wrapped by this scope.
  final Widget child;

  /// Returns the nearest [NotificationController] bound in [context].
  ///
  /// Throws a [StateError] if no [NotificationScope] is found in ancestor
  /// tree.
  static NotificationController of(final BuildContext context) {
    final controller = maybeOf(context);
    if (controller == null) {
      throw StateError(
        'No NotificationScope found in context. '
        'Ensure NotificationScope is mounted above context in the widget tree.',
      );
    }
    return controller;
  }

  /// Returns the nearest [NotificationController] bound in [context], or
  /// `null` if none.
  static NotificationController? maybeOf(final BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_NotificationScopeData>()
      ?.controller;

  /// Returns the nearest [QueueCoordinator] bound in [context], or `null` if
  /// none.
  static QueueCoordinator? maybeCoordinatorOf(final BuildContext context) =>
      maybeOf(context)?.coordinator;

  @override
  State<NotificationScope> createState() => _NotificationScopeState();
}

class _NotificationScopeState extends State<NotificationScope> {
  late QueueCoordinator _coordinator;
  StreamSubscription<NotificationEvent>? _eventSub;
  FocusNode? _savedAppFocus;

  @override
  void initState() {
    super.initState();
    _initCoordinator();
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
  }

  void _initCoordinator() {
    _coordinator = QueueCoordinator.fromController(widget.controller);
    widget.controller.attach(_coordinator);
    _eventSub = _coordinator.events.listen((final event) {
      if (event is NotificationDismissed) {
        if (_coordinator.activeNotifications.isEmpty) {
          _restoreAppFocus();
        }
      }
    });
  }

  bool _handleHardwareKey(final KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }

    final a11y = widget.controller.a11yOptions;
    if (a11y.focusShortcut != null &&
        a11y.focusShortcut!.accepts(event, HardwareKeyboard.instance)) {
      _handleFocusShortcut();
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape &&
        _coordinator.isNotificationFocused) {
      _handleGlobalEscape();
      return true;
    }

    return false;
  }

  void _handleFocusShortcut() {
    if (_coordinator.isNotificationFocused) {
      _restoreAppFocus();
      return;
    }

    _savedAppFocus = FocusManager.instance.primaryFocus;
    final focused = _coordinator.focusFirstNotification();
    if (!focused) {
      _restoreAppFocus();
    }
  }

  void _restoreAppFocus() {
    if (widget.controller.a11yOptions.restoreFocusOnExit &&
        _savedAppFocus != null &&
        _savedAppFocus!.canRequestFocus) {
      _savedAppFocus!.requestFocus();
      _savedAppFocus = null;
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      _savedAppFocus = null;
    }
  }

  void _handleGlobalEscape() {
    if (_coordinator.isNotificationFocused) {
      if (widget.controller.a11yOptions.escapeDismissesFocused) {
        _coordinator.dismissNewest();
      }
      _restoreAppFocus();
      return;
    }
    if (widget.controller.a11yOptions.globalEscapeDismiss) {
      _coordinator.dismissNewest();
    }
  }

  void _handleGlobalShiftEscape() {
    _coordinator.dismissAll();
    _restoreAppFocus();
  }

  @override
  void didUpdateWidget(final NotificationScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _eventSub?.cancel();
      oldWidget.controller.detach();
      _coordinator.dispose();
      _initCoordinator();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _eventSub?.cancel();
    widget.controller.detach();
    _coordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final a11y = widget.controller.a11yOptions;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        if (a11y.focusShortcut != null)
          a11y.focusShortcut!: _handleFocusShortcut,
        if (a11y.globalEscapeDismiss) ...{
          const SingleActivator(LogicalKeyboardKey.escape):
              _handleGlobalEscape,
          const SingleActivator(LogicalKeyboardKey.escape, shift: true):
              _handleGlobalShiftEscape,
        },
      },
      child: _NotificationScopeData(
        controller: widget.controller,
        child: NotificationOverlay(
          coordinator: _coordinator,
          child: widget.child,
        ),
      ),
    );
  }
}

class _NotificationScopeData extends InheritedWidget {
  const _NotificationScopeData({
    required this.controller,
    required super.child,
  });

  final NotificationController controller;

  @override
  bool updateShouldNotify(final _NotificationScopeData oldWidget) =>
      controller != oldWidget.controller;
}
