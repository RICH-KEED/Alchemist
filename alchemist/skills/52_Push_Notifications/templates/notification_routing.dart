// ignore_for_file: public_member_api_docs, sort_constructors_first
// Notification Routing — copy this file into lib/core/notification/ and adjust
// package imports.
//
// Covers:
//   1. NotificationRoute sealed class (all known notification types)
//   2. Payload parser: NotificationPayload → NotificationRoute
//   3. NotificationRouter service that maps routes → go_router locations
//   4. Integration with main.dart for initial + opened-message handling

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';

// Reuse the model from fcm_setup.dart (in real code both live in the same package)
import 'fcm_setup.dart';

// ---------------------------------------------------------------------------
// 1. NotificationRoute — a sealed hierarchy for every known notification type
// ---------------------------------------------------------------------------

/// Typed representation of where a notification tap should navigate.
///
/// Each variant carries the params needed to build a go_router location.
/// Use exhaustive switch in routing logic to guarantee all cases are handled.
sealed class NotificationRoute {
  const NotificationRoute();

  /// Parse a [NotificationPayload] into the correct [NotificationRoute] variant.
  ///
  /// Returns `null` when the route type is unknown (graceful no-op).
  static NotificationRoute? parse(NotificationPayload payload) {
    final data = payload.payload;
    return switch (payload.routeType) {
      'chat_message' => ChatMessage(
        conversationId: data['conversation_id'] ?? '',
      ),
      'promo' => Promo(
        promoId: data['promo_id'] ?? '',
      ),
      'order_update' => OrderUpdate(
        orderId: data['order_id'] ?? '',
      ),
      'friend_request' => FriendRequest(
        userId: data['user_id'] ?? '',
      ),
      'system_alert' => const SystemAlert(),
      _ => null, // unknown route type — no navigation
    };
  }

  /// Build the go_router location string for this route.
  String toLocation();

  /// Whether this route should replace the current entry (go) or push.
  /// Notification taps typically use `go` for the initial navigation and
  /// `push` for subsequent taps while the app is in the foreground.
  bool get shouldReplace => true;
}

class ChatMessage extends NotificationRoute {
  const ChatMessage({required this.conversationId});
  final String conversationId;

  @override
  String toLocation() => '/chat/$conversationId';
}

class Promo extends NotificationRoute {
  const Promo({required this.promoId});
  final String promoId;

  @override
  String toLocation() => '/promo/$promoId';
}

class OrderUpdate extends NotificationRoute {
  const OrderUpdate({required this.orderId});
  final String orderId;

  @override
  String toLocation() => '/orders/$orderId';
}

class FriendRequest extends NotificationRoute {
  const FriendRequest({required this.userId});
  final String userId;

  @override
  String toLocation() => '/profile/$userId';
}

class SystemAlert extends NotificationRoute {
  const SystemAlert();

  @override
  String toLocation() => '/alerts';
}

// ---------------------------------------------------------------------------
// 2. NotificationRouter — bridges notification taps to go_router
// ---------------------------------------------------------------------------

/// Hooks notification tap events into [GoRouter] navigation.
///
/// Usage in `main.dart`:
/// ```dart
/// final router = NotificationRouter();
/// await router.handleInitialMessage(); // cold-start tap
///
/// // Later, after building the widget tree:
/// final goRouter = GoRouter(
///   redirect: router.redirectGuard,
///   routes: [...],
/// );
/// router.goRouter = goRouter;
/// ```
class NotificationRouter {
  NotificationRouter();

  /// Set after [GoRouter] is created. We use a nullable field because the
  /// router is created in the widget tree, but we may need to process an
  /// initial message before the first frame.
  GoRouter? _goRouter;
  set goRouter(GoRouter router) => _goRouter = router;

  /// A route to navigate to once the GoRouter is available (deferred cold-start).
  NotificationRoute? _pendingRoute;

  // ---- cold start: getInitialMessage ----------------------------

  /// Call this once in `main()`, after `Firebase.initializeApp`.
  ///
  /// If a notification launched the app from terminated state, store the
  /// parsed route. The actual navigation is deferred until the first frame
  /// so the widget tree and GoRouter exist.
  Future<void> handleInitialMessage() async {
    final initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage == null) return;

