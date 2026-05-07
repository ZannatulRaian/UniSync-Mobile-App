import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/local_database_service.dart';
import '../services/connectivity_service.dart';
import '../models/isar_pending_action.dart';
import 'supabase_client.dart';
import 'notification_service.dart';

/// Maximum retries before giving up on a pending action.
const _maxRetries = 5;

/// Central offline-sync engine.
///
/// When the device comes back online, call [syncAll]. It iterates every
/// unsent [IsarPendingAction] in insertion order and replays it against
/// Supabase. On success the action is marked synced; on failure the retry
/// counter is incremented (actions are abandoned after [_maxRetries]).
class OfflineSyncService {
  final LocalDatabaseService _db;
  final ConnectivityService _connectivity;

  OfflineSyncService(this._db, this._connectivity);

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Replay all pending actions. Safe to call even when offline (no-op).
  /// Returns the number of actions that were successfully synced.
  Future<int> syncAll() async {
    if (_connectivity.isOffline) return 0;

    final pending = await _db.getPendingActions();
    if (pending.isEmpty) return 0;

    int synced = 0;

    for (final action in pending) {
      if (action.retryCount >= _maxRetries) {
        // Give up — mark synced so it stops blocking the queue
        print('[OfflineSync] Abandoning action ${action.actionType} '
            '(exceeded max retries)');
        if (action.id != null) await _db.markActionSynced(action.id!);
        continue;
      }

      try {
        await _replay(action);
        if (action.id != null) await _db.markActionSynced(action.id!);
        synced++;
        print('[OfflineSync] Synced action: ${action.actionType}');
      } catch (e) {
        print('[OfflineSync] Failed action ${action.actionType}: $e');
        if (action.id != null) await _db.incrementActionRetry(action.id!);
      }
    }

    // Cleanup synced records to keep the DB tidy
    await _db.clearSyncedActions();

    return synced;
  }

  /// How many actions are still waiting to be synced.
  Future<int> pendingCount() => _db.pendingActionCount();

