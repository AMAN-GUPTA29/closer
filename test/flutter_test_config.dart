import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the app's bundled fonts so widget tests lay out text with real
/// metrics instead of the square test font.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Future<void> load(String family, String path) async {
    final bytes = File(path).readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }

  await load('PlusJakartaSans', 'assets/fonts/PlusJakartaSans-Variable.ttf');
  await load('Fraunces', 'assets/fonts/Fraunces-Variable.ttf');
  await testMain();
}
