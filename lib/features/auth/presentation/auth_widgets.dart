import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../application/auth_providers.dart';
import '../domain/auth_models.dart';

/// Scrollable, centred, max-width layout shared by all auth screens.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.children, this.showBack = true});

  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBack
          ? AppBar(
              leading: IconButton(
                tooltip: 'Back',
                icon: const Icon(CloserIcons.back),
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(Routes.welcome),
              ),
            )
          : null,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: CloserSpacing.gutter,
              vertical: CloserSpacing.lg,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    // Left-aligned mark and serif title (Impeccable redesign).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KeeploomLogo(size: 28),
        const SizedBox(height: CloserSpacing.md),
        Semantics(
          header: true,
          child: Text(title, style: context.text.displaySmall),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: CloserSpacing.xs),
          Text(
            subtitle!,
            style: context.text.bodyLarge?.copyWith(
              color: context.closerColors.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
        const SizedBox(height: CloserSpacing.xl),
      ],
    );
  }
}

/// Explains when the backend is missing and, in debug builds only, offers
/// a preview of the UI without an account.
class BackendNotice extends ConsumerWidget {
  const BackendNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authRepositoryProvider).isConfigured) {
      return const SizedBox.shrink();
    }
    final previewAvailable = ref.watch(previewModeAvailableProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: CloserSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const NoticeCard(
            title: 'Backend not connected',
            message:
                'This build has no Supabase configuration, so accounts '
                'cannot be created yet. See docs/environment-setup.md.',
          ),
          if (previewAvailable) ...[
            const SizedBox(height: CloserSpacing.sm),
            CloserButton.secondary(
              label: 'Preview the app (debug only)',
              icon: const Icon(CloserIcons.eye),
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).enterPreview(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Google / Apple buttons. Unconfigured providers are shown disabled with an
/// explanation instead of pretending to work.
class SocialSignInButtons extends ConsumerStatefulWidget {
  const SocialSignInButtons({super.key, required this.onError});

  final ValueChanged<AppFailure> onError;

  @override
  ConsumerState<SocialSignInButtons> createState() =>
      _SocialSignInButtonsState();
}

class _SocialSignInButtonsState extends ConsumerState<SocialSignInButtons> {
  SocialProvider? _busy;

  Future<void> _start(SocialProvider provider) async {
    setState(() => _busy = provider);
    try {
      await ref.read(authRepositoryProvider).signInWithProvider(provider);
    } on AppFailure catch (f) {
      widget.onError(f);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final configured = ref.watch(authRepositoryProvider).isConfigured;
    final google = configured && config.googleAuthEnabled;
    final apple = configured && config.appleAuthEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CloserButton.secondary(
          label: 'Continue with Google',
          icon: const _BrandIcon('assets/brand/google.svg'),
          isLoading: _busy == SocialProvider.google,
          onPressed: google ? () => _start(SocialProvider.google) : null,
        ),
        const SizedBox(height: CloserSpacing.sm),
        CloserButton.secondary(
          label: 'Continue with Apple',
          icon: const _BrandIcon('assets/brand/apple.svg'),
          isLoading: _busy == SocialProvider.apple,
          onPressed: apple ? () => _start(SocialProvider.apple) : null,
        ),
        if (!google || !apple) ...[
          const SizedBox(height: CloserSpacing.xs),
          Text(
            !google && !apple
                ? 'Google and Apple sign-in are not set up yet.'
                : '${!google ? 'Google' : 'Apple'} sign-in is not set up yet.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(
              color: context.closerColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CloserSpacing.lg),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CloserSpacing.sm),
            child: Text('or', style: context.text.bodySmall),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

/// Inline error shown above the submit button; announced to screen readers.
class FormErrorText extends StatelessWidget {
  const FormErrorText(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m == null) return const SizedBox.shrink();
    final c = context.closerColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: CloserSpacing.md),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(CloserIcons.warning, size: 18, color: c.danger),
            const SizedBox(width: CloserSpacing.xs),
            Expanded(
              child: Text(
                m,
                style: context.text.bodySmall?.copyWith(color: c.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "By continuing you agree to the Terms and Privacy Policy".
class LegalFooter extends StatelessWidget {
  const LegalFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final style = context.text.bodySmall;
    final link = style?.copyWith(
      color: context.closerColors.accentStrong,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.only(top: CloserSpacing.lg),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('By continuing you agree to our ', style: style),
          InkWell(
            onTap: () => context.push('${Routes.legal}/terms'),
            child: Text('Terms', style: link),
          ),
          Text(' and ', style: style),
          InkWell(
            onTap: () => context.push('${Routes.legal}/privacy'),
            child: Text('Privacy Policy', style: link),
          ),
          Text('.', style: style),
        ],
      ),
    );
  }
}

/// "Already have an account? Sign in" style prompt.
class AuthSwitchPrompt extends StatelessWidget {
  const AuthSwitchPrompt({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prompt, style: context.text.bodyMedium),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    );
  }
}

/// Monochrome brand mark (Simple Icons, CC0) tinted with the button colour.
class _BrandIcon extends StatelessWidget {
  const _BrandIcon(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    final color =
        IconTheme.of(context).color ?? context.closerColors.textPrimary;
    return SvgPicture.asset(
      asset,
      width: 18,
      height: 18,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}
