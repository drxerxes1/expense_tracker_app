import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  void initialize() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
    // Check initial connectivity status
    _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('Error checking initial connectivity: $e');
      _isOnline = false;
      notifyListeners();
    }
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _isOnline = result == ConnectivityResult.mobile || 
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet ||
      result == ConnectivityResult.vpn;
    
    if (wasOnline != _isOnline) {
      debugPrint('Connectivity changed: ${_isOnline ? "Online" : "Offline"}');
      notifyListeners();
    }
  }

  /// Check if there's actual internet connectivity by making a real network request
  Future<bool> hasInternetConnection() async {
    try {
      // First check basic connectivity
      final result = await _connectivity.checkConnectivity();
      debugPrint('Connectivity result: $result');
      
      final hasBasicConnection = result == ConnectivityResult.mobile || 
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn;
      
      if (!hasBasicConnection) {
        debugPrint('No basic network connection');
        _isOnline = false;
        notifyListeners();
        return false;
      }

      // Test actual internet connectivity with a quick request
      try {
        final response = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 3));
        
        final hasInternet = response.isNotEmpty && response[0].rawAddress.isNotEmpty;
        debugPrint('Internet connectivity test: $hasInternet');
        
        // Update the cached state to match the fresh check
        if (_isOnline != hasInternet) {
          _isOnline = hasInternet;
          notifyListeners();
        }
        
        return hasInternet;
      } catch (e) {
        debugPrint('Internet connectivity test failed: $e');
        // If DNS lookup fails, assume no internet
        if (_isOnline) {
          _isOnline = false;
          notifyListeners();
        }
        return false;
      }
    } catch (e) {
      debugPrint('Error checking internet connection: $e');
      // On error, assume we're offline and update state
      if (_isOnline) {
        _isOnline = false;
        notifyListeners();
      }
      return false;
    }
  }

  /// Force refresh the connectivity state
  Future<void> refreshConnectivity() async {
    await _checkInitialConnectivity();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
