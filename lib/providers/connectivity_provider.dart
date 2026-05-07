import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';
import '../services/local_database_service.dart';
import '../services/offline_sync_service.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((_) {
  return ConnectivityService();
});

final isOnlineProvider = StateProvider<bool>((ref) {
  final connectivity = ref.watch(connectivityServiceProvider);
  return connectivity.isOnline;
});

final isOfflineProvider = StateProvider<bool>((ref) {
  final connectivity = ref.watch(connectivityServiceProvider);
  return connectivity.isOffline;
});

final localDatabaseProvider = Provider<LocalDatabaseService>((ref) {
  return LocalDatabaseService();
});

final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  final db           = ref.watch(localDatabaseProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  return OfflineSyncService(db, connectivity);
});

final syncTriggerProvider =
    StateNotifierProvider<SyncNotifier, bool>((ref) {
  final notifier     = SyncNotifier();
  final connectivity = ref.watch(connectivityServiceProvider);
  final syncService  = ref.watch(offlineSyncServiceProvider);

  connectivity.onConnectionRestored = () async {
    // 1. Flush every queued write (messages, announcements, events, uploads)
    try {
      final n = await syncService.syncAll();
      print('[SyncTrigger] Flushed $n pending actions');
    } catch (e) {
      print('[SyncTrigger] Sync error: $e');
    }
    // 2. Tell UI providers to rebuild their streams
    notifier.trigger();
  };

  return notifier;
});

class SyncNotifier extends StateNotifier<bool> {
  SyncNotifier() : super(false);
  void trigger() => state = !state;
}

/// How many actions are still waiting to be synced.
/// Use this to show a pending badge in the UI.
final pendingActionCountProvider = FutureProvider<int>((ref) async {
  ref.watch(syncTriggerProvider); // re-evaluate after every sync
  final db = ref.watch(localDatabaseProvider);
  return db.pendingActionCount();
});
