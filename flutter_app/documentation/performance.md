# Constellation graph — performance guide

How the Mutuals "constellation" view renders, what's been optimized, and the
levers to pull when it gets slow. Scope: the star-map graph (1500+ contacts).

## TL;DR

- The painter repaints **every frame** (continuous twinkle), so anything done
  *per node* happens ~60×/second × N nodes. Keep per-node work tiny.
- Heavy per-node work is **cached once per build**, not recomputed per frame.
- Stars render at **level-of-detail (LOD)** tiers by on-screen size, and
  **off-screen nodes are culled**, so overview frames stay cheap.
- There's a **benchmark** to catch regressions:
  `test/constellation_perf_benchmark_test.dart`.

## The render pipeline

```
main.dart (_filteredContacts)
  └─ GraphView (lib/widgets/graph_view.dart)        // state, gestures, photo decode
       ├─ computeConstellationSky()                 // lib/painters/constellation_layout.dart
       │     → node positions, figure lines, group index   (pure, deterministic)
       ├─ StarfieldPainter                          // lib/painters/starfield_painter.dart (background)
       └─ GraphPainter (lib/painters/graph_painter.dart)   // draws stars + lines + labels
```

Key fact: in the Mutuals view there is **no force simulation** — positions are
computed once by `computeConstellationSky` (a pure function). The cost is in
**painting**, which repeats every frame because `GraphPainter` is driven by
`super(repaint: Listenable.merge([viewTransform, twinkle]))`.

`GraphView._buildGraph()` runs only when the contact set / pivot changes (e.g. a
filter, an edit). `GraphPainter.paint()` runs every frame.

## What's optimized today

All in `lib/painters/graph_painter.dart` unless noted.

1. **Per-node strength cached once.** `strengthScore()` is non-trivial and was
   called per node *per frame*. It's now computed once per painter instance in
   `_strengthById` (`late final`, built on first paint) and reused every frame.

2. **Node lookup cached once.** `_byId` (id → node) is built once instead of
   rebuilt every frame (used by links, stars, edge labels).

3. **Level-of-detail (LOD) tiers** by on-screen radius (`screenRadius =
   radius * scale`):
   - `< _pointPx` (3.5): a single cheap point of light — no glow/disc/photo.
   - `< _glowPx` (7): flat colored disc + hot core (no soft glow, no rim).
   - `< _photoPx` (12): a glowing star, but no photo.
   - `>= _photoPx`: the full star with its photo.

   At overview, ~all nodes are tiny → they hit the cheapest tier. Glow and
   photos only appear as you zoom in.

4. **Viewport culling.** `_drawStars` skips any node whose center is outside the
   visible rect (`visible.inflate(120)`), derived from the inverse view
   transform. When zoomed in, only a handful of nodes are drawn.

5. **Reused `Paint` objects.** `fill`/`stroke` are allocated once per
   `_drawStars` call and mutated, instead of `new Paint()` per node per draw
   (which was ~4 × N × 60/s allocations).

6. **One shared glow gradient.** `_glowGradient` is a single static radial
   gradient, tinted per star via a `ColorFilter` + canvas scale — no per-star
   shader/blur allocation.

7. **Loose nodes on an even disc** (`constellation_layout.dart`). Contacts with
   no linking tag (e.g. "Imported"-only) form the "Orphans" group. They used to
   pile into a narrow band; then a √n grid (square block); now an even
   golden-angle ("sunflower") **disc** with light deterministic jitter, so a
   1500-node untagged set spreads out as an organic cloud with no pile-up. Named
   groups likewise spill overflow members onto a phyllotaxis spiral, and grid
   cells are sized to the largest group so clusters never overlap. Each group
   also exposes a `radius` so labels can sit *below* the cluster instead of in
   its middle.

8. **Name labels are gated, capped, and cached** — this is what keeps zooming
   smooth at 1500 nodes (`graph_painter.dart`):
   - **Gated** by zoom: names appear only past `_labelScale` (1.6); edge labels
     past their own threshold. Both are viewport-culled.
   - **Capped per frame** to `_maxLabels` (80) via `_drawLabels`: candidates are
     collected during the star pass, then only the most prominent (largest
     on-screen) are drawn. So crossing the label threshold — when hundreds of
     nodes can be on screen at once — never spawns hundreds of labels in one
     frame. Zoom further into a small cluster and *every* visible node is
     labelled (there are fewer than the cap).
   - **Cached** layouts: laid-out `TextPainter`s are kept in a process-wide
     `_labelPainterCache` keyed by `"name|fontSizePx"` (oldest-evicted at
     `_labelCacheCap` = 600). Text *measurement* (`TextPainter.layout`) is the
     expensive part; without the cache every visible node re-measured its name
     every frame, so the moment a zoom crossed `_labelScale` the view stuttered.
     Font size depends only on zoom, so it's uniform across a frame → near-100%
     cache hits while panning/zooming at a fixed level.

