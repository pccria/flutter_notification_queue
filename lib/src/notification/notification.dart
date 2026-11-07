import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

import '../core/core.dart';
import '../enums/enums.dart';
import '../models/offset_pair.dart';
import '../notification_channel/notification_channel.dart';
import '../notification_queue/notification_queue.dart';
import '../types/type_defs.dart';
import '../utils/utils.dart';
import 'theme/notification_theme_data.dart';

export 'theme/notification_theme_data.dart';

part 'app_notification.dart';
part 'interaction/drag_gesture_context.dart';
part 'interaction/gesture_state_machine.dart';
part 'interaction/overlays/dismissal_targets.dart';
part 'interaction/overlays/intent_targets.dart';
part 'interaction/overlays/relocation_targets.dart';
part 'interaction/overlays/reorder_targets.dart';
part 'interaction/plugins/base.dart';
part 'interaction/plugins/custom_action.dart';
part 'interaction/plugins/dismiss.dart';
part 'interaction/plugins/pin.dart';
part 'interaction/plugins/relocate.dart';
part 'interaction/plugins/reorder.dart';
part 'interaction/plugins/reorder_relocate.dart';
part 'interaction/plugins/resolver.dart';
part 'interaction/plugins/snooze.dart';
part 'interaction/widgets/draggable_transitions.dart';
part 'interaction/widgets/feedback_overlays.dart';
part 'interaction/zones/base.dart';
part 'interaction/zones/edges.dart';
part 'interaction/zones/positions.dart';
part 'interaction/zones/resolvers.dart';
part 'interaction/zones/slots.dart';
part 'notification_action.dart';
part 'theme/notification_theme.dart';

/// A widget representing an individual notification card in a queue.
///
/// [NotificationWidget] encapsulates the content (title, message, icon),
/// visual style overrides (colors), behavior overrides (tap, drag), and
/// metadata (priority, groupKey) for a single notification.
///
/// To display a notification, construct a [NotificationWidget] and call [show]:
/// ```dart
/// NotificationWidget(
///   message: 'Successfully saved settings',
///   channelName: 'success',
/// ).show();
/// ```
@internal
@immutable
class NotificationWidget extends StatefulWidget {
  /// Creates a new [NotificationWidget] with the specified content and style
  /// overrides.
  ///
  /// The [message] is required and represents the main text of the
  /// notification.
  ///
  /// Use [channelName] to apply defaults from a registered
  /// [NotificationChannel].
  ///
  /// Override settings like [tapBehavior], [dragBehavior], [dismissDuration],
  /// [color], [backgroundColor], and [foregroundColor] to customize the card's
  /// appearance and behavior.
  ///
  /// Set [permanent] to true to prevent the card from auto-dismissing.
  factory NotificationWidget({
    required final String message,
    final String? id,
    final String channelName = 'default',
    final String? title,
    final QueuePosition? position,
    final NotificationAction? action,
    final TapBehavior? tapBehavior,
    final DragBehavior? dragBehavior,
    final LongPressDragBehavior? longPressDragBehavior,
    final Widget? icon,
    final Color? color,
    final Color? foregroundColor,
    final Color? backgroundColor,
    final Color? accentColor,
    final Duration? dismissDuration,
    final bool permanent = false,
    final NotificationBuilder? builder,
    final NotificationPriority? priority,
    final bool initialIsPinned = false,
    final DateTime? snoozedAt,
    final String? groupKey,
    final ConfigurationManager? configuration,
    final QueueCoordinator? coordinator,
    final NotificationContextMenuBuilder? contextMenuBuilder,
  }) {
    assert(
      dismissDuration == null || dismissDuration > Duration.zero,
      'dismissDuration must be positive or null. '
      'Use permanent: true to keep a notification on screen indefinitely.',
    );
    final config = configuration ??
        coordinator?.configuration ??
        ConfigurationManager(
          queues: {const NotificationQueue()},
          channels: NotificationChannel.standardChannels(),
        );
    final resolvedId =
        id ?? 'notif_${_idCounter++}_${DateTime.now().microsecondsSinceEpoch}';
    final resolvedKey = GlobalObjectKey<NotificationWidgetState>(resolvedId);
    final resolveChannel = config.getChannel(channelName);
    final targetPosition = position ?? resolveChannel.position;
    final effectivePosition = config.getEffectiveQueuePosition(targetPosition);
    final resolvedQueue = config.getQueue(effectivePosition);

    // permanent: true forces null dismiss duration regardless of channel
    // default, allowing a single notification to opt out of auto-dismiss.
    final resolvedDismissDuration = permanent ? null : dismissDuration;

    return NotificationWidget._(
      id: resolvedId,
      key: resolvedKey,
      message: message,
      channelName: channelName,
      channel: resolveChannel,
      queue: resolvedQueue,
      title: title,
      action: action,
      tapBehavior: tapBehavior,
      dragBehavior: dragBehavior,
      longPressDragBehavior: longPressDragBehavior,
      icon: icon,
      color: color,
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
      accentColor: accentColor,
      dismissDuration: resolvedDismissDuration,
      permanent: permanent,
      builder: builder,
      priority: priority,
      initialIsPinned: initialIsPinned,
      snoozedAt: snoozedAt,
      groupKey: groupKey,
      coordinator: coordinator,
      contextMenuBuilder: contextMenuBuilder,
    );
  }
  NotificationWidget._({
    required final GlobalKey<NotificationWidgetState> key,
    required this.message,
    required this.id,
    required this.queue,
    required this.channelName,
    required this.channel,
    this.title,
    this.action,
    this.icon,
    this.color,
    this.foregroundColor,
    this.backgroundColor,
    this.accentColor,
    this.dismissDuration,
    this.permanent = false,
    this.tapBehavior,
    this.dragBehavior,
    this.longPressDragBehavior,
    this.builder,
    this.priority,
    final bool initialIsPinned = false,
    final ValueNotifier<bool>? isPinnedNotifier,
    this.snoozedAt,
    final DateTime? createdAt,
    this.groupKey,
    this.coordinator,
    this.contextMenuBuilder,
  })  : _key = key,
        isPinnedNotifier =
            isPinnedNotifier ?? ValueNotifier<bool>(initialIsPinned),
        createdAt = createdAt ?? DateTime.now();

