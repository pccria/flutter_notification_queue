import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';

import '../../bloc/setup_bloc.dart';
import '../../bloc/studio_bloc.dart';
import 'zone_frame.dart';
import 'zone_layout.dart';

/// The root transparent HUD overlay host for NFQ Studio.
///
/// Mounts 1:1 isolated [NotificationScope] zones directly over the running
/// application without obstructing underlying clicks, forms, or gestures.
///
/// In **Single Mode**, the active workspace zone covers the full viewport while
/// any inactive zone is held offscreen to preserve timer countdowns and state.
/// In **Dual Mode**, the viewport is cleanly divided (horizontally on wide
/// screens, vertically on portrait screens) with active boundary frames.
class StudioOverlayHost extends StatelessWidget {
  const StudioOverlayHost({super.key});

  @override
  Widget build(final BuildContext context) => LayoutBuilder(
        builder: (final context, final constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);

          return BlocBuilder<SetupBloc, SetupState>(
            builder: (final context, final setupState) =>
                BlocBuilder<StudioBloc, StudioState>(
              builder: (final context, final studioState) {
                final windows = setupState.windows.values.toList();
                if (windows.isEmpty) {
                  return const SizedBox.shrink();
                }

                final win1 = windows.first;
                final win2 = windows.length > 1 ? windows[1] : null;

                final rects = computeZoneRects(
                  totalSize: size,
                  isSplit: studioState.isSplitView && win2 != null,
                  windowCount: windows.length,
                  activeWindowId: setupState.activeWindowId,
                );

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // ── Scope A (Alpha) Overlay Zone ──
                    Positioned.fromRect(
                      rect: rects.zoneA,
                      child: NotificationScope(
                        key: ValueKey('hud_zone_${win1.id}'),
                        controller: win1.controller,
                        useRootOverlay: false,
                        child: const SizedBox.expand(),
                      ),
                    ),

                    // ── Scope B (Beta) Overlay Zone ──
                    if (win2 != null && rects.zoneB != null)
                      Positioned.fromRect(
                        rect: rects.zoneB!,
                        child: NotificationScope(
                          key: ValueKey('hud_zone_${win2.id}'),
                          controller: win2.controller,
                          useRootOverlay: false,
                          child: const SizedBox.expand(),
                        ),
                      ),

                    // ── Scope A Outlined Visual Boundary ──
                    Positioned.fromRect(
                      rect: rects.zoneA,
                      child: ZoneFrame(
                        window: win1,
                        isActive: setupState.activeWindowId == win1.id,
                        isSplit: rects.mode != OverlayLayoutMode.single,
                      ),
                    ),

                    // ── Scope B Outlined Visual Boundary ──
                    if (win2 != null && rects.zoneB != null)
                      Positioned.fromRect(
                        rect: rects.zoneB!,
                        child: ZoneFrame(
                          window: win2,
                          isActive: setupState.activeWindowId == win2.id,
                          isSplit: rects.mode != OverlayLayoutMode.single,
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      );
}
