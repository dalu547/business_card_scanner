import 'package:business_card_scanner_demo/services/card_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CardParser benchmark', () {
    final samples = <_Sample>[
      _Sample(
        name: 'standard executive card',
        rawText: '''
JOHN DOE
Senior Sales Manager
Acme Solutions Pvt Ltd
Mobile: +1 415 555 2671
Office: +1 (415) 555-2600
john.doe@acme.com
www.acme.com
245 Market Street, San Francisco, CA 94105, USA
''',
        expectations: {
          'name': 'JOHN DOE',
          'designation': 'Senior Sales Manager',
          'company': 'Acme Solutions Pvt Ltd',
          'mobile': '+1 415 555 2671',
          'office': '+1 (415) 555-2600',
          'email': 'john.doe@acme.com',
          'website': 'https://www.acme.com',
          'country': 'United States',
        },
      ),
      _Sample(
        name: 'minimal startup card',
        rawText: '''
Emily Carter
Co-Founder
BrightLoop Labs
+44 7700 900123
emily@brightloop.io
brightloop.io
''',
        expectations: {
          'name': 'Emily Carter',
          'designation': 'Co-Founder',
          'company': 'BrightLoop Labs',
          'mobile': '+44 7700 900123',
          'email': 'emily@brightloop.io',
          'website': 'https://brightloop.io',
        },
      ),
      _Sample(
        name: 'with social links',
        rawText: '''
Michael Brown
Product Manager
Nova Digital Inc.
M: +91 98765 43210
T: +91 22 4012 9911
michael.brown@novadigital.com
novadigital.com
linkedin.com/in/michaelbrownpm
instagram.com/mikebuilds
''',
        expectations: {
          'name': 'Michael Brown',
          'designation': 'Product Manager',
          'company': 'Nova Digital Inc.',
          'mobile': '+91 98765 43210',
          'office': '+91 22 4012 9911',
          'email': 'michael.brown@novadigital.com',
          'website': 'https://novadigital.com',
          'linkedin': 'https://linkedin.com/in/michaelbrownpm',
          'instagram': 'https://instagram.com/mikebuilds',
        },
      ),
      _Sample(
        name: 'logo text present in OCR',
        rawText: '''
INNOVATE
Sarah Wilson
HR Director
PeopleFirst Consulting LLC
Cell: +1-303-555-1133
sarah.wilson@peoplefirst.co
www.peoplefirst.co
''',
        expectations: {
          'name': 'Sarah Wilson',
          'designation': 'HR Director',
          'company': 'PeopleFirst Consulting LLC',
          'mobile': '+1-303-555-1133',
          'email': 'sarah.wilson@peoplefirst.co',
          'website': 'https://www.peoplefirst.co',
        },
      ),
      _Sample(
        name: 'address heavy card',
        rawText: '''
Priya Menon
Business Development Manager
Orbit Systems Ltd
Mobile +91 99887 77665
priya.menon@orbitsystems.in
orbitsystems.in
2nd Floor, Sapphire Tower, MG Road,
Bengaluru, Karnataka 560001, India
''',
        expectations: {
          'name': 'Priya Menon',
          'designation': 'Business Development Manager',
          'company': 'Orbit Systems Ltd',
          'mobile': '+91 99887 77665',
          'email': 'priya.menon@orbitsystems.in',
          'website': 'https://orbitsystems.in',
          'pincode': '560001',
          'country': 'India',
        },
      ),
      _Sample(
        name: 'email first layout',
        rawText: '''
support@blueharbor.tech
Blue Harbor Technologies
Daniel Kim
Lead Engineer
+1 646 555 9001
blueharbor.tech
''',
        expectations: {
          'name': 'Daniel Kim',
          'designation': 'Lead Engineer',
          'company': 'Blue Harbor Technologies',
          'mobile': '+1 646 555 9001',
          'email': 'support@blueharbor.tech',
          'website': 'https://blueharbor.tech',
        },
      ),
      _Sample(
        name: 'two mobiles and office',
        rawText: '''
Ava Thompson
Regional Director
Northfield Group
Mob: +1 202 555 4422 / +1 202 555 7788
Office: +1 202 555 1100
ava.thompson@northfieldgroup.com
www.northfieldgroup.com
''',
        expectations: {
          'name': 'Ava Thompson',
          'designation': 'Regional Director',
          'company': 'Northfield Group',
          'mobile': '+1 202 555 4422',
          'secondaryMobile': '+1 202 555 7788',
          'office': '+1 202 555 1100',
          'email': 'ava.thompson@northfieldgroup.com',
        },
      ),
      _Sample(
        name: 'domain without scheme and mixed case',
        rawText: '''
ROBERT KING
Chief Technology Officer
AlphaCore Ventures
Phone: +1 (917) 555-7721
ROBERT.KING@ALPHACORE.AI
WWW.ALPHACORE.AI
''',
        expectations: {
          'name': 'ROBERT KING',
          'designation': 'Chief Technology Officer',
          'company': 'AlphaCore Ventures',
          'mobile': '+1 (917) 555-7721',
          'email': 'robert.king@alphacore.ai',
          'website': 'https://WWW.ALPHACORE.AI',
        },
      ),
      _Sample(
        name: 'canada postal code',
        rawText: '''
Olivia Grant
Marketing Specialist
Maple Peak Agency
+1 416 555 2100
olivia@maplepeak.ca
maplepeak.ca
120 Queen St W, Toronto, ON M5H 2N2, Canada
''',
        expectations: {
          'name': 'Olivia Grant',
          'designation': 'Marketing Specialist',
          'company': 'Maple Peak Agency',
          'mobile': '+1 416 555 2100',
          'email': 'olivia@maplepeak.ca',
          'pincode': 'M5H 2N2',
          'country': 'Canada',
        },
      ),
      _Sample(
        name: 'social handle text',
        rawText: '''
Noah Patel
Sales Executive
Vertex Global Services
Mobile: +971 50 123 4567
noah@vertexglobal.ae
vertexglobal.ae
LinkedIn @noahpatel
X: @noah_sells
''',
        expectations: {
          'name': 'Noah Patel',
          'designation': 'Sales Executive',
          'company': 'Vertex Global Services',
          'mobile': '+971 50 123 4567',
          'email': 'noah@vertexglobal.ae',
          'linkedin': 'LinkedIn @noahpatel',
          'twitter': 'X: @noah_sells',
          'country': 'United Arab Emirates',
        },
      ),
      _Sample(
        name: 'all caps name with designer title',
        rawText: '''
THOMAS SMITH
Graphic Designer
your_email_add@gmail.com
phone: +18 2767 9470 1808
www.company-name.com
Media
SLOGANHERE
''',
        expectations: {
          'name': 'THOMAS SMITH',
          'designation': 'Graphic Designer',
          'email': 'your_email_add@gmail.com',
          'website': 'https://www.company-name.com',
        },
      ),
    ];

    test('parses core fields across representative english cards', () {
      for (final sample in samples) {
        final parsed = CardParser.parse(sample.rawText);
        final failures = _compare(parsed, sample.expectations);
        expect(
          failures,
          isEmpty,
          reason: 'Sample "${sample.name}" failed: ${failures.join('; ')}',
        );
      }
    });

    test('reports benchmark accuracy percentage', () {
      var totalChecks = 0;
      var passedChecks = 0;

      for (final sample in samples) {
        final parsed = CardParser.parse(sample.rawText);
        final checks = _countMatches(parsed, sample.expectations);
        totalChecks += checks.total;
        passedChecks += checks.passed;
      }

      final accuracy = totalChecks == 0 ? 0 : (passedChecks * 100) / totalChecks;
      // Keep this threshold realistic for heuristic parsing.
      expect(accuracy, greaterThanOrEqualTo(90));

      // ignore: avoid_print
      print('Parser benchmark accuracy: ${accuracy.toStringAsFixed(2)}% ' 
          '($passedChecks/$totalChecks checks)');
    });
  });
}

