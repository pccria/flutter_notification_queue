import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';

import '../models/channel_setup.dart';
import '../models/queue_setup.dart';
import '../models/studio_setup.dart';
import '../models/virtual_window_data.dart';

// ── Events ──

sealed class SetupEvent {
  const SetupEvent();
}

// Queue CRUD
final class AddQueue extends SetupEvent {
  const AddQueue(this.position, [this.setup = const QueueSetup()]);
  final QueuePosition position;
  final QueueSetup setup;
}

final class RemoveQueue extends SetupEvent {
  const RemoveQueue(this.position);
  final QueuePosition position;
}

final class UpdateQueue extends SetupEvent {
  const UpdateQueue(this.position, this.setup);
  final QueuePosition position;
  final QueueSetup setup;
}

// Channel CRUD
final class AddChannel extends SetupEvent {
  const AddChannel(this.setup);
  final ChannelSetup setup;
}

final class RemoveChannel extends SetupEvent {
  const RemoveChannel(this.name);
  final String name;
}

final class UpdateChannel extends SetupEvent {
  const UpdateChannel(this.name, this.setup);
  final String name;
  final ChannelSetup setup;
}

final class AddStandardPresets extends SetupEvent {
  const AddStandardPresets();
}

// Navigation
final class SelectActiveQueue extends SetupEvent {
  const SelectActiveQueue(this.position);
  final QueuePosition position;
}

// Bulk
final class ApplySetup extends SetupEvent {
  const ApplySetup(this.setup);
  final StudioSetup setup;
}

final class ResetSetup extends SetupEvent {
  const ResetSetup();
}

final class UpdateGlobalConfig extends SetupEvent {
  const UpdateGlobalConfig({
    this.maxHistoryEntries,
  });
  final int? maxHistoryEntries;
}

// ── Virtual Window Management Events ──

final class AddVirtualWindow extends SetupEvent {
  const AddVirtualWindow({this.title, this.accentColor});
  final String? title;
  final Color? accentColor;
}

final class RemoveVirtualWindow extends SetupEvent {
  const RemoveVirtualWindow(this.id);
  final String id;
}

final class SelectActiveWindow extends SetupEvent {
  const SelectActiveWindow(this.id);
  final String id;
}

final class ToggleWindowStasis extends SetupEvent {
  const ToggleWindowStasis(this.id);
  final String id;
}

final class ToggleWindowMount extends SetupEvent {
  const ToggleWindowMount(this.id);
  final String id;
}

final class ClearWindow extends SetupEvent {
  const ClearWindow(this.id);
  final String id;
}

// ── State ──

class SetupState {
  const SetupState({
    required this.windows,
    this.activeWindowId = 'win_1',
    this.activeQueuePosition = QueuePosition.topCenter,
  });

  /// Map of registered virtual windows keyed by window ID.
  final Map<String, VirtualWindowData> windows;

  /// The ID of the currently focused virtual window being edited in Studio.
  final String activeWindowId;

  /// Which queue is currently being edited in the configurator.
  final QueuePosition activeQueuePosition;

  /// Active virtual window data.
  VirtualWindowData get activeWindow =>
      windows[activeWindowId] ?? windows.values.first;

  /// Active studio setup for the focused window.
  StudioSetup get setup => activeWindow.setup;

  /// Active controller for the focused window.
  NotificationController get controller => activeWindow.controller;

  /// Convenience: the currently-active queue setup.
  QueueSetup? get activeQueue => setup.queues[activeQueuePosition];

  SetupState copyWith({
    final Map<String, VirtualWindowData>? windows,
    final String? activeWindowId,
    final QueuePosition? activeQueuePosition,
  }) =>
      SetupState(
        windows: windows ?? this.windows,
        activeWindowId: activeWindowId ?? this.activeWindowId,
        activeQueuePosition: activeQueuePosition ?? this.activeQueuePosition,
      );
}

// ── Bloc ──