> **Why not just show every name, always?** With ~1500 nodes that means ~1500
> `TextPainter.layout`s *per frame* (the painter repaints continuously) — it
> would jank constantly, not just on zoom, and the names would overlap into an
> unreadable mush at overview. The cap + cache instead make names appear
> smoothly for the nodes you're actually looking at, with the work bounded
> regardless of how many nodes exist. Raise `_maxLabels` if you want more on
> screen at once; the cache keeps the cost low, but readability degrades first.

### Tags & linking note

The `Imported` tag never groups/links people (see `lib/services/tag_rules.dart`,
`primaryLinkingTag` / `linkingTags`). That's a *correctness/UX* rule, but it also
matters for performance: it keeps imported contacts out of one giant cluster and
in the cheaply-rendered loose grid.

## Benchmarks

`test/constellation_perf_benchmark_test.dart` builds 1500 contacts (mostly
Imported-only) and prints:

- `layout 1500 contacts: N ms` — cost of `computeConstellationSky` (one-time).
- `paint/frame — overview: N ms, zoomed: N ms` — `GraphPainter.paint()` cost.

Run it:

```bash
flutter test test/constellation_perf_benchmark_test.dart
```

Reference numbers (host CPU, op-recording — **not** device GPU; use only for
relative comparison / regression detection): layout ~35 ms; paint/frame
overview ~14 ms, zoomed ~2 ms. Numbers vary by machine; what matters is they
don't jump by an order of magnitude after a change.

> Caveat: the benchmark records canvas ops (it doesn't rasterize to a texture),
> so it measures our CPU-side per-node work — exactly what the optimizations
> target — not GPU fill cost. Real device smoothness also depends on overdraw
> and texture memory (see below).

## How to investigate a slowdown

1. **Reproduce the scale.** Use the benchmark or bump its contact count.
2. **Profile on device** with `flutter run --profile` + DevTools "Performance"
   (look for long `paint`/`raster` frames) and the "Raster" timeline.
3. **Ask: per-frame or per-build?** If scrolling/zooming janks → it's
   `paint()` (per frame). If only the moment after a filter/edit janks → it's
   `_buildGraph` / `computeConstellationSky` / photo decode.
4. **Check overdraw.** Many large overlapping glows blow up GPU fill even when
   op count is low. The starfield + glows are additive soft circles — cheap on
   CPU, not free on GPU.

## Levers for the future (cheapest → biggest change)

- **Tune LOD thresholds.** Raise `_glowPx` / `_photoPx` (graph_painter.dart) so
  glow/photos appear only when larger on screen → fewer expensive draws.
- **Tune the point threshold.** Raise `_pointPx` so more nodes stay cheap points
  longer while zooming.
- **Throttle / pause twinkle.** The continuous repaint is the per-frame driver.
  Options: lower the `AnimationController` frequency, or stop it while idle and
  only animate after interaction, or disable twinkle when `nodes.length > N`.
  (It's wired in `graph_view.dart`'s `_animController` → painter `twinkle`.)
- **Cap decoded photo textures.** Every contact photo becomes a `ui.Image`
  (GPU memory). At thousands of photos that's significant. Decode/keep only
  photos for nodes near the viewport (and dispose far ones). See
  `_decodePhotos` / `_photos` in `graph_view.dart`.
- **Precompute strengths in `_buildGraph`.** Today strengths are cached on the
  painter (recomputed if the widget rebuilds, e.g. during photo decode).
  Computing them in `GraphView._buildGraph` and passing them in makes it truly
  once-per-build.
- **Batch draws.** Collect same-style circles and use `Canvas.drawPoints` /
  `drawRawPoints` for the point tier, or `drawAtlas` for photo orbs, to cut
  per-node call overhead at very large N.
- **Spatial index for hit-testing.** `_hitTest` is O(n) per tap; fine at 1500,
  but a grid/quadtree helps if N grows much larger.
- **Cache the static background.** `StarfieldPainter` redraws 220 stars each
  frame for twinkle. If twinkle is dropped, render it once to a `ui.Picture`/
  layer.

## Invariants to preserve when optimizing

- `computeConstellationSky` must stay **pure and deterministic** (seeded only by
  ids/tags, no `DateTime.now()` / `Random()` without a seed) — the "stable sky"
  depends on it. It has unit tests in `test/constellation_layout_test.dart`.
- Keep heavy work **out of `paint()`**; cache per-build instead.
- Re-run the benchmark after changes and keep the generous ceilings green.
