import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WebContextMenuController', () {
    test('initial state has zero requests and is not disabled', () {
      final controller = WebContextMenuController();
      expect(controller.disableRequests, 0);
      expect(controller.isContextMenuDisabled, isFalse);
    });

    test('ref counting lifecycle safety on non-web platforms', () {
      final controller = WebContextMenuController();
      expect(controller.disableRequests, 0);
      controller.releaseDisable();
      expect(controller.disableRequests, 0);
      controller.reset();
      expect(controller.disableRequests, 0);
    });
  });

  group('QueueCoordinator Context Menu Dismissal Registry', () {
    test('registerContextMenuDismiss closes previous callback', () {
      final controller = NotificationController();
      addTearDown(controller.dispose);
      final coordinator = QueueCoordinator.fromController(controller);
      addTearDown(coordinator.dispose);

      var firstDismissed = false;
      var secondDismissed = false;

      void firstDismiss() {
        firstDismissed = true;
      }

      void secondDismiss() {
        secondDismissed = true;
      }

      coordinator.registerContextMenuDismiss(firstDismiss);
      expect(firstDismissed, isFalse);

      coordinator.registerContextMenuDismiss(secondDismiss);
      expect(firstDismissed, isTrue);
      expect(secondDismissed, isFalse);

      coordinator.dismissActiveContextMenu();
      expect(secondDismissed, isTrue);
    });

    test('unregisterContextMenuDismiss cleans up matching callback', () {
      final controller = NotificationController();
      addTearDown(controller.dispose);
      final coordinator = QueueCoordinator.fromController(controller);
      addTearDown(coordinator.dispose);

      var dismissed = false;
      void dismiss() {
        dismissed = true;
      }

      coordinator.registerContextMenuDismiss(dismiss);
      coordinator.unregisterContextMenuDismiss(dismiss);

      coordinator.dismissActiveContextMenu();
      expect(dismissed, isFalse);
    });

    test('detach closes active context menu', () {
      final controller = NotificationController();
      addTearDown(controller.dispose);
      final coordinator = QueueCoordinator.fromController(controller);
      addTearDown(coordinator.dispose);

      var dismissed = false;
      coordinator.registerContextMenuDismiss(() {
        dismissed = true;
      });

      coordinator.detach();
      expect(dismissed, isTrue);
    });
  });
}
