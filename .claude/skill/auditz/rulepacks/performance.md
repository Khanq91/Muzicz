# Pack: performance — jank, wasted rebuilds, wasted memory

### rule_id: watch_whole_object
requires: riverpod
`ref.watch(provider)` on a large state object when only one field is used → whole widget rebuilds on every unrelated change. Use `ref.watch(provider.select((s) => s.field))`. Flag only when the build clearly uses a small slice of a bigger state.

### rule_id: rebuild_scope_too_wide
requires: flutter
`setState` high in a large widget tree to change one small thing, or a single giant `build` method (200+ lines) rebuilding everything together. Suggest extracting the changing part into its own widget / using ValueListenableBuilder or a scoped Consumer.

### rule_id: nonbuilder_list
requires: flutter
`ListView(children: items.map(...).toList())` or `Column` inside `SingleChildScrollView` for long/unbounded lists. Builds every item up front. Use `ListView.builder`/`separated` or slivers.

### rule_id: missing_const
requires: flutter
Widget subtrees that are fully constant but not marked `const`, especially inside frequently rebuilding builds or list items. Only flag clear, repeated cases — not one-off misses the linter would catch anyway.

### rule_id: shouldrepaint_always_true
requires: flutter
`CustomPainter.shouldRepaint` hard-returning `true` (or comparing nothing) while the painter has stable inputs, causing repaint every frame. Compare the actual fields; return true only when they changed. If it animates via `Listenable`, pass it to `CustomPainter(repaint:)` instead.

### rule_id: blur_layer_abuse
requires: flutter
`BackdropFilter`/`ImageFilter.blur`/glass effects stacked more than one layer deep in a subtree, applied inside scrolling list items, or animated per-frame. Each one forces a `saveLayer` — the most expensive raster op on mobile. Reduce layers, cache with `RepaintBoundary`, or blur a static snapshot.

### rule_id: expensive_work_in_build
requires: core
Sorting, filtering, parsing, `jsonDecode`, date formatting of collections, or object construction of heavy immutables executed inside `build` on every frame. Move to the controller/provider layer, memoize, or compute in `initState`/on data change.

### rule_id: image_unbounded
requires: flutter
Network/asset images decoded at full resolution into small boxes: missing `cacheWidth`/`cacheHeight` (or `memCacheWidth` for cached_network_image), missing size constraints in lists/grids. Blows the raster cache and causes GC churn.

### rule_id: opacity_animation
requires: flutter
Animating with `Opacity(opacity: controller.value)` rebuilt per tick, instead of `FadeTransition`/`AnimatedOpacity`. Same for `Transform` rebuilt via setState per frame instead of `AnimatedBuilder` scoped to the transformed child.

### rule_id: sync_io_main
requires: core
Synchronous file IO (`File.readAsStringSync`), heavy `compute`-worthy parsing, or crypto on the main isolate in user-interaction paths. Use async IO or `compute`/`Isolate.run` for CPU-bound work over ~1ms-per-frame budget.
