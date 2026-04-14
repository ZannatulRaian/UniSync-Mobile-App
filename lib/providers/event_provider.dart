import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/event_service.dart';
import '../models/event_model.dart';

final eventServiceProvider = Provider((_) => EventService());

// keepAlive: true — keeps event data alive across tab switches so the
// shimmer loader doesn't flash every time the user returns to Home or Events
final eventsStreamProvider = StreamProvider<List<Event>>((ref) {
  ref.keepAlive();
  return ref.watch(eventServiceProvider).getEvents();
});
