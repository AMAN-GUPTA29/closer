import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_foundation/path_provider_foundation.dart';

import '../../core/models/group_type.dart';
import '../../core/utils/dates.dart';
import '../groups/domain/group_models.dart';

/// App Group shared by the iOS app and its widget extension.
const iosAppGroupId = 'group.com.closerapp.closer';

/// Keys shared with the native widgets (Android `CloserWidgetProvider`,
/// iOS `CloserWidget`). Keep in sync with docs/widget-implementation.md.
abstract final class WidgetKeys {
  /// JSON list of {id, name, type} the user can pick when configuring.
  static const groupIndex = 'closer.groups';

  /// "true" while signed in; widgets show a sign-in prompt otherwise.
  static const signedIn = 'closer.signedIn';

  /// Per-group snapshot JSON.
  static String group(String id) => 'closer.group.$id';
}

/// What a widget shows for one group. No captions or private text beyond
/// the group name, which the user already sees on their home screen.
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.groupId,
    required this.name,
    required this.type,
    required this.subtitle,
    required this.updatedAt,
    this.imagePath,
  });

  final String groupId;
  final String name;
  final GroupType type;
  final String subtitle;
  final DateTime updatedAt;

  /// Local file with the cover thumbnail, readable by the widget.
  final String? imagePath;

  Map<String, dynamic> toJson() => {
    'id': groupId,
    'name': name,
    'type': type.name,
    'subtitle': subtitle,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'imagePath': imagePath,
  };

  /// "182 days" for couples with a counter, otherwise recent activity.
  static String subtitleFor(Group g, DateTime now) {
    if (g.hasCounter) {
      final d = daysTogether(g.relationshipStartDate!, now);
      return d == 1 ? '1 day' : '$d days';
    }
    if (g.photoCount == 0) {
      return '${g.memberCount} ${g.memberCount == 1 ? 'member' : 'members'}';
    }
    return 'New memory · ${relativeTime(g.lastActivityAt, now)}';
  }
}

/// Storage + native refresh used by [WidgetSync]; replaced in tests.
abstract interface class WidgetPlatform {
  Future<void> save(String key, String? value);
  Future<String?> read(String key);

  /// Writes the cover image where the widget can read it; returns its path.
  Future<String?> writeImage(String groupId, Uint8List? bytes);
  Future<void> deleteImage(String groupId);

  /// Asks the OS to redraw widgets: only those showing [groupId] where the
  /// platform allows it (Android), all Closer widgets otherwise (iOS).
  Future<void> refresh({String? groupId});
}

class HomeWidgetPlatform implements WidgetPlatform {
  HomeWidgetPlatform();

  static const _channel = MethodChannel('com.closerapp.closer/widgets');
  bool _initialised = false;

  Future<void> _init() async {
    if (_initialised) return;
    _initialised = true;
    if (Platform.isIOS) await HomeWidget.setAppGroupId(iosAppGroupId);
  }

  @override
  Future<void> save(String key, String? value) async {
    await _init();
    await HomeWidget.saveWidgetData<String>(key, value);
  }

  @override
  Future<String?> read(String key) async {
    await _init();
    return HomeWidget.getWidgetData<String>(key);
  }

  Future<Directory> _dir() async {
    if (Platform.isIOS) {
      final path = await PathProviderFoundation().getContainerPath(
        appGroupIdentifier: iosAppGroupId,
      );
      if (path != null) {
        return Directory('$path/widgets').create(recursive: true);
      }
    }
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/widgets').create(recursive: true);
  }

  @override
  Future<String?> writeImage(String groupId, Uint8List? bytes) async {
    final file = File('${(await _dir()).path}/$groupId.jpg');
    if (bytes == null) {
      if (await file.exists()) await file.delete();
      return null;
    }
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<void> deleteImage(String groupId) async {
    final file = File('${(await _dir()).path}/$groupId.jpg');
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> refresh({String? groupId}) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('refresh', {'groupId': groupId});
    } else if (Platform.isIOS) {
      // WidgetKit reloads by kind; instances re-read their own group.
      await HomeWidget.updateWidget(iOSName: 'CloserWidget');
    }
  }

  /// Android 8+: asks the launcher to pin a new Closer widget.
  Future<bool> requestPin() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('requestPin') ?? false;
  }
}

/// Keeps the data native widgets display in sync with the user's groups.
class WidgetSync {
  WidgetSync(this._platform, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final WidgetPlatform _platform;
  final DateTime Function() _clock;

  /// Writes every group, removes groups the user can no longer see (so a
  /// widget never keeps showing a group after access is revoked), then
  /// refreshes all widgets.
  Future<void> syncAll(
    List<Group> groups, {
    required Future<Uint8List?> Function(Group g) coverBytes,
  }) async {
    final previous = await _indexIds();
    for (final g in groups) {
      await _writeGroup(g, await _safe(() => coverBytes(g)));
    }
    final current = groups.map((g) => g.id).toSet();
    for (final gone in previous.difference(current)) {
      await _platform.save(WidgetKeys.group(gone), null);
      await _platform.deleteImage(gone);
    }
    await _platform.save(
      WidgetKeys.groupIndex,
      jsonEncode([
        for (final g in groups)
          {'id': g.id, 'name': g.name, 'type': g.type.name},
      ]),
    );
    await _platform.save(WidgetKeys.signedIn, 'true');
    await _platform.refresh();
  }

  /// Updates one group's snapshot and refreshes only its widgets.
  Future<void> updateGroup(Group g, {Uint8List? cover}) async {
    await _writeGroup(g, cover);
    await _platform.refresh(groupId: g.id);
  }

  /// Signed out or account deleted: wipe everything widgets could show.
  Future<void> clear() async {
    for (final id in await _indexIds()) {
      await _platform.save(WidgetKeys.group(id), null);
      await _platform.deleteImage(id);
    }
    await _platform.save(WidgetKeys.groupIndex, null);
    await _platform.save(WidgetKeys.signedIn, 'false');
    await _platform.refresh();
  }

  Future<void> _writeGroup(Group g, Uint8List? cover) async {
    final path = await _platform.writeImage(g.id, cover);
    final snap = WidgetSnapshot(
      groupId: g.id,
      name: g.name,
      type: g.type,
      subtitle: WidgetSnapshot.subtitleFor(g, _clock()),
      updatedAt: _clock(),
      imagePath: path,
    );
    await _platform.save(WidgetKeys.group(g.id), jsonEncode(snap.toJson()));
  }

  Future<Set<String>> _indexIds() async {
    final raw = await _platform.read(WidgetKeys.groupIndex);
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as List)
          .map((e) => (e as Map)['id'] as String)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<Uint8List?> _safe(Future<Uint8List?> Function() f) async {
    try {
      return await f();
    } catch (_) {
      // A missing cover must not stop the rest of the widget data.
      return null;
    }
  }
}
