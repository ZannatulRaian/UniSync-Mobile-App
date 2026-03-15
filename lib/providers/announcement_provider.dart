import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/announcement_service.dart';
import '../models/announcement_model.dart';

final announcementServiceProvider = Provider((_) => AnnouncementService());

final announcementsStreamProvider = StreamProvider.family<List<Announcement>, String?>((ref, type) =>
    ref.watch(announcementServiceProvider).getAnnouncements(type: type));