  // ─────────────────────────────────────────────────────────────────────────
  // Action replay dispatcher
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _replay(IsarPendingAction action) async {
    final payload = jsonDecode(action.payloadJson) as Map<String, dynamic>;

    switch (action.actionType) {
      case 'send_message':
        await _replaySendMessage(payload);
        break;
      case 'post_announcement':
        await _replayPostAnnouncement(payload);
        break;
      case 'create_event':
        await _replayCreateEvent(payload);
        break;
      case 'upload_resource':
        await _replayUploadResource(payload);
        break;
      case 'rsvp_event':
        await _replayRsvpEvent(payload);
        break;
      case 'delete_message':
        await _replayDeleteMessage(payload);
        break;
      case 'delete_announcement':
        await _replayDeleteAnnouncement(payload);
        break;
      case 'delete_event':
        await _replayDeleteEvent(payload);
        break;
      case 'delete_resource':
        await _replayDeleteResource(payload);
        break;
      default:
        print('[OfflineSync] Unknown action type: ${action.actionType}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Individual replayers
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _replaySendMessage(Map<String, dynamic> p) async {
    final roomId    = p['room_id']    as String;
    final senderId  = p['sender_id']  as String;
    final senderName= p['sender_name']as String;
    final content   = p['content']    as String;
    final createdAt = p['created_at'] as String;

    // Verify the user is still a member (room may have changed while offline)
    final roomCheck = await supabase
        .from('chat_rooms')
        .select('member_ids')
        .eq('id', roomId)
        .maybeSingle();
    if (roomCheck == null) {
      throw Exception('Chat room $roomId no longer exists');
    }
    final members = List<String>.from(roomCheck['member_ids'] ?? []);
    if (!members.contains(senderId)) {
      throw Exception('User $senderId is no longer a member of room $roomId');
    }

    await supabase.from('chat_messages').insert({
      'room_id':     roomId,
      'sender_id':   senderId,
      'sender_name': senderName,
      'content':     content,
      'created_at':  createdAt,
    });

    final preview = content.length > 60
        ? '${content.substring(0, 60)}...'
        : content;
    await supabase.from('chat_rooms').update({
      'last_message':      preview,
      'last_message_time': createdAt,
    }).eq('id', roomId);

    NotificationService.send(
      type:          'chat',
      title:         '💬 $senderName',
      body:          content.length > 80 ? '${content.substring(0, 80)}...' : content,
      excludeUserId: senderId,
    );

    // Remove the optimistic cached copy (identified by localTempId starting
    // with 'pending_') so the real server row replaces it on next fetch.
    if (p['local_temp_id'] != null) {
      await _db.deleteMessage(p['local_temp_id'] as String);
    }
  }

  Future<void> _replayPostAnnouncement(Map<String, dynamic> p) async {
    await supabase.from('announcements').insert({
      'title':        p['title'],
      'content':      p['content'],
      'posted_by':    p['posted_by'],
      'posted_by_id': p['posted_by_id'],
      'type':         p['type'],
    }).timeout(const Duration(seconds: 10));

    NotificationService.send(
      type:          'announcement',
      title:         '📢 New Announcement',
      body:          p['title'] as String,
      excludeUserId: p['posted_by_id'] as String,
    );
  }

  Future<void> _replayCreateEvent(Map<String, dynamic> p) async {
    await supabase.from('events').insert({
      'title':        p['title'],
      'description':  p['description'],
      'category':     p['category'],
      'location':     p['location'],
      'date':         p['date'],
      'time':         p['time'],
      'attendees':    0,
      'organizer':    p['organizer'],
      'organizer_id': p['organizer_id'],
      'image_color':  p['image_color'],
    }).timeout(const Duration(seconds: 10));

    NotificationService.send(
      type:          'event',
      title:         '📅 New Event: ${p['title']}',
      body:          '${p['location']} • ${p['time']}',
      excludeUserId: p['organizer_id'] as String,
    );
  }

  Future<void> _replayUploadResource(Map<String, dynamic> p) async {
    final localPath = p['local_file_path'] as String?;
    if (localPath == null || localPath.isEmpty) {
      throw Exception('Resource upload: local file path is missing');
    }

    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('Resource file no longer exists at $localPath');
    }

    final bytes       = await file.readAsBytes();
    final ext         = p['ext']           as String;
    final uploadedById= p['uploaded_by_id']as String;
    final storagePath = 'resources/$uploadedById/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final sizeKB      = (bytes.length / 1024).toStringAsFixed(0);

    await supabase.storage.from('resources').uploadBinary(storagePath, bytes);
    final url = supabase.storage.from('resources').getPublicUrl(storagePath);

    await supabase.from('resources').insert({
      'title':          p['title'],
      'subject':        p['subject'],
      'department':     p['department'],
      'semester':       p['semester'],
      'type':           p['type'],
      'file_url':       url,
      'storage_path':   storagePath,
      'size':           '$sizeKB KB',
      'uploaded_by':    p['uploaded_by'],
      'uploaded_by_id': uploadedById,
      'icon_color':     p['icon_color'],
    });

    NotificationService.send(
      type:          'resource',
      title:         '📚 New Resource: ${p['title']}',
      body:          '${p['subject']} • ${p['department']}',
      excludeUserId: uploadedById,
    );
  }

  Future<void> _replayRsvpEvent(Map<String, dynamic> p) async {
    await supabase.rpc('toggle_rsvp', params: {
      'p_event_id': p['event_id'],
      'p_user_id':  p['user_id'],
      'p_going':    p['going'],
    });
  }

  Future<void> _replayDeleteMessage(Map<String, dynamic> p) async {
    await supabase.from('chat_messages').delete().eq('id', p['id'] as String);
  }

  Future<void> _replayDeleteAnnouncement(Map<String, dynamic> p) async {
    await supabase.from('announcements').delete().eq('id', p['id'] as String);
  }

  Future<void> _replayDeleteEvent(Map<String, dynamic> p) async {
    await supabase.from('events').delete().eq('id', p['id'] as String);
  }

  Future<void> _replayDeleteResource(Map<String, dynamic> p) async {
    final storagePath = p['storage_path'] as String? ?? '';
    if (storagePath.isNotEmpty) {
      await supabase.storage.from('resources').remove([storagePath]);
    }
    await supabase.from('resources').delete().eq('id', p['id'] as String);
  }
}
