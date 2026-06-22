import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import 'app_attribution_config.dart';

class AppsFlyerService {
  AppsFlyerService._();

  static final AppsFlyerService instance = AppsFlyerService._();

  AppsflyerSdk? _sdk;
  Map<String, dynamic>? _conversionData;
  Map<String, dynamic>? _deepLinkData;
  Completer<void>? _conversionReady;
  bool _conversionFailed = false;

  Map<String, dynamic>? get conversionData => _conversionData;

  Map<String, dynamic>? get deepLinkData => _deepLinkData;

  bool get conversionFailed => _conversionFailed;

  Future<void> init() async {
    if (_sdk != null) {
      return;
    }

    if (!AppAttributionConfig.isAppsFlyerDevKeyConfigured) {
      debugPrint(
        'APPSFLYER ERROR: appsFlyerDevKey is still placeholder '
        '"YOUR_APPSFLYER_DEV_KEY". AppsFlyer server returns HTTP 404 '
        '(application doesn\'t exist) until a real Dev Key from the dashboard '
        'is set in app_attribution_config.dart.',
      );
    }

    if (Platform.isIOS && !AppAttributionConfig.isIosAppStoreIdConfigured) {
      debugPrint(
        'APPSFLYER WARNING: iosAppStoreId is still placeholder. '
        'Set the numeric App Store ID from AppsFlyer dashboard.',
      );
    }

    _conversionReady = Completer<void>();

    final options = AppsFlyerOptions(
      afDevKey: AppAttributionConfig.appsFlyerDevKey,
      appId: AppAttributionConfig.iosAppStoreId,
      showDebug: kDebugMode,
    );

    final sdk = AppsflyerSdk(options);
    _sdk = sdk;

    // Callbacks MUST be registered before initSdk().
    sdk.onInstallConversionData(_handleConversionData);
    sdk.onAppOpenAttribution(_handleAppOpenAttribution);
    sdk.onDeepLinking(_handleDeepLink);

    await sdk.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );

    final uid = await getAppsFlyerId();
    debugPrint('AF UID: ${uid ?? "(null)"}');
  }

  Future<String?> getAppsFlyerId() async {
    final sdk = _sdk;
    if (sdk == null) {
      return null;
    }

    try {
      return await sdk.getAppsFlyerUID();
    } catch (error) {
      debugPrint('AppsFlyer UID error: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>> waitForConversionData() async {
    await init();

    final ready = _conversionReady;
    if (ready != null && !ready.isCompleted) {
      try {
        await ready.future.timeout(AppAttributionConfig.conversionDataTimeout);
      } on TimeoutException {
        debugPrint(
          'AF CONVERSION DATA: timeout after '
          '${AppAttributionConfig.conversionDataTimeout.inSeconds}s',
        );
        _completeConversionReady();
      }
    }

    return Map<String, dynamic>.from(_conversionData ?? const {});
  }

  void _handleConversionData(dynamic result) {
    debugPrint('AF CONVERSION DATA: ${_encodeForLog(result)}');

    if (result is! Map) {
      _completeConversionReady();
      return;
    }

    final envelope = Map<String, dynamic>.from(result);
    if (envelope['status'] == 'failure') {
      _conversionFailed = true;
      debugPrint('AF CONVERSION FAILURE: ${envelope['payload']}');
      _completeConversionReady();
      return;
    }

    final payload = envelope['payload'] ?? envelope['data'];
    if (payload is Map) {
      // Store inner conversion fields exactly as AppsFlyer returns them.
      _conversionData = Map<String, dynamic>.from(payload);
      debugPrint('AF CONVERSION FIELDS: ${_encodeForLog(_conversionData)}');
    }

    _completeConversionReady();
  }

  void _handleAppOpenAttribution(dynamic result) {
    debugPrint('AF APP OPEN ATTRIBUTION: ${_encodeForLog(result)}');
    _mergeAttributionPayload(result);
  }

  void _handleDeepLink(DeepLinkResult result) {
    debugPrint('AF DEEP LINK status=${result.status} error=${result.error}');

    if (result.status != Status.FOUND || result.deepLink == null) {
      return;
    }

    final payload = Map<String, dynamic>.from(result.deepLink!.clickEvent);
    debugPrint('AF DEEP LINK DATA: ${_encodeForLog(payload)}');
    _deepLinkData = payload;
  }

  void _mergeAttributionPayload(dynamic result) {
    if (result is! Map) {
      return;
    }

    final map = Map<String, dynamic>.from(result);
    final nested = map['payload'] ?? map['data'];
    final payload = nested is Map
        ? Map<String, dynamic>.from(nested)
        : map;

    if (payload.isEmpty) {
      return;
    }

    _deepLinkData ??= {};
    for (final entry in payload.entries) {
      _deepLinkData!.putIfAbsent(entry.key, () => entry.value);
    }
  }

  void _completeConversionReady() {
    final ready = _conversionReady;
    if (ready != null && !ready.isCompleted) {
      ready.complete();
    }
  }

  String _encodeForLog(Object? value) {
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }
}
