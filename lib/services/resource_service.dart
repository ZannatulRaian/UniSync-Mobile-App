import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as pp;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/resource_model.dart';
import '../models/isar_resource.dart';
import '../services/connectivity_service.dart';
import '../services/local_database_service.dart';
import 'supabase_client.dart';
import 'notification_service.dart';

class ResourceService {
  static const _maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const _allowedExts = [
    'pdf', 'doc', 'docx', 'ppt', 'pptx', 'jpg', 'jpeg', 'png'
  ];

  final LocalDatabaseService _db;
  final ConnectivityService _connectivity;

  ResourceService(this._db, this._connectivity);

  Stream<List<Resource>> getResources({String? department, String? type}) {
    final controller = StreamController<List<Resource>>.broadcast();

    Future<void> _run() async {
      try {
        final cached =
            await _db.getCachedResources(department: department, type: type);
        if (!controller.isClosed) {
          controller.add(cached.map((r) => r.toResource()).toList());
        }
      } catch (e) {
        print('Error loading cached resources: $e');
      }

      if (!_connectivity.isOnline) return;

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

        final isarResources =
            list.map((r) => IsarResource.fromResource(r)).toList();
        await _db.cacheResources(isarResources);

        if (!controller.isClosed) controller.add(list);

        final channelName =
            'resources_${department ?? "all"}_${type ?? "all"}'
            '_${DateTime.now().millisecondsSinceEpoch}';
        supabase.channel(channelName).onPostgresChanges(
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

              final isarUpdates =
                  updatedList.map((r) => IsarResource.fromResource(r)).toList();
              await _db.cacheResources(isarUpdates);

              if (!controller.isClosed) controller.add(updatedList);
            } catch (e) {
              print('Error in realtime resource update: $e');
            }
          },
        ).subscribe();
      } catch (e) {
        print('Error fetching resources: $e');
        if (!controller.isClosed) controller.addError(e);
      }
    }

    _run();
    return controller.stream;
  }

  /// Upload a resource.
  ///
  /// **Online** → uploads immediately to Supabase Storage and inserts the row.
  ///
  /// **Offline** → validates the file, saves it to a persistent local
  /// directory, inserts an optimistic [IsarResource] so the UI reflects it
  /// right away, and queues an [IsarPendingAction] that
  /// [OfflineSyncService.syncAll] will process when connectivity returns.
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
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxFileSizeBytes) {
      throw Exception('File too large. Maximum size is 10 MB.');
    }

    final ext = p.extension(file.path).toLowerCase().replaceAll('.', '');
    if (!_allowedExts.contains(ext)) {
      throw Exception(
          'File type not allowed. Use PDF, DOCX, PPT, or image files.');
    }
    if (title.trim().isEmpty) throw Exception('Title required');

    const colors = ['1A56DB', '0E9F6E', 'E3A008', 'E02424', '9061F9'];
    final color = colors[DateTime.now().millisecond % colors.length];
    final sizeKB = (bytes.length / 1024).toStringAsFixed(0);

    if (_connectivity.isOffline) {
      // Save to stable local path so the file survives app restarts
      final pendingDir = await _getPendingUploadsDir();
      final savedFileName =
          'pending_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final savedFile = File('${pendingDir.path}/$savedFileName');
      await savedFile.writeAsBytes(bytes);

      await _db.enqueuePendingAction(
        actionType: 'upload_resource',
        payloadJson: jsonEncode({
          'local_file_path': savedFile.path,
          'ext':             ext,
          'title':           title.trim(),
          'subject':         subject.trim(),
          'department':      department,
          'semester':        semester,
          'type':            type.toUpperCase(),
          'uploaded_by':     uploadedBy,
          'uploaded_by_id':  uploadedById,
          'icon_color':      color,
        }),
      );

      // Optimistic local record — visible in the UI immediately
      final optimistic = IsarResource(
        remoteId:     'pending_${DateTime.now().millisecondsSinceEpoch}',
        title:        title.trim(),
        subject:      subject.trim(),
        department:   department,
        semester:     semester,
        type:         type.toUpperCase(),
        fileUrl:      savedFile.path,
        storagePath:  '',
        size:         '$sizeKB KB',
        uploadedBy:   uploadedBy,
        uploadedById: uploadedById,
        uploadedAt:   DateTime.now(),
        iconColor:    color,
        cachedAt:     DateTime.now(),
      );
      await _db.cacheResources([optimistic]);

      print('[ResourceService] Upload queued offline — will sync when online');
      return;
    }

    // Online path
    final storagePath =
        'resources/$uploadedById/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await supabase.storage.from('resources').uploadBinary(storagePath, bytes);
    final url = supabase.storage.from('resources').getPublicUrl(storagePath);

    await supabase.from('resources').insert({
      'title':          title.trim(),
      'subject':        subject.trim(),
      'department':     department,
      'semester':       semester,
      'type':           type.toUpperCase(),
      'file_url':       url,
      'storage_path':   storagePath,
      'size':           '$sizeKB KB',
      'uploaded_by':    uploadedBy,
      'uploaded_by_id': uploadedById,
      'icon_color':     color,
    });

    NotificationService.send(
      type:          'resource',
      title:         '📚 New Resource: ${title.trim()}',
      body:          '${subject.trim()} • $department',
      excludeUserId: uploadedById,
    );
  }

  Future<void> incrementDownloads(String id) async {
    if (_connectivity.isOffline) return;
    try {
      await supabase.rpc('increment_downloads', params: {'resource_id': id});
    } catch (e) {
      print('Error incrementing downloads: $e');
    }
  }

  Future<void> rateResource(String id, double newRating) async {
    if (_connectivity.isOffline) return;
    try {
      await supabase.rpc('rate_resource', params: {
        'p_resource_id': id,
        'p_rating':      newRating,
      });
    } catch (e) {
      print('Error rating resource: $e');
    }
  }

  Future<void> deleteResource(String id, String storagePath) async {
    await _db.deleteResource(id);

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
      if (!id.startsWith('pending_')) {
        await _db.enqueuePendingAction(
          actionType:  'delete_resource',
          payloadJson: jsonEncode({'id': id, 'storage_path': storagePath}),
        );
      }
    }
  }

  Future<void> syncDeletions() async {
    if (_connectivity.isOffline) return;
    try {
      final deletedItems = await _db.getDeletedItems();
      for (final id in deletedItems['resources'] ?? []) {
        if (id.startsWith('pending_')) continue;
        try {
          await supabase.from('resources').delete().eq('id', id);
        } catch (e) {
          print('Failed to sync deletion for $id: $e');
        }
      }
    } catch (e) {
      print('Error syncing resource deletions: $e');
    }
  }

  Future<Directory> _getPendingUploadsDir() async {
    final docs = await pp.getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/unisync_pending_uploads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
