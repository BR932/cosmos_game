import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'app_attribution_config.dart';
import 'appsflyer_service.dart';
import 'firebase_service.dart';

class ConfigResponse {
  const ConfigResponse({
    required this.ok,
    required this.statusCode,
    this.url,
    this.expires,
    this.message,
  });

  final bool ok;
  final int statusCode;
  final String? url;
  final int? expires;
  final String? message;

  bool get isSuccess => statusCode == 200 && ok && url != null && url!.isNotEmpty;
}

class ConfigClient {
  ConfigClient._();

  static final ConfigClient instance = ConfigClient._();

  Future<ConfigResponse> fetchConfig() async {
    final body = await _buildRequestBody();
    debugPrint('CONFIG REQUEST BODY: ${jsonEncode(body)}');

    try {
      final response = await http
          .post(
            Uri.parse(AppAttributionConfig.configUrl),
            headers: const {
              'accept': 'application/json',
              'content-type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(AppAttributionConfig.configRequestTimeout);

      debugPrint(
        'CONFIG RESPONSE: status=${response.statusCode} body=${response.body}',
      );

      Map<String, dynamic>? payload;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        } else if (decoded is Map) {
          payload = Map<String, dynamic>.from(decoded);
        }
      } on FormatException {
        payload = null;
      }

      if (payload == null) {
        return ConfigResponse(
          ok: false,
          statusCode: response.statusCode,
          message: 'Invalid response body',
        );
      }

      final expiresRaw = payload['expires'];
      int? expires;
      if (expiresRaw is int) {
        expires = expiresRaw;
      } else if (expiresRaw is String) {
        expires = int.tryParse(expiresRaw);
      }

      return ConfigResponse(
        ok: payload['ok'] == true,
        statusCode: response.statusCode,
        url: payload['url'] as String?,
        expires: expires,
        message: payload['message'] as String?,
      );
    } catch (error) {
      debugPrint('Config request failed: $error');
      return ConfigResponse(
        ok: false,
        statusCode: 0,
        message: error.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> _buildRequestBody() async {
    // Conversion fields are copied unchanged from AppsFlyer payload.
    final conversionData = await AppsFlyerService.instance.waitForConversionData();
    final body = Map<String, dynamic>.from(conversionData);

    final deepLinkData = AppsFlyerService.instance.deepLinkData;
    if (deepLinkData != null) {
      for (final entry in deepLinkData.entries) {
        body.putIfAbsent(entry.key, () => entry.value);
      }
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final afId = await AppsFlyerService.instance.getAppsFlyerId();
    final locale = PlatformDispatcher.instance.locale;
    final localeValue = locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';

    body['af_id'] = afId ?? '';
    body['bundle_id'] = packageInfo.packageName;
    body['locale'] = localeValue;

    if (Platform.isIOS) {
      body['os'] = 'iOS';
      body['store_id'] = AppAttributionConfig.iosStoreId;
    } else if (Platform.isAndroid) {
      body['os'] = 'Android';
      body['store_id'] = packageInfo.packageName;
    }

    final firebase = FirebaseService.instance;
    if (firebase.isInitialized) {
      await firebase.refreshToken();
      final pushToken = firebase.pushToken;
      final projectId = firebase.firebaseProjectId;
      if (pushToken != null && pushToken.isNotEmpty) {
        body['push_token'] = pushToken;
      }
      if (projectId != null && projectId.isNotEmpty) {
        body['firebase_project_id'] = projectId;
      }
    }

    return body;
  }
}