/// Manages virtual windows and their declarative [StudioSetup] lifecycles.
class SetupBloc extends Bloc<SetupEvent, SetupState> {
  SetupBloc() : super(_createInitialState()) {
    // ── Queue CRUD (operates on active window) ──
    on<AddQueue>((final event, final emit) {
      final active = state.activeWindow;
      final queues = Map<QueuePosition, QueueSetup>.from(active.setup.queues);
      queues[event.position] = event.setup;
      final newSetup = _maintainRelocationInvariants(
        active.setup.copyWith(queues: queues),
      );
      _reconfigureWindow(active, newSetup);

      final updatedWindow = active.copyWith(setup: newSetup);
      final newWindows = Map<String, VirtualWindowData>.from(state.windows)
        ..[state.activeWindowId] = updatedWindow;

      emit(
        state.copyWith(
          windows: newWindows,
          activeQueuePosition: event.position,
        ),
      );
    });

    on<RemoveQueue>((final event, final emit) {
      final active = state.activeWindow;
      final queues = Map<QueuePosition, QueueSetup>.from(active.setup.queues)
        ..remove(event.position);
      if (queues.isEmpty) {
        return; // must have at least one queue
      }
      final newActive = state.activeQueuePosition == event.position
          ? queues.keys.first
          : state.activeQueuePosition;
      final newSetup = active.setup.copyWith(queues: queues);
      _reconfigureWindow(active, newSetup);

      final updatedWindow = active.copyWith(setup: newSetup);
      final newWindows = Map<String, VirtualWindowData>.from(state.windows)
        ..[state.activeWindowId] = updatedWindow;

      emit(
        state.copyWith(
          windows: newWindows,
          activeQueuePosition: newActive,
        ),
      );
    });

    on<UpdateQueue>((final event, final emit) {
      final active = state.activeWindow;
      final queues = Map<QueuePosition, QueueSetup>.from(active.setup.queues);
      queues[event.position] = event.setup;
      final newSetup = _maintainRelocationInvariants(
        active.setup.copyWith(queues: queues),
        priorityOwner: event.position,
      );
      _reconfigureWindow(active, newSetup);

      final updatedWindow = active.copyWith(setup: newSetup);
      final newWindows = Map<String, VirtualWindowData>.from(state.windows)
        ..[state.activeWindowId] = updatedWindow;

      emit(state.copyWith(windows: newWindows));
    });

    // ── Channel CRUD (operates on active window) ──
    on<AddChannel>((final event, final emit) {
      final active = state.activeWindow;
      final channels = Map<String, ChannelSetup>.from(active.setup.channels);
      channels[event.setup.name] = event.setup;
      final newSetup = active.setup.copyWith(channels: channels);
      _reconfigureWindow(active, newSetup);

      final updatedWindow = active.copyWith(setup: newSetup);
      final newWindows = Map<String, VirtualWindowData>.from(state.windows)
        ..[state.activeWindowId] = updatedWindow;

      emit(state.copyWith(windows: newWindows));
    });

    on<RemoveChannel>((final event, final emit) {
      final active = state.activeWindow;
      final channels = Map<String, ChannelSetup>.from(active.setup.channels)
        ..remove(event.name);
      final newSetup = active.setup.copyWith(channels: channels);
      _reconfigureWindow(active, newSetup);

      final updatedWindow = active.copyWith(setup: newSetup);
      final newWindows = Map<String, VirtualWindowData>.from(state.windows)
        ..[state.activeWindowId] = updatedWindow;

      emit(state.copyWith(windows: newWindows));
    });

    on<UpdateChannel>((final event, final emit) {
      final active = state.activeWindow;
      final channels = Map<String, ChannelSetup>.from(active.setup.channels);
      channels[event.name] = event.setup;
      final newSetup = active.setup.copyWith(channels: channels);
      _reconfigureWindow(active, newSetup);

      final updatedWindow = active.copyWith(setup: newSetup);
      final newWindows = Map<String, VirtualWindowData>.from(state.windows)
        ..[state.activeWindowId] = updatedWindow;

      emit(state.copyWith(windows: newWindows));
    });

    on<AddStandardPresets>((final event, final emit) {
      final active = state.activeWindow;
      final newChannels = Map<String, ChannelSetup>.from(active.setup.channels)
        ..addAll(ChannelSetup.standardChannels());
      final newSetup = active.setup.copyWith(channels: newChannels);
      _reconfigureWindow(active, newSetup);

      final updatedWindow = active.copyWith(setup: newSetup);
      final newWindows = Map<String, VirtualWindowData>.from(state.windows)
        ..[state.activeWindowId] = updatedWindow;

      emit(state.copyWith(windows: newWindows));
    });

    // ── Navigation ──
    on<SelectActiveQueue>((final event, final emit) {
      emit(state.copyWith(activeQueuePosition: event.position));
    });

    // ── Bulk ──
    on<ApplySetup>((final event, final emit) {
      final active = state.activeWindow;
      final newPos = event.setup.queues.isEmpty
          ? QueuePosition.topCenter
          : (event.setup.queues.containsKey(state.activeQueuePosition)
              ? state.activeQueuePosition
              : event.setup.queues.keys.first);
      _reconfigureWindow(active, event.setup);

      final updatedWindow = active.copyWith(setup: event.setup);
      final newWindows = Map<String, VirtualWindowData>.from(state.windows)
        ..[state.activeWindowId] = updatedWindow;

      emit(
        state.copyWith(
          windows: newWindows,
          activeQueuePosition: newPos,
        ),
      );
    });

    on<UpdateGlobalConfig>((final event, final emit) {
      final active = state.activeWindow;
      final newSetup = active.setup.copyWith(
        maxHistoryEntries: event.maxHistoryEntries,
      );
      _reconfigureWindow(active, newSetup);

      final updatedWindow = active.copyWith(setup: newSetup);
      final newWindows = Map<String, VirtualWindowData>.from(state.windows)
        ..[state.activeWindowId] = updatedWindow;

      emit(state.copyWith(windows: newWindows));
    });

    on<ResetSetup>((final event, final emit) {
      final active = state.activeWindow;
      final defaultSetup = StudioSetup.withDefaults();
      _reconfigureWindow(active, defaultSetup);

      final updatedWindow = active.copyWith(setup: defaultSetup);
      final newWindows = Map<String, VirtualWindowData>.from(state.windows)
        ..[state.activeWindowId] = updatedWindow;

      emit(
        state.copyWith(
          windows: newWindows,
          activeQueuePosition: QueuePosition.topCenter,
        ),
      );
    });

    // ── Virtual Window Management ──
    on<AddVirtualWindow>((final event, final emit) {
      if (state.windows.length >= 2) {
        return; // Currently support dual split windows (Win 1 & Win 2)
      }
      const newId = 'win_2';
      final activeSetup = state.setup;

      // Provide a contrasting setup: clone channels with beta prefix / accent
      final win2Controller = NotificationController(
        queues: activeSetup.toLibraryQueues(),
        channels: activeSetup.toLibraryChannels(),
        maxHistoryEntries: activeSetup.maxHistoryEntries,
      );

      final newWindow = VirtualWindowData(
        id: newId,
        title: event.title ?? 'Workspace B (Beta)',
        accentColor: event.accentColor ?? const Color(0xFF10B981),
        setup: activeSetup,
        controller: win2Controller,
      );

      final newWindows = Map<String, VirtualWindowData>.from(state.windows)
        ..[newId] = newWindow;

      emit(
        state.copyWith(
          windows: newWindows,
          activeWindowId: newId,
        ),
      );
    });

    on<RemoveVirtualWindow>((final event, final emit) {
      if (event.id == 'win_1' || !state.windows.containsKey(event.id)) {
        return; // Always preserve primary window
      }
      final target = state.windows[event.id];
      target?.controller.dispose();

      final newWindows = Map<String, VirtualWindowData>.from(state.windows)
        ..remove(event.id);
      final newActive =
          state.activeWindowId == event.id ? 'win_1' : state.activeWindowId;

      emit(
        state.copyWith(
          windows: newWindows,
          activeWindowId: newActive,
        ),
      );
    });

    on<SelectActiveWindow>((final event, final emit) {
      if (!state.windows.containsKey(event.id)) {
        return;
      }
      final win = state.windows[event.id]!;
      final validActiveQueue =
          win.setup.queues.containsKey(state.activeQueuePosition)
              ? state.activeQueuePosition
              : (win.setup.queues.keys.firstOrNull ?? QueuePosition.topCenter);

      emit(
        state.copyWith(
          activeWindowId: event.id,
          activeQueuePosition: validActiveQueue,
        ),
      );
    });

    on<ToggleWindowStasis>((final event, final emit) {
      final win = state.windows[event.id];
      if (win == null) {
        return;
      }
      final newPaused = !win.isPaused;
      if (newPaused) {
        win.controller.pauseAll();
      } else {
        win.controller.resumeAll();
      }

      final updated = win.copyWith(isPaused: newPaused);
      final newWindows = Map<String, VirtualWindowData>.from(state.windows)
        ..[event.id] = updated;

      emit(state.copyWith(windows: newWindows));
    });

    on<ToggleWindowMount>((final event, final emit) {
      final win = state.windows[event.id];
      if (win == null) {
        return;
      }
      final newMounted = !win.isMounted;
      final updated = win.copyWith(isMounted: newMounted);
      final newWindows = Map<String, VirtualWindowData>.from(state.windows)
        ..[event.id] = updated;

      emit(state.copyWith(windows: newWindows));
    });

    on<ClearWindow>((final event, final emit) {
      state.windows[event.id]?.controller.dismissAll(clearBacklog: true);
    });
  }

