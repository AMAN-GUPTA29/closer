import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/closer_icons.dart';
import '../../core/theme/closer_theme.dart';
import '../../core/widgets/widgets.dart';
import '../auth/application/auth_providers.dart';

enum LegalDoc {
  privacy('Privacy policy'),
  terms('Terms of use');

  const LegalDoc(this.title);
  final String title;

  static LegalDoc parse(String? value) =>
      value == 'terms' ? LegalDoc.terms : LegalDoc.privacy;
}

/// Shows a plain-language summary and links to the published document when
/// its URL is configured. The summary is a draft until legal review.
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.doc});

  final LegalDoc doc;

  static const _privacy = [
    'Your groups are private. Only members can see a group\'s photos, '
        'journal and milestones.',
    'Photos are stored in private cloud storage and are delivered through '
        'short-lived, authenticated links.',
    'We do not sell your data or show ads. We do not log your captions or '
        'photos in diagnostics.',
    'Notifications never include your photos or private captions.',
    'You can delete your account at any time from Profile.',
  ];

  static const _terms = [
    'Only share photos you have the right to share.',
    'Basic groups keep the latest 10 photos. Older photos are removed '
        'permanently when new ones are added.',
    'Keeploom Memories is a one-time upgrade for a single group that keeps '
        'every photo for all of its members.',
    'Do not use Keeploom to harass others or share illegal content.',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final url = doc == LegalDoc.privacy
        ? (config.hasPrivacyPolicy ? config.privacyPolicyUrl : null)
        : (config.hasTerms ? config.termsUrl : null);
    final points = doc == LegalDoc.privacy ? _privacy : _terms;

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
        child: ListView(
          padding: const EdgeInsets.all(CloserSpacing.gutter),
          children: [
            Text('In short', style: context.text.headlineSmall),
            const SizedBox(height: CloserSpacing.md),
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: CloserSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        CloserIcons.heart,
                        size: 14,
                        color: context.closerColors.accent,
                      ),
                    ),
                    const SizedBox(width: CloserSpacing.sm),
                    Expanded(child: Text(p, style: context.text.bodyLarge)),
                  ],
                ),
              ),
            const SizedBox(height: CloserSpacing.lg),
            if (url != null)
              CloserButton.secondary(
                label: 'Read the full ${doc.title.toLowerCase()}',
                icon: const Icon(CloserIcons.link),
                onPressed: () => launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                ),
              )
            else
              const NoticeCard(
                message:
                    'This is a draft summary. The full document will be '
                    'published before Keeploom is released.',
              ),
          ],
        ),
      ),
    );
  }
}
