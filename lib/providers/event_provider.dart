import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/event_service.dart';
import '../models/event_model.dart';
import 'connectivity_provider.dart';

final eventServiceProvider = Provider<EventService>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  return EventService(db, connectivity);
});

// keepAlive: true — keeps event data alive across tab switches
final eventsStreamProvider = StreamProvider<List<Event>>((ref) {
  ref.keepAlive();
  return ref.watch(eventServiceProvider).getEvents();
});
