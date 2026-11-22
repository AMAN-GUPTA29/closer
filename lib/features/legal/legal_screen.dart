import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/closer_icons.dart';
import '../../core/theme/closer_theme.dart';
import '../../core/widgets/widgets.dart';
import '../auth/application/auth_providers.dart';
import 'legal_content.dart';

enum LegalDoc {
  privacy('Privacy policy', 'assets/legal/privacy.md'),
  terms('Terms of use', 'assets/legal/terms.md'),
  support('Help & support', 'assets/legal/support.md');

  const LegalDoc(this.title, this.asset);
  final String title;
  final String asset;

  static LegalDoc parse(String? value) => switch (value) {
    'terms' => LegalDoc.terms,
    'support' => LegalDoc.support,
    _ => LegalDoc.privacy,
  };
}

/// Shows a document from `assets/legal/` (the same text is published on the
/// web for the store listings, see `site/`).
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.doc});

  final LegalDoc doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final support = ref.watch(appConfigProvider).supportEmail;
    return Scaffold(
      appBar: AppBar(
        title: Text(doc.title),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(CloserIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<String>(
          future: DefaultAssetBundle.of(context).loadString(doc.asset),
          builder: (context, snapshot) {
            final source = snapshot.data;
            if (source == null) {
              return snapshot.hasError
                  ? const EmptyState(
                      icon: CloserIcons.document,
                      title: 'This page couldn’t be opened',
                      message: 'Please try again later.',
                    )
                  : const Center(child: CircularProgressIndicator());
            }
            final blocks = parseLegalMarkdown(
              source,
              contact: legalContactText(support),
            );
            return ListView(
              padding: const EdgeInsets.all(CloserSpacing.gutter),
              children: [
                for (final b in blocks) _Block(b),
                if (doc == LegalDoc.support && support.isNotEmpty) ...[
                  const SizedBox(height: CloserSpacing.sm),
                  CloserButton.secondary(
                    label: 'Email us',
                    onPressed: () =>
                        launchUrl(Uri(scheme: 'mailto', path: support)),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block(this.block);

  final LegalBlock block;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final body = context.text.bodyMedium?.copyWith(color: c.textPrimary);
    TextSpan rich(TextStyle? style) => TextSpan(
      children: [
        for (final (text, bold) in legalInlineRuns(block.text))
          TextSpan(
            text: text,
            style: bold ? const TextStyle(fontWeight: FontWeight.w600) : null,
          ),
      ],
      style: style,
    );
    return switch (block.kind) {
      // The app bar already shows the document title.
      LegalBlockKind.title => const SizedBox.shrink(),
      LegalBlockKind.heading => Padding(
        padding: const EdgeInsets.only(
          top: CloserSpacing.md,
          bottom: CloserSpacing.xs,
        ),
        child: Semantics(
          header: true,
          child: Text(block.text, style: context.text.titleMedium),
        ),
      ),
      LegalBlockKind.paragraph => Padding(
        padding: const EdgeInsets.only(bottom: CloserSpacing.sm),
        child: Text.rich(rich(body)),
      ),
      LegalBlockKind.bullet => DotPoint.rich(rich(null)),
    };
  }
}
