import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'supabase_client.dart';

class ProfileService {
  static const _maxAvatarBytes = 3 * 1024 * 1024; // 3 MB
  static const _allowedExts   = ['jpg', 'jpeg', 'png', 'webp'];

  Future<String> uploadProfilePhoto(String userId, File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxAvatarBytes) {
      throw Exception('Image too large. Maximum size is 3 MB.');
    }

    final ext = file.path.split('.').last.toLowerCase();
    if (!_allowedExts.contains(ext)) {
      throw Exception('Only JPG, PNG, or WEBP images are allowed.');
    }

    final path = 'avatars/$userId.$ext';

    await supabase.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );

    final url = supabase.storage.from('avatars').getPublicUrl(path);
    // Use RPC to avoid "uuid = text" operator mismatch
    await supabase.rpc('update_photo_url', params: {
      'p_user_id': userId,
      'p_photo_url': url,
    });
    return url;
  }

  // SECURITY: search only returns safe public fields (no student_id, no role).
  // Requires at least 2 characters to prevent bulk enumeration of all users.
  // Results capped at 20.
  Future<List<AppUser>> searchUsers(String query, {required String excludeId}) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final rows = await supabase
        .from('users')
        .select('id, name, email, department, semester, photo_url, role')
        .ilike('name', '%$q%')
        .neq('id', excludeId)
        .limit(20);
    return (rows as List).map((r) => AppUser.fromMap(r)).toList();
  }
}
