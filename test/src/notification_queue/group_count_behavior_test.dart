import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupCountBehavior Unit Tests', () {
    group('HiddenCount', () {
      test('defaults format correctly under maxCount', () {
        const count = HiddenCount();
        expect(count.maxCount, equals(9));
        expect(count.includePending, isTrue);
        expect(count.prefix, equals('+'));
        expect(count.overflowSuffix, equals('+'));

        expect(count.format(totalCount: 3, hiddenCount: 2), equals('+2'));
        expect(count.format(totalCount: 1, hiddenCount: 0), equals('+0'));
      });

      test('formats overflow when hiddenCount exceeds maxCount', () {
        const count = HiddenCount(maxCount: 10);
        expect(count.format(totalCount: 11, hiddenCount: 10), equals('+10'));
        expect(count.format(totalCount: 12, hiddenCount: 11), equals('10+'));
        expect(count.format(totalCount: 100, hiddenCount: 99), equals('10+'));
      });

      test('supports custom prefix and overflowSuffix', () {
        const count = HiddenCount(
          maxCount: 5,
          prefix: 'more: ',
          overflowSuffix: '!',
        );
        expect(count.format(totalCount: 4, hiddenCount: 3), equals('more: 3'));
        expect(count.format(totalCount: 8, hiddenCount: 7), equals('more: 5!'));
      });

      test('equality and hashCode contract', () {
        const b1 = HiddenCount(maxCount: 50, includePending: false);
        const b2 = HiddenCount(maxCount: 50, includePending: false);
        const b3 = HiddenCount(maxCount: 9, includePending: false);

        expect(b1, equals(b2));
        expect(b1.hashCode, equals(b2.hashCode));
        expect(b1, isNot(equals(b3)));
      });
    });

    group('TotalCount', () {
      test('defaults format total count correctly under maxCount', () {
        const count = TotalCount();
        expect(count.maxCount, equals(9));
        expect(count.includePending, isTrue);
        expect(count.prefix, equals(''));
        expect(count.overflowSuffix, equals('+'));

        expect(count.format(totalCount: 3, hiddenCount: 2), equals('3'));
        expect(count.format(totalCount: 9, hiddenCount: 8), equals('9'));
      });

      test('formats overflow when totalCount exceeds maxCount', () {
        const count = TotalCount(maxCount: 10);
        expect(count.format(totalCount: 10, hiddenCount: 9), equals('10'));
        expect(count.format(totalCount: 11, hiddenCount: 10), equals('10+'));
      });

      test('supports custom prefix and overflowSuffix', () {
        const count = TotalCount(
          maxCount: 5,
          prefix: '#',
          overflowSuffix: ' max',
        );
        expect(count.format(totalCount: 3, hiddenCount: 2), equals('#3'));
        expect(count.format(totalCount: 8, hiddenCount: 7), equals('#5 max'));
      });

      test('equality and hashCode contract', () {
        const b1 = TotalCount(maxCount: 20);
        const b2 = TotalCount(maxCount: 20);
        const b3 = TotalCount(maxCount: 30);

        expect(b1, equals(b2));
        expect(b1.hashCode, equals(b2.hashCode));
        expect(b1, isNot(equals(b3)));
      });
    });

    group('CustomCount', () {
      test('delegates formatting to custom callback', () {
        final count = CustomCount(
          formatter: ({
            required final totalCount,
            required final hiddenCount,
            required final isOverflow,
          }) =>
              'items: $totalCount${isOverflow ? ' (capped)' : ''}',
          maxCount: 5,
        );

        expect(
          count.format(totalCount: 3, hiddenCount: 2),
          equals('items: 3'),
        );
        expect(
          count.format(totalCount: 10, hiddenCount: 9),
          equals('items: 10 (capped)'),
        );
      });

      test('equality and hashCode contract', () {
        String? fn({
          required final int totalCount,
          required final int hiddenCount,
          required final bool isOverflow,
        }) =>
            '$totalCount';

        final b1 = CustomCount(formatter: fn, maxCount: 10);
        final b2 = CustomCount(formatter: fn, maxCount: 10);

        expect(b1, equals(b2));
        expect(b1.hashCode, equals(b2.hashCode));
      });
    });

    group('NoCount', () {
      test('always returns null and suppresses counter', () {
        const count = NoCount();
        expect(count.format(totalCount: 5, hiddenCount: 4), isNull);
        expect(count.includePending, isFalse);
        expect(count.maxCount, equals(0));
      });

      test('equality and hashCode contract', () {
        const b1 = NoCount();
        const b2 = NoCount();

        expect(b1, equals(b2));
        expect(b1.hashCode, equals(b2.hashCode));
      });
    });
  });
}