  static SetupState _createInitialState() {
    final initialSetup = StudioSetup.withDefaults();
    final initialController = NotificationController(
      queues: initialSetup.toLibraryQueues(),
      channels: initialSetup.toLibraryChannels(),
      maxHistoryEntries: initialSetup.maxHistoryEntries,
    );

    final initialWindow = VirtualWindowData(
      id: 'win_1',
      title: 'Workspace A (Alpha)',
      accentColor: const Color(0xFF6366F1),
      setup: initialSetup,
      controller: initialController,
    );

    return SetupState(
      windows: {'win_1': initialWindow},
      activeWindowId: 'win_1',
      activeQueuePosition: QueuePosition.topCenter,
    );
  }

  void _reconfigureWindow(
    final VirtualWindowData window,
    final StudioSetup setup,
  ) {
    window.controller.reconfigure(
      queues: setup.toLibraryQueues(),
      channels: setup.toLibraryChannels(),
      maxHistoryEntries: setup.maxHistoryEntries,
    );
  }

  /// Convenience: gets the active controller.
  NotificationController get controller => state.controller;

  /// Convenience: looks up a window by ID.
  VirtualWindowData? getWindow(final String id) => state.windows[id];

  @override
  Future<void> close() {
    for (final window in state.windows.values) {
      window.controller.dispose();
    }
    return super.close();
  }

