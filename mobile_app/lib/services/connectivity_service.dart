import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for monitoring network connectivity
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamController<bool>? _connectionController;
  Stream<bool>? _connectionStream;
  bool _isConnected = true;

  /// Stream of connectivity status changes
  Stream<bool> get onConnectivityChanged {
    _connectionController ??= StreamController<bool>.broadcast();
    _connectionStream ??= _connectionController!.stream;

    // Start listening to connectivity changes
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      final isConnected = result != ConnectivityResult.none;
      if (_isConnected != isConnected) {
        _isConnected = isConnected;
        _connectionController?.add(isConnected);
      }
    });

    // Check initial connectivity
    _checkConnectivity();

    return _connectionStream!;
  }

  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _isConnected = result != ConnectivityResult.none;
    return _isConnected;
  }

  Future<void> _checkConnectivity() async {
    _isConnected = await checkConnectivity();
    _connectionController?.add(_isConnected);
  }

  /// Get current connectivity status (cached)
  bool get isConnected => _isConnected;

  /// Dispose resources
  void dispose() {
    _connectionController?.close();
    _connectionController = null;
    _connectionStream = null;
  }
}
