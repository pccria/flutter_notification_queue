import 'package:flutter_notification_queue/src/core/core.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationIdGenerator (A-06)', () {
    test('Default generator starts at 0 and produces monotonic IDs', () {
      final generator = NotificationIdGenerator();
      expect(generator.currentCount, equals(0));

      final id0 = generator.nextId();
      expect(generator.currentCount, equals(1));
      expect(id0, startsWith('notif_0_'));

      final id1 = generator.nextId();
      expect(generator.currentCount, equals(2));
      expect(id1, startsWith('notif_1_'));
    });

    test('Custom prefix is applied correctly', () {
      final generator = NotificationIdGenerator();
      final customId = generator.nextId('alert');
      expect(customId, startsWith('alert_0_'));
      expect(generator.currentCount, equals(1));
    });

    test('Custom initialSeed is respected', () {
      final generator = NotificationIdGenerator(initialSeed: 100);
      expect(generator.currentCount, equals(100));

      final id = generator.nextId();
      expect(id, startsWith('notif_100_'));
      expect(generator.currentCount, equals(101));
    });

    test('Separate instances maintain isolated monotonic sequence state', () {
      final genA = NotificationIdGenerator();
      final genB = NotificationIdGenerator();

      genA
        ..nextId()
        ..nextId()
        ..nextId();
      expect(genA.currentCount, equals(3));
      expect(genB.currentCount, equals(0));

      final b0 = genB.nextId();
      expect(b0, startsWith('notif_0_'));
      expect(genB.currentCount, equals(1));
    });

    test('QueueCoordinator owns isolated instance-scoped idGenerator', () {
      final coordA = QueueCoordinator();
      final coordB = QueueCoordinator();

      final idA0 = coordA.idGenerator.nextId();
      final idA1 = coordA.idGenerator.nextId();
      expect(idA0, startsWith('notif_0_'));
      expect(idA1, startsWith('notif_1_'));
      expect(coordA.idGenerator.currentCount, equals(2));

      expect(coordB.idGenerator.currentCount, equals(0));
      final idB0 = coordB.idGenerator.nextId();
      expect(idB0, startsWith('notif_0_'));
      expect(coordB.idGenerator.currentCount, equals(1));
    });

    test('NotificationController forwards idGenerator to coordinator', () {
      final customGen = NotificationIdGenerator(initialSeed: 50);
      final controller = NotificationController(idGenerator: customGen);

      expect(controller.idGenerator.currentCount, equals(50));
      final coord = QueueCoordinator.fromController(controller);
      expect(coord.idGenerator.currentCount, equals(50));
      final id = coord.idGenerator.nextId();
      expect(id, startsWith('notif_50_'));
      expect(controller.idGenerator.currentCount, equals(51));
    });

    test('NotificationWidget resolves explicit id over generator', () {
      final widget = NotificationWidget(
        message: 'Explicit',
        id: 'custom_id_42',
      );
      expect(widget.id, equals('custom_id_42'));
    });

    test('NotificationWidget uses custom idGenerator when provided', () {
      final gen = NotificationIdGenerator(initialSeed: 7);
      final widget = NotificationWidget(
        message: 'With Generator',
        idGenerator: gen,
      );
      expect(widget.id, startsWith('notif_7_'));
      expect(gen.currentCount, equals(8));
    });

    test('NotificationWidget delegates to coordinator idGenerator', () {
      final coordinator = QueueCoordinator();
      final widget1 = NotificationWidget(
        message: 'First',
        coordinator: coordinator,
      );
      final widget2 = NotificationWidget(
        message: 'Second',
        coordinator: coordinator,
      );

      expect(widget1.id, startsWith('notif_0_'));
      expect(widget2.id, startsWith('notif_1_'));
      expect(coordinator.idGenerator.currentCount, equals(2));
    });
  });
}
