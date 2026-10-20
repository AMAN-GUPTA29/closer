import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Sample photos for the onboarding collage (the original images behind the
/// Keeploom design showcase, split from `docs/design/*.png`). Marketing art
/// only; user content never appears here.
abstract final class _Photos {
  static const sunset = 'assets/onboarding/sunset_golden.jpg';
  static const mountain = 'assets/onboarding/mountain.jpg';
  static const cat = 'assets/onboarding/cat.jpg';
  static const couple = 'assets/onboarding/couple.jpg';
  static const catBed = 'assets/onboarding/cat_bed.jpg';
  static const cove = 'assets/onboarding/sunset_cove.jpg';
}

class _OnboardingPage {
  const _OnboardingPage(this.title, this.body, this.hero, this.inset);
  final String title;
  final String body;
  final String hero;
  final String inset;
}

const _pages = [
  _OnboardingPage(
    'Keep what brings\nyou closer.',
    'Private groups for your partner, friends and family. Only they see '
        'what you share.',
    _Photos.couple,
    _Photos.cat,
  ),
  _OnboardingPage(
    'Private by\ndesign.',
    'Every group is invite-only. Only the people in it ever see what’s '
        'inside.',
    _Photos.sunset,
    _Photos.catBed,
  ),
  _OnboardingPage(
    'Keep the story\ntogether.',
    'Milestones, a shared journal and your people right on your home '
        'screen.',
    _Photos.cove,
    _Photos.mountain,
  ),
];

/// Onboarding, as on the Keeploom showcase: headline, a three-photo
/// collage, page dots, "Get started" and a plain "Sign in" link.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final p in _pages) {
      for (final a in [p.hero, p.inset]) {
        precacheImage(AssetImage(a), context);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Scaffold(
      backgroundColor: c.background,
      body: DecoratedBox(
        decoration: BoxDecoration(color: c.background),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      // Fills the screen above the dots; grows with the
                      // user's text size (the page then scrolls).
                      height: math.max(
                        620 * scale,
                        MediaQuery.sizeOf(context).height -
                            MediaQuery.paddingOf(context).vertical -
                            170,
                      ),
                      child: PageView.builder(
                        clipBehavior: Clip.none,
                        controller: _controller,
                        itemCount: _pages.length,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemBuilder: (context, i) => _PageContent(_pages[i]),
                      ),
                    ),
                    const Spacer(),
                    _Dots(count: _pages.length, index: _page),
                    const SizedBox(height: CloserSpacing.lg),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CloserSpacing.gutter,
                      ),
                      child: CloserButton(
                        label: 'Get started',
                        onPressed: () => context.push(Routes.signUp),
                      ),
                    ),
                    const SizedBox(height: CloserSpacing.xs),
                    Center(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: c.textPrimary,
                          minimumSize: const Size(200, 48),
                        ),
                        onPressed: () => context.push(Routes.signIn),
                        child: const Text('I already have an account'),
                      ),
                    ),
                    const SizedBox(height: CloserSpacing.sm),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  const _PageContent(this.page);

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CloserSpacing.gutter,
        CloserSpacing.md,
        CloserSpacing.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _Photos2(page: page)),
          const SizedBox(height: CloserSpacing.md),
          Row(
            children: [
              const KeeploomLogo(size: 22),
              const SizedBox(width: CloserSpacing.xs),
              Text(
                KeeploomLogo.name,
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: CloserSpacing.sm),
          Semantics(
            header: true,
            child: Text(
              page.title,
              style: context.text.displayMedium?.copyWith(height: 1.05),
            ),
          ),
          const SizedBox(height: CloserSpacing.sm),
          Text(
            page.body,
            style: context.text.bodyLarge?.copyWith(
              color: c.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

/// One large photo with a smaller one overlapping its lower right corner,
/// ringed in the page colour.
class _Photos2 extends StatelessWidget {
  const _Photos2({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) {
          final insetW = box.maxWidth * 0.32;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: insetW * 0.35,
                child: ClipRRect(
                  borderRadius: CloserRadii.xlAll,
                  child: Image.asset(
                    page.hero,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              Positioned(
                right: CloserSpacing.sm,
                bottom: 0,
                child: Container(
                  width: insetW,
                  height: insetW * 1.25,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: c.background,
                    borderRadius: BorderRadius.circular(CloserRadii.lg + 5),
                  ),
                  child: ClipRRect(
                    borderRadius: CloserRadii.lgAll,
                    child: Image.asset(
                      page.inset,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    return Semantics(
      label: 'Page ${index + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: CloserMotion.of(context, CloserMotion.medium),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? c.accent : c.line,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
