import 'package:business_card_scanner_demo/services/payment_card_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentCardParser', () {
    test('finds a card number grouped with spaces', () {
      final result = PaymentCardParser.parse('''
VISA
4111 1111 1111 1111
VALID THRU 12/30
''');

      expect(result.cardNumber, '4111111111111111');
      expect(result.formattedCardNumber, '4111 1111 1111 1111');
      expect(result.hasCardNumber, isTrue);
    });

    test('finds a card number grouped with hyphens', () {
      final result = PaymentCardParser.parse('5500-0000-0000-0004');

      expect(result.cardNumber, '5500000000000004');
      expect(result.hasCardNumber, isTrue);
    });

    test('finds 16 contiguous digits', () {
      final result = PaymentCardParser.parse('Number: 4000000000000002');

      expect(result.cardNumber, '4000000000000002');
    });

    test('does not accept fewer than 16 digits', () {
      final result = PaymentCardParser.parse('1234 5678 9012');

      expect(result.cardNumber, isEmpty);
      expect(result.hasCardNumber, isFalse);
    });

    test('does not extract 16 digits from a longer number', () {
      final result = PaymentCardParser.parse('12345678901234567');

      expect(result.cardNumber, isEmpty);
    });
  });
}