  /// Gets the effective [QueueCoordinator] for this notification.
  QueueCoordinator get effectiveCoordinator {
    if (coordinator != null) {
      return coordinator!;
    }
    throw StateError(
      'No QueueCoordinator bound to NotificationWidget ($id). '
      'Ensure a coordinator is passed or display notifications via '
      'NotificationController and NotificationScope.',
    );
  }

  static int _idCounter = 0;

  final GlobalKey<NotificationWidgetState> _key;

  @override
  GlobalKey<NotificationWidgetState> get key => _key;

  /// ValueNotifier tracking the pinned status of this notification.
  final ValueNotifier<bool> isPinnedNotifier;

  /// Whether this notification is currently pinned.
  bool get isPinned => isPinnedNotifier.value;
  set isPinned(final bool value) => isPinnedNotifier.value = value;

  /// The timestamp when this notification was snoozed, if any.
  final DateTime? snoozedAt;

  /// The timestamp when this notification was created.
  final DateTime createdAt;

  /// Optional Notification ID
  ///
  /// A unique [GlobalKey] will be provided for [NotificationWidget]
  /// if [id] is provided or not,
  /// but to have more control over [NotificationWidget], you can
  /// set the [id] and use it.
  final String id;

  /// Name of the notification channel.
  ///
  /// Defaults to the system's default [NotificationChannel] if
  /// [channelName] is not registered.
  ///
  final String channelName;

  /// Optional group key for bundling notifications. If null, falls back to
  /// [channelName].
  final String? groupKey;

  /// The resolved group key, falling back to [channelName] if null.
  String get resolvedGroupKey => groupKey ?? channelName;

  /// Notification title
  final String? title;

  /// Notification message Text
  final String message;

  /// Optional [NotificationAction] provides notification with
  /// an action callback
  ///
  /// A [NotificationAction] can be created via [NotificationAction.button].
  final NotificationAction? action;

  /// Per-notification override for the tap behavior.
  ///
  /// When set, this takes precedence over the queue's
  /// [NotificationQueue.tapBehavior]. When null, the queue-level
  /// behavior is used.
  ///
  /// Example — make a single notification show a detail sheet on tap:
  /// ```dart
  /// NotificationWidget(
  ///   message: 'New message from Alice',
  ///   tapBehavior: TapToAct(
  ///     onTap: (n) => showDetailSheet(n),
  ///   ),
  /// )
  /// ```
  final TapBehavior? tapBehavior;

  /// Per-notification override for the drag behavior.
  final DragBehavior? dragBehavior;

  /// Per-notification override for the long-press drag behavior.
  final LongPressDragBehavior? longPressDragBehavior;

  /// Semantic priority rank override for this notification.
  ///
  /// When set, this takes precedence over the channel's default priority.
  final NotificationPriority? priority;

  /// The resolved priority level, falling back to channel default.
  NotificationPriority get resolvedPriority =>
      priority ?? channel.defaultPriority;

  /// Notification [Icon] widget
  ///
  /// An optional [Icon] widget shown besides the [message].
  final Widget? icon;

  /// Notification color.
  ///
  /// Colors notification icon, border, and body filled [QueueStyle]s.
  /// If null, defaults to Notification Channels
  /// [NotificationChannel.defaultColor] and if that's null
  /// [Theme.of(Context).colorScheme.primary].
  @Deprecated(
    'Use theme: NotificationThemeData(color: ...) instead. '
    'Scheduled for removal in v0.6.0.',
  )
  final Color? color;

  /// Notification foreground color.
  ///
  /// Colors notification texts, close, expand and action buttons
  /// and the progressIndicator.
  /// If null, defaults to Notification Channels
  /// [NotificationChannel.defaultForegroundColor] and if that's null
  /// [Theme.of(Context).colorScheme.onSurface].
  @Deprecated(
    'Use theme: NotificationThemeData(foregroundColor: ...) instead. '
    'Scheduled for removal in v0.6.0.',
  )
  final Color? foregroundColor;

  /// Notification background color
  ///
  /// Colors notification body.
  /// If null, defaults to Notification's
  /// [NotificationChannel.defaultBackgroundColor] and if that's not provided
  /// (null value or Unregistered [NotificationChannel]),
  /// [Theme.of(Context).colorScheme.surface].
  @Deprecated(
    'Use theme: NotificationThemeData(backgroundColor: ...) instead. '
    'Scheduled for removal in v0.6.0.',
  )
  final Color? backgroundColor;

