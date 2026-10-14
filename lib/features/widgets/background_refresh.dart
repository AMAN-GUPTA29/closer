import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/config/app_config.dart';
import '../groups/domain/group_models.dart';
import '../notifications/push/push_service.dart';
import 'widget_sync.dart';

/// Runs in a background isolate when a push arrives while the app is not in
/// the foreground. If the push is about new content in a group, the group's
/// widget snapshot and cover are refreshed using the signed-in session that
/// supabase_flutter persisted on the device. Everything is best effort: the
/// OS may limit background work, and the next app open re-syncs anyway.
@pragma('vm:entry-point')
Future<void> closerBackgroundMessage(RemoteMessage message) async {
  final event = PushEvent.fromData(message.data);
  final groupId = event.groupId;
  if (groupId == null) return;
  if (event.type != 'photo_added' && event.type != 'milestone_added') return;
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await FirebasePushService.ensureFirebase();
    final config = AppConfig.fromEnvironment();
    if (!config.isSupabaseConfigured) return;
    try {
      await sb.Supabase.initialize(
        url: config.supabaseUrl,
        publishableKey: config.supabaseAnonKey,
      );
    } catch (_) {
      // Already initialised in this isolate.
    }
    final db = sb.Supabase.instance.client;
    if (db.auth.currentSession == null) return;
    final row = await db
        .from('group_summaries')
        .select()
        .eq('id', groupId)
        .maybeSingle();
    if (row == null) return; // No longer a member: nothing to show.
    final group = Group.fromJson(row);
    Uint8List? cover;
    final path = group.latestThumbPath;
    if (path != null) cover = await db.storage.from('photos').download(path);
    await WidgetSync(HomeWidgetPlatform()).updateGroup(group, cover: cover);
  } catch (_) {
    // Never crash a background isolate.
  }
}
