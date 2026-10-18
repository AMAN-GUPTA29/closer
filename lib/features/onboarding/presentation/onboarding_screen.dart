import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/widgets/widgets.dart';

class _OnboardingPage {
  const _OnboardingPage(this.title, this.body, this.art);
  final String title;
  final String body;

  /// Three [SunsetArt] variants for the photo collage.
  final List<int> art;
}

const _pages = [
  _OnboardingPage(
    'Share little moments.\nStay close.',
    'Photos, memories and milestones with the people who matter.',
    [0, 2, 3],
  ),
  _OnboardingPage(
    'Private by design.',
    'Couples, friends and families. Every group is invite-only, and '
        'only its members ever see what’s inside.',
    [1, 4, 0],
  ),
  _OnboardingPage(
    'Keep the story together.',
    'A shared journal with milestones like 100 days together, first trips '
        'and family reunions, right on your home screen.',
    [3, 1, 2],
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

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
        // A soft peach glow at the bottom, as on the brand board.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.background, c.background, c.accentSoft],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CloserSpacing.gutter,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: CloserSpacing.lg),
                      Row(
                        children: [
                          const KeeploomLogo(size: 36),
                          const SizedBox(width: CloserSpacing.xs),
                          Text(
                            KeeploomLogo.name,
                            style: context.text.titleLarge?.copyWith(
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        // Grows with the user's text size; the page scrolls.
                        height: (430 * scale).clamp(430, 760),
                        child: PageView.builder(
                          controller: _controller,
                          itemCount: _pages.length,
                          onPageChanged: (i) => setState(() => _page = i),
                          itemBuilder: (context, i) => _PageContent(_pages[i]),
                        ),
                      ),
                      const Spacer(),
                      _Dots(count: _pages.length, index: _page),
                      const SizedBox(height: CloserSpacing.lg),
                      CloserButton(
                        label: 'Get Started',
                        onPressed: () => context.push(Routes.signUp),
                      ),
                      const SizedBox(height: CloserSpacing.xs),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Already have an account?',
                            style: context.text.bodyMedium,
                          ),
                          TextButton(
                            onPressed: () => context.push(Routes.signIn),
                            child: const Text('Sign In'),
                          ),
                        ],
                      ),
                      const SizedBox(height: CloserSpacing.xs),
                    ],
                  ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: CloserSpacing.xl),
        Text(
          page.title,
          style: context.text.displaySmall?.copyWith(height: 1.12),
        ),
        const SizedBox(height: CloserSpacing.sm),
        Text(
          page.body,
          style: context.text.bodyLarge?.copyWith(
            color: context.closerColors.textSecondary,
          ),
        ),
        const SizedBox(height: CloserSpacing.lg),
        Expanded(child: _Collage(art: page.art)),
      ],
    );
  }
}

/// Three tilted photo cards, like prints on a table. Painted art only: real
/// photos belong to users, never to marketing screens.
class _Collage extends StatelessWidget {
  const _Collage({required this.art});

  final List<int> art;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight;
        final w = box.maxWidth;
        final big = math.min(h * 0.86, w * 0.6);
        Widget card(int variant, double size, double angle) => Transform.rotate(
          angle: angle,
          child: Container(
            width: size,
            height: size * 1.12,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: CloserRadii.lgAll,
              boxShadow: CloserElevation.medium,
            ),
            child: ClipRRect(
              borderRadius: CloserRadii.mdAll,
              child: SunsetArt(
                variant: variant,
                showFigures: variant == art[0],
              ),
            ),
          ),
        );
        return ExcludeSemantics(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: w * 0.02,
                top: h * 0.32,
                child: card(art[1], big * 0.52, -0.12),
              ),
              Positioned(
                right: w * 0.02,
                top: h * 0.44,
                child: card(art[2], big * 0.5, 0.14),
              ),
              Positioned(
                left: (w - big) / 2,
                top: 0,
                child: card(art[0], big * 0.82, 0.05),
              ),
            ],
          ),
        );
      },
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
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == index
                    ? c.accentStrong
                    : c.accent.withValues(alpha: 0.3),
                borderRadius: CloserRadii.pillAll,
              ),
            ),
        ],
      ),
    );
  }
}
