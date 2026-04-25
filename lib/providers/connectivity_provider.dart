import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';
import '../services/local_database_service.dart';

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

final syncTriggerProvider =
    StateNotifierProvider<SyncNotifier, bool>((ref) {
  final notifier = SyncNotifier();
  final connectivity = ref.watch(connectivityServiceProvider);
  connectivity.onConnectionRestored = () => notifier.trigger();
  return notifier;
});

class SyncNotifier extends StateNotifier<bool> {
  SyncNotifier() : super(false);

  void trigger() {
    state = !state;
  }
}
