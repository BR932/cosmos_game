import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

typedef PushTokenRefreshCallback = Future<void> Function(String token);

class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  bool _initialized = false;
  String? _pushToken;
  String? _pendingNotificationUrl;
  PushTokenRefreshCallback? _onTokenRefresh;

  bool get isInitialized => _initialized;

  String? get pushToken => _pushToken;

  String? get firebaseProjectId {
    if (!_initialized) {
      return null;
    }

    final options = Firebase.app().options;
    if (options.projectId.isNotEmpty) {
      return options.projectId;
    }

    return options.messagingSenderId;
  }

  void setTokenRefreshCallback(PushTokenRefreshCallback callback) {
    _onTokenRefresh = callback;
  }

  /// Returns a notification deep-link URL once, without persisting it.
  String? consumePendingNotificationUrl() {
    final url = _pendingNotificationUrl;
    _pendingNotificationUrl = null;
    return url;
  }

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    try {
      await Firebase.initializeApp();
      _initialized = true;

      final messaging = FirebaseMessaging.instance;
      if (Platform.isIOS) {
        await messaging.requestPermission();
      } else if (Platform.isAndroid) {
        await messaging.requestPermission();
      }

      _pushToken = await messaging.getToken();
      debugPrint('FIREBASE TOKEN: ${_pushToken ?? "(null)"}');
      debugPrint('FIREBASE PROJECT ID: ${firebaseProjectId ?? "(null)"}');

      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        _pushToken = token;
        debugPrint('FIREBASE TOKEN REFRESH: $token');
        final callback = _onTokenRefresh;
        if (callback != null) {
          await callback(token);
        }
      });

      final initialMessage = await messaging.getInitialMessage();
      _captureNotificationUrl(initialMessage);

      FirebaseMessaging.onMessageOpenedApp.listen(_captureNotificationUrl);
    } catch (error) {
      debugPrint('Firebase init failed: $error');
    }
  }

  Future<void> refreshToken() async {
    if (!_initialized) {
      return;
    }

    try {
      if (Platform.isIOS) {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) {
          return;
        }
      }

      _pushToken = await FirebaseMessaging.instance.getToken();
    } catch (error) {
      debugPrint('Firebase token refresh failed: $error');
    }
  }

  void _captureNotificationUrl(RemoteMessage? message) {
    if (message == null) {
      return;
    }

    final url = message.data['url'] ?? message.data['link'];
    if (url is String && url.isNotEmpty) {
      _pendingNotificationUrl = url;
      debugPrint('FIREBASE NOTIFICATION URL (one-shot): $url');
    }
  }
}
