import '../models/event_model.dart';
import 'supabase_client.dart';

class EventService {
  Stream<List<Event>> getEvents() => supabase
      .from('events')
      .stream(primaryKey: ['id'])
      .order('date', ascending: true)
      .map((rows) => rows.map(Event.fromMap).toList());

  Future<void> createEvent({
    required String title, required String description,
    required String category, required String location,
    required DateTime date,  required String time,
    required String organizer, required String organizerId,
  }) async {
    if (title.trim().isEmpty) throw Exception('Title required');
    const colors = ['1A56DB','0E9F6E','E3A008','E02424','9061F9','3F83F8'];
    final color  = colors[DateTime.now().millisecond % colors.length];
    await supabase.from('events').insert({
      'title':        title.trim(),
      'description':  description.trim(),
      'category':     category,
      'location':     location.trim(),
      'date':         date.toIso8601String(),
      'time':         time.trim(),
      'attendees':    0,
      'organizer':    organizer,
      'organizer_id': organizerId,
      'image_color':  color,
    });
  }

  // SECURITY FIX: atomic RSVP via a single Postgres RPC — no race condition
  Future<void> rsvpEvent(String eventId, String userId, bool going) async {
    await supabase.rpc('toggle_rsvp', params: {
      'p_event_id': eventId,
      'p_user_id':  userId,
      'p_going':    going,
    });
  }

  Future<void> deleteEvent(String id) async {
    await supabase.from('events').delete().eq('id', id);
  }
}