  /// Optional experimental accent color override.
  @experimental
  final Color? accentColor;

  /// Notification dismiss duration.
  ///
  /// If `null`, defaults to [NotificationChannel.defaultDismissDuration]. If
  /// that is also null, or if the notification is pinned (`isPinned == true`),
  /// the notification remains permanent until explicitly dismissed.
  final Duration? dismissDuration;

  /// Whether this notification is permanent (immune to auto-dismiss timers).
  final bool permanent;

  final NotificationQueue queue;

  final NotificationChannel channel;

  /// Custom builder for the notification stack indicator.
  final NotificationBuilder? builder;

  /// The [QueueCoordinator] driving this notification instance.
  final QueueCoordinator? coordinator;

  /// Custom context menu builder for right-click and keyboard shortcut.
  final NotificationContextMenuBuilder? contextMenuBuilder;

  /// Converts this [NotificationWidget] back into an [AppNotification] intent.
  AppNotification toNotification() => AppNotification(
        id: id,
        title: title,
        message: message,
        channelName: channelName,
        priority: priority,
        tapBehavior: tapBehavior,
        groupKey: groupKey,
        icon: icon,
        accentColor: accentColor,
        dismissDuration: dismissDuration,
        permanent: permanent,
        builder: builder,
        action: action,
        contextMenuBuilder: contextMenuBuilder,
      );

  void show() => effectiveCoordinator.queue(this);

  Future<void> dismiss() async {
    final state = key.currentState;
    if (state != null) {
      await state.dismiss(reason: DismissReason.programmatic);
    } else {
      effectiveCoordinator.dismissWidget(
        this,
        reason: DismissReason.programmatic,
      );
    }
  }

  NotificationWidget? relocateTo(final QueuePosition position) =>
      effectiveCoordinator.relocateWidget(this, position);

  @override
  State<StatefulWidget> createState() => NotificationWidgetState();

