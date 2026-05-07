import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/announcement_service.dart';
import '../models/announcement_model.dart';
import 'connectivity_provider.dart';

final announcementServiceProvider = Provider<AnnouncementService>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  return AnnouncementService(db, connectivity);
});

// FIX: Normalize key so 'All' and null both map to the same keepAlive stream.
// Previously null (from profile screen) vs 'All' (from home/announcements screen)
// created two separate stream instances → two DB write batches → duplicate records.
final announcementsStreamProvider =
    StreamProvider.family<List<Announcement>, String?>((ref, type) {
  ref.keepAlive();
  // Treat null and 'All' identically — always fetch all, filter client-side if needed
  final effectiveType = (type == null || type == 'All') ? null : type;
  return ref
      .watch(announcementServiceProvider)
      .getAnnouncements(type: effectiveType);
});
