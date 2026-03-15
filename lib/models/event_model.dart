class Event {
  final String id;
  final String title;
  final String description;
  final String category;
  final String location;
  final DateTime date;
  final String time;
  final int attendees;
  final String organizer;
  final String organizerId;
  final String imageColor;
  final DateTime createdAt;
  bool isRSVPed;

  Event({
    required this.id, required this.title, required this.description,
    required this.category, required this.location, required this.date,
    required this.time, this.attendees = 0, required this.organizer,
    required this.organizerId, required this.imageColor,
    required this.createdAt, this.isRSVPed = false,
  });

  factory Event.fromMap(Map<String, dynamic> d) => Event(
    id:          d['id'],
    title:       d['title'] ?? '',
    description: d['description'] ?? '',
    category:    d['category'] ?? 'General',
    location:    d['location'] ?? '',
    date:        DateTime.parse(d['date']),
    time:        d['time'] ?? '',
    attendees:   d['attendees'] ?? 0,
    organizer:   d['organizer'] ?? '',
    organizerId: d['organizer_id'] ?? '',
    imageColor:  d['image_color'] ?? '1A56DB',
    createdAt:   DateTime.parse(d['created_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'title': title, 'description': description,
    'category': category, 'location': location,
    'date': date.toIso8601String(), 'time': time,
    'attendees': attendees, 'organizer': organizer,
    'organizer_id': organizerId, 'image_color': imageColor,
    'created_at': createdAt.toIso8601String(),
  };
}