  @override
  String toString({final DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'NotificationWidget('
      'key: $key,'
      ' channel: $channelName,'
      ' title: $title,'
      ' message: $message,'
      ' action: $action,'
      ' icon: $icon,'
      ' backgroundColor: $backgroundColor,'
      ' color: $color,'
      ' dismissDuration: $dismissDuration,'
      ' tapBehavior: $tapBehavior,'
      ' dragBehavior: $dragBehavior,'
      ' longPressDragBehavior: $longPressDragBehavior,'
      ' priority: $priority,'
      ' builder: $builder,)';

  NotificationWidget copyToQueue(
    final NotificationQueue targetQueue,
  ) =>
      NotificationWidget._(
        key: key,
        id: id,
        message: message,
        queue: targetQueue,
        channelName: channelName,
        channel: channel,
        title: title,
        action: action,
        tapBehavior: tapBehavior,
        dragBehavior: dragBehavior,
        longPressDragBehavior: longPressDragBehavior,
        icon: icon,
        color: color,
        foregroundColor: foregroundColor,
        backgroundColor: backgroundColor,
        accentColor: accentColor,
        dismissDuration: dismissDuration,
        permanent: permanent,
        builder: builder,
        priority: priority,
        isPinnedNotifier: isPinnedNotifier,
        snoozedAt: snoozedAt,
        createdAt: createdAt,
        groupKey: groupKey,
        coordinator: coordinator,
      );

  NotificationWidget copyForRequeue({
    final DateTime? snoozedAt,
  }) =>
      NotificationWidget._(
        key: key,
        id: id,
        message: message,
        queue: queue,
        channelName: channelName,
        channel: channel,
        title: title,
        action: action,
        tapBehavior: tapBehavior,
        dragBehavior: dragBehavior,
        longPressDragBehavior: longPressDragBehavior,
        icon: icon,
        color: color,
        foregroundColor: foregroundColor,
        backgroundColor: backgroundColor,
        accentColor: accentColor,
        dismissDuration: dismissDuration,
        permanent: permanent,
        builder: builder,
        priority: priority,
        isPinnedNotifier: isPinnedNotifier,
        snoozedAt: snoozedAt,
        createdAt: createdAt,
        groupKey: groupKey,
        coordinator: coordinator,
      );

  /// Creates a copy of this [NotificationWidget] with updated content and
  /// style fields for in-place mutation, preserving its runtime identity,
  /// creation timestamp, channel, and queue placement.
  NotificationWidget copyForUpdate({
    final String? message,
    final String? title,
    final Widget? icon,
    final NotificationAction? action,
    final NotificationPriority? priority,
    final Color? color,
    final Color? backgroundColor,
    final Color? foregroundColor,
    final Color? accentColor,
    final Duration? dismissDuration,
    final bool? permanent,
  }) {
    final effectivePermanent = permanent ?? this.permanent;
    final effectiveDuration = effectivePermanent
        ? null
        : (dismissDuration ?? this.dismissDuration);

    return NotificationWidget._(
      key: key,
      id: id,
      message: message ?? this.message,
      queue: queue,
      channelName: channelName,
      channel: channel,
      title: title ?? this.title,
      action: action ?? this.action,
      tapBehavior: tapBehavior,
      dragBehavior: dragBehavior,
      longPressDragBehavior: longPressDragBehavior,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      accentColor: accentColor ?? this.accentColor,
      dismissDuration: effectiveDuration,
      permanent: effectivePermanent,
      builder: builder,
      priority: priority ?? this.priority,
      isPinnedNotifier: isPinnedNotifier,
      snoozedAt: snoozedAt,
      createdAt: createdAt,
      groupKey: groupKey,
      coordinator: coordinator,
    );
  }

  /// Converts this [NotificationWidget] back into a lightweight
  /// [AppNotification] payload.
  AppNotification toAppNotification() => AppNotification(
        id: id,
        message: message,
        title: title,
        channelName: channelName,
        action: action,
        tapBehavior: tapBehavior,
        icon: icon,
        accentColor: accentColor,
        dismissDuration: dismissDuration,
        permanent: permanent,
        builder: builder,
        priority: priority,
        groupKey: groupKey,
      );
}

/// The active state of a [NotificationWidget].
///
/// This state manages the notification's lifecycle, gesture detection, timers,
/// and entrance/exit transitions.
@internal
class NotificationWidgetState extends State<NotificationWidget>
    with TickerProviderStateMixin {
  late NotificationTheme theme;

  /// Caches the brightness last used to resolve the theme so that
  /// [didChangeDependencies] can skip re-resolving on every inherited
  /// widget change that does not affect colours (e.g. window resize).
  Brightness? _lastBrightness;

  Duration? get resolvedDismissDuration {
    if (widget.isPinned || widget.permanent) {
      return null;
    }
    return widget.dismissDuration ?? widget.channel.defaultDismissDuration;
  }

  bool get hasTitle => widget.title != null;

  bool get hasButtonAction =>
      widget.action != null &&
      widget.action!.type == NotificationActionType.button;

  /// Resolves the effective tap behavior for this notification.
  ///
  /// The notification's own [NotificationWidget.tapBehavior] takes precedence
  /// over the queue-level [NotificationQueue.tapBehavior].
  TapBehavior get _resolvedTapBehavior {
    // 1. Per-notification override wins.
    if (widget.tapBehavior != null) {
      return widget.tapBehavior!;
    }
    // 2. Queue-level default.
    return widget.queue.tapBehavior;
  }

  /// Whether user expanded the notification.
  ///
  /// An expanded notification will not be dismissed using [dismissTimer].
  final ValueNotifier<bool> isExpanded = ValueNotifier(false);

  AnimationController? _dismissProgressController;
  bool _isMouseHovering = false;
  bool _isDragPaused = false;
  TapDownDetails? _lastSecondaryTapDown;
  static final Timer _dummyTimer = Timer(Duration.zero, () {});
  Timer? get dismissTimer =>
      _dismissProgressController != null ? _dummyTimer : null;

  late final AnimationController animationController;
  late final FocusNode _focusNode;

  /// Whether this notification card currently holds keyboard focus.
  bool get isFocused => _focusNode.hasFocus;

  /// Requests keyboard focus onto this notification card.
  void requestFocus() => _focusNode.requestFocus();

  void _handleFocusChanged() {
    if (mounted) {
      if (widget.queue.closeButtonBehavior is! Hidden) {
        if (_focusNode.hasFocus) {
          _showCloseButton.value = 1.0;
        } else {
          _showCloseButton.value = widget.queue.closeButtonBehavior
              .onHover(isHovering: _isMouseHovering);
        }
      }
      setState(() {});
    }
  }

  static final _logger = Logger.get('fnq.Notification');

  @override
  void initState() {
    _logger.debugBuffer
      ?..writeln('Created State.')
      ..sink();
    super.initState();
    _focusNode = FocusNode(debugLabel: 'NotificationCard_${widget.id}')
      ..addListener(_handleFocusChanged);
    _showCloseButton.value = widget.queue.closeButtonBehavior.initialOpacity;
    // NOTE: The entry/exit animation for this notification is driven by the
    // QueueWidget's item-level AnimationController (via
    // QueueWidget._buildItem).
    // This controller is intentionally NOT forwarded here to avoid a
    // redundant active ticker that would block pumpAndSettle() in tests.
    // It is kept as a TickerProvider placeholder and may be used for future
    // internal animations.
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      animationBehavior: AnimationBehavior.preserve,
      reverseDuration: const Duration(milliseconds: 240),
    )..value = 1.0;

    widget.isPinnedNotifier.addListener(_handlePinChanged);
    if (NotificationTimerScope.isEnabledNonSubscribing(context)) {
      initDismissTimer();
    }
  }

  @override
  void didChangeDependencies() {
    // Only re-resolve the theme when the platform brightness actually
    // changes. Skipping on every inherited-widget notification prevents
    // a full NotificationTheme reconstruction on each resize frame.
    final brightness = Theme.of(context).brightness;
    if (brightness != _lastBrightness) {
      _lastBrightness = brightness;
      theme = NotificationTheme.resolveWith(
        context,
        widget.queue.style,
        widget,
      );
    }

    final timerAllowed = NotificationTimerScope.isEnabled(context);
    if (!timerAllowed) {
      ditchDismissTimer();
    } else if (_dismissProgressController == null &&
        !widget.isPinned &&
        !isExpanded.value &&
        !_isMouseHovering &&
        !_isDragPaused) {
      initDismissTimer();
    }

    _logger.debugBuffer
      ?..writeAll([
        'NotificationState: $this',
      ])
      ..sink();

    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(final NotificationWidget oldWidget) {
    _logger.debugBuffer
      ?..writeAll(['oldWidget: $oldWidget', 'newWidget: $widget'])
      ..sink();
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPinnedNotifier != widget.isPinnedNotifier) {
      oldWidget.isPinnedNotifier.removeListener(_handlePinChanged);
      widget.isPinnedNotifier.addListener(_handlePinChanged);
    }
    if (oldWidget.accentColor != widget.accentColor ||
        oldWidget.queue.style != widget.queue.style ||
        // ignore: deprecated_member_use_from_same_package
        oldWidget.color != widget.color ||
        // ignore: deprecated_member_use_from_same_package
        oldWidget.backgroundColor != widget.backgroundColor ||
        // ignore: deprecated_member_use_from_same_package
        oldWidget.foregroundColor != widget.foregroundColor) {
      theme = NotificationTheme.resolveWith(
        context,
        widget.queue.style,
        widget,
      );
    }
    if (oldWidget.permanent != widget.permanent ||
        oldWidget.dismissDuration != widget.dismissDuration) {
      if (widget.permanent || widget.isPinned) {
        ditchDismissTimer();
      } else if (resolvedDismissDuration != null) {
        if (_dismissProgressController == null) {
          initDismissTimer();
        } else {
          _dismissProgressController!.duration = resolvedDismissDuration;
        }
      }
    }
  }

  void _handlePinChanged() {
    if (widget.isPinned) {
      ditchDismissTimer();
    } else {
      initDismissTimer();
    }
    if (mounted) {
      setState(() {});
    }
  }

  QueueCoordinator get coordinator {
    final c =
        widget.coordinator ?? NotificationScope.maybeCoordinatorOf(context);
    if (c == null) {
      throw StateError(
        'No QueueCoordinator available for NotificationWidget. '
        'Ensure your app or test tree is wrapped in a NotificationScope or '
        'pass a coordinator explicitly.',
      );
    }
    return c;
  }

  Future<void> dismiss({
    final DismissReason reason = DismissReason.programmatic,
  }) async {
    await animationController.reverse();
    coordinator.dismissWidget(widget, reason: reason);
    _logger.debugBuffer
      ?..writeAll(['Dismissed.'])
      ..sink();
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    widget.isPinnedNotifier.removeListener(_handlePinChanged);
    ditchDismissTimer();
    animationController.dispose();
    isExpanded.dispose();
    _logger.debugBuffer
      ?..writeln('Disposed')
      ..sink();

    super.dispose();
  }

  void initDismissTimer() {
    if (_isDragPaused) {
      return;
    }
    if (mounted && !NotificationTimerScope.isEnabledNonSubscribing(context)) {
      ditchDismissTimer();
      return;
    }
    if (resolvedDismissDuration != null) {
      if (_dismissProgressController == null) {
        _dismissProgressController = AnimationController(
          vsync: this,
          duration: resolvedDismissDuration,
        );
        _dismissProgressController!.addStatusListener((final status) {
          if (status == AnimationStatus.completed) {
            if (mounted && !isExpanded.value) {
              dismiss(reason: DismissReason.timeout);
            }
          }
        });
      } else {
        _dismissProgressController!.duration = resolvedDismissDuration;
      }
      _dismissProgressController!.reset();
      _dismissProgressController!.forward();
    }
  }

  void ditchDismissTimer() {
    _dismissProgressController?.stop(canceled: false);
    _dismissProgressController?.dispose();
    _dismissProgressController = null;
  }

  /// Pauses the auto-dismiss timer (e.g. while being dragged or hovered).
  void pauseDismissTimer() {
    _isDragPaused = true;
    _dismissProgressController?.stop(canceled: false);
  }

  /// Resumes the auto-dismiss timer if not paused by expansion or hover.
  void resumeDismissTimer() {
    _isDragPaused = false;
    if (!_isMouseHovering && !isExpanded.value) {
      if (_dismissProgressController != null) {
        _dismissProgressController!.forward();
      } else {
        initDismissTimer();
      }
    }
  }

  void _toggleExpanded() {
    isExpanded.value = !isExpanded.value;

    if (isExpanded.value) {
      _dismissProgressController?.stop(canceled: false);
    } else if (!_isMouseHovering) {
      _dismissProgressController?.forward();
    }
    if (mounted) {
      setState(() {});
    }
  }

  KeyEventResult _handleCardKeyEvent(
    final FocusNode node,
    final KeyEvent event,
  ) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final a11y = coordinator.configuration.a11yOptions;

    // Shift + Delete or Shift + Backspace dismisses the active bundle/group.
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    if (a11y.enableKeyboardDismiss &&
        isShift &&
        (event.logicalKey == a11y.dismissKey ||
            event.logicalKey == LogicalKeyboardKey.backspace)) {
      coordinator.dismissGroup(
        widget.resolvedGroupKey,
        reason: DismissReason.programmatic,
      );
      return KeyEventResult.handled;
    }

    if (a11y.enableKeyboardDismiss) {
      if (event.logicalKey == a11y.dismissKey ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
        dismiss(reason: DismissReason.programmatic);
        return KeyEventResult.handled;
      }

      if (a11y.escapeDismissesFocused &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        dismiss(reason: DismissReason.programmatic);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _focusNode.unfocus();
      return KeyEventResult.handled;
    }

    // Toggle card expansion (E).
    if (event.logicalKey == LogicalKeyboardKey.keyE) {
      _toggleExpanded();
      return KeyEventResult.handled;
    }

    // Toggle pinned state (P).
    if (event.logicalKey == LogicalKeyboardKey.keyP) {
      if (widget.isPinned) {
        coordinator.unpinById(widget.id);
      } else {
        coordinator.pinById(widget.id);
      }
      return KeyEventResult.handled;
    }

    // Snooze notification (S).
    if (event.logicalKey == LogicalKeyboardKey.keyS) {
      final snoozeDuration = widget.dismissDuration ??
          widget.channel.defaultDismissDuration ??
          const Duration(seconds: 10);
      coordinator.snoozeById(widget.id, snoozeDuration);
      return KeyEventResult.handled;
    }

    // Context menu shortcut (Shift + F10 or ContextMenu key).
    if (a11y.enableContextMenu &&
        (event.logicalKey == LogicalKeyboardKey.contextMenu ||
            (isShift && event.logicalKey == LogicalKeyboardKey.f10))) {
      final renderBox = context.findRenderObject() as RenderBox?;
      final center = renderBox != null
          ? renderBox.localToGlobal(renderBox.size.center(Offset.zero))
          : Offset.zero;
      _openContextMenu(center);
      return KeyEventResult.handled;
    }

    // Enter triggers the primary action if available, or card tap behavior.
    // Space is intentionally not handled here so it activates focused inner
    // elements (buttons, icons) when cycling through them via Tab.
    if (node.hasPrimaryFocus &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      if (widget.action != null) {
        widget.action!.onPressed();
        dismiss(reason: DismissReason.userTap);
        return KeyEventResult.handled;
      }

      switch (_resolvedTapBehavior) {
        case TapDisabled():
          break;
        case TapToDismiss():
          coordinator.emitTapped(
            notification: widget,
            behavior: _resolvedTapBehavior,
          );
          dismiss(reason: DismissReason.userTap);
          return KeyEventResult.handled;
        case TapToExpand():
          coordinator.emitTapped(
            notification: widget,
            behavior: _resolvedTapBehavior,
          );
          _toggleExpanded();
          return KeyEventResult.handled;
        case TapToAct(:final onTap, :final dismissOnAct):
          coordinator.emitTapped(
            notification: widget,
            behavior: _resolvedTapBehavior,
          );
          onTap();
          if (dismissOnAct) {
            dismiss(reason: DismissReason.userTap);
          }
          return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final queueState =
          coordinator.getWidgetKey(widget.queue.position).currentState;
      queueState?.focusNext(widget.id);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final queueState =
          coordinator.getWidgetKey(widget.queue.position).currentState;
      queueState?.focusPrevious(widget.id);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _openContextMenu(final Offset globalPosition) async {
    final a11y = coordinator.configuration.a11yOptions;
    if (!a11y.enableContextMenu) {
      return;
    }

    _dismissProgressController?.stop(canceled: false);

    final position = RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      globalPosition.dx,
      globalPosition.dy,
    );

    final List<PopupMenuEntry<void>> items;
    if (widget.contextMenuBuilder != null) {
      items = widget.contextMenuBuilder!(
        context,
        widget.toNotification(),
        coordinator.controller,
      );
    } else {
      items = _buildDefaultContextMenuItems();
    }

    try {
      await showMenu<void>(
        context: context,
        position: position,
        items: items,
        elevation: 6,
      );
    } finally {
      if (mounted &&
          !_isMouseHovering &&
          !widget.isPinned &&
          !isExpanded.value) {
        _dismissProgressController?.forward();
      }
    }
  }

  List<PopupMenuEntry<void>> _buildDefaultContextMenuItems() => [
        PopupMenuItem<void>(
          onTap: () {
            if (widget.isPinned) {
              coordinator.unpinById(widget.id);
            } else {
              coordinator.pinById(widget.id);
            }
          },
          child: Row(
            children: [
              Icon(
                widget.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(widget.isPinned ? 'Unpin' : 'Pin'),
            ],
          ),
        ),
        PopupMenuItem<void>(
          onTap: () {
            final snoozeDuration = widget.dismissDuration ??
                widget.channel.defaultDismissDuration ??
                const Duration(seconds: 10);
            coordinator.snoozeById(widget.id, snoozeDuration);
          },
          child: const Row(
            children: [
              Icon(Icons.snooze_rounded, size: 18),
              SizedBox(width: 8),
              Text('Snooze'),
            ],
          ),
        ),
        PopupMenuItem<void>(
          onTap: () {
            Clipboard.setData(ClipboardData(text: widget.message));
          },
          child: const Row(
            children: [
              Icon(Icons.copy_rounded, size: 18),
              SizedBox(width: 8),
              Text('Copy Message'),
            ],
          ),
        ),
        if (widget.action != null && widget.action!.label != null)
          PopupMenuItem<void>(
            onTap: () {
              widget.action!.onPressed();
              dismiss(reason: DismissReason.userTap);
            },
            child: Row(
              children: [
                const Icon(Icons.touch_app_rounded, size: 18),
                const SizedBox(width: 8),
                Text(widget.action!.label!),
              ],
            ),
          ),
        PopupMenuItem<void>(
          onTap: () {
            dismiss(reason: DismissReason.userTap);
          },
          child: const Row(
            children: [
              Icon(Icons.close_rounded, size: 18),
              SizedBox(width: 8),
              Text('Dismiss'),
            ],
          ),
        ),
      ];

  @override
  // The transition animation is already applied by QueueWidget._buildItem using
  // the queue-level item AnimationController. Applying it again here would
  // create a double-transition and an extra active ticker that hangs tests.
  Widget build(final BuildContext context) {
    final title = widget.title;
    final message = widget.message;
    final semanticLabel = title != null && title.isNotEmpty
        ? 'Notification: $title, $message'
        : 'Notification: $message';

    return Semantics(
      container: true,
      focused: _focusNode.hasFocus,
      label: semanticLabel,
      hint: 'Press Delete or Escape to dismiss. '
          'Press Enter to act, E to expand, P to pin, '
          'or Tab to reach action buttons.',
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Dismiss'): () {
          dismiss(reason: DismissReason.programmatic);
        },
        CustomSemanticsAction(
          label: isExpanded.value ? 'Collapse' : 'Expand',
        ): _toggleExpanded,
        CustomSemanticsAction(
          label: widget.isPinned ? 'Unpin' : 'Pin',
        ): () {
          if (widget.isPinned) {
            coordinator.unpinById(widget.id);
          } else {
            coordinator.pinById(widget.id);
          }
        },
        const CustomSemanticsAction(label: 'Snooze'): () {
          final snoozeDuration = widget.dismissDuration ??
              widget.channel.defaultDismissDuration ??
              const Duration(seconds: 10);
          coordinator.snoozeById(widget.id, snoozeDuration);
        },
        if (widget.action != null && widget.action!.label != null)
          CustomSemanticsAction(label: widget.action!.label!): () {
            widget.action!.onPressed();
          },
      },
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleCardKeyEvent,
        child: _buildNotification(),
      ),
    );
  }

  Widget _buildNotification() => Directionality(
        textDirection: Utils.estimateDirectionOfText(
          widget.title ?? widget.message,
        ),
        child: ValueListenableBuilder(
          valueListenable: isExpanded,
          builder: (final context, final isExpanded, final child) {
            final useBlur = theme.opacity < 1.0;
            final isFocused = _focusNode.hasFocus;
            final ShapeBorder? effectiveShape;
            if (isFocused) {
              final focusColor = theme.color != Colors.transparent
                  ? theme.color
                  : Theme.of(context).colorScheme.primary;
              final baseShape = theme.shape;
              if (baseShape is RoundedRectangleBorder) {
                effectiveShape = baseShape.copyWith(
                  side: BorderSide(
                    color: focusColor,
                    width: 2.5,
                  ),
                );
              } else {
                effectiveShape = RoundedRectangleBorder(
                  borderRadius: theme.borderRadius,
                  side: BorderSide(
                    color: focusColor,
                    width: 2.5,
                  ),
                );
              }
            } else {
              effectiveShape = theme.shape;
            }

            final content = Material(
              shape: effectiveShape,
              borderOnForeground: true,
              type: MaterialType.canvas,
              color: theme.backgroundColor.withValues(alpha: theme.opacity),
              child: Listener(
                onPointerDown: (final _) {
                  _dismissProgressController?.stop(canceled: false);
                },
                onPointerUp: (final _) {
                  if (!_isMouseHovering && !isExpanded) {
                    _dismissProgressController?.forward();
                  }
                },
                child: MouseRegion(
                  onEnter: (final _) {
                    _isMouseHovering = true;
                    _showCloseButton.value = widget.queue.closeButtonBehavior
                        .onHover(isHovering: true);
                    _dismissProgressController?.stop(canceled: false);
                  },
                  onExit: (final _) {
                    _isMouseHovering = false;
                    _showCloseButton.value = widget.queue.closeButtonBehavior
                        .onHover(isHovering: false);
                    if (!isExpanded) {
                      _dismissProgressController?.forward();
                    }
                  },
                  child: InkWell(
                    onSecondaryTapDown: (final details) {
                      _lastSecondaryTapDown = details;
                    },
                    onSecondaryTap: () {
                      if (_lastSecondaryTapDown != null) {
                        _openContextMenu(_lastSecondaryTapDown!.globalPosition);
                      }
                    },
                    onTap: switch (_resolvedTapBehavior) {
                      TapDisabled() =>
                        () {}, // Intercept tap to prevent drag FSM reset
                      TapToDismiss() => () {
                          coordinator.emitTapped(
                            notification: widget,
                            behavior: _resolvedTapBehavior,
                          );
                          dismiss(reason: DismissReason.userTap);
                        },
                      TapToExpand() => () {
                          coordinator.emitTapped(
                            notification: widget,
                            behavior: _resolvedTapBehavior,
                          );
                          _toggleExpanded();
                        },
                      TapToAct(:final onTap, :final dismissOnAct) => () {
                          coordinator.emitTapped(
                            notification: widget,
                            behavior: _resolvedTapBehavior,
                          );
                          onTap();
                          if (dismissOnAct) {
                            dismiss(reason: DismissReason.userTap);
                          }
                        },
                    },
                    child: ConstrainedBox(
                      // NOTE: Using a plain ConstrainedBox (not
                      // AnimatedContainer) because the constraints only
                      // change during window resize. Running dozens of
                      // 220 ms animations concurrently during resize was
                      // the primary cause of CPU spikes and crashes.
                      constraints: Utils.horizontalConstraints(
                        context,
                        widget.queue.maxWidth,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: theme.border,
                        ),
                        child: Padding(
                          padding: theme.padding ??
                              EdgeInsetsDirectional.symmetric(
                                vertical: isExpanded ? 8 : 4,
                                horizontal: 4,
                              ),
                          child: Column(
                            spacing: 4,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                spacing: 4,
                                children: [
                                  _getExpandButton(isExpanded: isExpanded),
                                  Expanded(
                                    child: _getTitle(isExpanded: isExpanded),
                                  ),
                                  _getCloseButton(isExpanded: true),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsetsGeometry.symmetric(
                                  horizontal: 12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 8,
                                  children: [
                                    IconTheme(
                                      data: theme.iconTheme ??
                                          IconThemeData(
                                            color: theme.color,
                                            size: 24,
                                          ),
                                      child: widget.icon ??
                                          widget.channel.defaultIcon ??
                                          const SizedBox.shrink(),
                                    ),
                                    Expanded(
                                      child: Text(
                                        widget.message,
                                        style: theme.messageTextStyle ??
                                            theme.themeData.textTheme.bodyMedium
                                                ?.copyWith(
                                              color: theme.foregroundColor,
                                            ),
                                        maxLines: isExpanded ? 10 : 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _getActionButton(),
                              _timerIndicator(isExpanded: isExpanded),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );

            // Conditionally omit BackdropFilter entirely when opacity == 1.0.
            // Even `enabled: false` installs a compositing layer and can
            // schedule continuous frames in the test environment, permanently
            // blocking pumpAndSettle().
            return ClipRRect(
              borderRadius: theme.borderRadius,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                child: useBlur
                    ? BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                        child: content,
                      )
                    : content,
              ),
            );
          },
        ),
      );

  Widget _getTitle({required final bool isExpanded}) => hasTitle
      ? Directionality(
          textDirection: Utils.estimateDirectionOfText(widget.title ?? ''),
          child: Text(
            widget.title ?? '',
            style: theme.titleTextStyle ??
                theme.themeData.textTheme.titleMedium?.copyWith(
                  color: theme.foregroundColor,
                  fontWeight: FontWeight.bold,
                ),
            maxLines: isExpanded ? 5 : null,
            overflow: TextOverflow.ellipsis,
          ),
        )
      : const SizedBox.shrink();

  Widget _getActionButton() => hasButtonAction
      ? Container(
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextButton(
            focusNode: widget.action!.focusNode,
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              visualDensity: VisualDensity.compact,
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadiusGeometry.circular(4),
                ),
              ),
            ),
            child: Text(
              widget.action!.label!,
              style: theme.actionTextStyle ??
                  theme.themeData.textTheme.labelMedium
                      ?.copyWith(color: theme.foregroundColor),
            ),
            onPressed: () {
              widget.action!.onPressed();
              dismiss();
            },
          ),
        )
      : const SizedBox.shrink();

  Widget _timerIndicator({required final bool isExpanded}) =>
      _dismissProgressController != null && !isExpanded
          ? AnimatedBuilder(
              animation: _dismissProgressController!,
              builder: (final context, final child) => Padding(
                padding: const EdgeInsetsGeometry.only(
                  right: 4,
                  left: 4,
                ),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.foregroundColor.withValues(alpha: 0.5),
                  ),
                  backgroundColor: theme.backgroundColor,
                  value: _dismissProgressController!.value,
                ),
              ),
            )
          : const SizedBox.shrink();

  Widget _getExpandButton({required final bool isExpanded}) {
    final isBottom = widget.queue.verticalDirection == VerticalDirection.up;
    final expandMoreIcon = isBottom ? Icons.expand_less : Icons.expand_more;
    final expandLessIcon = isBottom ? Icons.expand_more : Icons.expand_less;
    return SizedBox.square(
      dimension: 32,
      child: Center(
        child: IconButton(
          alignment: AlignmentGeometry.center,
          padding: EdgeInsets.zero,
          icon: Icon(
            isExpanded ? expandLessIcon : expandMoreIcon,
            color: theme.foregroundColor,
          ),
          visualDensity: VisualDensity.compact,
          onPressed: _toggleExpanded,
        ),
      ),
    );
  }

  final _showCloseButton = ValueNotifier(0.0);

  Widget _getCloseButton({required final bool isExpanded}) => SizedBox.square(
        dimension: 24,
        child: ValueListenableBuilder(
          valueListenable: _showCloseButton,
          builder: (final context, final opacity, final child) =>
              ExcludeFocus(
            excluding: opacity == 0.0,
            child: IgnorePointer(
              ignoring: opacity == 0.0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                opacity: opacity,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onPressed: dismiss,
                  iconSize: 18,
                  icon: Icon(
                    Icons.close,
                    color: theme.foregroundColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Scope widget controlling whether dismiss timers are allowed to run for
/// descendant [NotificationWidget]s.
///
/// When [enabled] is false (e.g. for peek cards underneath lifted group
/// representatives or paused bundles), descendant notifications ditch their
/// dismiss timers and remain in a dormant state.
@internal
class NotificationTimerScope extends InheritedWidget {
  const NotificationTimerScope({
    required this.enabled,
    required super.child,
    super.key,
  });

  final bool enabled;

  static bool isEnabled(final BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NotificationTimerScope>()
          ?.enabled ??
      true;

  static bool isEnabledNonSubscribing(final BuildContext context) =>
      context
          .getInheritedWidgetOfExactType<NotificationTimerScope>()
          ?.enabled ??
      true;

  @override
  bool updateShouldNotify(covariant final NotificationTimerScope oldWidget) =>
      enabled != oldWidget.enabled;
}
