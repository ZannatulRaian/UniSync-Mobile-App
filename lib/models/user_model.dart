class AppUser {
  final String id;
  final String name;
  final String email;
  final String department;
  final String semester;
  final String studentId;
  final String role;
  final String? photoUrl;
  final List<String> bookmarkedAnnouncements;
  final List<String> rsvpedEvents;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.department,
    required this.semester,
    required this.studentId,
    this.role = 'student',
    this.photoUrl,
    this.bookmarkedAnnouncements = const [],
    this.rsvpedEvents = const [],
  });

  // Backward-compatible alias
  String get uid => id;

  factory AppUser.fromMap(Map<String, dynamic> d) => AppUser(
    id:         d['id'] ?? '',
    name:       d['name'] ?? '',
    email:      d['email'] ?? '',
    department: d['department'] ?? '',
    semester:   d['semester'] ?? '',
    studentId:  d['student_id'] ?? '',
    role:       d['role'] ?? 'student',
    photoUrl:   d['photo_url'],
    bookmarkedAnnouncements: List<String>.from(d['bookmarked_announcements'] ?? []),
    rsvpedEvents:            List<String>.from(d['rsvped_events'] ?? []),
  );

  AppUser copyWith({
    String? name, String? email, String? department, String? semester,
    String? studentId, String? role, String? photoUrl,
    List<String>? bookmarkedAnnouncements, List<String>? rsvpedEvents,
  }) => AppUser(
    id:                      id,
    name:                    name       ?? this.name,
    email:                   email      ?? this.email,
    department:              department ?? this.department,
    semester:                semester   ?? this.semester,
    studentId:               studentId  ?? this.studentId,
    role:                    role       ?? this.role,
    photoUrl:                photoUrl   ?? this.photoUrl,
    bookmarkedAnnouncements: bookmarkedAnnouncements ?? this.bookmarkedAnnouncements,
    rsvpedEvents:            rsvpedEvents ?? this.rsvpedEvents,
  );
}
