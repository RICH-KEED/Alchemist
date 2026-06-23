---
name: Loading States
description: Render every async surface's four states — loading, data, empty, error — consistently and premium. Use when a screen fetches data, shows a spinner, "feels janky / blank / flickers", needs skeletons/shimmer, an empty state, a retry, pull-to-refresh, pagination, or optimistic updates. Produces a reusable AsyncValueView wrapper + skeleton, empty, and error widgets in core/widgets/.
when_to_use: Stage 16 of the pipeline. Trigger on "loading state", "shimmer/skeleton", "empty state", "no results screen", "spinner everywhere", "pull to refresh", "load more / pagination", "optimistic update", or any data surface that isn't yet handling all four states. For the error *types* themselves invoke 15; for the controller producing AsyncValue invoke 08.
---

# Loading States

Stage **16** of the [24-stage pipeline](../../references/PIPELINE.md). You make every async surface render its **four states** consistently and beautifully: **loading · data · empty · error**. This is core to "awesome UI" — placeholders should feel premium (shimmer that mirrors the layout, not spinners everywhere) and empty states should be helpful (cause + a primary action), never blank.

House style is law: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) §4 (widget hygiene) and §6 (state contract). Controllers (skill **08**) produce `AsyncValue<T>`; you consume it. Error *copy* comes from skill **15**'s `Failure` UX. Colors/sizes come from `Theme`/`AppTokens` (skill **04**) — never hardcode.

**Exit gate:** *all four async states on every data surface.*

---

## The Four-State Law

Every surface that loads data MUST handle all four — missing one is a bug, not a nicety:

| State | When | What the user sees |
|---|---|---|
| **Loading** | first load, no data yet | a **skeleton** of the final layout (or a spinner for tiny/indeterminate surfaces) |
| **Data** | success, non-empty | the real content |
| **Empty** | success, *zero items* | a helpful placeholder: cause + primary action |
| **Error** | failed | friendly copy (skill 15 mapping) + a retry |

The trap: most code handles loading/data/error and **forgets empty** — an empty list silently renders as a blank screen. Empty is a *distinct* successful state, not a sub-case of data. The `AsyncValueView` wrapper makes all four impossible to skip.

---

## The canonical pattern: `AsyncValueView<T>`

Don't hand-roll `.when` branches per screen — they drift and forget cases. Compose one wrapper that maps `AsyncValue<T>` → the four states, treating empty collections as their own state. See [`templates/async_value_view.dart`](templates/async_value_view.dart).

```dart
final state = ref.watch(productsControllerProvider);
return AsyncRefreshView(
  onRefresh: () => ref.refresh(productsControllerProvider.future),
  child: AsyncValueView<List<Product>>(
    value: state,
    isEmpty: (items) => items.isEmpty,
    onRetry: () => ref.invalidate(productsControllerProvider),
    loading: (_) => const ListSkeleton(),
    empty: (_) => EmptyState(
      icon: Icons.inventory_2_outlined,
      title: 'No products yet',
      message: 'Products you add will appear here.',
      actionLabel: 'Add product',
      onAction: () => context.push('/products/new'),
    ),
    data: (items) => ProductList(items: items),
  ),
);
```

State selection order inside the wrapper:
1. **error & no data** → error state (skill 15 UX + retry).
2. data present & `isEmpty(data)` → **empty** state.
3. data present → **data**.
4. loading → **loading** (skeleton/spinner).

`isEmpty` is optional — omit it for surfaces that can't be empty (a single object, a profile).

---

## Skeleton vs spinner — when to use which

Default to **skeletons**; reach for a spinner only in the narrow cases below.

| Use a **skeleton** when… | Use a **spinner** when… |
|---|---|
| the layout is known ahead of time (lists, cards, detail pages) | the surface is tiny (a button, an inline chip) |
| first load of a content-heavy screen | duration is genuinely indeterminate & shape unknown |
| you want zero layout shift when data lands | a brief in-place action (submitting a form) |

A premium app almost never shows a full-screen centered spinner for a screen that will become a list. The skeleton **mirrors the final layout** so nothing shifts when data arrives — that absence of jank is what reads as "polished". See [`templates/skeletons.dart`](templates/skeletons.dart): a dependency-free `Shimmer` (a `ShaderMask` sweep driven by an `AnimatedBuilder`, colored from `surfaceContainerHighest`), plus `ListTileSkeleton`, `CardSkeleton`, and `ListSkeleton`. The shimmer honors **reduce-motion** (`MediaQuery.disableAnimations`) by falling back to a still skeleton.

> Skeleton dimensions and spacing come from `AppTokens` (skill 04). The templates inline the numeric values with a comment; swap to `context.tokens.spacing.*` / `.radius.*` once the host app's theme is wired.

---

## Designing helpful empty states

An empty state is a successful result with zero items — treat it as a feature, not an afterthought. A good one answers **why is this empty** and **what do I do next**. See [`templates/empty_state.dart`](templates/empty_state.dart).

- **Illustration or icon** — never a bare line of text. A tonal icon badge is the minimum; a bespoke illustration for marquee surfaces.
- **Title** — short, human ("No saved recipes yet").
- **Message** — one sentence: the cause and/or the next step.
- **Primary action (CTA)** — a `FilledButton` that resolves the emptiness ("Add recipe", "Clear filters"). For a *search* empty state, the cause is the query, so the CTA is "Clear search".

Distinguish **"nothing yet"** (first-run — invite creation) from **"no matches"** (filtered — invite broadening the filter). They need different copy and CTAs.

---

## Error states — wired to skill 15

