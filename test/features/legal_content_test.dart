import 'package:closer/features/legal/legal_content.dart';
import 'package:closer/features/legal/legal_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses headings, joined paragraphs, bullets and the contact', () {
    const source = '''# Title

Intro line one
line two.

## Section
- **Bold** point
- Plain point

Ask: {{contact}}
''';
    expect(parseLegalMarkdown(source, contact: 'Email us.'), const [
      LegalBlock(LegalBlockKind.title, 'Title'),
      LegalBlock(LegalBlockKind.paragraph, 'Intro line one line two.'),
      LegalBlock(LegalBlockKind.heading, 'Section'),
      LegalBlock(LegalBlockKind.bullet, '**Bold** point'),
      LegalBlock(LegalBlockKind.bullet, 'Plain point'),
      LegalBlock(LegalBlockKind.paragraph, 'Ask: Email us.'),
    ]);
    expect(legalInlineRuns('**Bold** point'), [
      ('Bold', true),
      (' point', false),
    ]);
  });

  test('contact text depends on the support email', () {
    expect(legalContactText(''), contains('before Keeploom is released'));
    expect(legalContactText('help@x.io'), contains('help@x.io'));
  });

  for (final doc in LegalDoc.values) {
    test('${doc.name} document is bundled, titled and has a contact', () async {
      final source = await rootBundle.loadString(doc.asset);
      final blocks = parseLegalMarkdown(source);
      expect(blocks.first, LegalBlock(LegalBlockKind.title, doc.title));
      expect(source, contains('{{contact}}'));
      // Pricing must match the yearly pass, never the old one-time upgrade.
      expect(source.toLowerCase(), isNot(contains('one-time')));
    });
  }
}
