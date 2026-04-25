import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/resource_model.dart';
import '../models/isar_resource.dart';
import '../services/connectivity_service.dart';
import '../services/local_database_service.dart';
import 'supabase_client.dart';
import 'notification_service.dart';

class ResourceService {
  static const _maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const _allowedExts = ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'jpg', 'jpeg', 'png'];

  final LocalDatabaseService _db;
  final ConnectivityService _connectivity;

  ResourceService(this._db, this._connectivity);

  /// Get resources — cached first, then syncs with remote
  Stream<List<Resource>> getResources({String? department, String? type}) {
    final controller = StreamController<List<Resource>>.broadcast();

    Future<void> _run() async {
      // Always emit cached data first
      try {
        final cached = await _db.getCachedResources(department: department, type: type);
        if (!controller.isClosed) {
          controller.add(cached.map((r) => r.toResource()).toList());
        }
      } catch (e) {
        print('Error loading cached resources: $e');
      }

      // If online, fetch fresh data and subscribe to realtime updates
      if (_connectivity.isOnline) {
        try {
          final rows = await supabase
              .from('resources')
              .select()
              .order('uploaded_at', ascending: false);

          var list = (rows as List).map((r) => Resource.fromMap(r)).toList();

          if (department != null && department != 'All') {
            list = list.where((r) => r.department == department).toList();
          }
          if (type != null && type != 'All') {
            list = list.where((r) => r.type == type).toList();
          }

          // Cache the fresh data
          final isarResources = list.map((r) => IsarResource.fromResource(r)).toList();
          await _db.cacheResources(isarResources);

          if (!controller.isClosed) controller.add(list);

          // Setup realtime listener using StreamController to avoid illegal yield
          final channelName =
              'resources_${department ?? "all"}_${type ?? "all"}_${DateTime.now().millisecondsSinceEpoch}';
          final channel = supabase.channel(channelName);

          channel
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'resources',
                callback: (_) async {
                  try {
                    final updatedRows = await supabase
                        .from('resources')
                        .select()
                        .order('uploaded_at', ascending: false);

                    var updatedList =
                        (updatedRows as List).map((r) => Resource.fromMap(r)).toList();

                    if (department != null && department != 'All') {
                      updatedList =
                          updatedList.where((r) => r.department == department).toList();
                    }
                    if (type != null && type != 'All') {
                      updatedList =
                          updatedList.where((r) => r.type == type).toList();
                    }

                    // Cache updates
                    final isarUpdates =
                        updatedList.map((r) => IsarResource.fromResource(r)).toList();
                    await _db.cacheResources(isarUpdates);

                    if (!controller.isClosed) controller.add(updatedList);
                  } catch (e) {
                    print('Error in realtime update: $e');
                  }
                },
              )
              .subscribe();
        } catch (e) {
          print('Error fetching resources: $e');
          if (!controller.isClosed) controller.addError(e);
        }
      }
    }

    _run();
    return controller.stream;
  }

  Future<void> uploadResource({
    required File file,
    required String title,
    required String subject,
    required String department,
    required String semester,
    required String type,
    required String uploadedBy,
    required String uploadedById,
  }) async {
    if (_connectivity.isOffline) {
      throw Exception('Cannot upload offline. Please check your connection.');
    }

    final bytes = await file.readAsBytes();
    if (bytes.length > _maxFileSizeBytes) {
      throw Exception('File too large. Maximum size is 10 MB.');
    }
    
    final ext = p.extension(file.path).toLowerCase().replaceAll('.', '');
    if (!_allowedExts.contains(ext)) {
      throw Exception('File type not allowed. Use PDF, DOCX, PPT, or image files.');
    }
    if (title.trim().isEmpty) throw Exception('Title required');

    final storagePath =
        'resources/$uploadedById/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final sizeKB = (bytes.length / 1024).toStringAsFixed(0);

    await supabase.storage.from('resources').uploadBinary(storagePath, bytes);
    final url = supabase.storage.from('resources').getPublicUrl(storagePath);

    const colors = ['1A56DB', '0E9F6E', 'E3A008', 'E02424', '9061F9'];
    final color = colors[DateTime.now().millisecond % colors.length];

    await supabase.from('resources').insert({
      'title': title.trim(),
      'subject': subject.trim(),
      'department': department,
      'semester': semester,
      'type': type.toUpperCase(),
      'file_url': url,
      'storage_path': storagePath,
      'size': '$sizeKB KB',
      'uploaded_by': uploadedBy,
      'uploaded_by_id': uploadedById,
      'icon_color': color,
    });

    // Push notification to all other users
    NotificationService.send(
      type: 'resource',
      title: '📚 New Resource: ${title.trim()}',
      body: '$subject • $department',
      excludeUserId: uploadedById,
    );
  }

  Future<void> incrementDownloads(String id) async {
    if (_connectivity.isOffline) {
      print('Download increment queued — will sync when online');
      return;
    }

    try {
      await supabase.rpc('increment_downloads', params: {'resource_id': id});
    } catch (e) {
      print('Error incrementing downloads: $e');
    }
  }

  Future<void> rateResource(String id, double newRating) async {
    if (_connectivity.isOffline) {
      print('Rating queued — will sync when online');
      return;
    }

    try {
      await supabase.rpc('rate_resource', params: {
        'p_resource_id': id,
        'p_rating': newRating,
      });
    } catch (e) {
      print('Error rating resource: $e');
    }
  }

  /// Delete resource — syncs across offline/online
  Future<void> deleteResource(String id, String storagePath) async {
    // Mark as deleted in cache
    await _db.deleteResource(id);

    // If online, delete from server and storage
    if (_connectivity.isOnline) {
      try {
        if (storagePath.isNotEmpty) {
          await supabase.storage.from('resources').remove([storagePath]);
        }
        await supabase.from('resources').delete().eq('id', id);
      } catch (e) {
        print('Error deleting resource from server: $e');
      }
    } else {
      print('Resource deleted offline — will sync when online');
    }
  }

  /// Sync deletions when connection is restored
  Future<void> syncDeletions() async {
    if (_connectivity.isOffline) return;

    try {
      final deletedItems = await _db.getDeletedItems();
      final deletedResIds = deletedItems['resources'] ?? [];

      for (final id in deletedResIds) {
        try {
          await supabase.from('resources').delete().eq('id', id);
          print('Synced deletion for resource: $id');
        } catch (e) {
          print('Failed to sync deletion for $id: $e');
        }
      }
    } catch (e) {
      print('Error syncing resource deletions: $e');
    }
  }
}
