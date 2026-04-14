import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/announcement_service.dart';
import '../models/announcement_model.dart';

final announcementServiceProvider = Provider((_) => AnnouncementService());

// keepAlive: true — prevents re-fetching every time the tab is revisited
final announcementsStreamProvider =
    StreamProvider.family<List<Announcement>, String?>((ref, type) {
  ref.keepAlive();
  return ref.watch(announcementServiceProvider).getAnnouncements(type: type);
});
