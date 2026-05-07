import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  final Connectivity _connectivity = Connectivity();

  bool _isOnline = true;
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  Future<void> initialize() async {
    // connectivity_plus 6.x returns List<ConnectivityResult>
    final results = await _connectivity.checkConnectivity();
    _isOnline = _resultsToOnline(results);
    print('ConnectivityService initialized: ${_isOnline ? "ONLINE" : "OFFLINE"}');

    _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = _resultsToOnline(results);

      print('Connectivity changed: ${_isOnline ? "ONLINE" : "OFFLINE"}');

      if (!wasOnline && _isOnline) {
        print('Connection restored! Triggering sync...');
        onConnectionRestored?.call();
      }
    });
  }

  /// Works with both single ConnectivityResult and List<ConnectivityResult>
  bool _resultsToOnline(dynamic results) {
    if (results is List) {
      return results.any((r) => r != ConnectivityResult.none);
    }
    // Older versions return a single result
    return results != ConnectivityResult.none;
  }

  void Function()? onConnectionRestored;

  void setOffline() {
    _isOnline = false;
    print('Manually set to OFFLINE');
  }

  void setOnline() {
    _isOnline = true;
    print('Manually set to ONLINE');
  }
}
