# Device Matrix Report

## Run metadata

| Field | Value |
|---|---|
| Date | YYYY-MM-DD |
| App version | X.Y.Z |
| Commit SHA | abc1234 |
| Tier | 1 / 2 / 3 |
| Total devices | N |
| Runner | Firebase Test Lab / local |

## Results summary

| Pass | Fail | Inconclusive | Total |
|---|---|---|---|
| N | N | N | N |

## Results per device

| # | Device | Model | API | RAM | Orientation | Locale | Result | Duration | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Pixel 6 | redfin | 33 | 8GB | portrait | en_US | PASS | 2m 15s | — |
| 2 | Pixel 6 | redfin | 33 | 8GB | landscape | en_US | PASS | 2m 22s | — |
| 3 | Moto G Power | grunt | 30 | 2GB | portrait | en_US | FAIL | 3m 40s | OOM on image grid |
| ... | | | | | | | | | |

## Failure analysis

### Device: Moto G Power (grunt, API 30)
- **Test:** `image_grid_test.dart` — scroll through 100-image grid
- **Symptom:** OutOfMemoryError during image decode at image #47
- **Root cause:** Full-resolution images decoded into memory; 2GB device cannot hold 100 decoded bitmaps.
- **Fix:** Use `ResizeImage` with max dimensions, or implement a recycling image cache, or paginate the grid.
- **Also fails on:** (list other devices with same failure, or "unique to this device")

### Device: Pixel Fold (felis, API 33) — landscape (unfolded)
- **Test:** `responsive_layout_test.dart`
- **Symptom:** Bottom navigation bar overlaps content on unfold transition.
- **Root cause:** Layout does not re-layout on `MediaQuery` change; the old narrow layout persists after unfolding.
- **Fix:** Wrap the scaffold body in a `LayoutBuilder` or use `MediaQuery.of(context).size` reactively; ensure `didChangeDependencies` triggers a rebuild on size change.

## Performance observations

| Device | Cold start (ms) | Warm start (ms) | Scroll jank (avg frame time) | Memory peak (MB) |
|---|---|---|---|---|
| Pixel 6 (8GB) | 1200 | 400 | 8ms | 180 |
| Moto G Power (2GB) | 2400 | 900 | 22ms | 195 (crashed) |
| ... | | | | |

## Foldable-specific

| Test | Result | Notes |
|---|---|---|
| Fold → unfold transition | PASS / FAIL | |
| Unfold → fold transition | PASS / FAIL | |
| Hinge-aware layout | PASS / FAIL / N/A | |
| Multi-window (split screen) | PASS / FAIL / N/A | |

## RTL locale check

| Device | Locale | Layout correct? | Text clipped? | Icons mirrored? |
|---|---|---|---|---|
| Pixel 6 | ar_SA | YES / NO | YES / NO | YES / NO |
| Pixel 6 | he_IL | YES / NO | YES / NO | YES / NO |

## Verdict

- [ ] **CLEAR** — all devices pass. Release gate satisfied for Tier [N].
- [ ] **BLOCKED** — [N] devices failed. Blocking issues listed above.
- [ ] **CONDITIONAL** — failures are non-blocking (pre-existing issues, tracked separately). Release may proceed.

## Blocking issues for next run

1. **[ISSUE-ID]** — [device] — [summary] — [owner]
2. ...
