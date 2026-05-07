import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/isar_resource.dart';
import 'connectivity_service.dart';
import 'local_database_service.dart';
import 'supabase_client.dart';

class MarkingService {
  final LocalDatabaseService _db;
  final ConnectivityService _connectivity;

  MarkingService(this._db, this._connectivity);

  /// Mark/unmark a resource as bookmarked — works offline and online
  /// The bookmark state is saved immediately to local cache,
  /// and synced to Supabase when online
  Future<void> toggleResourceBookmark(
    String resourceId,
    bool shouldBookmark,
  ) async {
    try {
      // Always update cache first (optimistic update)
      await _db.updateResourceBookmark(resourceId, shouldBookmark);

      // If online, sync to Supabase
      if (_connectivity.isOnline) {
        try {
          // Create/update a bookmark record in Supabase
          // You'll need to add a 'resource_bookmarks' table to Supabase
          await supabase.from('resource_bookmarks').upsert({
            'resource_id': resourceId,
            'is_bookmarked': shouldBookmark,
            'updated_at': DateTime.now().toIso8601String(),
          });

          print('Bookmark synced: $resourceId = $shouldBookmark');
        } catch (e) {
          print('Warning: Could not sync bookmark to server: $e');
          print('Bookmark saved locally, will sync when online');
        }
      } else {
        print('Offline: Bookmark saved locally, will sync when online');
      }
    } catch (e) {
      print('Error toggling bookmark: $e');
      rethrow;
    }
  }

  /// Get all bookmarked resources from local cache
  Future<List<IsarResource>> getBookmarkedResources() async {
    try {
      return await _db.getBookmarkedResources();
    } catch (e) {
      print('Error fetching bookmarked resources: $e');
      return [];
    }
  }

  /// Sync bookmarks when coming back online
  Future<void> syncBookmarks() async {
    if (_connectivity.isOffline) return;

    try {
      final bookmarked = await _db.getBookmarkedResources();

      for (final resource in bookmarked) {
        try {
          await supabase.from('resource_bookmarks').upsert({
            'resource_id': resource.remoteId,
            'is_bookmarked': true,
            'updated_at': DateTime.now().toIso8601String(),
          });

          print('Synced bookmark for: ${resource.remoteId}');
        } catch (e) {
          print('Failed to sync bookmark for ${resource.remoteId}: $e');
        }
      }
    } catch (e) {
      print('Error syncing bookmarks: $e');
    }
  }
}
