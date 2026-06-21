import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final InternetConnection _connection = InternetConnection.createInstance(
    checkInterval: const Duration(seconds: 3),
  );

  final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);

  StreamSubscription<InternetStatus>? _subscription;

  Future<void> init() async {
    isOffline.value = false;
    _subscription = _connection.onStatusChange.listen(_onStatusChanged);
  }

  Future<void> _onStatusChanged(InternetStatus status) async {
    if (status == InternetStatus.connected) {
      isOffline.value = false;
      return;
    }

    isOffline.value = await _verifyOffline();
  }

  /// Runs repeated checks while the loading screen is visible.
  /// Returns `true` only when the device is genuinely offline.
  Future<bool> waitForReliableCheck({
    Duration timeout = const Duration(seconds: 4),
    Duration retryInterval = const Duration(milliseconds: 600),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final offline = await _verifyOffline();
      if (!offline) {
        isOffline.value = false;
        return false;
      }

      await Future.delayed(retryInterval);
    }

    final offline = await _verifyOffline();
    isOffline.value = offline;
    return offline;
  }

  Future<bool> refresh() {
    return waitForReliableCheck(
      timeout: const Duration(seconds: 3),
      retryInterval: const Duration(milliseconds: 500),
    );
  }

  Future<bool> _verifyOffline() async {
    if (!await _hasNetworkInterface()) {
      return true;
    }

    final hasInternet = await _connection.hasInternetAccess;
    return !hasInternet;
  }

  Future<bool> _hasNetworkInterface() async {
    final results = await _connectivity.checkConnectivity();
    if (results.isEmpty) {
      return false;
    }

    return results.any((result) => result != ConnectivityResult.none);
  }

  void dispose() {
    _subscription?.cancel();
    _connection.dispose();
    isOffline.dispose();
  }
}
