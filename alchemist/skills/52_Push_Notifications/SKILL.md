---
name: Push Notifications
description: End-to-end Firebase Cloud Messaging in Flutter — Android 13+ runtime permission, typed freezed payload models, foreground/background/terminated handlers, deep-link routing from notification tap. Use when adding push notifications, wiring FCM, handling notification taps for navigation, or setting up Android notification channels.
when_to_use: Trigger on "add push notifications", "wire up FCM", "notification tap opens a screen", "Android notification permission", "handle firebase message in background", "deep link from notification", "notification routing", or any request to receive and route remote push messages in a Flutter app.
---

# Push Notifications (Roadmap #52)

Firebase Cloud Messaging end-to-end in Flutter: setup, Android 13+ runtime permission,
typed payload models, three-state message handling, and deep-link routing from notification
tap through `go_router`. House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).

---

## 1. Setup checklist

| Step | Action | Validation |
|---|---|---|
| 1 | Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com) | Project exists, billing plan set (Blaze for Functions optional) |
| 2 | Add Android app with `applicationId` from `app/build.gradle.kts` | `google-services.json` downloaded |
| 3 | Place `google-services.json` in `android/app/` | File present; **never commit it** — add to `.gitignore` |
| 4 | Apply `com.google.gms.google-services` plugin in `android/app/build.gradle.kts` | Plugin line present |
| 5 | Add `firebase_core` + `firebase_messaging` to `pubspec.yaml`, run `flutter pub get` | Dependencies resolve |
| 6 | Initialize Firebase in `main.dart` before `runApp` | `WidgetsFlutterBinding.ensureInitialized(); await Firebase.initializeApp(options: ...);` |
| 7 | Declare `POST_NOTIFICATIONS` permission in `AndroidManifest.xml` (Android 13+) | `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` |
| 8 | **Request** the permission at runtime before subscribing to topics or expecting delivery (§5) | `PermissionStatus.granted` returned |

---

## 2. Payload model (freezed)

Messages arrive as `RemoteMessage`. Map them into a **typed domain model** so the rest of the
app never touches `RemoteMessage` directly.

```dart
// The raw FCM envelope — map this in the data layer
RemoteMessage
├── notification?          // Visible notification payload (title, body)
│   └── android?           // Android-specific: channelId, icon, color, sound
├── data                   // Custom key-value payload (the routing intent lives here)
├── messageId / sentTime / ttl / from / collapseKey
```

Your freezed model separates **display info** from **routing intent**:

| Field | Source | Purpose |
|---|---|---|
| `notificationId` | `message.data['notification_id']` | Stable identifier for dedup / "mark read" |
| `title` | `message.notification?.title ?? message.data['title']` | In-app banner text |
| `body` | `message.notification?.body ?? message.data['body']` | In-app banner detail |
| `routeType` | `message.data['route']` | Enum string that maps to a `NotificationRoute` variant |
| `payload` | `message.data` (full map) | Raw params parsed by the route-specific parser |
| `imageUrl` | `message.data['image_url']` | Optional rich-media attachment |

See `templates/fcm_setup.dart` for the complete freezed model and `fromRemoteMessage` factory.

**Data vs notification payload:**

- **Notification payload** (`message.notification`) — what the OS tray shows. FCM auto-displays
  it when the app is in the **background**. You only need it in the foreground for in-app banners.
- **Data payload** (`message.data`) — custom key-value map. This is where you put the **routing
  intent** (`route`, `conversation_id`, `promo_id`, etc.). On Android, a data-only message will
  **always** be delivered to `onMessage` (foreground) or `onBackgroundMessage` (background)
  regardless of app state — use this for silent routing updates.

---

## 3. Three app states

FCM delivers differently depending on whether the app is foreground, background, or terminated.
Each state needs its own handler.

| App state | FCM callback | Behavior on Android | What you do |
|---|---|---|---|
| **Foreground** | `FirebaseMessaging.onMessage` | OS **does not** show a notification automatically | You show a local notification (or in-app banner/popup) |
| **Background** | `FirebaseMessaging.onMessageOpenedApp` | OS shows the tray notification; tap opens app + delivers here | Parse route → navigate via `go_router` |
| **Terminated** | `getInitialMessage()` (called once after `Firebase.initializeApp`) | OS shows tray notification; tap cold-starts app | Parse route → defer navigation until router is ready |
| **Background handler** | `FirebaseMessaging.onBackgroundMessage` (top-level `@pragma('vm:entry-point')`) | Runs in a **separate isolate** with no UI access | Show a local notification; store data for UI pickup; no `BuildContext` |

Critical: `onBackgroundMessage` **must** be a top-level or static function annotated with
`@pragma('vm:entry-point')`. It runs in a fresh isolate — no Riverpod, no `BuildContext`,
no shared memory with the main isolate. Use `flutter_local_notifications` or write to local
storage; push updates to the UI isolate via `IsolateNameServer` when needed.

---

## 4. Deep-link routing

The routing flow from notification tap to target screen:

