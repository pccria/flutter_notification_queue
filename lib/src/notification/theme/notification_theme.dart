import 'package:flutter/material.dart';

import '../../notification_channel/notification_channel.dart';
import '../../notification_queue/notification_queue.dart';
import 'notification_theme_data.dart';

/// An interface for objects providing channel and accent color overrides to
/// [NotificationTheme.resolveWith].
abstract interface class NotificationThemeTarget {
  /// The channel for cascading theme resolution.
  NotificationChannel? get channel;

  /// The per-notification accent color override.
  Color? get accentColor;
}

/// Runtime resolved theme for an in-app notification card.
@immutable
class NotificationTheme {
  const NotificationTheme._({
    required this.themeData,
    required this.color,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.shadowColor,
    required this.elevation,
    required this.opacity,
    required this.borderRadius,
    required this.shape,
    required this.border,
    this.padding,
    this.borderWidth,
    this.titleTextStyle,
    this.messageTextStyle,
    this.actionTextStyle,
    this.iconTheme,
    this.theme,
  });

  factory NotificationTheme.resolveWith(
    final BuildContext context,
    final QueueStyle style, [
    final NotificationThemeTarget? notification,
    final NotificationChannel? channel,
    final Color? accentColor,
  ]) {
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;
    final ambientExtension = themeData.extension<NotificationThemeData>();

    // 1. Structural Archetype (Style belongs exclusively to the Queue):
    final effectiveStyle = style;

    // 2. Cascade theme tokens:
    final effectiveChannel = notification?.channel ?? channel;
    final cTheme = effectiveChannel?.theme;

    final tokenColor = accentColor ??
        notification?.accentColor ??
        cTheme?.color ??
        ambientExtension?.color;
    final tokenShadowColor = themeData.shadowColor;
    final titleTextStyle =
        cTheme?.titleTextStyle ?? ambientExtension?.titleTextStyle;
    final messageTextStyle =
        cTheme?.messageTextStyle ?? ambientExtension?.messageTextStyle;
    final actionTextStyle =
        cTheme?.actionTextStyle ?? ambientExtension?.actionTextStyle;
    final iconTheme = cTheme?.iconTheme ?? ambientExtension?.iconTheme;

    // Fallbacks to deprecated scalar color properties:
    // ignore: deprecated_member_use_from_same_package
    final fallbackColor = effectiveChannel?.defaultColor;

    final candidateColor = tokenColor ?? fallbackColor;

    final Color color;
    final Color backgroundColor;
    final Color foregroundColor;
    final ShapeBorder? shapeBorder;
    final BoxBorder? border;
    final opacity = effectiveStyle.opacity;
    final tokenBorderRadius = effectiveStyle.borderRadius;
    final tokenBorderWidth = effectiveStyle.borderWidth;
    final tokenElevation = effectiveStyle.elevation;

    switch (effectiveStyle) {
      case FilledQueueStyle():
        color = candidateColor ?? colorScheme.primary;
        backgroundColor = color;
        foregroundColor = (backgroundColor.computeLuminance() > 0.5
            ? Colors.black
            : Colors.white);
        shapeBorder = RoundedSuperellipseBorder(
          borderRadius: tokenBorderRadius,
        );
        border = null;

      case OutlinedQueueStyle():
        color = candidateColor ?? colorScheme.primary;
        foregroundColor = colorScheme.onSurface;
        backgroundColor = colorScheme.surface;
        shapeBorder = RoundedRectangleBorder(
          borderRadius: tokenBorderRadius,
          side: BorderSide(
            color: color,
            width: tokenBorderWidth ?? 1.0,
          ),
        );
        border = null;

      case FlatQueueStyle():
        color = candidateColor ?? colorScheme.primary;
        foregroundColor = colorScheme.onSurface;
        backgroundColor = colorScheme.surface;
        shapeBorder = RoundedRectangleBorder(
          borderRadius: tokenBorderRadius,
        );
        border = BorderDirectional(
          start: BorderSide(
            color: color,
            width: tokenBorderWidth ?? 4.0,
          ),
        );
    }

    final resolvedIconTheme = (iconTheme ?? const IconThemeData()).copyWith(
      color: iconTheme?.color ??
          (effectiveStyle is FilledQueueStyle ? foregroundColor : color),
    );

    return NotificationTheme._(
      themeData: themeData,
      color: color,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      shadowColor: tokenShadowColor,
      borderRadius: tokenBorderRadius,
      elevation: tokenElevation,
      opacity: opacity,
      border: border,
      shape: shapeBorder,
      padding: effectiveStyle.padding,
      borderWidth: tokenBorderWidth,
      titleTextStyle: titleTextStyle,
      messageTextStyle: messageTextStyle,
      actionTextStyle: actionTextStyle,
      iconTheme: resolvedIconTheme,
      theme: cTheme ?? ambientExtension,
    );
  }

  final ThemeData themeData;

  /// Notification color.
  ///
  /// Colors icon, borders, filled [QueueStyle]s' background color.
  final Color color;

  /// Notification foreground color.
  ///
  /// Colors notification texts, close, expand and action buttons,
  /// progressIndicator, etc.
  final Color foregroundColor;

  /// Notification background color.
  ///
  /// Colors notification body. Filled styles will ignore this and replace it
  /// with [color].
  final Color backgroundColor;

  /// Notification shadow color, derived from [ThemeData.shadowColor] or tokens.
  final Color shadowColor;

  final ShapeBorder? shape;
  final BoxBorder? border;
  final double elevation;
  final double opacity;
  final BorderRadiusGeometry borderRadius;

  /// Card internal content padding defined by the [QueueStyle].
  final EdgeInsetsGeometry? padding;

  /// Card border stroke width defined by the [QueueStyle].
  final double? borderWidth;

  /// Typography styling override for the notification title.
  final TextStyle? titleTextStyle;

  /// Typography styling override for the notification message.
  final TextStyle? messageTextStyle;

  /// Typography styling override for the action button label.
  final TextStyle? actionTextStyle;

  /// Icon theme override for the leading icon.
  final IconThemeData? iconTheme;

  /// Effective [NotificationThemeData] token bundle resolved for this
  /// notification.
  final NotificationThemeData? theme;
}
