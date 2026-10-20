import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// A change the app should react to while it's open. Ids only: the app
/// refetches content through the normal (RLS-protected) queries.
class RealtimeChange {
  const RealtimeChange(this.table, {this.groupId, this.rowId});

  final String table;
  final String? groupId;

  /// Primary key of the changed row when it is numeric (notifications).
  final int? rowId;
}

abstract interface class RealtimeFeed {
  Stream<RealtimeChange> start(String userId);
  Future<void> stop();
}

class NoopRealtimeFeed implements RealtimeFeed {
  const NoopRealtimeFeed();

  @override
  Stream<RealtimeChange> start(String userId) => const Stream.empty();
  @override
  Future<void> stop() async {}
}

/// Supabase Realtime postgres changes. Row Level Security applies, so the
/// user only hears about rows they are allowed to read.
class SupabaseRealtimeFeed implements RealtimeFeed {
  SupabaseRealtimeFeed(this._db);

  final sb.SupabaseClient _db;
  sb.RealtimeChannel? _channel;
  StreamController<RealtimeChange>? _out;

  @override
  Stream<RealtimeChange> start(String userId) {
    stop();
    final out = _out = StreamController<RealtimeChange>.broadcast();
    void emit(String table, sb.PostgresChangePayload p) {
      final row = p.newRecord.isNotEmpty ? p.newRecord : p.oldRecord;
      final id = row['id'];
      out.add(
        RealtimeChange(
          table,
          groupId: row['group_id'] as String?,
          rowId: id is num ? id.toInt() : null,
        ),
      );
    }

    _channel = _db
        .channel('closer-sync-$userId')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.all,
          schema: 'public',
          table: 'photos',
          callback: (p) => emit('photos', p),
        )
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.all,
          schema: 'public',
          table: 'milestones',
          callback: (p) => emit('milestones', p),
        )
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (p) => emit('notifications', p),
        )
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.insert,
          schema: 'public',
          table: 'group_members',
          callback: (p) => emit('group_members', p),
        )
        .subscribe();
    return out.stream;
  }

  @override
  Future<void> stop() async {
    final c = _channel;
    _channel = null;
    if (c != null) await _db.removeChannel(c);
    await _out?.close();
    _out = null;
  }
}