```
Notification tap
    → NotificationPayload.fromRemoteMessage(message)
    → NotificationRoute.parse(payload)
    → NotificationRouter.routeFor(routeType) → String location
    → go_router.go(location) or go_router.push(location)
```

**Route mapping table** (example — extend per app's notification types):

| Data `route` value | `NotificationRoute` variant | go_router location |
|---|---|---|
| `chat_message` | `chatMessage(conversationId)` | `/chat/:conversationId` |
| `promo` | `promo(promoId)` | `/promo/:promoId` |
| `order_update` | `orderUpdate(orderId)` | `/orders/:orderId` |
| `friend_request` | `friendRequest(userId)` | `/profile/:userId` |
| `system_alert` | `systemAlert` | `/alerts` |

The `NotificationRouter` from `templates/notification_routing.dart` is a service class that
holds a reference to a `GoRouter` delegate (set after router creation) and exposes
`handleInitialMessage()` and `handleOpenedMessage()` methods to call from `main.dart`.

**Deferred navigation for cold start:** When `getInitialMessage()` returns a message before
the first frame, store the parsed route and call `go_router.go(location)` inside
`WidgetsBinding.instance.addPostFrameCallback` so the widget tree and `GoRouter` are wired.

---

## 5. Permission flow (Android 13+)

Android 13+ requires the `POST_NOTIFICATIONS` runtime permission. The flow:

```
1. Check current status         → Permission.notifications.status
2. If denied                    → request() with rationale dialog (explain *why*)
3. If permanentlyDenied         → openAppSettings() + in-app fallback
4. If granted                   → proceed to getToken() / subscribeToTopic()
```

**Rationale dialog:** show a Material 3 `AlertDialog` explaining the concrete value (e.g.,
"Get notified when your order ships") before calling `request()`. Users who see a rationale
grant permission at ~2x the rate of users who see the bare OS prompt.

**Fallback when permanently denied:** do not degrade into a dead-end state. Offer an in-app
notifications hub (`/notifications`), a "Check manually" banner on affected screens, and
periodic gentle re-prompts after a feature-visible delay (e.g., after a user places an order).

**iOS note:** iOS does not require runtime notification permission (it delegates to the OS
dialog on first registration). The `firebase_messaging` APNs entitlement setup is still
required via Xcode.

---

## 6. Common pitfalls

| Pitfall | Why it happens | Fix |
|---|---|---|
| **Stale FCM token** | Token regenerates on app reinstall, data clear, or device restore | Listen to `onTokenRefresh`; send new token to backend on every refresh |
| **Missing channel (Android)** | Android 8+ requires notification channels; no channel = no sound or delivery | Call `createNotificationChannel()` once on startup (idempotent) |
| **Background handler crash** | `onBackgroundMessage` uses plugin APIs that need the Flutter engine | Initialize `firebase_core` inside the handler (plugin registration); don't call UI-only APIs |
| **iOS APNs certificate expired** | APNs key/cert has a yearly rotation cadence | Check Firebase console → Project settings → Cloud Messaging → APNs auth key |
| **Huawei devices no FCM** | Huawei phones (since 2019) lack Google Play Services | Consider HMS Push Kit as a fallback channel; or detect HMS and show an in-app notice |
| **Data-only message not delivered in background** | `priority` is `normal` (default) instead of `high` | Send with `priority: high` on the server side; this wakes the device |
| **Notification tap opens app but doesn't navigate** | Router not ready yet on cold start | Use `addPostFrameCallback` for deferred navigation (§4) |

---

## 7. Testing

**FCM test messages:**
Firebase Console → Cloud Messaging → Send your first campaign → Notification (not Data)
→ target the FCM token from `debugPrint(token)` in your dev build.

```bash
# Programmatic test via FCM HTTP v1 API (requires OAuth or server key)
curl -X POST "https://fcm.googleapis.com/v1/projects/<project-id>/messages:send" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "token": "<fcm-token>",
      "notification": {"title": "Test", "body": "Hello from curl"},
      "data": {"route": "promo", "promo_id": "42"}
    }
  }'
```

**Local notification testing:**
`flutter_local_notifications` can fire a scheduled notification that simulates a tap
without needing a server. The tap opens the same `onSelectNotification` callback you
wire in the router.

**Deep-link testing:**
```bash
# Android: test go_router deep links directly
adb shell am start -W -a android.intent.action.VIEW \
  -d "yourapp://chat/conv_123" com.yourcompany.yourapp
```

---

## 8. Template files

| Template | Purpose |
|---|---|
| [`templates/fcm_setup.dart`](templates/fcm_setup.dart) | Full FCM initialization, freezed payload model, permission flow, channel creation |
| [`templates/notification_routing.dart`](templates/notification_routing.dart) | `NotificationRoute` sealed class, parser, `NotificationRouter` service, go_router integration |

Both files are self-contained, import-complete Dart files. Copy into the appropriate
layer (`core/notification/` or `features/notification/data/`) and adjust package imports.
