/// Replace placeholder values with credentials provided by your manager.
class AppAttributionConfig {
  AppAttributionConfig._();

  static const String configUrl = 'https://spacechhicken.com/config.php';

  /// AppsFlyer dev key from the dashboard (App Settings → Dev Key).
  static const String appsFlyerDevKey = 'YOUR_APPSFLYER_DEV_KEY';

  /// Apple App Store numeric ID without the `id` prefix (iOS only).
  static const String iosAppStoreId = 'YOUR_APP_STORE_ID';

  /// Apple App Store ID with the `id` prefix for config `store_id`.
  static const String iosStoreId = 'idYOUR_APP_STORE_ID';

  static const String androidPackageName = 'com.space_chicken';

  static const Duration conversionDataTimeout = Duration(seconds: 15);
  static const Duration configRequestTimeout = Duration(seconds: 20);

  static const String cachedUrlKey = 'config_cached_url';
  static const String cachedExpiresKey = 'config_cached_expires';
  static const String launchModeKey = 'config_launch_mode';

  /// Legacy key – cleared on init so failed launches can retry config.
  static const String configPermanentlySkippedKey = 'config_permanently_skipped';

  static const String launchModeWebView = 'webview';
  static const String launchModeGame = 'game';

  static bool get isAppsFlyerDevKeyConfigured =>
      appsFlyerDevKey.isNotEmpty &&
      appsFlyerDevKey != 'YOUR_APPSFLYER_DEV_KEY';

  static bool get isIosAppStoreIdConfigured =>
      iosAppStoreId.isNotEmpty && iosAppStoreId != 'YOUR_APP_STORE_ID';
}
