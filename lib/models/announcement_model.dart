class Announcement {
  final String id;
  final String title;
  final String content;
  final String postedBy;
  final String postedById;
  final DateTime postedAt;
  final String type;
  bool isBookmarked;

  Announcement({
    required this.id, required this.title, required this.content,
    required this.postedBy, required this.postedById,
    required this.postedAt, required this.type, this.isBookmarked = false,
  });

  factory Announcement.fromMap(Map<String, dynamic> d) => Announcement(
    id:         d['id'],
    title:      d['title'] ?? '',
    content:    d['content'] ?? '',
    postedBy:   d['posted_by'] ?? '',
    postedById: d['posted_by_id'] ?? '',
    postedAt:   DateTime.parse(d['posted_at'] ?? DateTime.now().toIso8601String()),
    type:       d['type'] ?? 'General',
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'title': title, 'content': content,
    'posted_by': postedBy, 'posted_by_id': postedById,
    'posted_at': postedAt.toIso8601String(), 'type': type,
  };
}