    final payload = NotificationPayload.fromRemoteMessage(initialMessage);
    final route = NotificationRoute.parse(payload);
    if (route == null) {
      debugPrint(
        '[NotificationRouter] Unknown initial route type: ${payload.routeType}',
      );
      return;
    }

    // Defer navigation to first post-frame callback.
    _pendingRoute = route;
  }

  /// Call this inside `WidgetsBinding.instance.addPostFrameCallback`, after
  /// the first frame is rendered. This executes the deferred cold-start
  /// navigation.
  void runDeferredNavigation() {
    final route = _pendingRoute;
    if (route == null) return;
    _pendingRoute = null;

    final location = route.toLocation();
    debugPrint(
      '[NotificationRouter] Deferred navigation to: $location',
    );
    _goRouter?.go(location);
  }

  // ---- background tap: onMessageOpenedApp -----------------------

  /// Call this from the [NotificationService.onNotificationTap] stream
  /// (or from [FirebaseMessaging.onMessageOpenedApp] directly).
  void handleOpenedMessage(NotificationPayload payload) {
    final route = NotificationRoute.parse(payload);
    if (route == null) {
      debugPrint(
        '[NotificationRouter] Unknown opened route type: ${payload.routeType}',
      );
      return;
    }

    final location = route.toLocation();
    debugPrint('[NotificationRouter] Navigating to: $location');

    if (route.shouldReplace) {
      _goRouter?.go(location);
    } else {
      _goRouter?.push(location);
    }
  }

  /// go_router redirect guard: if a cold-start notification is pending and
  /// someone navigates to `/`, intercept and redirect to the notification
  /// target instead.
  String? redirectGuard(BuildContext context, GoRouterState state) {
    if (_pendingRoute == null || state.matchedLocation != '/') return null;

    final location = _pendingRoute!.toLocation();
    _pendingRoute = null;
    debugPrint(
      '[NotificationRouter] Redirect guard: / → $location',
    );
    return location;
  }
}

// ---------------------------------------------------------------------------
// 3. Integration guide (add to main.dart)
// ---------------------------------------------------------------------------
//
// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(options: ...);
//
//   // --- Notification setup (from fcm_setup.dart) ---
//   final localNotifications = FlutterLocalNotificationsPlugin();
//   await localNotifications.initialize(...);
//
//   final notificationService = NotificationService(
//     messaging: FirebaseMessaging.instance,
//     localNotifications: localNotifications,
//   );
//   await notificationService.initialize();
//
//   // --- Router (with cold-start handling) ---
//   final notificationRouter = NotificationRouter();
//   await notificationRouter.handleInitialMessage();
//
//   final goRouter = GoRouter(
//     initialLocation: '/',
//     redirect: notificationRouter.redirectGuard,
//     routes: [
//       GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
//       GoRoute(path: '/chat/:conversationId', builder: (_, state) =>
//           ChatScreen(conversationId: state.pathParameters['conversationId']!)),
//       GoRoute(path: '/promo/:promoId', builder: (_, state) =>
//           PromoScreen(promoId: state.pathParameters['promoId']!)),
//       GoRoute(path: '/orders/:orderId', builder: (_, state) =>
//           OrderDetailScreen(orderId: state.pathParameters['orderId']!)),
//       GoRoute(path: '/profile/:userId', builder: (_, state) =>
//           ProfileScreen(userId: state.pathParameters['userId']!)),
//       GoRoute(path: '/alerts', builder: (_, __) => const AlertsScreen()),
//     ],
//   );
//   notificationRouter.goRouter = goRouter;
//
//   // --- Wire background taps ---
//   notificationService.onNotificationTap.listen(
//     notificationRouter.handleOpenedMessage,
//   );
//
//   runApp(ProviderScope(
//     overrides: [
//       notificationServiceProvider.overrideWithValue(notificationService),
//     ],
//     child: App(goRouter: goRouter),
//   ));
//
//   // --- Deferred cold-start navigation ---
//   WidgetsBinding.instance.addPostFrameCallback((_) {
//     notificationRouter.runDeferredNavigation();
//   });
// }
