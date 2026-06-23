// ignore_for_file: public_member_api_docs, sort_constructors_first
// FCM Setup — copy this file into lib/core/notification/ and adjust package imports.
//
// Covers:
//   1. Firebase initialization + FCM instance wiring
//   2. Android 13+ POST_NOTIFICATIONS permission request
//   3. Notification channel creation (Android 8+)
//   4. Foreground / background / terminated handlers
//   5. Token refresh listener
//   6. Freezed RemoteMessagePayload model

import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'fcm_setup.freezed.dart';
part 'fcm_setup.g.dart';

// ---------------------------------------------------------------------------
// 1. Freezed payload model — maps from RemoteMessage to a type-safe domain object
// ---------------------------------------------------------------------------

@freezed
class NotificationPayload with _$NotificationPayload {
  const factory NotificationPayload({
    required String notificationId,
    required String title,
    required String body,
    required String routeType,
    required Map<String, String> payload,
    String? imageUrl,
    String? channelId,
  }) = _NotificationPayload;

  const NotificationPayload._();

  /// Parse a [RemoteMessage] into a typed [NotificationPayload].
  ///
  /// Prefers `message.data` for routing fields (works in all app states);
  /// falls back to `message.notification` for display text only.
  factory NotificationPayload.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    return NotificationPayload(
      notificationId: data['notification_id'] ??
          message.messageId ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: data['title'] ?? message.notification?.title ?? '',
      body: data['body'] ?? message.notification?.body ?? '',
      routeType: data['route'] ?? 'unknown',
      payload: data,
      imageUrl: data['image_url'],
      channelId:
          message.notification?.android?.channelId ?? data['android_channel_id'],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Top-level background handler (runs in a separate isolate)
// ---------------------------------------------------------------------------

/// Must be a top-level function annotated with `vm:entry-point` so the engine
/// can find it in a fresh isolate. No BuildContext, no Riverpod, no UI access.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Re-initialize Firebase in this isolate so plugins are registered.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Show a local notification from the background isolate.
  final payload = NotificationPayload.fromRemoteMessage(message);
  await _showLocalNotificationFromIsolate(payload);
}

/// Shows a local notification without BuildContext (called from background isolate).
Future<void> _showLocalNotificationFromIsolate(
  NotificationPayload payload,
) async {
  // flutter_local_notifications must be initialized in the background isolate.
  // If you use a separate plugin instance, create it here.
  // For simplicity, this is a placeholder — real implementation would create a
  // FlutterLocalNotificationsPlugin with the same settings as the main isolate.
}

// ---------------------------------------------------------------------------
// 3. NotificationService — Riverpod provider wrapping FirebaseMessaging
// ---------------------------------------------------------------------------

/// The [NotificationService] wraps [FirebaseMessaging] and exposes a typed API
/// for the rest of the app. Create it once in `main.dart` via its provider.
class NotificationService {
  NotificationService({
    required this.messaging,
    required this.localNotifications,
  });

  final FirebaseMessaging messaging;
  final FlutterLocalNotificationsPlugin localNotifications;

