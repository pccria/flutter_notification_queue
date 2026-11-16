import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ── Events ──

sealed class StudioEvent {
  const StudioEvent();
}

final class ToggleTheme extends StudioEvent {
  const ToggleTheme();
}

final class ResizeCodeEditor extends StudioEvent {
  const ResizeCodeEditor({
    required this.delta,
    required this.totalWidth,
  });

  final double delta;
  final double totalWidth;
}

final class ToggleCodeEditor extends StudioEvent {
  const ToggleCodeEditor({this.open});

  final bool? open;
}

final class ResizeEventLog extends StudioEvent {
  const ResizeEventLog({
    required this.delta,
    required this.totalWidth,
  });

  final double delta;
  final double totalWidth;
}

final class ToggleEventLog extends StudioEvent {
  const ToggleEventLog({this.open});

  final bool? open;
}

final class ToggleStage extends StudioEvent {
  const ToggleStage({this.open});

  final bool? open;
}

final class ResizeConfigurator extends StudioEvent {
  const ResizeConfigurator({
    required this.delta,
    required this.totalWidth,
  });

  final double delta;
  final double totalWidth;
}

final class ResetPaneLayout extends StudioEvent {
  const ResetPaneLayout();
}

// ── State ──

class StudioState {
  const StudioState({
    this.themeMode = ThemeMode.dark,
    this.codeEditorWidth = 460.0,
    this.isCodeEditorOpen = true,
    this.eventLogWidth = 280.0,
    this.isEventLogOpen = true,
    this.isStageOpen = true,
    this.configuratorWidth = 380.0,
  });

  static const double minMainPaneWidth = 340.0;
  static const double minConfiguratorWidth = 320.0;
  static const double maxConfiguratorWidth = 650.0;
  static const double minCodeEditorWidth = 280.0;
  static const double maxCodeEditorWidth = 900.0;
  static const double minEventLogWidth = 220.0;
  static const double maxEventLogWidth = 550.0;

  final ThemeMode themeMode;
  final double codeEditorWidth;
  final bool isCodeEditorOpen;
  final double eventLogWidth;
  final bool isEventLogOpen;
  final bool isStageOpen;
  final double configuratorWidth;

  StudioState copyWith({
    final ThemeMode? themeMode,
    final double? codeEditorWidth,
    final bool? isCodeEditorOpen,
    final double? eventLogWidth,
    final bool? isEventLogOpen,
    final bool? isStageOpen,
    final double? configuratorWidth,
  }) =>
      StudioState(
        themeMode: themeMode ?? this.themeMode,
        codeEditorWidth: codeEditorWidth ?? this.codeEditorWidth,
        isCodeEditorOpen: isCodeEditorOpen ?? this.isCodeEditorOpen,
        eventLogWidth: eventLogWidth ?? this.eventLogWidth,
        isEventLogOpen: isEventLogOpen ?? this.isEventLogOpen,
        isStageOpen: isStageOpen ?? this.isStageOpen,
        configuratorWidth: configuratorWidth ?? this.configuratorWidth,
      );
}

// ── Bloc ──

/// Manages Studio appearance and resizable pane layouts.
class StudioBloc extends Bloc<StudioEvent, StudioState> {
  StudioBloc() : super(const StudioState()) {
    on<ToggleTheme>((final event, final emit) {
      emit(
        state.copyWith(
          themeMode: state.themeMode == ThemeMode.dark
              ? ThemeMode.light
              : ThemeMode.dark,
        ),
      );
    });

    on<ResizeCodeEditor>((final event, final emit) {
      if (!state.isCodeEditorOpen) {
        emit(state.copyWith(isCodeEditorOpen: true));
      }
      final newWidth = state.codeEditorWidth - event.delta;
      if (newWidth < 140.0) {
        emit(state.copyWith(isCodeEditorOpen: false));
        return;
      }
      final otherOccupied =
          (state.isEventLogOpen ? state.eventLogWidth : 28.0) + 30.0;
      final maxAllowed =
          (event.totalWidth - otherOccupied - StudioState.minMainPaneWidth)
              .clamp(
        StudioState.minCodeEditorWidth,
        StudioState.maxCodeEditorWidth,
      );
      final clamped =
          newWidth.clamp(StudioState.minCodeEditorWidth, maxAllowed);
      emit(state.copyWith(codeEditorWidth: clamped, isCodeEditorOpen: true));
    });

    on<ToggleCodeEditor>((final event, final emit) {
      emit(
        state.copyWith(
          isCodeEditorOpen: event.open ?? !state.isCodeEditorOpen,
        ),
      );
    });

    on<ResizeEventLog>((final event, final emit) {
      if (!state.isEventLogOpen) {
        emit(state.copyWith(isEventLogOpen: true));
      }
      final newWidth = state.eventLogWidth - event.delta;
      if (newWidth < 120.0) {
        emit(state.copyWith(isEventLogOpen: false));
        return;
      }
      final otherOccupied =
          (state.isCodeEditorOpen ? state.codeEditorWidth : 28.0) + 30.0;
      final maxAllowed = (event.totalWidth -
              otherOccupied -
              StudioState.minMainPaneWidth)
          .clamp(StudioState.minEventLogWidth, StudioState.maxEventLogWidth);
      final clamped = newWidth.clamp(StudioState.minEventLogWidth, maxAllowed);
      emit(state.copyWith(eventLogWidth: clamped, isEventLogOpen: true));
    });

    on<ToggleEventLog>((final event, final emit) {
      emit(
        state.copyWith(
          isEventLogOpen: event.open ?? !state.isEventLogOpen,
        ),
      );
    });

    on<ToggleStage>((final event, final emit) {
      final willOpen = event.open ?? !state.isStageOpen;
      emit(
        state.copyWith(
          isStageOpen: willOpen,
          isCodeEditorOpen: !willOpen && state.isCodeEditorOpen,
          isEventLogOpen: !willOpen && state.isEventLogOpen,
        ),
      );
    });

    on<ResizeConfigurator>((final event, final emit) {
      final newWidth = state.configuratorWidth + event.delta;
      final clamped = newWidth.clamp(
        StudioState.minConfiguratorWidth,
        StudioState.maxConfiguratorWidth,
      );
      emit(state.copyWith(configuratorWidth: clamped));
    });

    on<ResetPaneLayout>((final event, final emit) {
      emit(
        state.copyWith(
          codeEditorWidth: 460.0,
          isCodeEditorOpen: true,
          eventLogWidth: 280.0,
          isEventLogOpen: true,
          isStageOpen: true,
          configuratorWidth: 380.0,
        ),
      );
    });
  }
}
