class ParsedPaymentCardData {
  const ParsedPaymentCardData({
    required this.cardNumber,
    required this.rawText,
  });

  final String cardNumber;
  final String rawText;

  bool get hasCardNumber => cardNumber.length == 16;

  String get formattedCardNumber {
    if (!hasCardNumber) return cardNumber;
    return List.generate(
      4,
      (index) => cardNumber.substring(index * 4, (index + 1) * 4),
    ).join(' ');
  }
}

class PaymentCardParser {
  // Card numbers are commonly printed as 16 contiguous digits or as four
  // groups separated by spaces/hyphens. A Luhn check is intentionally not
  // required: for this scanner, finding exactly 16 digits is sufficient.
  static final RegExp _cardNumberPattern = RegExp(
    r'(?<!\d)\d{4}(?:[\s-]?\d{4}){3}(?!\d)',
  );

  static ParsedPaymentCardData parse(String rawText) {
    final match = _cardNumberPattern.firstMatch(rawText);
    final cardNumber = match?.group(0)?.replaceAll(RegExp(r'\D'), '') ?? '';

    return ParsedPaymentCardData(
      cardNumber: cardNumber,
      rawText: rawText,
    );
  }
}
