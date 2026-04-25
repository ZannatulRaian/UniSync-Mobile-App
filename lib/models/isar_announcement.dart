import 'package:isar/isar.dart';
import 'announcement_model.dart';

part 'isar_announcement.g.dart';

@collection
class IsarAnnouncement {
  Id? id = Isar.autoIncrement;
  
  late String remoteId;
  late String title;
  late String content;
  late String postedBy;
  late String postedById;
  late DateTime postedAt;
  late String type;
  late bool isBookmarked;
  late DateTime cachedAt;
  late bool isDeleted;
  
  IsarAnnouncement({
    this.id,
    required this.remoteId,
    required this.title,
    required this.content,
    required this.postedBy,
    required this.postedById,
    required this.postedAt,
    required this.type,
    this.isBookmarked = false,
    required this.cachedAt,
    this.isDeleted = false,
  });

  factory IsarAnnouncement.fromAnnouncement(Announcement a) => IsarAnnouncement(
    remoteId: a.id,
    title: a.title,
    content: a.content,
    postedBy: a.postedBy,
    postedById: a.postedById,
    postedAt: a.postedAt,
    type: a.type,
    isBookmarked: a.isBookmarked,
    cachedAt: DateTime.now(),
  );

  Announcement toAnnouncement() => Announcement(
    id: remoteId,
    title: title,
    content: content,
    postedBy: postedBy,
    postedById: postedById,
    postedAt: postedAt,
    type: type,
    isBookmarked: isBookmarked,
  );

  Map<String, dynamic> toMap() => {
    'id': remoteId,
    'title': title,
    'content': content,
    'posted_by': postedBy,
    'posted_by_id': postedById,
    'posted_at': postedAt.toIso8601String(),
    'type': type,
  };
}
