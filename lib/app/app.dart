import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/routing/app_router.dart';
import '../core/theme/closer_theme.dart';

class CloserApp extends ConsumerWidget {
  const CloserApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Closer',
      debugShowCheckedModeBanner: false,
      theme: CloserTheme.light,
      darkTheme: CloserTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en')],
    );
  }
}
