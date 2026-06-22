import 'package:flutter/foundation.dart';

import 'app_attribution_config.dart';
import 'appsflyer_service.dart';
import 'config_client.dart';
import 'config_storage.dart';
import 'firebase_service.dart';

enum ConfigLaunchTarget {
  webView,
  game,
}

class ConfigLaunchDecision {
  const ConfigLaunchDecision._({
    required this.target,
    this.url,
    this.reason,
  });

  final ConfigLaunchTarget target;
  final String? url;
  final String? reason;

  factory ConfigLaunchDecision.webView(String url, {String? reason}) {
    return ConfigLaunchDecision._(
      target: ConfigLaunchTarget.webView,
      url: url,
      reason: reason,
    );
  }

  factory ConfigLaunchDecision.game({String? reason}) {
    return ConfigLaunchDecision._(
      target: ConfigLaunchTarget.game,
      reason: reason,
    );
  }
}

class ConfigCoordinator {
  ConfigCoordinator._();

  static final ConfigCoordinator instance = ConfigCoordinator._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    await ConfigStorage.instance.init();
    FirebaseService.instance.setTokenRefreshCallback(_refreshConfigInBackground);
    await FirebaseService.instance.init();
    await AppsFlyerService.instance.init();

    _initialized = true;
  }

  Future<ConfigLaunchDecision> resolveLaunchDecision() async {
    await init();

    final storage = ConfigStorage.instance;

    final notificationUrl = FirebaseService.instance.consumePendingNotificationUrl();
    if (notificationUrl != null && notificationUrl.isNotEmpty) {
      _logLaunchDecision(
        ConfigLaunchDecision.webView(
          notificationUrl,
          reason: 'push_notification (not persisted)',
        ),
      );
      return ConfigLaunchDecision.webView(
        notificationUrl,
        reason: 'push_notification',
      );
    }

    if (storage.isCachedUrlValid) {
      final decision = ConfigLaunchDecision.webView(
        storage.cachedUrl!,
        reason: 'cached_url_valid',
      );
      _logLaunchDecision(decision);
      return decision;
    }

    final response = await ConfigClient.instance.fetchConfig();
    if (response.isSuccess) {
      await storage.saveConfigUrl(
        url: response.url!,
        expires: response.expires ?? 0,
      );
      final decision = ConfigLaunchDecision.webView(
        response.url!,
        reason: 'config_api_success',
      );
      _logLaunchDecision(decision);
      return decision;
    }

    if (storage.hasCachedUrl) {
      final decision = ConfigLaunchDecision.webView(
        storage.cachedUrl!,
        reason: 'config_api_failed_cached_fallback',
      );
      _logLaunchDecision(decision);
      return decision;
    }

    await storage.saveLaunchMode(AppAttributionConfig.launchModeGame);
    final decision = ConfigLaunchDecision.game(reason: 'config_api_failed_no_cache');
    _logLaunchDecision(decision);
    return decision;
  }

  Future<void> _refreshConfigInBackground(String token) async {
    debugPrint('FIREBASE TOKEN REFRESH: $token');
    final storage = ConfigStorage.instance;

    try {
      final response = await ConfigClient.instance.fetchConfig();
      if (response.isSuccess) {
        await storage.saveConfigUrl(
          url: response.url!,
          expires: response.expires ?? 0,
        );
      }
    } catch (error) {
      debugPrint('Background config refresh failed: $error');
    }
  }

  void _logLaunchDecision(ConfigLaunchDecision decision) {
    if (decision.target == ConfigLaunchTarget.webView) {
      debugPrint(
        'LAUNCH MODE: webview | reason=${decision.reason} | url=${decision.url}',
      );
    } else {
      debugPrint('LAUNCH MODE: game | reason=${decision.reason}');
    }
  }
}
