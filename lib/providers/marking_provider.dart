import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/marking_service.dart';
import '../models/isar_resource.dart';
import 'connectivity_provider.dart';

final markingServiceProvider = Provider<MarkingService>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  return MarkingService(db, connectivity);
});

// Watch bookmarked resources
final bookmarkedResourcesProvider =
    FutureProvider<List<IsarResource>>((ref) async {
  final markingService = ref.watch(markingServiceProvider);
  return await markingService.getBookmarkedResources();
});

// Track individual resource bookmark state
final resourceBookmarkProvider =
    StateNotifierProvider.family<ResourceBookmarkNotifier, bool, String>(
  (ref, resourceId) {
    final markingService = ref.watch(markingServiceProvider);
    return ResourceBookmarkNotifier(markingService, resourceId);
  },
);

class ResourceBookmarkNotifier extends StateNotifier<bool> {
  final MarkingService _markingService;
  final String _resourceId;

  ResourceBookmarkNotifier(this._markingService, this._resourceId)
      : super(false) {
    _initialize();
  }

  Future<void> _initialize() async {
    final bookmarked = await _markingService.getBookmarkedResources();
    final isBookmarked =
        bookmarked.any((r) => r.remoteId == _resourceId);
    state = isBookmarked;
  }

  Future<void> toggle() async {
    final newState = !state;
    state = newState;

    try {
      await _markingService.toggleResourceBookmark(_resourceId, newState);
    } catch (e) {
      // Revert state if error
      state = !newState;
      print('Failed to toggle bookmark: $e');
      rethrow;
    }
  }
}
