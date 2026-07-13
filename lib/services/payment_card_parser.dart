enum PaymentCardNetwork {
  visa('Visa'),
  mastercard('Mastercard'),
  rupay('RuPay'),
  americanExpress('American Express'),
  unknown('Unknown network');

  const PaymentCardNetwork(this.label);

  final String label;
}

class ParsedPaymentCardData {
  const ParsedPaymentCardData({
    required this.cardNumber,
    required this.network,
    required this.rawText,
    required this.usedOcrCorrections,
  });

  final String cardNumber;
  final PaymentCardNetwork network;
  final String rawText;
  final bool usedOcrCorrections;

  bool get hasCardNumber =>
      cardNumber.isNotEmpty &&
      PaymentCardParser.isValidLength(cardNumber, network);

  bool get passesLuhnCheck => PaymentCardParser.passesLuhn(cardNumber);

  String get formattedCardNumber {
    if (cardNumber.isEmpty) return '';

    // American Express is conventionally displayed as 4-6-5.
    if (network == PaymentCardNetwork.americanExpress &&
        cardNumber.length == 15) {
      return '${cardNumber.substring(0, 4)} '
          '${cardNumber.substring(4, 10)} '
          '${cardNumber.substring(10)}';
    }

    final groups = <String>[];
    for (var start = 0; start < cardNumber.length; start += 4) {
      final end = (start + 4).clamp(0, cardNumber.length);
      groups.add(cardNumber.substring(start, end));
    }
    return groups.join(' ');
  }
}

class PaymentCardParser {
  // Allows irregular grouping and the separators commonly produced by OCR.
  // The digit boundaries prevent taking a valid-looking substring from a
  // longer number.
  static final RegExp _candidatePattern = RegExp(
    r'(?<!\d)\d(?:[ \t.\-–—]*\d){11,18}(?![ \t.\-–—]*\d)',
  );

  static ParsedPaymentCardData parse(String rawText) {
    final candidates = <_Candidate>[];

    for (final rawLine in rawText.split(RegExp(r'\r?\n'))) {
      final correctedLine = _correctDigitHeavyOcrLine(rawLine);
      final lineVariants = <String>[rawLine];
      if (correctedLine != rawLine) lineVariants.add(correctedLine);

      for (final line in lineVariants) {
        for (final match in _candidatePattern.allMatches(line)) {
          final number = match.group(0)!.replaceAll(RegExp(r'\D'), '');
          if (number.length < 12 || number.length > 19) continue;

          final network = _detectNetwork(number, rawText);
          candidates.add(
            _Candidate(
              number: number,
              network: network,
              usedOcrCorrections: line != rawLine,
            ),
          );
        }
      }
    }

    _Candidate? selected;
    for (final candidate in candidates) {
      if (isValidLength(candidate.number, candidate.network)) {
        selected = candidate;
        break;
      }
    }

    return ParsedPaymentCardData(
      cardNumber: selected?.number ?? '',
      network: selected?.network ?? PaymentCardNetwork.unknown,
      rawText: rawText,
      usedOcrCorrections: selected?.usedOcrCorrections ?? false,
    );
  }

  static bool isValidLength(String number, PaymentCardNetwork network) {
    switch (network) {
      case PaymentCardNetwork.visa:
        return const {13, 16, 19}.contains(number.length);
      case PaymentCardNetwork.mastercard:
      case PaymentCardNetwork.rupay:
        return number.length == 16;
      case PaymentCardNetwork.americanExpress:
        return number.length == 15;
      case PaymentCardNetwork.unknown:
        // Retain the original fallback for unrecognized networks.
        return number.length == 16;
    }
  }

  static bool passesLuhn(String number) {
    if (number.isEmpty || !RegExp(r'^\d+$').hasMatch(number)) return false;

    var sum = 0;
    var doubleDigit = false;
    for (var index = number.length - 1; index >= 0; index--) {
      var digit = int.parse(number[index]);
      if (doubleDigit) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      doubleDigit = !doubleDigit;
    }
    return sum % 10 == 0;
  }

  static String _correctDigitHeavyOcrLine(String line) {
    final digitCount = RegExp(r'\d').allMatches(line).length;
    if (digitCount < 10) return line;

    // Apply only high-confidence OCR corrections.
    // 'O' → '0' and 'I/l' → '1' are very low-risk.
    // We skip 'B' → '8' because 'b' can also be a misread '6',
    // and we can't know which without Luhn validation.
    var corrected = line
        .replaceAll(RegExp(r'[Oo]'), '0')
        .replaceAll(RegExp(r'[Il|]'), '1');

    // Strip characters that aren't digits or recognized separators.
    // OCR of card numbers often produces extra letters mixed with digits;
    // on digit-heavy lines, these are almost certainly artifacts.
    return corrected.replaceAll(RegExp(r'[a-zA-Z]'), '');
  }

  static PaymentCardNetwork _detectNetwork(String number, String rawText) {
    final lowerText = rawText.toLowerCase();

    // Printed brand text is the strongest signal, especially for RuPay,
    // whose issuer ranges can overlap other payment networks.
    if (lowerText.contains('american express') || lowerText.contains('amex')) {
      return PaymentCardNetwork.americanExpress;
    }
    if (lowerText.contains('mastercard') || lowerText.contains('master card')) {
      return PaymentCardNetwork.mastercard;
    }
    if (lowerText.contains('rupay') || lowerText.contains('ru pay')) {
      return PaymentCardNetwork.rupay;
    }
    if (RegExp(r'\bvisa\b').hasMatch(lowerText)) {
      return PaymentCardNetwork.visa;
    }

    if (number.startsWith('34') || number.startsWith('37')) {
      return PaymentCardNetwork.americanExpress;
    }
    if (number.startsWith('4')) return PaymentCardNetwork.visa;

    if (number.length >= 4) {
      final firstTwo = int.parse(number.substring(0, 2));
      final firstFour = int.parse(number.substring(0, 4));
      if ((firstTwo >= 51 && firstTwo <= 55) ||
          (firstFour >= 2221 && firstFour <= 2720)) {
        return PaymentCardNetwork.mastercard;
      }
    }

    // Common RuPay prefixes. Brand text above takes precedence because some
    // ranges overlap with international networks.
    if (number.startsWith('508') ||
        number.startsWith('60') ||
        number.startsWith('81') ||
        number.startsWith('82')) {
      return PaymentCardNetwork.rupay;
    }

    return PaymentCardNetwork.unknown;
  }
}

class _Candidate {
  const _Candidate({
    required this.number,
    required this.network,
    required this.usedOcrCorrections,
  });

  final String number;
  final PaymentCardNetwork network;
  final bool usedOcrCorrections;
}
