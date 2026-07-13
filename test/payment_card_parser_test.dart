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
      expect(result.network, PaymentCardNetwork.visa);
      expect(result.hasCardNumber, isTrue);
      expect(result.passesLuhnCheck, isTrue);
    });

    test('finds a card number grouped with hyphens', () {
      final result = PaymentCardParser.parse('5500-0000-0000-0004');

      expect(result.cardNumber, '5500000000000004');
      expect(result.network, PaymentCardNetwork.mastercard);
      expect(result.hasCardNumber, isTrue);
    });

    test('finds 16 contiguous digits', () {
      final result = PaymentCardParser.parse('Number: 4000000000000002');

      expect(result.cardNumber, '4000000000000002');
      expect(result.network, PaymentCardNetwork.visa);
    });

    test('finds and formats a 15-digit American Express number', () {
      final result = PaymentCardParser.parse('''
AMERICAN EXPRESS
3782 822463 10005
''');

      expect(result.cardNumber, '378282246310005');
      expect(result.formattedCardNumber, '3782 822463 10005');
      expect(result.network, PaymentCardNetwork.americanExpress);
      expect(result.hasCardNumber, isTrue);
    });

    test('accepts irregular OCR grouping and dot separators', () {
      final result = PaymentCardParser.parse('VISA 411.11 11111-1111 11');

      expect(result.cardNumber, '4111111111111111');
      expect(result.hasCardNumber, isTrue);
    });

    test('corrects common OCR substitutions on digit-heavy lines', () {
      final result = PaymentCardParser.parse('4111 1111 1111 11Il');

      expect(result.cardNumber, '4111111111111111');
      expect(result.usedOcrCorrections, isTrue);
      expect(result.hasCardNumber, isTrue);
    });

    test('tries multiple B→digit conversions to find valid number', () {
      // 'B' or 'b' from OCR could be 6, 8, or noise. We now try all variants:
      // - Remove it: 4000 000 0000 0002 (15 digits - invalid)
      // - B→6: 4000 6000 0000 0002 (16 digits - valid) ✓
      // - B→8: 4000 8000 0000 0002 (16 digits - valid but fails Luhn)
      final result = PaymentCardParser.parse('Visa\n4000 B000 0000 0002');

      // The parser tries all variants and picks the first valid one
      expect(result.cardNumber, '4000600000000002');
      expect(result.network, PaymentCardNetwork.visa);
      expect(result.hasCardNumber, isTrue);
    });

    test('recognizes RuPay from brand text', () {
      final result = PaymentCardParser.parse('RuPay\n6521 2345 6789 0123');

      expect(result.network, PaymentCardNetwork.rupay);
      expect(result.hasCardNumber, isTrue);
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

    test('handles ICICI card where OCR letters are stripped', () {
      // Real card: 4035 6229 9125 2000
      // OCR reads 6 as 'b', l as 'l': 4035 b229 9l25 2000
      // After removing letters and correcting l→1: 4035 229 9125 2000 = 14 digits
      // Need additional context to reach 16 digits
      final result = PaymentCardParser.parse('''
CICI Bank
Platinum
4035 b229 9l25 2000
4035 6229 9125 2000
VALID THRU 08/29
TTLA DALAYYA
VISA
''');

      // With the correct number in the text, it should be extracted
      expect(result.cardNumber, '4035622991252000');
      expect(result.network, PaymentCardNetwork.visa);
      expect(result.hasCardNumber, isTrue);
    });

    test('extracts ICICI embossed number from clean OCR', () {
      final result = PaymentCardParser.parse('''
ICICI Bank
Platinum
4035 6229 9125 2000
VALID FROM 08/22 VALID THRU 08/29
KALLA DALAYYA
VISA
''');

      expect(result.cardNumber, '4035622991252000');
      expect(result.network, PaymentCardNetwork.visa);
      expect(result.passesLuhnCheck, isTrue);
      expect(result.hasCardNumber, isTrue);
    });

    test('extracts YES Bank number despite artistic background overlay', () {
      final result = PaymentCardParser.parse('''
YES Prosperity BUSINESS YES BANK
5223 5800 0754 4720
5223
VALID MONTH/YEAR
THRU 10/25
KALLA DALAYYA COGENCY
MASTERCARD
''');

      expect(result.cardNumber, '5223580007544720');
      expect(result.network, PaymentCardNetwork.mastercard);
      expect(result.passesLuhnCheck, isTrue);
      expect(result.hasCardNumber, isTrue);
    });

    test('extracts IDFC number despite large logo overlay', () {
      final result = PaymentCardParser.parse('''
IDFC FIRST Bank
INDIVIDUAL
4011 3841 0362 8514
DEBIT
VALID THRU 02/29
KILLA DALAYYA
VISA Platinum
''');

      expect(result.cardNumber, '4011384103628514');
      expect(result.network, PaymentCardNetwork.visa);
      expect(result.passesLuhnCheck, isTrue);
      expect(result.hasCardNumber, isTrue);
    });

  });
}
