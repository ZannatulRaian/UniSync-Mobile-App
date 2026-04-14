import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/resource_service.dart';
import '../models/resource_model.dart';

final resourceServiceProvider = Provider((_) => ResourceService());

class ResourceFilter {
  final String? dept;
  final String? type;
  const ResourceFilter({this.dept, this.type});

  @override
  bool operator ==(Object other) =>
      other is ResourceFilter && other.dept == dept && other.type == type;

  @override
  int get hashCode => Object.hash(dept, type);
}

// keepAlive so resources don't reload on every tab switch
final resourcesStreamProvider =
    StreamProvider.family<List<Resource>, ResourceFilter>((ref, filter) {
  ref.keepAlive();
  return ref
      .watch(resourceServiceProvider)
      .getResources(department: filter.dept, type: filter.type);
});
