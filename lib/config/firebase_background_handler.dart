import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

const String _androidNotificationChannelId = 'high_importance_channel_v3';
const String _androidNotificationChannelName = 'High importance notifications';
const String _androidNotificationChannelDescription =
    'Notifications with offers and app updates';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM BACKGROUND: id=${message.messageId} data=${message.data}');

  if (message.notification != null) {
    return;
  }

  await _showDataOnlyBackgroundNotification(message);
}

Future<void> _showDataOnlyBackgroundNotification(RemoteMessage message) async {
  try {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(settings: settings);
    await _createAndroidNotificationChannel(plugin);

    final title = _stringValue(message.data, const ['title']) ?? 'Egg Escape';
    final body = _stringValue(message.data, const ['body', 'message']) ?? '';
    final imageUrl = _stringValue(message.data, const [
      'image',
      'imageUrl',
      'picture',
      'big_picture',
      'bigPicture',
    ]);
    final style = await _bigPictureStyle(imageUrl, title, body);
    final payload = _stringValue(message.data, const ['url', 'link']);

    final androidDetails = AndroidNotificationDetails(
      _androidNotificationChannelId,
      _androidNotificationChannelName,
      channelDescription: _androidNotificationChannelDescription,
      icon: 'ic_notification',
      largeIcon: const DrawableResourceAndroidBitmap('ic_notification_large'),
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(<int>[0, 250, 120, 250]),
      styleInformation: style,
      channelShowBadge: true,
      category: AndroidNotificationCategory.message,
      ticker: title,
      visibility: NotificationVisibility.public,
    );

    await plugin.show(
      id: message.messageId?.hashCode ?? Random().nextInt(1 << 31),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: payload,
    );

    debugPrint('FCM BACKGROUND DATA NOTIFICATION SHOWN');
  } catch (error) {
    debugPrint('FCM BACKGROUND DATA NOTIFICATION FAILED: $error');
  }
}

Future<void> _createAndroidNotificationChannel(
  FlutterLocalNotificationsPlugin plugin,
) async {
  final androidPlugin = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (androidPlugin == null) {
    debugPrint('FCM BACKGROUND CHANNEL: Android plugin is null');
    return;
  }

  await androidPlugin.createNotificationChannel(
    AndroidNotificationChannel(
      _androidNotificationChannelId,
      _androidNotificationChannelName,
      description: _androidNotificationChannelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(<int>[0, 250, 120, 250]),
      showBadge: true,
    ),
  );
}

Future<StyleInformation?> _bigPictureStyle(
  String? imageUrl,
  String title,
  String body,
) async {
  if (imageUrl == null || imageUrl.isEmpty) {
    return null;
  }

  final bytes = await _downloadNotificationImage(imageUrl);
  if (bytes == null || bytes.isEmpty) {
    return null;
  }

  return BigPictureStyleInformation(
    ByteArrayAndroidBitmap(bytes),
    contentTitle: title,
    summaryText: body,
  );
}

Future<Uint8List?> _downloadNotificationImage(String imageUrl) async {
  try {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null || !uri.hasScheme) {
      return null;
    }

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint(
        'FCM BACKGROUND IMAGE FAILED: status=${response.statusCode} '
        'url=$imageUrl',
      );
      return null;
    }

    return response.bodyBytes;
  } catch (error) {
    debugPrint('FCM BACKGROUND IMAGE DOWNLOAD FAILED: $error');
    return null;
  }
}

String? _stringValue(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
  }

  return null;
}