List<String> _compare(
  ParsedCardData parsed,
  Map<String, String> expected,
) {
  final failures = <String>[];

  for (final entry in expected.entries) {
    final actual = _valueForKey(parsed, entry.key);
    if (actual != entry.value) {
      failures.add('${entry.key}: expected "${entry.value}", got "$actual"');
    }
  }

  return failures;
}

_AccuracyCounts _countMatches(
  ParsedCardData parsed,
  Map<String, String> expected,
) {
  var passed = 0;
  var total = 0;

  for (final entry in expected.entries) {
    total += 1;
    if (_valueForKey(parsed, entry.key) == entry.value) {
      passed += 1;
    }
  }

  return _AccuracyCounts(total: total, passed: passed);
}

String _valueForKey(ParsedCardData parsed, String key) {
  switch (key) {
    case 'name':
      return parsed.name;
    case 'designation':
      return parsed.designation;
    case 'company':
      return parsed.company;
    case 'mobile':
      return parsed.mobileNumber;
    case 'secondaryMobile':
      return parsed.secondaryMobile;
    case 'office':
      return parsed.officePhone;
    case 'email':
      return parsed.email;
    case 'website':
      return parsed.website;
    case 'address':
      return parsed.address;
    case 'city':
      return parsed.city;
    case 'state':
      return parsed.state;
    case 'pincode':
      return parsed.pincode;
    case 'country':
      return parsed.country;
    case 'linkedin':
      return parsed.linkedin;
    case 'instagram':
      return parsed.instagram;
    case 'twitter':
      return parsed.twitter;
    case 'notes':
      return parsed.notes;
    default:
      return '';
  }
}

class _Sample {
  const _Sample({
    required this.name,
    required this.rawText,
    required this.expectations,
  });

  final String name;
  final String rawText;
  final Map<String, String> expectations;
}

class _AccuracyCounts {
  const _AccuracyCounts({required this.total, required this.passed});

  final int total;
  final int passed;
}
