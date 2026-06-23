# Leak Pattern Catalog — State Leak Auditor (Skill #40)

Reference of every leak pattern the scanner detects, with the regex signature, why it leaks,
a before/after fix snippet, severity, and any Riverpod-specific notes.

House style: [`../../../references/CONVENTIONS.md`](../../../references/CONVENTIONS.md).

---

## 1. AnimationController without dispose

- **Category:** `animation-controller-no-dispose`
- **Severity:** critical
- **Regex signature:** `AnimationController(` appears in the file; `.dispose()` does not appear
- **Confidence boosters:** Instance stored in a `late final` field of a `State` subclass

### Why it leaks

`AnimationController` creates a `Ticker` that registers with the `SchedulerBinding`. The ticker
fires every frame until `.dispose()` is called. If the owning widget is removed from the tree
without calling dispose, the ticker keeps running — draining CPU, blocking GC of the widget's
entire subtree, and potentially calling `setState` on an unmounted widget (causing a framework
exception).

### Before

```dart
class _PulseWidgetState extends State<PulseWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this, duration: const Duration(seconds: 2),
  );

  @override
  void initState() {
    super.initState();
    _pulse.repeat();
  }

  // BUG: no dispose() override — ticker runs forever
}
```

### After

```dart
class _PulseWidgetState extends State<PulseWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this, duration: const Duration(seconds: 2),
  );

  @override
  void initState() {
    super.initState();
    _pulse.repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }
}
```

### Riverpod note

AnimationController does not belong in a Riverpod provider (it requires a `TickerProvider` /
`vsync`). Keep it in widget state and dispose it in `State.dispose()`.

---

## 2. StreamSubscription without cancel

- **Category:** `stream-subscription-no-cancel`
- **Severity:** critical
- **Regex signature:** `.listen(` appears in the file; `.cancel()` does not appear
- **Confidence boosters:** `.listen(` result is assigned to a field (e.g. `_sub =`)

### Why it leaks

`Stream.listen()` returns a `StreamSubscription`. Until `.cancel()` is called, the subscription
holds a strong reference to the callback closure, which in turn holds strong references to
everything the closure captures. If the stream is long-lived (e.g. a `BehaviorSubject`, a
`ChangeNotifier` stream, or a Firebase real-time stream), the callback runs indefinitely — even
after the widget or provider that created it is dead. This is a **dangling listener** leak.

### Before

```dart
class _ChatWidgetState extends State<ChatWidget> {
  late final StreamSubscription _messagesSub;

  @override
  void initState() {
    super.initState();
    _messagesSub = messageStream.listen((msg) {
      setState(() { _messages.add(msg); });
    });
    // BUG: never cancelled
  }
}
```

### After

```dart
class _ChatWidgetState extends State<ChatWidget> {
  late final StreamSubscription _messagesSub;

  @override
  void initState() {
    super.initState();
    _messagesSub = messageStream.listen((msg) {
      setState(() { _messages.add(msg); });
    });
  }

  @override
  void dispose() {
    _messagesSub.cancel();
    super.dispose();
  }
}
```

### Riverpod alternative

Use `ref.onDispose(() => sub.cancel())` in a `Notifier`, or better — use `ref.watch` on a
`StreamProvider` which auto-cancels when no longer watched:

```dart
@riverpod
Stream<List<Message>> messages(MessagesRef ref) {
  return messageService.stream; // auto-cancelled by Riverpod
}
```

---

## 3. TextEditingController without dispose

- **Category:** `text-editing-controller-no-dispose`
- **Severity:** critical
- **Regex signature:** `TextEditingController(` appears; `.dispose()` does not appear in file

### Why it leaks

`TextEditingController` extends `ValueNotifier` and holds a `TextEditingValue`. It also
registers with the framework's focus system when attached to a `TextField`. If not disposed, the
notifier keeps listeners alive and the focus attachment persists — a **memory leak** and
potential **focus-traversal bug**.

### Before

```dart
class _FormWidgetState extends State<FormWidget> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  // BUG: neither disposed
}
```

### After

```dart
class _FormWidgetState extends State<FormWidget> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
```

---

## 4. FocusNode without dispose

- **Category:** `focus-node-no-dispose`
- **Severity:** high
- **Regex signature:** `FocusNode(` appears; `.dispose()` does not appear in file

### Why it leaks

`FocusNode` participates in the Flutter focus tree. An undisposed `FocusNode` remains in the
focus traversal order, meaning the user can tab to a widget that no longer exists — a
**focus-traversal leak** that also pins the node's memory.

### Before

```dart
class _SearchWidgetState extends State<SearchWidget> {
  final FocusNode _searchFocus = FocusNode();
  // BUG: never disposed
}
```

### After

```dart
class _SearchWidgetState extends State<SearchWidget> {
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }
}
```

---

## 5. ScrollController without dispose

- **Category:** `scroll-controller-no-dispose`
- **Severity:** high
- **Regex signature:** `ScrollController(` appears; `.dispose()` does not appear in file

### Why it leaks

