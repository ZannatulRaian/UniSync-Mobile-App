import 'package:isar/isar.dart';

part 'isar_pending_action.g.dart';

/// Represents an action queued while offline that will be synced when connectivity
/// is restored. Covers create/upload operations for announcements, events, chat
/// messages, and resource uploads.
@collection
class IsarPendingAction {
  Id? id = Isar.autoIncrement;

  /// One of: 'send_message', 'post_announcement', 'create_event',
  ///         'upload_resource', 'rsvp_event', 'delete_resource',
  ///         'delete_announcement', 'delete_event', 'delete_message'
  late String actionType;

  /// JSON-encoded payload with all fields needed to replay the action.
  late String payloadJson;

  /// ISO-8601 timestamp for display / ordering.
  late DateTime createdAt;

  /// How many times the sync attempt has failed (for retry limiting).
  late int retryCount;

  /// Set to true once successfully synced so it can be cleaned up.
  late bool isSynced;

  /// Optional: local temp ID used so the UI can show the item immediately.
  late String localTempId;

  IsarPendingAction({
    this.id,
    required this.actionType,
    required this.payloadJson,
    required this.createdAt,
    this.retryCount = 0,
    this.isSynced = false,
    this.localTempId = '',
  });
}
