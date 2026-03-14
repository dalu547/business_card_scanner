class ParsedCardData {
  const ParsedCardData({
    required this.name,
    required this.designation,
    required this.company,
    required this.mobileNumber,
    required this.secondaryMobile,
    required this.officePhone,
    required this.email,
    required this.website,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.country,
    required this.linkedin,
    required this.instagram,
    required this.twitter,
    required this.notes,
    required this.rawText,
  });

  final String name;
  final String designation;
  final String company;
  final String mobileNumber;
  final String secondaryMobile;
  final String officePhone;
  final String email;
  final String website;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String country;
  final String linkedin;
  final String instagram;
  final String twitter;
  final String notes;
  final String rawText;
}

class CardParser {
  static ParsedCardData parse(String rawText) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((line) => _clean(line))
        .where((line) => line.isNotEmpty)
        .toList();

    final usedIndices = <int>{};
    final emails = _extractEmails(lines, usedIndices);
    final websites = _extractWebsites(lines, usedIndices);
    final phones = _extractPhones(lines, usedIndices);
    final social = _extractSocial(lines, websites, usedIndices);
    final roleData = _extractNameRoleCompany(
      lines,
      usedIndices,
      primaryEmail: emails.isNotEmpty ? emails.first : '',
      primaryWebsite: websites.isNotEmpty ? websites.first : '',
    );
    final addressData = _extractAddress(lines, usedIndices);

    final notes = _buildNotes(lines, usedIndices);

