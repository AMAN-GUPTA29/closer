import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/groups/application/group_providers.dart';
import '../../features/groups/domain/group_models.dart';
import '../../features/journal/application/content_providers.dart';
import '../../features/notifications/presentation/in_app_banner.dart';
import '../../features/notifications/push/push_service.dart';
import '../../features/photos/application/photo_providers.dart';
import '../../features/widgets/widget_sync.dart';
import '../routing/app_router.dart';
import '../routing/routes.dart';
import 'realtime_feed.dart';

final pushServiceProvider = Provider<PushService>((ref) {
  if (!FirebaseConfig.isConfigured ||
      !ref.watch(authRepositoryProvider).isConfigured) {
    return const NoopPushService();
  }
  return FirebasePushService(
    SupabaseDeviceRegistry(sb.Supabase.instance.client),
  );
});

final realtimeFeedProvider = Provider<RealtimeFeed>((ref) {
  if (!ref.watch(authRepositoryProvider).isConfigured) {
    return const NoopRealtimeFeed();
  }
  return SupabaseRealtimeFeed(sb.Supabase.instance.client);
});

final widgetSyncProvider = Provider<WidgetSync>(
  (ref) => WidgetSync(HomeWidgetPlatform()),
);

/// Keeps everything fresh while the app runs:
///   * push: registers the device; foreground pushes refresh data; tapped
///     pushes open the group;
///   * realtime: refreshes affected screens and that group's widgets;
///   * resume: refetches groups and notifications;
///   * widgets: re-synced whenever the group list changes, wiped on sign-out.
/// Pushes and realtime are signals only — data always comes from queries.
class AppSync extends ConsumerStatefulWidget {
  const AppSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppSync> createState() => _AppSyncState();
}

class _AppSyncState extends ConsumerState<AppSync> with WidgetsBindingObserver {
  final _subs = <StreamSubscription<Object?>>[];
  String? _activeUser;
  BannerContent? _banner;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onAuth(ref.read(authControllerProvider));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerTimer?.cancel();
    _stopStreams();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _activeUser != null) {
      ref
        ..invalidate(myGroupsProvider)
        ..invalidate(notificationsProvider);
    }
  }

  void _stopStreams() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  Future<void> _onAuth(AuthStatus status) async {
    final userId = switch (status) {
      SignedIn(:final user) => user.id,
      PreviewSession() => PreviewSession.user.id,
      _ => null,
    };
    if (userId == _activeUser) return;
    _stopStreams();
    if (userId == null) {
      _activeUser = null;
      _hideBanner();
      unawaited(ref.read(pushServiceProvider).stop());
      unawaited(ref.read(realtimeFeedProvider).stop());
      unawaited(_guard(() => ref.read(widgetSyncProvider).clear()));
      return;
    }
    _activeUser = userId;
    final push = ref.read(pushServiceProvider);
    _subs
      ..add(push.foreground.listen((e) => _refresh(e.groupId, notify: true)))
      ..add(push.opened.listen(_openGroup))
      ..add(
        ref.read(realtimeFeedProvider).start(userId).listen((c) {
          _refresh(c.groupId, notify: c.table == 'notifications');
          if (c.table == 'notifications') unawaited(_announce(c.rowId));
        }),
      );
    if (status is SignedIn) unawaited(push.start());
  }

  /// Shows a new notification as an in-app banner. Driven by realtime, so it
  /// works without push and never shows twice when a push arrives as well.
  Future<void> _announce(int? id) async {
    try {
      final latest = await ref
          .read(contentBackendProvider)
          .notifications(limit: 5);
      final n = id == null
          ? latest.where((n) => n.isUnread).firstOrNull
          : latest.where((n) => n.id == id).firstOrNull;
      if (n == null || !mounted || _activeUser == null) return;
      final groups = await ref.read(myGroupsProvider.future);
      final name = groups
          .where((g) => g.id == n.groupId)
          .map((g) => g.name)
          .firstOrNull;
      if (!mounted) return;
      _bannerTimer?.cancel();
      setState(
        () => _banner = BannerContent(
          id: n.id,
          message: n.message(name ?? 'your group'),
          groupId: n.groupId,
        ),
      );
      _bannerTimer = Timer(const Duration(seconds: 5), _hideBanner);
    } catch (_) {
      // The Notifications tab still shows it; a banner is a bonus.
    }
  }

  void _hideBanner() {
    _bannerTimer?.cancel();
    if (mounted && _banner != null) setState(() => _banner = null);
  }

  void _openBanner() {
    final b = _banner;
    _hideBanner();
    if (b == null) return;
    unawaited(
      ref
          .read(contentBackendProvider)
          .markNotificationsRead([b.id])
          .then((_) => ref.invalidate(notificationsProvider))
          .catchError((Object _) {}),
    );
    ref.read(routerProvider).push(Routes.group(b.groupId));
  }

  void _openGroup(PushEvent e) {
    final id = e.groupId;
    if (id == null) return;
    ref.read(routerProvider).push(Routes.group(id));
  }

  void _refresh(String? groupId, {bool notify = false}) {
    ref.invalidate(myGroupsProvider);
    ref.invalidate(journalProvider(null));
    if (notify) ref.invalidate(notificationsProvider);
    if (groupId != null) {
      ref
        ..invalidate(groupProvider(groupId))
        ..invalidate(groupPhotosProvider(groupId))
        ..invalidate(journalProvider(groupId))
        ..invalidate(milestonesProvider(groupId));
    }
  }

  Future<void> _syncWidgets(List<Group> groups) async {
    final photos = ref.read(photosBackendProvider);
    await ref
        .read(widgetSyncProvider)
        .syncAll(
          groups,
          coverBytes: (g) async {
            final path = g.latestThumbPath;
            if (path == null) return null;
            return Uint8List.fromList(await photos.thumbnailBytes(path));
          },
        );
  }

  static Future<void> _guard(Future<void> Function() f) async {
    try {
      await f();
    } catch (_) {
      // Widgets are best effort (e.g. platform without widget support).
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, next) => _onAuth(next));
    ref.listen(myGroupsProvider, (_, next) {
      final groups = next.value;
      if (groups != null && _activeUser != null) {
        unawaited(_guard(() => _syncWidgets(groups)));
      }
    });
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: InAppNotificationBanner(
            content: _banner,
            onTap: _openBanner,
            onDismiss: _hideBanner,
          ),
        ),
      ],
    );
  }
}
