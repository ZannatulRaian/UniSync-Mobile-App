class Resource {
  final String id;
  final String title;
  final String subject;
  final String department;
  final String semester;
  final String type;
  final String fileUrl;
  final String storagePath;
  final String size;
  final int downloads;
  final double rating;
  final int ratingCount;
  final String uploadedBy;
  final String uploadedById;
  final DateTime uploadedAt;
  final String iconColor;

  const Resource({
    required this.id, required this.title, required this.subject,
    required this.department, required this.semester, required this.type,
    required this.fileUrl, this.storagePath = '',
    required this.size, this.downloads = 0,
    this.rating = 0.0, this.ratingCount = 0,
    required this.uploadedBy, required this.uploadedById,
    required this.uploadedAt, required this.iconColor,
  });

  factory Resource.fromMap(Map<String, dynamic> d) => Resource(
    id:           d['id'] ?? '',
    title:        d['title'] ?? '',
    subject:      d['subject'] ?? '',
    department:   d['department'] ?? '',
    semester:     d['semester'] ?? '',
    type:         d['type'] ?? 'PDF',
    fileUrl:      d['file_url'] ?? '',
    storagePath:  d['storage_path'] ?? '',
    size:         d['size'] ?? '0 KB',
    downloads:    d['downloads'] ?? 0,
    rating:       (d['rating'] ?? 0.0).toDouble(),
    ratingCount:  d['rating_count'] ?? 0,
    uploadedBy:   d['uploaded_by'] ?? '',
    uploadedById: d['uploaded_by_id'] ?? '',
    uploadedAt:   DateTime.tryParse(d['uploaded_at'] ?? '') ?? DateTime.now(),
    iconColor:    d['icon_color'] ?? '1A56DB',
  );
}
