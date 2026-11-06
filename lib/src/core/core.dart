/// The FNQ core engine.
///
/// This barrel exports the three core components that power the notification
/// system:
///
/// - [ConfigurationManager] — stores queues and channels, resolves lookups.
/// - [QueueCoordinator] — bridges queue lifecycle with the rendering surface.
/// - [NotificationOverlay] — the rendering surface that mounts notifications
///   into the widget tree.
///
/// All core components of FNQ.
///
/// Public entry points are [NotificationController] and [NotificationScope].
library;

import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logd/logd.dart';

import '../enums/enums.dart';
import '../notification/notification.dart';
import '../notification_channel/notification_channel.dart';
import '../notification_queue/notification_queue.dart';
import '../utils/utils.dart';

part 'configuration_manager.dart';
part 'notification_event.dart';
part 'history_logger.dart';
part 'notification_controller.dart';
part 'notification_overlay.dart';
part 'notification_entry.dart';
part 'notification_handle.dart';
part 'notification_scope.dart';
part 'queue_coordinator.dart';
