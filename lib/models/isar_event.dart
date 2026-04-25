import 'package:isar/isar.dart';
import 'event_model.dart';

part 'isar_event.g.dart';

@collection
class IsarEvent {
  Id? id = Isar.autoIncrement;
  
  late String remoteId;
  late String title;
  late String description;
  late String category;
  late String location;
  late DateTime date;
  late String time;
  late int attendees;
  late String organizer;
  late String organizerId;
  late String imageColor;
  late DateTime createdAt;
  late bool isRSVPed;
  late DateTime cachedAt;
  late bool isDeleted;
  
  IsarEvent({
    this.id,
    required this.remoteId,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.date,
    required this.time,
    this.attendees = 0,
    required this.organizer,
    required this.organizerId,
    required this.imageColor,
    required this.createdAt,
    this.isRSVPed = false,
    required this.cachedAt,
    this.isDeleted = false,
  });

  factory IsarEvent.fromEvent(Event e) => IsarEvent(
    remoteId: e.id,
    title: e.title,
    description: e.description,
    category: e.category,
    location: e.location,
    date: e.date,
    time: e.time,
    attendees: e.attendees,
    organizer: e.organizer,
    organizerId: e.organizerId,
    imageColor: e.imageColor,
    createdAt: e.createdAt,
    isRSVPed: e.isRSVPed,
    cachedAt: DateTime.now(),
  );

  Event toEvent() => Event(
    id: remoteId,
    title: title,
    description: description,
    category: category,
    location: location,
    date: date,
    time: time,
    attendees: attendees,
    organizer: organizer,
    organizerId: organizerId,
    imageColor: imageColor,
    createdAt: createdAt,
    isRSVPed: isRSVPed,
  );

  Map<String, dynamic> toMap() => {
    'id': remoteId,
    'title': title,
    'description': description,
    'category': category,
    'location': location,
    'date': date.toIso8601String(),
    'time': time,
    'attendees': attendees,
    'organizer': organizer,
    'organizer_id': organizerId,
    'image_color': imageColor,
    'created_at': createdAt.toIso8601String(),
  };
}
