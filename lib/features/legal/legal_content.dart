/// The privacy policy, terms and support page live in `assets/legal/*.md`.
/// The same files are published as web pages by `site/build.mjs`, so the app
/// and the store links always show the same text. Only a small subset of
/// Markdown is used: `#`/`##` headings, paragraphs, `- ` bullets and
/// `**bold**`, plus a `{{contact}}` placeholder.
library;

enum LegalBlockKind { title, heading, paragraph, bullet }

class LegalBlock {
  const LegalBlock(this.kind, this.text);

  final LegalBlockKind kind;

  /// Raw text, still containing `**bold**` markers.
  final String text;

  @override
  bool operator ==(Object other) =>
      other is LegalBlock && other.kind == kind && other.text == text;

  @override
  int get hashCode => Object.hash(kind, text);

  @override
  String toString() => '$kind: $text';
}

/// What `{{contact}}` becomes, given the configured support email.
String legalContactText(String supportEmail) => supportEmail.isEmpty
    ? 'Contact details will be added here before Keeploom is released.'
    : 'Email us at $supportEmail. We reply within a few working days.';

/// Splits a document into blocks. Lines in one paragraph are joined.
List<LegalBlock> parseLegalMarkdown(String source, {String contact = ''}) {
  final blocks = <LegalBlock>[];
  final paragraph = <String>[];

  void flush() {
    if (paragraph.isEmpty) return;
    blocks.add(LegalBlock(LegalBlockKind.paragraph, paragraph.join(' ')));
    paragraph.clear();
  }

  for (final raw in source.replaceAll('{{contact}}', contact).split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) {
      flush();
    } else if (line.startsWith('## ')) {
      flush();
      blocks.add(LegalBlock(LegalBlockKind.heading, line.substring(3)));
    } else if (line.startsWith('# ')) {
      flush();
      blocks.add(LegalBlock(LegalBlockKind.title, line.substring(2)));
    } else if (line.startsWith('- ')) {
      flush();
      blocks.add(LegalBlock(LegalBlockKind.bullet, line.substring(2)));
    } else {
      paragraph.add(line);
    }
  }
  flush();
  return blocks;
}

/// Splits `**bold**` runs: returns (text, isBold) pairs in order.
List<(String, bool)> legalInlineRuns(String text) {
  final parts = text.split('**');
  return [
    for (var i = 0; i < parts.length; i++)
      if (parts[i].isNotEmpty) (parts[i], i.isOdd),
  ];
}
