import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/widgets/widgets.dart';

class _OnboardingPage {
  const _OnboardingPage(this.title, this.body, this.artVariant);
  final String title;
  final String body;
  final int artVariant;
}

const _pages = [
  _OnboardingPage(
    'A private space for the people who matter most.',
    'Couples, friends and families — each group is invite-only.',
    0,
  ),
  _OnboardingPage(
    'Share a moment in seconds.',
    'Snap or pick a photo, add a caption, and it appears for everyone '
        'in the group — even on their home screen.',
    2,
  ),
  _OnboardingPage(
    'Keep the story together.',
    'A shared journal with milestones like 100 days together, first '
        'trips and family reunions.',
    3,
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
    final duration = CloserMotion.of(context, CloserMotion.slow);
    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Hero art (top ~68%) cross-fades with the page; an ivory wash
          // blends it into the copy area below.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.sizeOf(context).height * 0.68,
            child: AnimatedSwitcher(
              duration: duration,
              child: SunsetArt(
                key: ValueKey(_pages[_page].artVariant),
                variant: _pages[_page].artVariant,
                showFigures: true,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c.background.withValues(alpha: 0),
                  c.background.withValues(alpha: 0),
                  c.background.withValues(alpha: 0.9),
                  c.background,
                ],
                stops: const [0, 0.5, 0.62, 0.68],
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CloserSpacing.gutter,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: CloserSpacing.xxl),
                        const CloserLogo(
                          size: 76,
                          showWordmark: true,
                          wordmarkColor: Colors.white,
                        ),
                        const SizedBox(height: CloserSpacing.xs),
                        Text(
                          'Your people. Your moments.\nAlways close.',
                          textAlign: TextAlign.center,
                          style: context.text.titleMedium?.copyWith(
                            color: Colors.white,
                            shadows: const [
                              Shadow(color: Color(0x55000000), blurRadius: 12),
                            ],
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          // Grows with the user's text size; the page scrolls.
                          height: MediaQuery.textScalerOf(context)
                              .scale(170)
                              .clamp(170, 420),
                          child: PageView.builder(
                            controller: _controller,
                            itemCount: _pages.length,
                            onPageChanged: (i) => setState(() => _page = i),
                            itemBuilder: (context, i) => Column(
                              children: [
                                Text(
                                  _pages[i].title,
                                  textAlign: TextAlign.center,
                                  style: context.text.headlineSmall,
                                ),
                                const SizedBox(height: CloserSpacing.xs),
                                Text(
                                  _pages[i].body,
                                  textAlign: TextAlign.center,
                                  style: context.text.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                        _Dots(count: _pages.length, index: _page),
                        const SizedBox(height: CloserSpacing.xl),
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
        ],
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
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == index
                    ? c.accentStrong
                    : c.accent.withValues(alpha: 0.25),
                borderRadius: CloserRadii.pillAll,
              ),
            ),
        ],
      ),
    );
  }
}
