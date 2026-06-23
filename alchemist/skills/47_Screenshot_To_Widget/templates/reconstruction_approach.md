# Screenshot Reconstruction — Systematic Approach

## Phase 1 — Skeleton identification

Read the screenshot top-to-bottom, left-to-right. Identify the structural shell:

| Visual region | Likely Flutter widget | Key observation |
|---|---|---|
| Top bar with title + optional back arrow | `AppBar` | Title text role? Action icons? |
| Bottom tabs (3-5 items, icon + label) | `NavigationBar` (M3) / `BottomNavigationBar` | Selected state color? |
| Floating action button | `FloatingActionButton` / `SmallFAB` / `LargeFAB` | Position: center/end? Extended? |
| Drawer / side sheet | `NavigationDrawer` / `Drawer` | Profile header? |
| Body scrolls vertically | `ListView` / `SingleChildScrollView + Column` | Separators? Pull-to-refresh? |
| Body scrolls horizontally | `PageView` / horizontal `ListView` | Page indicator dots? |
| Fixed bottom bar (e.g. checkout total) | `BottomAppBar` / `SafeArea + Row` | Pinned below content? |

## Phase 2 — Content regions (iterate per region)

For each distinct content region in the scroll body:

### Card / List Item
1. **Layout:** Row with leading widget + Column of text + trailing widget? Or a Card wrapper?
2. **Spacing:** Measure padding — snap to nearest `AppTokens.spacing` value (4,8,12,16,24,32,48).
3. **Typography:** title → `titleMedium`/`titleSmall`? subtitle → `bodyMedium`/`bodySmall`? metadata → `labelSmall`?
4. **Media:** leading icon → `Icon(Icons.xxx)` or `CircleAvatar`? trailing chevron → `Icons.chevron_right`?
5. **Separator:** `Divider` with `indent`? Or card-based gaps?
6. **Tap target:** ensure ≥48dp height.

### Form / Input
1. **Label:** `InputDecoration(labelText: ...)` using `labelMedium`?
2. **Border:** `OutlineInputBorder` or `UnderlineInputBorder`? Radius?
3. **Helper/error text:** `helperText` / `errorText` placement.
4. **Button:** `FilledButton` / `ElevatedButton` / `OutlinedButton`? Full-width or intrinsic?

### Grid / Gallery
1. **Columns:** count visible items per row → `SliverGrid` `crossAxisCount`.
2. **Aspect ratio:** estimate from screenshot → `childAspectRatio`.
3. **Spacing:** `crossAxisSpacing` / `mainAxisSpacing` → snap to spacing tokens.

### Hero / Header Section
1. **Image:** `AssetImage` / `NetworkImage` placeholder with AspectRatio.
2. **Overlay text:** `Stack` with gradient overlay + `Positioned` text.
3. **Scrim:** gradient from `Colors.transparent` to `ColorScheme.surface`.

## Phase 3 — Token mapping quick-reference

| Visual property | Screenshot observation | Token |
|---|---|---|
| Gap between cards | ~16px | `AppTokens.spacing.md` (16) |
| Card corner rounding | slightly rounded | `AppTokens.radius.md` (12) |
| Button height | ~48px | `AppTokens.spacing.xxl` (48) or min touch target |
| Primary action color | blue-ish | `ColorScheme.primary` |
| Background | white / near-black | `ColorScheme.surface` |
| Subtitle color | gray | `ColorScheme.onSurfaceVariant` |
| Divider | thin gray line | `ColorScheme.outlineVariant` |
| Error text | red | `ColorScheme.error` |

## Phase 4 — State surfaces (must cover)

Every data region must handle four states. Identify where each goes:

| State | Widget approach |
|---|---|
| **Loading** | `SkeletonLoader`-shaped placeholder matching card structure |
| **Data** | The reconstructed widget (what the screenshot shows) |
| **Empty** | Illustration + "No items yet" using `bodyLarge` in `onSurfaceVariant` |
| **Error** | `ErrorView` with retry button (skill 16 pattern) |
