import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/src/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestWidget extends StatefulWidget {
  const _TestWidget({
    this.explicitCoordinator,
    this.callerName,
    super.key,
  });

  final QueueCoordinator? explicitCoordinator;
  final String? callerName;

  @override
  State<_TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<_TestWidget>
    with CoordinatorResolver<_TestWidget> {
  QueueCoordinator? resolved;
  Object? error;

  void attemptResolve() {
    try {
      resolved = resolveCoordinator(
        explicitCoordinator: widget.explicitCoordinator,
        callerName: widget.callerName,
      );
    } on Object catch (e) {
      error = e;
    }
  }

  @override
  Widget build(final BuildContext context) => const SizedBox.shrink();
}

void main() {
  group('CoordinatorResolver Unit & Widget Tests', () {
    testWidgets('resolves explicit coordinator when provided',
        (final tester) async {
      final coordinator = QueueCoordinator();
      final key = GlobalKey<_TestWidgetState>();

      await tester.pumpWidget(
        MaterialApp(
          home: _TestWidget(
            key: key,
            explicitCoordinator: coordinator,
          ),
        ),
      );

      key.currentState!.attemptResolve();
      expect(key.currentState!.resolved, same(coordinator));
      expect(key.currentState!.error, isNull);
    });

    testWidgets('resolves ambient scope coordinator when explicit is null',
        (final tester) async {
      final controller = NotificationController();
      final key = GlobalKey<_TestWidgetState>();

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationScope(
            controller: controller,
            child: _TestWidget(key: key),
          ),
        ),
      );

      final coordinator = controller.coordinator!;
      key.currentState!.attemptResolve();
      expect(key.currentState!.resolved, same(coordinator));
      expect(key.currentState!.error, isNull);
    });

    testWidgets('explicit coordinator takes precedence over ambient scope',
        (final tester) async {
      final controller = NotificationController();
      final explicitCoordinator = QueueCoordinator();
      final key = GlobalKey<_TestWidgetState>();

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationScope(
            controller: controller,
            child: _TestWidget(
              key: key,
              explicitCoordinator: explicitCoordinator,
            ),
          ),
        ),
      );

      final scopeCoordinator = controller.coordinator!;
      key.currentState!.attemptResolve();
      expect(key.currentState!.resolved, same(explicitCoordinator));
      expect(key.currentState!.resolved, isNot(same(scopeCoordinator)));
    });

    testWidgets(
        'throws StateError containing callerName when neither is available',
        (final tester) async {
      final key = GlobalKey<_TestWidgetState>();

      await tester.pumpWidget(
        MaterialApp(
          home: _TestWidget(
            key: key,
            callerName: 'CustomCallerWidget',
          ),
        ),
      );

      key.currentState!.attemptResolve();
      expect(key.currentState!.resolved, isNull);
      expect(key.currentState!.error, isA<StateError>());
      final message = (key.currentState!.error! as StateError).message;
      expect(message, contains('No QueueCoordinator available'));
      expect(message, contains('CustomCallerWidget'));
      expect(message, contains('NotificationScope'));
    });

    testWidgets(
        'throws StateError containing runtimeType when callerName is omitted',
        (final tester) async {
      final key = GlobalKey<_TestWidgetState>();

      await tester.pumpWidget(
        MaterialApp(
          home: _TestWidget(key: key),
        ),
      );

      key.currentState!.attemptResolve();
      expect(key.currentState!.resolved, isNull);
      expect(key.currentState!.error, isA<StateError>());
      final message = (key.currentState!.error! as StateError).message;
      expect(message, contains('_TestWidget'));
    });
  });
}
