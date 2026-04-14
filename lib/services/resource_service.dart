import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/resource_model.dart';
import 'supabase_client.dart';

class ResourceService {
  static const _maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const _allowedExts = ['pdf','doc','docx','ppt','pptx','jpg','jpeg','png'];

  Stream<List<Resource>> getResources({String? department, String? type}) {
    final controller = StreamController<List<Resource>>();

    Future<List<Resource>> fetch() async {
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
      return list;
    }

    // Do initial fetch immediately — no loading->error flash on filter change
    fetch().then((data) {
      if (!controller.isClosed) controller.add(data);
    }).catchError((e) {
      if (!controller.isClosed) controller.addError(e);
    });

    // Subscribe to realtime and re-fetch on any table change
    final channelName = 'resources_${department ?? "all"}_${type ?? "all"}';
    final channel = supabase.channel(channelName);
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'resources',
      callback: (_) async {
        if (!controller.isClosed) {
          try {
            controller.add(await fetch());
          } catch (e) {
            if (!controller.isClosed) controller.addError(e);
          }
        }
      },
    ).subscribe();

    controller.onCancel = () {
      supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  Future<void> uploadResource({
    required File file,
    required String title, required String subject,
    required String department, required String semester,
    required String type, required String uploadedBy,
    required String uploadedById,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxFileSizeBytes) {
      throw Exception('File too large. Maximum size is 10 MB.');
    }
    final ext = p.extension(file.path).toLowerCase().replaceAll('.', '');
    if (!_allowedExts.contains(ext)) {
      throw Exception('File type not allowed. Use PDF, DOCX, PPT, or image files.');
    }
    if (title.trim().isEmpty) throw Exception('Title required');

    final storagePath = 'resources/$uploadedById/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final sizeKB = (bytes.length / 1024).toStringAsFixed(0);

    await supabase.storage.from('resources').uploadBinary(storagePath, bytes);
    final url = supabase.storage.from('resources').getPublicUrl(storagePath);

    const colors = ['1A56DB','0E9F6E','E3A008','E02424','9061F9'];
    final color  = colors[DateTime.now().millisecond % colors.length];

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
  }

  Future<void> incrementDownloads(String id) async {
    await supabase.rpc('increment_downloads', params: {'resource_id': id});
  }

  Future<void> rateResource(String id, double newRating) async {
    await supabase.rpc('rate_resource', params: {
      'p_resource_id': id,
      'p_rating':      newRating,
    });
  }

  Future<void> deleteResource(String id, String storagePath) async {
    if (storagePath.isNotEmpty) {
      await supabase.storage.from('resources').remove([storagePath]);
    }
    await supabase.from('resources').delete().eq('id', id);
  }
}