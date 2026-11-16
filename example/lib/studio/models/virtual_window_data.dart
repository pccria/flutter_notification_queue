import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';

import 'studio_setup.dart';

/// Represents a live virtual viewport window hosted within the Studio canvas.
class VirtualWindowData {
  VirtualWindowData({
    required this.id,
    required this.title,
    required this.accentColor,
    required this.setup,
    required this.controller,
    final GlobalKey? globalKey,
    this.isMounted = true,
    this.isPaused = false,
  }) : globalKey = globalKey ?? GlobalKey();

  /// Unique identifier (e.g. `'win_1'`, `'win_2'`).
  final String id;

  /// Display title for the window chrome (e.g. `'Window 1 (Main)'`).
  final String title;

  /// Semantic theme accent color for this window.
  final Color accentColor;

  /// The declarative queue and channel setup powering this window.
  final StudioSetup setup;

  /// The dedicated 1:1 [NotificationController] attached to this window's
  /// viewport scope.
  final NotificationController controller;

  /// Stable [GlobalKey] to allow seamless element re-parenting across layouts
  /// without re-attaching or triggering 1:1 controller scope invariants.
  final GlobalKey globalKey;

  /// Whether this window's [NotificationScope] is currently mounted.
  final bool isMounted;

  /// Whether this window's queue timers are in stasis.
  final bool isPaused;

  VirtualWindowData copyWith({
    final String? title,
    final Color? accentColor,
    final StudioSetup? setup,
    final NotificationController? controller,
    final GlobalKey? globalKey,
    final bool? isMounted,
    final bool? isPaused,
  }) =>
      VirtualWindowData(
        id: id,
        title: title ?? this.title,
        accentColor: accentColor ?? this.accentColor,
        setup: setup ?? this.setup,
        controller: controller ?? this.controller,
        globalKey: globalKey ?? this.globalKey,
        isMounted: isMounted ?? this.isMounted,
        isPaused: isPaused ?? this.isPaused,
      );
}