`ScrollController` stores a `ScrollPosition` that tracks pixels, viewport dimensions, and
attached listeners. If not disposed, scroll listeners fire for a widget that is no longer in
the tree — a **rebuild leak** (listeners trigger rebuilds on dead state) plus a memory leak.

### Before

```dart
class _FeedWidgetState extends State<FeedWidget> {
  final ScrollController _scrollController = ScrollController();
  // BUG: never disposed
}
```

### After

```dart
class _FeedWidgetState extends State<FeedWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
```

---

## 6. PageController without dispose

- **Category:** `page-controller-no-dispose`
- **Severity:** high
- **Regex signature:** `PageController(` appears; `.dispose()` does not appear in file

### Why it leaks

Same family as `ScrollController` — holds a `ScrollPosition` plus page-viewport state. An
undisposed `PageController` keeps page-change listeners registered and can cause
**setState-on-unmounted** exceptions when a swipe triggers a page-change callback on a dead
widget.

---

## 7. VideoPlayerController without dispose

- **Category:** `video-player-controller-no-dispose`
- **Severity:** critical
- **Regex signature:** `VideoPlayerController\.(file|network|asset)(` appears; `.dispose()` does not appear in file

### Why it leaks

`VideoPlayerController` from the `video_player` package holds a **platform-channel connection**
to a native media player. Until `.dispose()` is called, the native player holds audio focus,
hardware codec resources, and possibly a surface texture. This is the most expensive leak in the
catalog — it can cause audio-session conflicts, GPU texture exhaustion, and battery drain.

### Before / After

Same pattern as AnimationController: create in `initState`, dispose in `dispose()`.

```dart
@override
void dispose() {
  _videoController.dispose();
  super.dispose();
}
```

---

## 8. Timer without cancel

- **Category:** `timer-no-cancel`
- **Severity:** high
- **Regex signature:** `Timer(` or `Timer.periodic(` appears; `.cancel()` does not appear in file

### Why it leaks

A `Timer` holds a callback scheduled for future execution. If the owning widget or provider is
destroyed before the timer fires, the callback still runs — potentially calling `setState` on an
unmounted widget or mutating state in a disposed provider. Periodic timers that are never
cancelled run forever, causing a **callback leak** and unintended background work.

### Before

```dart
@override
void initState() {
  super.initState();
  _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
    _fetchUpdates();
  });
  // BUG: never cancelled
}
```

### After

```dart
@override
void initState() {
  super.initState();
  _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
    _fetchUpdates();
  });
}

@override
void dispose() {
  _pollTimer.cancel();
  super.dispose();
}
```

### Riverpod alternative

Use `ref.onDispose(() => timer.cancel())` or — even cleaner — use Riverpod's built-in
`ref.keepAlive()` / `ref.onCancel()` lifecycle:

```dart
@Riverpod(keepAlive: false)
class PollingNotifier extends _$PollingNotifier {
  Timer? _timer;

  @override
  FutureOr<void> build() {
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _poll());
    ref.onDispose(() => _timer?.cancel());
  }
}
```

---

## 9. Riverpod provider missing autoDispose

- **Category:** `riverpod-no-autodispose`
- **Severity:** medium
- **Regex signature:** `@riverpod` or `@Riverpod(` annotation present; neither `autoDispose` nor `keepAlive: false` appears in the immediate declaration context

### Why it leaks

Without `autoDispose` (or `keepAlive: false` in codegen syntax), a Riverpod provider retains
state for the **full lifetime of `ProviderScope`** — typically the entire app session. If the
provider holds large data (a fetched list, a loaded image, a WebSocket connection), that memory
is never released even when no widget watches the provider. Over many navigations this becomes a
**rebuild leak** — stale state triggers unnecessary rebuilds when the provider is watched again.

### Before

```dart
@riverpod
class SearchResults extends _$SearchResults {
  @override
  Future<List<Item>> build(String query) async {
    return _repo.search(query);
  }
}
```

### After

```dart
@Riverpod(keepAlive: false)
class SearchResults extends _$SearchResults {
  @override
  Future<List<Item>> build(String query) async {
    return _repo.search(query);
  }
}
```

### Function-provider syntax

```dart
// BEFORE
@riverpod
Future<List<Item>> searchResults(SearchResultsRef ref, String query) async { ... }

// AFTER
@riverpod
Future<List<Item>> autoDisposeSearchResults(AutoDisposeSearchResultsRef ref, String query) async { ... }
```

### When it is NOT a leak

A small number of providers legitimately need to live for the app session: auth state, theme
preferences, feature flags. Mark these as **reviewed + intentional** in the scan report rather
than suppressing the check globally.

---

## Severity reference

| Severity | Definition | Example |
|---|---|---|
| **critical** | Deterministic resource leak; ship-stopper | AnimationController, VideoPlayerController, TextEditingController without dispose |
| **high** | High-confidence leak; listener or background work persists | FocusNode, Timer, ScrollController, PageController, StreamSubscription without teardown |
| **medium** | Potential leak; needs human triage | Riverpod provider without autoDispose (may be intentional) |
| **low** | Cosmetic or low-confidence | Controller created but possibly disposed through an indirect path |
