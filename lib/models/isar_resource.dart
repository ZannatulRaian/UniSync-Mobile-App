import 'package:isar/isar.dart';
import 'resource_model.dart';

part 'isar_resource.g.dart';

@collection
class IsarResource {
  Id? id = Isar.autoIncrement;
  
  late String remoteId;
  late String title;
  late String subject;
  late String department;
  late String semester;
  late String type;
  late String fileUrl;
  late String storagePath;
  late String size;
  late int downloads;
  late double rating;
  late int ratingCount;
  late String uploadedBy;
  late String uploadedById;
  late DateTime uploadedAt;
  late String iconColor;
  late DateTime cachedAt;
  late bool isDeleted;
  
  IsarResource({
    this.id,
    required this.remoteId,
    required this.title,
    required this.subject,
    required this.department,
    required this.semester,
    required this.type,
    required this.fileUrl,
    this.storagePath = '',
    required this.size,
    this.downloads = 0,
    this.rating = 0.0,
    this.ratingCount = 0,
    required this.uploadedBy,
    required this.uploadedById,
    required this.uploadedAt,
    required this.iconColor,
    required this.cachedAt,
    this.isDeleted = false,
  });

  factory IsarResource.fromResource(Resource r) => IsarResource(
    remoteId: r.id,
    title: r.title,
    subject: r.subject,
    department: r.department,
    semester: r.semester,
    type: r.type,
    fileUrl: r.fileUrl,
    storagePath: r.storagePath,
    size: r.size,
    downloads: r.downloads,
    rating: r.rating,
    ratingCount: r.ratingCount,
    uploadedBy: r.uploadedBy,
    uploadedById: r.uploadedById,
    uploadedAt: r.uploadedAt,
    iconColor: r.iconColor,
    cachedAt: DateTime.now(),
  );

  Resource toResource() => Resource(
    id: remoteId,
    title: title,
    subject: subject,
    department: department,
    semester: semester,
    type: type,
    fileUrl: fileUrl,
    storagePath: storagePath,
    size: size,
    downloads: downloads,
    rating: rating,
    ratingCount: ratingCount,
    uploadedBy: uploadedBy,
    uploadedById: uploadedById,
    uploadedAt: uploadedAt,
    iconColor: iconColor,
  );

  Map<String, dynamic> toMap() => {
    'id': remoteId,
    'title': title,
    'subject': subject,
    'department': department,
    'semester': semester,
    'type': type,
    'file_url': fileUrl,
    'storage_path': storagePath,
    'size': size,
    'downloads': downloads,
    'rating': rating,
    'rating_count': ratingCount,
    'uploaded_by': uploadedBy,
    'uploaded_by_id': uploadedById,
    'uploaded_at': uploadedAt.toIso8601String(),
    'icon_color': iconColor,
  };
}