  /// Call this once after [Firebase.initializeApp] completes.
  Future<void> initialize() async {
    // 3a. Android notification channel (idempotent, safe to call on every launch)
    if (Platform.isAndroid) {
      await _createDefaultChannel(localNotifications);
    }

    // 3b. Request Android 13+ runtime notification permission
    await _requestPermission();

    // 3c. Register foreground handler
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 3d. Register background/terminated tap handler
    // This fires when the user taps a notification while the app is backgrounded.
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // 3e. Token refresh — send new token to your backend
    messaging.onTokenRefresh.listen(_onTokenRefresh);

    // 3f. Set the isolate-level background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // ---- permission ------------------------------------------------

  Future<void> _requestPermission() async {
    if (!Platform.isAndroid) return; // iOS delegates to OS prompt on registration

    // Android 13+ needs POST_NOTIFICATIONS
    final status = await Permission.notification.status;

    if (status.isGranted) return;

    if (status.isDenied) {
      // Request directly; rationale dialog should be shown by the caller
      // before calling request() if the user already denied once.
      final result = await Permission.notification.request();
      if (result.isGranted || result.isLimited) return;
    }

    if (status.isPermanentlyDenied) {
      // Can't request again — guide user to system settings.
      // The caller (UI layer) should detect this and call openAppSettings().
      debugPrint(
        '[NotificationService] Permission permanently denied. '
        'Direct user to system settings.',
      );
    }
  }

  /// Public utility: returns true if the app can show notifications.
  Future<bool> get hasPermission async {
    if (!Platform.isAndroid) return true;
    return await Permission.notification.isGranted;
  }

  // ---- notification channel (Android 8+) ------------------------

  Future<void> _createDefaultChannel(
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    const channel = AndroidNotificationChannel(
      'default_channel', // id — use a constant, referenced in server payloads
      'General Notifications', // user-visible name in system settings
      description: 'Standard app notifications including chat, promos, and alerts',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ---- foreground message ---------------------------------------

  void _onForegroundMessage(RemoteMessage message) {
    final payload = NotificationPayload.fromRemoteMessage(message);

    // Option A: Show a local notification (acts like a background message)
    // Option B: Show an in-app banner/snackbar via a Riverpod notifier
    // Option C: Both — local notification + update in-app unread count
    //
    // Example for Option A:
    _showLocalNotification(payload);

    debugPrint(
      '[NotificationService] Foreground message: ${payload.routeType} '
      'id=${payload.notificationId}',
    );
  }

  // ---- background / terminated tap ------------------------------

  void _onMessageOpenedApp(RemoteMessage message) {
    final payload = NotificationPayload.fromRemoteMessage(message);
    // Navigation is handled by NotificationRouter — call it via the provider
    // or a global delegate. See notification_routing.dart.
    debugPrint(
      '[NotificationService] Message opened from background: '
      '${payload.routeType}',
    );
    _openedMessageController.add(payload);
  }

  /// Stream of payloads from notification taps (background → foreground).
  /// UI layer listens to this to trigger navigation.
  final _openedMessageController =
      StreamController<NotificationPayload>.broadcast();
  Stream<NotificationPayload> get onNotificationTap =>
      _openedMessageController.stream;

  // ---- token management -----------------------------------------

  void _onTokenRefresh(String newToken) {
    debugPrint('[NotificationService] FCM token refreshed: $newToken');
    // TODO: POST this token to your backend /push-register endpoint.
    // Your backend must store (userId, fcmToken, platform, lastSeen).
  }

  /// Returns the current FCM registration token.
  /// Call after [initialize] and permission grant.
  Future<String?> getToken() async {
    if (!Platform.isAndroid || await hasPermission) {
      return messaging.getToken();
    }
    return null;
  }

  // ---- local notification helper --------------------------------

  Future<void> _showLocalNotification(NotificationPayload payload) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'General Notifications',
      channelDescription: 'Standard app notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher', // must exist in android/app/src/main/res
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await localNotifications.show(
      payload.notificationId.hashCode, // unique int ID per notification
      payload.title,
      payload.body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload.routeType, // passed through to onSelectNotification
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Riverpod provider
// ---------------------------------------------------------------------------

@riverpod
NotificationService notificationService(NotificationServiceRef ref) {
  // In tests, override this provider with a fake.
  throw UnimplementedError('Override this provider in main.dart bootstrap');
}

// ---------------------------------------------------------------------------
// 5. Bootstrap in main.dart
// ---------------------------------------------------------------------------
//
// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
//
//   final localNotifications = FlutterLocalNotificationsPlugin();
//   // Initialize local notifications for the main isolate
//   const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
//   const iosInit = DarwinInitializationSettings();
//   await localNotifications.initialize(
//     const InitializationSettings(android: androidInit, iOS: iosInit),
//     onDidReceiveNotificationResponse: _onNotificationResponse,
//   );
//
//   final service = NotificationService(
//     messaging: FirebaseMessaging.instance,
//     localNotifications: localNotifications,
//   );
//   await service.initialize();
//
//   final token = await service.getToken();
//   debugPrint('FCM Token: $token');
//   // POST token to backend
//
//   runApp(
//     ProviderScope(
//       overrides: [
//         notificationServiceProvider.overrideWithValue(service),
//       ],
//       child: const App(),
//     ),
//   );
// }
//
// void _onNotificationResponse(NotificationResponse response) {
//   // Route to screen based on response.payload (which we set to routeType)
//   // See notification_routing.dart for the NotificationRouter integration.
// }
