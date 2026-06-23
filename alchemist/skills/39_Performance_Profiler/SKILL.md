---
name: Performance Profiler
description: From a DevTools timeline export, --profile trace, or frame rendering stats, identify excessive rebuilds and slow frames, then recommend const, select, RepaintBoundary, and isolate offload fixes with before/after estimates. Use when the app drops frames, scrolling stutters, animations judder, or the profiler shows 16ms budget violations. Merges rebuild profiling and jank profiling into one skill — the same artifact delivers both diagnoses.
when_to_use: Trigger on "profile the app", "find jank", "why is this frame slow", "rebuild audit", "DevTools timeline shows red", "frame budget exceeded", "60fps regression", "shader compilation jank", "raster thread is slow", or a pasted --profile trace. Pairs with #09 Animation (which gates on "motion runs 60fps; no jank in profile") and #20 Testing (which runs golden/profile tests). For isolated build-speed profiling, use #37 Build Doctor instead.
---

# Performance Profiler (Roadmap #39)

Every frame misses its 16ms budget for a reason. Your job is to **read a DevTools timeline
export or `--profile` trace, identify the top causes, and produce a prioritized fix list**
with estimated ms savings — no guessing, no "try removing everything." House style:
[`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).

This skill merges rebuild profiling and jank profiling into one pass: excessive widget
rebuilds and expensive raster/layout work produce the same artifact — a frame that missed
vsync. Diagnose both from the same timeline.

---

## 1. Inputs — what you consume

| Source | How to get it | What it contains |
|---|---|---|
| **DevTools timeline export** | DevTools > Performance > **Export** (JSON) | Per-frame events: build, layout, paint, raster durations; widget rebuild counts; GPU/UI thread slices |
| **`--profile` trace** | `flutter run --profile --trace-startup` or `--trace-skia` | SkSL shader timings, timeline events via Observatory/DevTools |
| **Frame rendering stats** | DevTools > Performance > **Frame rendering stats** toggle, or `debugProfileBuilds` | Rebuild counts per widget, build durations |
| **CPU profiler** | DevTools > CPU Profiler > record a janky interaction | Dart call-tree with self-time per function |
| **Memory snapshot** | DevTools > Memory > snapshot during an interaction | Live instances, retention paths (memory-only jank) |
| **Flutter Driver timeline** | `flutter drive --profile` with `traceAction` | Automated scenario traces for CI |

**How to export the data the profiler needs:**
1. Run the app in profile mode: `flutter run --profile`
2. Open DevTools (`flutter devtools` or via IDE)
3. Navigate to the **Performance** tab
4. Reproduce the janky interaction while recording
5. Stop recording, then **Export** the timeline as JSON
6. Share that file — or paste the per-frame summary table visible in the timeline

---

## 2. Analysis dimensions

For each frame in the trace, inspect these metrics. A frame is janky when **any** thread
exceeds the budget.

| Dimension | Measure | Budget | Tool location |
|---|---|---|---|
| **Rebuild count** | Widgets rebuilt this frame | < ~50 (fewer is better) | Timeline > "Widget rebuilds" row, or frame stats overlay |
| **Build duration** | Total `build()` time on UI thread | < 6–8 ms | Timeline > UI thread > build phase |
| **Layout duration** | `performLayout` / layout pass | < 2–3 ms | Timeline > UI thread > layout phase |
| **Paint duration** | `paint` / compositing | < 2–3 ms | Timeline > UI thread > paint phase |
| **Raster thread time** | GPU work: `drawFrame`, `Canvas::Flush` | < 6–8 ms (32ms total budget minus UI thread) | Timeline > Raster thread |
| **Shader compilation** | `GrGLGpu::compileShader` or `SkSL` events on raster thread | 0 ms (pre-warm) | Timeline > Raster thread; also `--trace-skia` |
| **Dart GC** | `GC` / `Sweep` events on UI thread | < 1 ms per frame | Timeline > UI thread |
| **Frame total** | VSYNC-to-VSYNC | **16.67 ms** (60 fps) | Timeline > Frame track summary |

### Rebuild severity tiers

| Tier | Rebuilds / frame | Action |
|---|---|---|
| **Critical** | 200+ | Immediate refactor needed — likely a high-level provider causing full-screen rebuilds |
| **High** | 100–199 | `select()` imprecision or missing `const` in a hot list |
| **Medium** | 50–99 | Tuning needed before ship |
| **Low** | < 50 | Acceptable unless frame budget still violated by expensive builds |

---

## 3. Common causes and fixes

| Signal in timeline | Root cause | Fix | Typical saving |
|---|---|---|---|
| Large "Widget rebuilds" row with `MyWidget build` appearing repeatedly | Missing `const` constructor or constructor call | Add `const` to the widget constructor and call-site | 0.3–1 ms per widget instance |
| Many rebuilds of unrelated widgets when a provider updates | `ref.watch(provider)` instead of `ref.watch(provider.select(...))` | Narrow with `select`: `ref.watch(userProvider.select((u) => u.name))` | 50–90% rebuild reduction |
| `build()` self-time > 2 ms in a single widget | Expensive build method (nested loops, layout calcs, image decoding in build) | **RepaintBoundary** around the subtree; pre-compute values outside build; extract `ListView.builder` | 2–5 ms per frame |
| `computeLuminance` / `ColorFilter` / `ShaderMask` on UI thread | Shader-backed widget without `RepaintBoundary` | Wrap the widget in `RepaintBoundary` so the rasterized layer is cached | 1–4 ms on repaint |
| `decodeImageFromList` / `Image.network` in build | Image decode/network in build | Use `precacheImage` in `didChangeDependencies`; use `FadeInImage` with a placeholder | 5–20 ms (blocks frame) |
| Large raster-thread block with `Canvas::drawRect` / `saveLayer` | Overdraw from overlapping opacity, clip, or `BackdropFilter` | Flatten the widget tree; remove unnecessary `Opacity`; prefer `ClipRRect` over manual clip paths | 2–8 ms |
| `GrGLGpu::compileShader` on raster thread | First-run shader compilation jank | **Shader warm-up**: `flutter run --profile --cache-sksl`, capture with `--write-sksl-on-exit`, bundle `flutter_01.sksl` | 5–20 ms first run, 0 ms after |
| `GC` blocks on UI thread | Excessive allocations in build or animation callback | Reduce per-frame allocations; reuse objects; avoid `List.generate` or `Map.from` in hot paths | 1–3 ms |
| `String concatenation` / `toString` in build | Debug-mode formatting in release builds | Remove `debugPrint`, `toString`, and `assert` from production paths | 0.5–1 ms |
| `setState` on a high-level `StatefulWidget` | Imprecise state management | Move state down; use `ValueNotifier` + `ValueListenableBuilder` for localized rebuilds, or Riverpod per-field providers | 30–70% rebuild reduction |
| Large `Column`/`Row` with 50+ children all rebuilding | Un-keyed list or non-lazy layout | Switch to `ListView.builder` with `itemExtent` or `prototypeItem`; add stable `Key` values | 3–10 ms |
| `Opacity(opacity: 0.0)` widget still in tree | Invisible widget still painting | Replace with `Visibility` or conditional `if` in the tree so it is not composited | 0.5–2 ms |
| `BackdropFilter` in scrolling list | Per-item blur on raster thread | Extract the filter above the list (single instance) or remove it | 8–15 ms |

---

## 4. Output — the prioritized fix list

Produce a table sorted by **estimated impact (ms saved) × frequency (frames affected)**.
Use the format in [`templates/profiling_report.md`](templates/profiling_report.md).

Each row must include:
- **Frame range** — which frames in the trace show this issue
- **Root cause** — which of the signals from §3
- **Affected widget / file** — class name and source path
- **Fix recommendation** — specific code change (add `const`, add `select`, add `RepaintBoundary`, etc.)
- **Estimated improvement** — a range in ms (e.g. "3–5 ms per frame")
- **Confidence** — HIGH / MEDIUM / LOW (based on whether the signal is unambiguous)

---

## 5. Jank categories — how to classify what you see

When the timeline shows a frame violation, classify it into one of four jank categories
so the fix route is clear.

### 5.1 Dart VM jank

**Signals:** GC events on UI thread, high allocation rate in CPU profiler, `Dart_New` calls.
**Fix route:** Reduce per-frame allocations (reuse objects, avoid closures in hot loops, prefer
`for` over `.map().toList()`). Offload heavy serialization to an isolate.

### 5.2 Layout jank

**Signals:** `performLayout` > 2 ms, deep widget tree with `IntrinsicHeight`/`IntrinsicWidth`,
nested `Flex` widgets, `LayoutBuilder` callbacks doing work.
**Fix route:** Flatten layout, remove intrinsics, set `itemExtent` on lists, prefer
`SliverGrid`/`SliverList` for scrolling layouts.

### 5.3 Rasterization jank

**Signals:** Raster thread > UI thread, `saveLayer`, `drawRect` storms, complex paths.
**Fix route:** Add `RepaintBoundary` at stable subtree roots, reduce overdraw, remove
unnecessary opacity layers, simplify clip paths, pre-raster images.

### 5.4 Shader compilation jank

**Signals:** `GrGLGpu::compileShader` or `SkSL` compilation on raster thread, first-run spikes
that disappear on the second visit to a screen.
**Fix route:** SkSL warm-up pipeline (§3). Also: `--trace-skia` to capture, `flutter test --update-sksl`
in CI to keep the warm-up bundle in sync.

---

## 6. Isolate offload checklist

When the CPU profiler shows > 4 ms of compute on the UI thread in a single function,
offload it. The skill recommends, not implements — provide the scaffold pattern.

| Compute type | Offload target | API |
|---|---|---|
| JSON parsing (large payload) | Isolate | `Isolate.run(() => jsonDecode(raw))` or `compute()` |
| Image processing / compression | Isolate | `Isolate.run` with `dart:ui` imported on isolate (decode outside) |
| Sorting / filtering large lists | Isolate | `Isolate.run(() => list..sort())` — pass a shallow copy |
| Crypto / hashing | Isolate | `Isolate.run(() => sha256.convert(bytes))` |
| Regular DB migrations | Background isolate | `drift` `Isolate.native` or `sqflite` background |

---

## 7. Integration with the pipeline

- **Stage 09 (Animation)** gates on this skill's output: "motion runs 60fps; no jank in profile."
  Before marking stage 09 done, run a full profile pass with this skill.
- **Stage 20 (Testing)** adds `flutter test --profile` and frame-budget assertions; this skill
  provides the thresholds for those assertions.
- **CI profile pipeline** (stage 21): add a `flutter drive --profile` step that runs representative
  scenarios and fails on frame-build times exceeding thresholds.
- **Pre-ship checklist**: use [`templates/perf_checklist.md`](templates/perf_checklist.md) before
  every release.

---

## 8. Quick reference — Flutter profile commands

```bash
# Record a profile with the SkSL warm-up
flutter run --profile --trace-skia

# Run a drive test with timeline
flutter drive --profile --target=test_driver/perf.dart

# Check frame build times in debug (coarse but useful pre-test)
flutter run --debug --trace-startup

# Dump the widget rebuild counts
flutter run --profile
# Then in DevTools: Performance > Frame rendering stats

# Export SkSL for bundling (after exercising the app)
flutter run --profile --cache-sksl --write-sksl-on-exit=sksl_capture.json

# Bundle SkSL in release
flutter build apk --bundle-sksl-path=sksl_capture.json

# Analyze a specific trace file
flutter pub run devtools --launch-timeline=<path-to-trace.json>
```

---

See [`templates/profiling_report.md`](templates/profiling_report.md) for the fix-list template,
[`templates/perf_checklist.md`](templates/perf_checklist.md) for the pre-ship audit,
and house style in [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).