    return ParsedCardData(
      name: roleData.name,
      designation: roleData.designation,
      company: roleData.company,
      mobileNumber: phones.mobile,
      secondaryMobile: phones.secondaryMobile,
      officePhone: phones.office,
      email: emails.isNotEmpty ? emails.first : '',
      website: websites.isNotEmpty ? websites.first : '',
      address: addressData.address,
      city: addressData.city,
      state: addressData.state,
      pincode: addressData.pincode,
      country: addressData.country,
      linkedin: social.linkedin,
      instagram: social.instagram,
      twitter: social.twitter,
      notes: notes,
      rawText: rawText,
    );
  }

  static String _clean(String line) {
    return line
        .replaceAll('•', ' ')
        .replaceAll('|', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<String> _extractEmails(List<String> lines, Set<int> usedIndices) {
    final emailRegex = RegExp(
      r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
      caseSensitive: false,
    );
    final emails = <String>[];

    for (var i = 0; i < lines.length; i++) {
      for (final match in emailRegex.allMatches(lines[i])) {
        final value = (match.group(0) ?? '').toLowerCase();
        if (value.isNotEmpty && !emails.contains(value)) {
          emails.add(value);
          usedIndices.add(i);
        }
      }
    }

    return emails;
  }

  static List<String> _extractWebsites(
    List<String> lines,
    Set<int> usedIndices,
  ) {
    final websites = <String>[];
    final webRegex = RegExp(
      r'\b((?:https?:\/\/)?(?:www\.)?[a-z0-9-]+(?:\.[a-z0-9-]+)+(?:\/[\w\-./?%&=]*)?)\b',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lowerLine = line.toLowerCase();
      if (lowerLine.contains('@') &&
          !lowerLine.contains('www') &&
          !lowerLine.contains('http')) {
        continue;
      }

      for (final match in webRegex.allMatches(line)) {
        final raw = (match.group(1) ?? '').trim();
        if (raw.isEmpty) continue;

        final lower = raw.toLowerCase();
        final looksLikeDomain = lower.contains('.') &&
            !lower.contains('@') &&
            !lower.contains('linkedin.com') &&
            !lower.contains('instagram.com') &&
            !lower.contains('twitter.com') &&
            !lower.contains('x.com/');

        if (!looksLikeDomain) continue;

        final normalized = _normalizeUrl(raw);
        if (!_isProbablyWebsite(normalized)) continue;

        if (!websites.contains(normalized)) {
          websites.add(normalized);
          usedIndices.add(i);
        }
      }
    }

    return websites;
  }

  static _PhoneData _extractPhones(List<String> lines, Set<int> usedIndices) {
    final phoneRegex = RegExp(
      r'(?:\+?\d[\d\s().-]{6,}\d)(?:\s*(?:x|ext\.?|extension)\s*\d{1,5})?',
      caseSensitive: false,
    );

    final seen = <String>{};
    String mobile = '';
    String secondaryMobile = '';
    String office = '';

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();
      final linePhones = <String>[];

      for (final match in phoneRegex.allMatches(line)) {
        final candidate = (match.group(0) ?? '').trim();
        final normalized = _normalizePhone(candidate);
        final digitCount = _phoneDigitCount(normalized);
        if (digitCount < 8 || digitCount > 15) continue;
        if (seen.add(normalized)) {
          linePhones.add(normalized);
        }
      }

      if (linePhones.isEmpty) continue;

      final hasMobileLabel = lower.contains('mobile') ||
          lower.contains('mob') ||
          lower.contains('cell') ||
          lower.contains('m:') ||
          lower.contains('whatsapp') ||
          lower.contains('wa');
      final hasOfficeLabel = lower.contains('office') ||
          lower.contains('tel') ||
          lower.contains('t:') ||
          lower.contains('phone') ||
          lower.contains('landline') ||
          lower.contains('direct') ||
          lower.contains('desk');

      for (final phone in linePhones) {
        if (hasMobileLabel) {
          if (mobile.isEmpty) {
            mobile = phone;
          } else if (secondaryMobile.isEmpty && phone != mobile) {
            secondaryMobile = phone;
          }
          usedIndices.add(i);
          continue;
        }

        if (hasOfficeLabel) {
          if (office.isEmpty) {
            office = phone;
          } else if (mobile.isEmpty) {
            mobile = phone;
          } else if (secondaryMobile.isEmpty && phone != mobile) {
            secondaryMobile = phone;
          }
          usedIndices.add(i);
          continue;
        }

        if (mobile.isEmpty) {
          mobile = phone;
        } else if (secondaryMobile.isEmpty && phone != mobile) {
          secondaryMobile = phone;
        } else if (office.isEmpty &&
            phone != mobile &&
            phone != secondaryMobile) {
          office = phone;
        }

        usedIndices.add(i);
      }
    }

    if (mobile.isEmpty && office.isNotEmpty) {
      mobile = office;
    }

    return _PhoneData(
      mobile: mobile,
      secondaryMobile: secondaryMobile,
      office: office,
    );
  }

  static _SocialData _extractSocial(
    List<String> lines,
    List<String> websites,
    Set<int> usedIndices,
  ) {
    String linkedin = '';
    String instagram = '';
    String twitter = '';

    final candidates = <String>[...lines, ...websites];

    for (var i = 0; i < candidates.length; i++) {
      final source = candidates[i].trim();
      if (source.isEmpty) continue;

      final lower = source.toLowerCase();
      final normalized = _normalizeUrl(source);

      if (linkedin.isEmpty && lower.contains('linkedin.com')) {
        linkedin = normalized;
        if (i < lines.length) usedIndices.add(i);
      }

      if (instagram.isEmpty && lower.contains('instagram.com')) {
        instagram = normalized;
        if (i < lines.length) usedIndices.add(i);
      }

      if (twitter.isEmpty &&
          (lower.contains('twitter.com') || lower.contains('x.com/'))) {
        twitter = normalized;
        if (i < lines.length) usedIndices.add(i);
      }

      final hasHandle =
          RegExp(r'(^|\s)@[a-z0-9_.]+', caseSensitive: false).hasMatch(source);
      if (!hasHandle) continue;

      if (linkedin.isEmpty && lower.contains('linkedin')) {
        linkedin = source;
        if (i < lines.length) usedIndices.add(i);
      }
      if (instagram.isEmpty && lower.contains('insta')) {
        instagram = source;
        if (i < lines.length) usedIndices.add(i);
      }
      if (twitter.isEmpty &&
          (lower.contains('twitter') || lower.contains('x:'))) {
        twitter = source;
        if (i < lines.length) usedIndices.add(i);
      }
    }

    return _SocialData(
      linkedin: linkedin,
      instagram: instagram,
      twitter: twitter,
    );
  }

  static _RoleData _extractNameRoleCompany(
    List<String> lines,
    Set<int> usedIndices, {
    required String primaryEmail,
    required String primaryWebsite,
  }) {
    String name = '';
    String designation = '';
    String company = '';

    final headerLimit = lines.length < 12 ? lines.length : 12;

    final scoredNameCandidates = <_ScoredLine>[];
    final scoredDesignationCandidates = <_ScoredLine>[];
    final scoredCompanyCandidates = <_ScoredLine>[];

    for (var i = 0; i < headerLimit; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      if (_isContactMetaLine(lower) || _likelyPhoneLine(line)) {
        continue;
      }

      final nameScore = _nameScore(line, lower);
      if (nameScore > 0) {
        scoredNameCandidates.add(_ScoredLine(i, line, nameScore));
      }

      final designationScore = _designationScore(lower);
      if (designationScore > 0) {
        scoredDesignationCandidates.add(_ScoredLine(i, line, designationScore));
      }

      final companyScore = _companyScore(line, lower);
      if (companyScore > 0) {
        scoredCompanyCandidates.add(_ScoredLine(i, line, companyScore));
      }
    }

    scoredNameCandidates.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.index.compareTo(b.index);
    });
    scoredDesignationCandidates.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.index.compareTo(b.index);
    });
    scoredCompanyCandidates.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.index.compareTo(b.index);
    });

    if (scoredNameCandidates.isNotEmpty) {
      name = scoredNameCandidates.first.line;
      usedIndices.add(scoredNameCandidates.first.index);
    }

    if (scoredDesignationCandidates.isNotEmpty) {
      final pick = scoredDesignationCandidates.firstWhere(
        (item) => item.line != name,
        orElse: () => scoredDesignationCandidates.first,
      );
      designation = pick.line;
      usedIndices.add(pick.index);
    }

    if (scoredCompanyCandidates.isNotEmpty) {
      final pick = scoredCompanyCandidates.firstWhere(
        (item) => item.line != name && item.line != designation,
        orElse: () => scoredCompanyCandidates.first,
      );
      company = pick.line;
      usedIndices.add(pick.index);
    }

    if (company.isEmpty && primaryWebsite.isNotEmpty) {
      final host = _hostFromUrl(primaryWebsite);
      if (host.isNotEmpty) {
        company = host
            .split('.')
            .first
            .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), ' ')
            .trim();
        company = _titleCase(company);
      }
    }

    if (name.isEmpty && primaryEmail.isNotEmpty) {
      final local = primaryEmail
          .split('@')
          .first
          .replaceAll(RegExp(r'[._-]+'), ' ')
          .trim();
      if (local.isNotEmpty) {
        name = local
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
      }
    }

    return _RoleData(name: name, designation: designation, company: company);
  }

  static _AddressData _extractAddress(
    List<String> lines,
    Set<int> usedIndices,
  ) {
    final addressLines = <String>[];
    String city = '';
    String state = '';
    String pincode = '';
    String country = '';

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      if (!_likelyPhoneLine(line) &&
          !lower.contains('mobile') &&
          !lower.contains('mob') &&
          !lower.contains('tel') &&
          !lower.contains('phone')) {
        final pinMatch = RegExp(
          r'\b\d{5}(?:-\d{4})?\b|\b\d{6}\b|\b[A-Z]\d[A-Z]\s?\d[A-Z]\d\b',
          caseSensitive: false,
        ).firstMatch(line);
        if (pincode.isEmpty && pinMatch != null) {
          pincode = (pinMatch.group(0) ?? '').trim();
        }
      }

      if (country.isEmpty) {
        for (final c in _countryKeywords) {
          if (lower.contains(c)) {
            country = _normalizedCountry(c);
            break;
          }
        }
      }

      final looksLikeAddress = _looksLikeAddressLine(lower) ||
          (pincode.isNotEmpty && line.contains(pincode));

      if (looksLikeAddress) {
        addressLines.add(line);
        usedIndices.add(i);
      }

      final parts = line
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (parts.length >= 2) {
        if (city.isEmpty) {
          final candidate =
              parts[parts.length - 2].replaceAll(RegExp(r'\d'), '').trim();
          if (_isLikelyCity(candidate)) city = candidate;
        }

        if (state.isEmpty) {
          final tail = parts.last.replaceAll(RegExp(r'\d'), '').trim();
          if (_isLikelyState(tail)) state = tail;
        }
      }
    }

    if (country.isEmpty) {
      country = _inferCountryFromCallingCode(lines);
    }

    var address = addressLines.toSet().join(', ');

    if (address.isEmpty) {
      final fallback = <String>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lower = line.toLowerCase();
        if (usedIndices.contains(i)) continue;
        if (_isContactMetaLine(lower)) continue;
        if (_likelyPhoneLine(line)) continue;
        if (_likelyNameOrRoleLine(lower)) continue;
        if (_companyScore(line, lower) >= 4) continue;
        if (_looksLikeNoiseLine(line, lower)) continue;

        fallback.add(line);
        usedIndices.add(i);
        if (fallback.length == 3) break;
      }
      address = fallback.join(', ');
    }

    if (city.isEmpty || state.isEmpty) {
      final tokens = address
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (city.isEmpty && tokens.length >= 2) {
        final candidate =
            tokens[tokens.length - 2].replaceAll(RegExp(r'\d'), '').trim();
        if (_isLikelyCity(candidate)) city = candidate;
      }
      if (state.isEmpty && tokens.isNotEmpty) {
        final candidate = tokens.last.replaceAll(RegExp(r'\d'), '').trim();
        if (_isLikelyState(candidate)) state = candidate;
      }
    }

    return _AddressData(
      address: address,
      city: city,
      state: state,
      pincode: pincode,
      country: country,
    );
  }

  static bool _isContactMetaLine(String lower) {
    final hasPhoneLabel = RegExp(
      r'\b(tel|mobile|mob|phone|office|cell|landline|whatsapp)\b|(^|\s)[mtp]:',
      caseSensitive: false,
    ).hasMatch(lower);

    return lower.contains('@') ||
        lower.contains('http') ||
        lower.contains('www') ||
        lower.contains('linkedin') ||
        lower.contains('instagram') ||
        lower.contains('twitter') ||
        lower.contains('x.com') ||
        hasPhoneLabel;
  }

  static int _nameScore(String line, String lower) {
    final words =
        line.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (words.length < 2 || words.length > 4) return 0;
    if (RegExp(r'\d').hasMatch(line)) return 0;
    if (_designationScore(lower) > 0 || _companyScore(line, lower) >= 4) {
      return 0;
    }
    if (_looksLikeAddressLine(lower)) return 0;

    var score = 2;
    final capsWords = words.where(_looksLikePersonNameWord).length;
    if (capsWords >= 2) score += 3;
    if (lower.contains('.') &&
        !lower.contains('mr.') &&
        !lower.contains('ms.')) {
      score -= 2;
    }
    return score;
  }

  static bool _looksLikePersonNameWord(String word) {
    final clean = word.replaceAll(RegExp(r"[^A-Za-z'-]"), '');
    if (clean.isEmpty) return false;
    if (clean.length == 1) return true;
    final first = clean[0];
    final rest = clean.substring(1);
    final titleCaseLike =
        RegExp(r'[A-Z]').hasMatch(first) && rest == rest.toLowerCase();
    final upperCaseLike = clean == clean.toUpperCase();
    return titleCaseLike || upperCaseLike;
  }

  static int _designationScore(String lower) {
    var score = 0;
    for (final keyword in _designationKeywords) {
      if (lower.contains(keyword)) {
        score += keyword.contains(' ') ? 5 : 4;
      }
    }
    if (lower.contains('department')) score += 2;
    return score;
  }

  static int _companyScore(String line, String lower) {
    if (RegExp(r'\d').hasMatch(line)) return 0;
    if (_isContactMetaLine(lower)) return 0;

    var score = 0;
    for (final keyword in _companyKeywords) {
      if (lower.contains(keyword)) {
        score += keyword.length <= 3 ? 3 : 4;
      }
    }

    if (RegExp(r'^[A-Z0-9& .,-]{4,}$').hasMatch(line) &&
        line.split(RegExp(r'\s+')).length <= 5) {
      score += 2;
    }

    if (line.split(RegExp(r'\s+')).length >= 2 &&
        line.split(RegExp(r'\s+')).length <= 6) {
      score += 1;
    }

    return score;
  }

  static bool _looksLikeAddressLine(String lower) {
    for (final keyword in _addressKeywords) {
      if (lower.contains(keyword)) return true;
    }

    return false;
  }

  static bool _looksLikeNoiseLine(String line, String lower) {
    if (line.length <= 2) return true;
    if (RegExp(r'^[^A-Za-z0-9]+$').hasMatch(line)) return true;

    final words = line.split(RegExp(r'\s+'));
    if (words.length == 1) {
      final word = words.first;
      if (word == word.toUpperCase() && word.length <= 3) {
        return true;
      }
    }

    if (lower.contains('scan me') || lower.contains('follow us')) {
      return true;
    }

    return false;
  }

  static bool _likelyPhoneLine(String line) {
    return RegExp(r'^[+\d()\s.-]{8,}$').hasMatch(line.trim());
  }

  static bool _likelyNameOrRoleLine(String lower) {
    return _designationScore(lower) > 0;
  }

  static String _buildNotes(List<String> lines, Set<int> usedIndices) {
    final remaining = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (!usedIndices.contains(i) &&
          !_looksLikeNoiseLine(lines[i], lines[i].toLowerCase())) {
        remaining.add(lines[i]);
      }
    }
    return remaining.join('\n');
  }

  static int _phoneDigitCount(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '').length;
  }

  static String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _normalizeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  static bool _isProbablyWebsite(String value) {
    final host = _hostFromUrl(value);
    if (host.isEmpty) return false;
    return RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+$', caseSensitive: false)
        .hasMatch(host);
  }

  static String _hostFromUrl(String value) {
    try {
      return Uri.parse(value).host.toLowerCase();
    } catch (_) {
      return '';
    }
  }

  static bool _isLikelyCity(String value) {
    if (value.isEmpty) return false;
    if (value.length < 2 || value.length > 40) return false;
    if (RegExp(r'\d').hasMatch(value)) return false;
    final tokenCount = value.split(RegExp(r'\s+')).length;
    return tokenCount <= 4;
  }

  static bool _isLikelyState(String value) {
    if (value.isEmpty) return false;
    if (RegExp(r'\d').hasMatch(value)) return false;
    final normalized = value.toUpperCase();
    if (_usStateCodes.contains(normalized)) return true;

    final tokenCount = value.split(RegExp(r'\s+')).length;
    return tokenCount <= 4;
  }

  static String _normalizedCountry(String value) {
    if (value == 'usa' || value == 'u.s.a' || value == 'us') {
      return 'United States';
    }
    if (value == 'uk') {
      return 'United Kingdom';
    }
    if (value == 'uae') {
      return 'United Arab Emirates';
    }
    return _titleCase(value);
  }

  static String _inferCountryFromCallingCode(List<String> lines) {
    final joined = lines.join(' ').toLowerCase();
    if (joined.contains('+971')) return 'United Arab Emirates';
    if (joined.contains('+91')) return 'India';
    if (joined.contains('+44')) return 'United Kingdom';
    if (joined.contains('+61')) return 'Australia';
    if (joined.contains('+65')) return 'Singapore';
    if (joined.contains('+49')) return 'Germany';
    if (joined.contains('+33')) return 'France';
    if (joined.contains('+81')) return 'Japan';
    if (joined.contains('+86')) return 'China';
    return '';
  }

  static String _titleCase(String value) {
    return value
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  static const Set<String> _companyKeywords = {
    'pvt',
    'private',
    'limited',
    'ltd',
    'llc',
    'inc',
    'corp',
    'corporation',
    'co.',
    'co ',
    'group',
    'systems',
    'solutions',
    'services',
    'technologies',
    'technology',
    'enterprises',
    'partners',
    'consulting',
    'digital',
    'labs',
    'studio',
    'holdings',
    'global',
    'ventures',
    'agency',
    'industries',
    'associates',
    'plc',
    'llp',
    'gmbh',
  };

  static const Set<String> _designationKeywords = {
    'ceo',
    'cto',
    'cfo',
    'coo',
    'chief executive officer',
    'chief technology officer',
    'chief operating officer',
    'chief financial officer',
    'founder',
    'co-founder',
    'director',
    'managing director',
    'general manager',
    'manager',
    'engineer',
    'developer',
    'designer',
    'graphic designer',
    'ui designer',
    'ux designer',
    'architect',
    'analyst',
    'consultant',
    'executive',
    'officer',
    'president',
    'vice president',
    'vp',
    'head',
    'lead',
    'specialist',
    'associate',
    'admin',
    'marketing',
    'sales',
    'hr',
    'human resources',
    'business development',
    'product manager',
    'project manager',
    'account manager',
    'operations manager',
  };

  static const Set<String> _addressKeywords = {
    'address',
    'road',
    ' rd',
    'rd ',
    'street',
    ' st',
    'st ',
    'avenue',
    'ave',
    'lane',
    'nagar',
    'colony',
    'building',
    'floor',
    'flr',
    'suite',
    'ste',
    'block',
    'sector',
    'district',
    'near',
    'plot',
    'tower',
    'parkway',
    'boulevard',
    'blvd',
    'zip',
    'postal',
  };

  static const Set<String> _countryKeywords = {
    'india',
    'united states',
    'usa',
    'u.s.a',
    'uk',
    'united kingdom',
    'canada',
    'australia',
    'singapore',
    'uae',
    'germany',
    'france',
    'japan',
    'china',
    'netherlands',
    'switzerland',
    'ireland',
    'new zealand',
    'south africa',
  };

  static const Set<String> _usStateCodes = {
    'AL',
    'AK',
    'AZ',
    'AR',
    'CA',
    'CO',
    'CT',
    'DE',
    'FL',
    'GA',
    'HI',
    'ID',
    'IL',
    'IN',
    'IA',
    'KS',
    'KY',
    'LA',
    'ME',
    'MD',
    'MA',
    'MI',
    'MN',
    'MS',
    'MO',
    'MT',
    'NE',
    'NV',
    'NH',
    'NJ',
    'NM',
    'NY',
    'NC',
    'ND',
    'OH',
    'OK',
    'OR',
    'PA',
    'RI',
    'SC',
    'SD',
    'TN',
    'TX',
    'UT',
    'VT',
    'VA',
    'WA',
    'WV',
    'WI',
    'WY',
  };
}

class _PhoneData {
  const _PhoneData({
    required this.mobile,
    required this.secondaryMobile,
    required this.office,
  });

  final String mobile;
  final String secondaryMobile;
  final String office;
}

class _SocialData {
  const _SocialData({
    required this.linkedin,
    required this.instagram,
    required this.twitter,
  });

  final String linkedin;
  final String instagram;
  final String twitter;
}

class _RoleData {
  const _RoleData({
    required this.name,
    required this.designation,
    required this.company,
  });

  final String name;
  final String designation;
  final String company;
}

class _AddressData {
  const _AddressData({
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.country,
  });

  final String address;
  final String city;
  final String state;
  final String pincode;
  final String country;
}

class _ScoredLine {
  const _ScoredLine(this.index, this.line, this.score);

  final int index;
  final String line;
  final int score;
}
