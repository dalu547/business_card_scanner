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
    print('\n=== Card Number Parser Started ===');
    print('Raw text to parse:\n$rawText\n');

    final candidates = <_Candidate>[];
    final lines = rawText.split(RegExp(r'\r?\n'));
    print('Found ${lines.length} lines to parse');

    for (var lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      final rawLine = lines[lineIdx];
      print('Line $lineIdx: "$rawLine"');

      // Generate all possible correction variants for this line
      final lineVariants = _generateCorrectionVariants(rawLine);

      for (final line in lineVariants) {
        for (final match in _candidatePattern.allMatches(line)) {
          final number = match.group(0)!.replaceAll(RegExp(r'\D'), '');
          print('  Found candidate: "$number" (${number.length} digits)');

          if (number.length < 12 || number.length > 19) {
            print('    ✗ Invalid length (need 12-19 digits)');
            continue;
          }

          final network = _detectNetwork(number, rawText);
          print('    ✓ Network: ${network.label}, Luhn: ${passesLuhn(number) ? "PASS" : "FAIL"}');
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

    print('\nFound ${candidates.length} total candidates');

    _Candidate? selected;
    for (final candidate in candidates) {
      final isValidLen = isValidLength(candidate.number, candidate.network);
      print('Checking candidate: ${candidate.number} (${candidate.network.label})');
      print('  Length valid: $isValidLen');

      if (isValidLen) {
        selected = candidate;
        print('  ✓ SELECTED');
        break;
      } else {
        print('  ✗ Invalid length for ${candidate.network.label}');
      }
    }

    if (selected == null) {
      print('\n✗ No valid card number found');
    } else {
      print('\n✓ Card number extracted: ${selected.number}');
    }
    print('=== Card Number Parser Completed ===\n');

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

    // Apply high-confidence OCR corrections.
    // 'O' → '0' and 'I/l' → '1' are very safe.
    return line
        .replaceAll(RegExp(r'[Oo]'), '0')
        .replaceAll(RegExp(r'[Il|]'), '1');
  }

  static List<String> _generateCorrectionVariants(String line) {
    // For lines with ambiguous letters like 'b'/'B' that could be misread digits,
    // generate multiple variants to try. We'll parse them all and keep valid ones.
    final variants = <String>{line}; // Start with original

    final digitCount = RegExp(r'\d').allMatches(line).length;
    if (digitCount < 10) return variants.toList();

    // Apply base corrections (safe substitutions)
    var corrected = _correctDigitHeavyOcrLine(line);
    variants.add(corrected);

    // For lines containing 'b' or 'B' (ambiguous: could be 6, 8, or noise):
    // Generate multiple interpretations
    if (RegExp(r'[bB]').hasMatch(corrected)) {
      // Variant 1: Remove 'b'/'B' (treat as noise/artifact)
      variants.add(corrected.replaceAll(RegExp(r'[bB]'), ''));

      // Variant 2: Convert 'b'/'B' to '6' (most common misread on cards)
      variants.add(corrected.replaceAll(RegExp(r'[bB]'), '6'));

      // Variant 3: Convert 'b'/'B' to '8' (embossed cards with 8 shaped like B)
      variants.add(corrected.replaceAll(RegExp(r'[bB]'), '8'));
    }

    // For any remaining letters, remove them (these are likely OCR noise)
    for (final variant in variants.toList()) {
      final cleaned = variant.replaceAll(RegExp(r'[a-zA-Z]'), '');
      if (cleaned != variant) {
        variants.add(cleaned);
      }
    }

    print('Generated ${variants.length} correction variants for: "$line"');
    for (final v in variants) {
      print('  - "$v"');
    }

    return variants.toList();
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