Errors are mapped, not raw. Skill **15** ships `Failure` (sealed) plus a `failure_x.dart` extension that turns each `Failure` into user-facing copy (`title`, `description`, `icon`, `isRetryable`). The `ErrorStateView` (see [`templates/error_state.dart`](templates/error_state.dart)) consumes that mapping — never the developer-facing `failure.message`.

```dart
// inside ErrorStateView.fromError — uses skill 15's mapping when present:
if (error is Failure) {
  return ErrorStateView(
    icon: error.icon,
    title: error.title,
    message: error.description,
    onRetry: error.isRetryable ? onRetry : null,
  );
}
```

Rules:
- **Always offer a way forward.** Retryable failures get a retry button (`() => ref.invalidate(provider)`). Non-retryable ones (e.g. `UnauthorizedFailure`) hide retry and the caller wires a relevant action (re-authenticate, go home). No dead-ends.
- **Partial vs full error.** A whole-surface failure → `ErrorStateView`. A failure in *one widget* of an otherwise-fine screen → `InlineErrorBanner`, leaving the rest intact.
- **Failed refresh with data on screen** → keep the data, surface the error via a `SnackBar`/banner. Don't collapse populated content back to an error screen.

---

## Optimistic updates + rollback

For mutations where success is the overwhelming norm (like, favorite, toggle, add-to-cart), update the UI *before* the server confirms, then roll back if it fails. This makes the app feel instant.

```dart
Future<void> toggleFavorite(Product p) async {
  final previous = state;                       // snapshot for rollback
  state = AsyncData(_withFavorite(p, !p.isFav)); // optimistic
  final res = await _repo.setFavorite(p.id, !p.isFav);
  if (res case Err(:final failure)) {
    state = previous;                           // rollback
    _showSnack(failure);                        // surface the error (skill 15)
  }
}
```

Principles: snapshot before mutating; **roll back to the exact prior state** on `Err`; tell the user it failed (don't silently revert — that's confusing). Reserve optimism for low-stakes, high-success-rate actions; for risky ones, show a spinner and await confirmation.

---

## Pull-to-refresh & pagination

- **Pull-to-refresh** — wrap the scrollable in `AsyncRefreshView` (a themed `RefreshIndicator`). Return the controller's `.future` so the indicator stays until the reload completes. Refresh keeps current data on screen (`skipLoadingOnRefresh`), never flashing back to a skeleton.
- **Pagination footers** — when loading the next page, keep loaded items visible and show a small footer (`PaginationFooter`): a compact spinner while loading, or a retry row if the next page failed. Never replace the whole list with a spinner to load page 2. The end-of-list state ("You're all caught up") is its own quiet footer.

---

## ANTI-PATTERNS — reject these in review

| Anti-pattern | Why it's wrong | Do instead |
|---|---|---|
| Full-screen spinner while only part of the screen loads | hides content the user already has | skeleton the loading region; keep the rest live |
| Loading placeholder that doesn't match final layout | content lands → everything jumps (layout shift) | skeleton mirrors the real box model |
| No empty state (empty list → blank screen) | looks broken; user is stuck | distinct `EmptyState` with cause + CTA |
| Raw `failure.message` shown to users | developer text leaks; scary/unhelpful | skill 15's `failure_x` user copy |
| Dead-end error (no retry, no path forward) | user is trapped | retry, or an alternative action |
| Refresh collapses populated screen to a spinner | jarring; loses scroll position & data | keep data; `skipLoadingOnRefresh` + indicator |
| `.when` branches copy-pasted per screen | cases drift; empty/error forgotten | compose `AsyncValueView` once |
| Spinner for an instant low-stakes action | feels sluggish | optimistic update + rollback |
| Shimmer ignoring reduce-motion | a11y / vestibular issue | still skeleton when `disableAnimations` |

---

## What you produce

Under `lib/core/widgets/` (shared primitives — CONVENTIONS §2):

1. **`async_value_view.dart`** — `AsyncValueView<T>` (+ `AsyncRefreshView`): the four-state mapper. [template](templates/async_value_view.dart)
2. **`skeletons.dart`** — `Shimmer`, `SkeletonBox`, `ListTileSkeleton`, `CardSkeleton`, `ListSkeleton`, `PaginationFooter`. [template](templates/skeletons.dart)
3. **`empty_state.dart`** — `EmptyState` (icon/illustration, title, message, CTA). [template](templates/empty_state.dart)
4. **`error_state.dart`** — `ErrorStateView` (+ `InlineErrorBanner`), wired to skill 15's `Failure` UX. [template](templates/error_state.dart)

Then sweep every feature screen: each data surface composes `AsyncValueView` with a skeleton, an `isEmpty` predicate + empty builder, and a retry.

### Exit-gate checklist

- [ ] Every data surface renders **all four** states via `AsyncValueView` (or an equivalent that covers loading/data/empty/error).
- [ ] Loading uses a **skeleton that mirrors the final layout** (spinner only for tiny/indeterminate surfaces); no layout shift when data lands.
- [ ] Every collection surface has an `isEmpty` predicate and a **helpful** empty state (cause + primary action).
- [ ] Errors use skill 15's `failure_x` copy and always offer a path forward (retry or alternative); no raw `failure.message`.
- [ ] Refresh keeps data on screen; pagination uses a footer, not a full-screen spinner.
- [ ] Optimistic mutations snapshot + roll back on `Err` and surface the failure.
- [ ] No hardcoded colors/sizes — all from `Theme`/`AppTokens`; shimmer respects reduce-motion.
- [ ] `flutter analyze` clean under `very_good_analysis`.

Consumes **08** (AsyncValue), **15** (Failure UX), **04** (tokens). Hands off polished surfaces to **17** (Responsive_UI) and **20** (widget/golden tests of each state).
