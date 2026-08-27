# Pack: correctness — latent bugs that will crash or corrupt state

### rule_id: async_context_use
requires: flutter
Using `BuildContext` (Navigator.of, ScaffoldMessenger.of, Theme.of, context.push, showDialog...) after an `await` without first checking `mounted` (State) or `context.mounted`. The widget may be gone when the future completes.
Violation: `await save(); Navigator.of(context).pop();`
OK: `await save(); if (!context.mounted) return; Navigator.of(context).pop();`

### rule_id: undisposed_resource
requires: flutter
`AnimationController`, `TextEditingController`, `ScrollController`, `PageController`, `FocusNode`, `StreamSubscription`, `Timer.periodic`, or `Ticker` created in a State but never disposed/cancelled in `dispose()`. Also flag `dispose()` overrides that forget `super.dispose()`.

### rule_id: ref_watch_in_callback
requires: riverpod
`ref.watch(...)` inside onPressed/onTap/listeners/async callbacks or any code that runs outside build. Must be `ref.read(...)`. Conversely, `ref.read` used inside `build` for reactive data that should rebuild the widget.

### rule_id: missing_autodispose
requires: riverpod
Screen-scoped or parameterized (`.family`) providers declared without `autoDispose`, keeping dead state and leaking memory after the screen closes. App-lifetime singletons (auth, settings, db) are OK to keep alive — use judgment from the provider's name and usage.

### rule_id: provider_side_effect_in_build
requires: riverpod
Mutating provider state (`ref.read(x.notifier).state = ...`, calling notifier methods) directly inside `build`, or navigation/dialogs fired from `build` instead of `ref.listen` / callbacks. Causes "setState during build" errors and loops.

### rule_id: hive_schema_versioning
requires: hive_json
Project stores JSON strings in Hive without TypeAdapters. Flag model `fromJson` that reads keys with `!` or without fallbacks (`json['newField'] as String`), and renamed/removed fields without a schema `version` key + migration path. Old on-disk data will crash the app after an update.
OK: `json['newField'] as String? ?? defaultValue` and an explicit version/migration.

### rule_id: freezed_maybewhen_swallow
requires: freezed
`maybeWhen`/`maybeMap` with a broad `orElse` that silently swallows union cases (especially error/loading states). New variants added later get eaten without a compile error. Prefer exhaustive `when`/`map` or a Dart 3 exhaustive `switch`.

### rule_id: silent_catch
requires: core
Empty `catch` blocks, `catch (e) {}`, or catches that neither rethrow, log, nor surface the error to the user. Also `on Exception catch` that hides programming errors which should crash in debug.

### rule_id: unawaited_future
requires: core
A `Future`-returning call whose result is discarded in a context where completion/failure matters (writes, navigation guards, transaction commits). Errors vanish. Either `await` it, or mark intent explicit with `unawaited(...)` and handle errors.

### rule_id: setstate_after_async_gap
requires: flutter
`setState` called after an `await` without a `mounted` guard. Throws "setState() called after dispose()" in production when the user leaves the screen mid-request.

### rule_id: bloc_emit_after_close
requires: bloc
`emit` reachable after an async gap without `isClosed`/`emit.isDone` checks, or subscriptions in a Bloc/Cubit not cancelled in `close()`.

### rule_id: race_shared_mutable
requires: core
Multiple concurrent async paths mutating the same field/list without sequencing (no queue, no cancellation of the previous request). Classic symptom: search-as-you-type where a slow old response overwrites a newer one. Look for missing request tokens/`cancelToken`/debounce.