  StudioSetup _maintainRelocationInvariants(
    final StudioSetup setup, {
    final QueuePosition? priorityOwner,
  }) {
    final activePositions = setup.queues.keys.toSet();
    final updatedQueues = <QueuePosition, QueueSetup>{...setup.queues};

    // 1. Initial prune: Targets cannot be Master (active) queues.
    for (final entry in updatedQueues.entries) {
      final pos = entry.key;
      final q = entry.value;
      final valid =
          q.relocateTargets.where((final p) => !activePositions.contains(p));
      updatedQueues[pos] = q.copyWith(relocateTargets: valid.toSet());
    }

    // 2. Strict Isolation: Each Slave belongs to at most one Master.
    if (priorityOwner != null) {
      final priorityTargets = updatedQueues[priorityOwner]?.relocateTargets;
      if (priorityTargets != null) {
        for (final pos in updatedQueues.keys) {
          if (pos == priorityOwner) {
            continue;
          }
          final q = updatedQueues[pos]!;
          final filtered = q.relocateTargets
              .where((final t) => !priorityTargets.contains(t))
              .toSet();
          if (filtered.length != q.relocateTargets.length) {
            updatedQueues[pos] = q.copyWith(relocateTargets: filtered);
          }
        }
      }
    }

    return setup.copyWith(queues: updatedQueues);
  }
}
