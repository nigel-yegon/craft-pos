import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Lightweight wrapper around connectivity_plus.
/// Offline-first apps should treat "online" as an opportunity, not a requirement.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _onlineController =
  StreamController<bool>.broadcast();

  bool _isOnline = false;
  bool get isOnline => _isOnline;
  Stream<bool> get onOnlineChanged => _onlineController.stream;

  StreamSubscription? _sub;

  Future<void> init() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = _hasConnection(results);
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final online = _hasConnection(results);
      if (online != _isOnline) {
        _isOnline = online;
        _onlineController.add(online);
      }
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) =>
    r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _onlineController.close();
  }
}