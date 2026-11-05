import 'dart:io';

import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Version Synchronization', () {
    test('NotificationController.version matches pubspec.yaml version', () {
      final pubspecFile = File('pubspec.yaml');
      expect(
        pubspecFile.existsSync(),
        isTrue,
        reason: 'Root pubspec.yaml must exist',
      );

      final content = pubspecFile.readAsStringSync();
      final match = RegExp(
        r'^version:\s*([^\s+]+)',
        multiLine: true,
      ).firstMatch(content);

      expect(
        match,
        isNotNull,
        reason: 'pubspec.yaml must contain a version field',
      );

      final pubspecVersion = match!.group(1);
      expect(
        NotificationController.version,
        equals(pubspecVersion),
        reason:
            'NotificationController.version must match pubspec.yaml version',
      );
    });
  });
}
