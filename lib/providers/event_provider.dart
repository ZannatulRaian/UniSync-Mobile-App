import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/event_service.dart';
import '../models/event_model.dart';

final eventServiceProvider = Provider((_) => EventService());

final eventsStreamProvider = StreamProvider<List<Event>>((ref) =>
    ref.watch(eventServiceProvider).getEvents());
