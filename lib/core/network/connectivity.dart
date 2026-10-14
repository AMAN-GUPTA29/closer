import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device has any network connection. Starts optimistic so the
/// app never shows a false "offline" flash at launch. Overridden in tests.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool online(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);
  yield true;
  try {
    yield online(await connectivity.checkConnectivity());
  } catch (_) {
    // Plugin unavailable: assume online and let requests report failures.
  }
  yield* connectivity.onConnectivityChanged.map(online);
});
