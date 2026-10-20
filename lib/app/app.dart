import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/routing/app_router.dart';
import '../core/theme/appearance.dart';
import '../core/theme/closer_theme.dart';
import '../core/sync/app_sync.dart';
import '../features/invitations/application/invite_links.dart';

class CloserApp extends ConsumerWidget {
  const CloserApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Keeploom',
      debugShowCheckedModeBanner: false,
      theme: CloserTheme.light,
      darkTheme: CloserTheme.dark,
      themeMode: ref.watch(appearanceProvider),
      routerConfig: router,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en')],
      builder: (context, child) {
        final theme = Theme.of(context);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: systemBarsFor(
            theme.brightness,
            context.closerColors.background,
          ),
          child: InviteLinkListener(
            child: AppSync(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}
