# Pack: flow_ux — user-facing flow problems readable from code

### rule_id: error_state_missing
requires: flutter
Async UI whose error branch is dead weight: `AsyncValue.when(error: (e, s) => SizedBox.shrink())`, bare `Text('$error')` dumping raw exceptions at users, or FutureBuilder/StreamBuilder with no `hasError` handling. Users get a blank screen or a stack trace. Errors need a human message + retry affordance.

### rule_id: empty_state_missing
requires: flutter
Lists/grids rendered from data with no explicit empty state — `items.isEmpty` renders nothing. First-run users see a blank screen and assume the app is broken.

### rule_id: loading_state_missing
requires: flutter
Async data rendered with no loading branch, or a full-screen spinner replacing already-visible content on refresh (losing scroll position). Prefer skeletons/inline refresh for reloads.

### rule_id: route_guard_gap
requires: go_router
`redirect` logic that does not cover all protected routes (new routes added outside the guard), or guards checking auth synchronously against state that may not be loaded yet at cold start / deep link entry.

### rule_id: deeplink_backstack
requires: go_router
Deep-linkable detail routes declared top-level instead of nested under their parent, so system Back exits the app instead of going to the list. Also `context.push` vs `context.go` misuse that builds a wrong stack.

### rule_id: no_action_feedback
requires: flutter
Mutating actions (save, delete, send, pay) with no success/failure feedback — no SnackBar/toast/haptic/navigation, and no disabled+spinner state on the button while in flight (allowing double-submit). Flag double-submit especially for anything money-related.

### rule_id: unsaved_changes_lost
requires: flutter
Forms/editors with local edits and no `PopScope`/`onWillPop` confirm, so Back silently discards user input.

### rule_id: form_field_ergonomics
requires: flutter
TextFields missing the right `keyboardType` (phone/email/number), `textInputAction` (next/done), `autofillHints`, or validators; multi-field forms where Done doesn't submit. Also `resizeToAvoidBottomInset: false` on scaffolds that contain inputs (keyboard covers the field).

### rule_id: hardcoded_ui_strings
requires: core
User-facing strings hardcoded inline instead of going through the project's i18n mechanism (if one exists) or at least a central strings file. Severity low; report per-file once with examples, not per-string.

### rule_id: hardcoded_style
requires: flutter
Raw `Color(0xFF...)`, magic font sizes/spacings scattered in widgets instead of `Theme.of(context)`/design tokens. Breaks dark mode and consistency. Report per-file once with the worst examples.

### rule_id: tap_target_small
requires: flutter
Interactive elements visibly sized under ~44-48dp: `GestureDetector` wrapping a small `Icon`/`Text` without padding, `IconButton` with tiny `splashRadius`/constraints, list rows with cramped trailing actions.

### rule_id: missing_semantics
requires: flutter
Icon-only buttons without `tooltip`/`Semantics` label, images without `semanticLabel`, custom gesture surfaces invisible to screen readers. Flag the interactive cases, not decorative ones.

### rule_id: list_refresh_missing
requires: flutter
Primary content lists backed by remote data with no `RefreshIndicator`/pull-to-refresh and no other visible refresh path. Severity low.
