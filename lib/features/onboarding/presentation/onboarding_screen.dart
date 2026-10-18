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
  static const alley = 'assets/onboarding/mediterranean.jpg';
  static const catBed = 'assets/onboarding/cat_bed.jpg';
  static const cove = 'assets/onboarding/sunset_cove.jpg';
  static const sunsetTall = 'assets/onboarding/sunset_portrait.jpg';
}

class _OnboardingPage {
  const _OnboardingPage(
    this.title,
    this.body,
    this.hero,
    this.left,
    this.right,
  );
  final String title;
  final String body;
  final String hero;
  final String left;
  final String right;
}

const _pages = [
  _OnboardingPage(
    'Share little\nmoments.\nStay close.',
    'Photos, memories and milestones\nwith the people who matter.',
    _Photos.sunset,
    _Photos.mountain,
    _Photos.cat,
  ),
  _OnboardingPage(
    'Private by\ndesign.',
    'Every group is invite-only. Only the\npeople in it ever see what’s inside.',
    _Photos.couple,
    _Photos.alley,
    _Photos.catBed,
  ),
  _OnboardingPage(
    'Keep the story\ntogether.',
    'Milestones, a shared journal and your\npeople right on your home screen.',
    _Photos.cove,
    _Photos.sunsetTall,
    _Photos.cat,
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
      for (final a in [p.hero, p.left, p.right]) {
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
        // Soft blush glow towards the bottom, as on the showcase.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.background, c.background, c.accentSoft],
            stops: const [0, 0.6, 1],
          ),
        ),
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
                            200,
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
                    const SizedBox(height: CloserSpacing.md),
                    _Dots(count: _pages.length, index: _page),
                    const SizedBox(height: CloserSpacing.xl),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CloserSpacing.xl,
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
                          minimumSize: const Size(120, 48),
                        ),
                        onPressed: () => context.push(Routes.signIn),
                        child: const Text('Sign in'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CloserSpacing.xxl,
            CloserSpacing.xxxl,
            CloserSpacing.xl,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  page.title,
                  style: context.text.displaySmall?.copyWith(
                    fontSize: 36,
                    height: 1.12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              const SizedBox(height: CloserSpacing.md),
              Text(
                page.body,
                style: context.text.bodyLarge?.copyWith(
                  color: c.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: CloserSpacing.xl),
        Expanded(child: _Collage(page: page)),
      ],
    );
  }
}

/// A landscape photo tilted at the top with two smaller prints overlapping
/// its lower corners. Proportions follow the showcase (fractions of width),
/// scaled down when the available height is short.
class _Collage extends StatelessWidget {
  const _Collage({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) {
          // Design box is 1.0w wide and 0.98w tall.
          final k = math.min(box.maxWidth, box.maxHeight / 0.98);
          final dx = (box.maxWidth - k) / 2;
          Widget at(
            double l,
            double t,
            double w,
            double h,
            String a,
            double r,
          ) => Positioned(
            left: dx + l * k,
            top: t * k,
            child: _Print(asset: a, width: w * k, height: h * k, angle: r),
          );
          return Stack(
            clipBehavior: Clip.none,
            children: [
              at(0.14, 0.02, 0.74, 0.62, page.hero, 0.06),
              at(0.03, 0.36, 0.34, 0.50, page.left, -0.07),
              at(0.48, 0.55, 0.40, 0.40, page.right, 0.07),
            ],
          );
        },
      ),
    );
  }
}

class _Print extends StatelessWidget {
  const _Print({
    required this.asset,
    required this.width,
    required this.height,
    required this.angle,
  });

  final String asset;
  final double width;
  final double height;
  final double angle;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: CloserRadii.lgAll,
          boxShadow: [
            BoxShadow(
              color: dark
                  ? Colors.black.withValues(alpha: 0.45)
                  : c.accent.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: CloserRadii.mdAll,
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
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
