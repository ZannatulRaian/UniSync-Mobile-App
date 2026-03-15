import '../models/announcement_model.dart';
import 'supabase_client.dart';

class AnnouncementService {
  Stream<List<Announcement>> getAnnouncements({String? type}) {
    return supabase
        .from('announcements')
        .stream(primaryKey: ['id'])
        .order('posted_at', ascending: false)
        .map((rows) {
      var list = rows.map(Announcement.fromMap).toList();
      if (type != null && type != 'All') {
        list = list.where((a) => a.type == type).toList();
      }
      return list;
    });
  }

  Future<void> postAnnouncement({
    required String title,
    required String content,
    required String postedBy,
    required String postedById,
    required String type,
  }) async {
    // Basic input validation
    if (title.trim().isEmpty)   throw Exception('Title cannot be empty');
    if (content.trim().isEmpty) throw Exception('Content cannot be empty');
    // DB policy enforces faculty only — double check in UI too
    await supabase.from('announcements').insert({
      'title':        title.trim(),
      'content':      content.trim(),
      'posted_by':    postedBy,
      'posted_by_id': postedById,
      'type':         type,
      // id + posted_at set by DB defaults
    });
  }

  // SECURITY FIX: use Postgres array_append/array_remove instead of
  // read-modify-write (which has a race condition if user taps quickly)
  Future<void> bookmarkToggle(String userId, String announcementId, bool add) async {
    if (add) {
      await supabase.rpc('append_bookmark', params: {
        'user_id': userId, 'ann_id': announcementId,
      });
    } else {
      await supabase.rpc('remove_bookmark', params: {
        'user_id': userId, 'ann_id': announcementId,
      });
    }
  }

  Future<void> deleteAnnouncement(String id) async {
    // DB policy enforces faculty only
    await supabase.from('announcements').delete().eq('id', id);
  }
}
