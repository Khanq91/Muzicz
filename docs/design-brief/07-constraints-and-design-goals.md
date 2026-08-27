# 07 — Constraints, Known Issues & Design Goals

**Read this file before proposing anything.**

## 1. Hard constraints

### 1.1 Liquid glass scope is FROZEN at current usage
Shipped glass = exactly two opt-in surfaces (bottom nav bar + mini player, "Xịn xò"
style) plus four manual blurs (Now Playing background σ40, queue sheet σ10 deferred,
artist header σ20, downloader σ12). That is the whole budget.

- You **may propose** new/changed glass usage, but every such proposal must be:
  (a) explicitly labeled **PROPOSAL — requires owner approval**,
  (b) accompanied by a performance-impact assessment (which surfaces, static or
  scrolling, expected blur/shader cost, fallback for weak devices),
  (c) never bundled silently into other changes.
- Context for why: premium-quality glass shipped with **zero real-device frame
  profiling**; adaptive quality was deliberately not enabled; the planned
  performance advisor was never built. The team knows this and treats glass
  expansion as performance-gated.

### 1.2 Performance discipline
The codebase's established rules — proposals should conform or explicitly price the
violation:
- Audio-driven signals never flow through global app state; visuals live in isolated
  RepaintBoundary subtrees with per-widget controllers.
- Blur is treated as expensive: deferred during motion (queue sheet pattern), never on
  scrolling content.
- Disabled features cost nothing (subtree gating, not opacity/visibility hiding).
- No shimmer/Lottie/Rive; loaders are cheap spinners/bars.
- Big lists are builder/sliver-based; thumbnails intentionally low filter quality.
- Known perf debt (don't make it worse): song rows watch the whole music provider;
  lyrics do a linear scan per tick; thumbnails decode at full size; waveform cache
  is uncapped.

### 1.3 Platform & product facts
- Portrait-only, edge-to-edge, Android-first (Impeller on), Material 3, Outfit only.
- Vietnamese-first copy. Three themes (Dark default / AMOLED / Light) — every visual
  proposal must work in all three.
- The Now Playing background is always blurred album art (white on-player text ladder
  is theme-independent by design).
- Downloader feature is out of scope for redesign.
- The system font-scale is currently clamped to 1.15× app-wide (accessibility debt —
  unclamping will expose overflows, especially Now Playing).

## 2. Known issues & inconsistencies (fix-worthy raw material)

### Visual/theming bugs
1. Light theme is broken in spots: Welcome title hard-coded white; Library sort menu
   and the whole downloader use a static dark palette; status-bar icons hard-coded
   light; playlist-detail back/edit icons white-on-white when collapsed.
2. Wordmark inconsistency: "Muzicz" (splash) vs "Muzic" (welcome); About dialog says
   "Muzizc Audio v1.0.0" (app is 2.0.0).
3. Playlist FAB shadow uses fully-opaque primary (harsh halo); FAB and detail-screen
   action buttons have no ripple/press feedback (inconsistent with the app-wide
   press-squeeze pattern).
4. Mini player title/artist bypass the Outfit helper (falls back via text theme —
   subtle but real inconsistency).
5. Home and Library search fields differ slightly (15sp/r14/v12 vs 14sp/r12/v10) for
   no apparent reason.

### UX gaps
6. Deleting a playlist has **no confirmation**; removing a song from a playlist is
   also instant.
7. No drag-to-reorder in playlist detail (only the Now Playing queue reorders).
8. "Lọc file dưới 30 giây" settings switch is decorative (does nothing).
9. Onboarding: hard 5 s delay before the OS permission prompt; fake progress bar;
   ≈7.6 s minimum dwell; rescans stack Home instances on the navigator.
10. No error UI on Home (scan errors masquerade as an empty library).
11. Long titles ellipsize (no marquee) on the player; artist names with no line cap
    can wrap awkwardly on the artist header.
12. Hidden-song restore and queue-remove rows vanish with no animation.
13. Touch targets below 48 dp: mini-player play 36, prev/next ≈34, queue remove ≈26.
14. Contrast: `textDisabled` used for real content at ~2.7:1 (dark) / ~2.0:1 (light)
    against a 4.5:1 requirement.
15. Icon-only controls widely lack semantic labels/tooltips; inactive nav tabs have
    no visible label.

### Accessibility summary
UI-02 font-scale clamp · UI-04 missing semantics · UI-05 small targets ·
UI-06 contrast — all confirmed findings from the project's own audit.

## 3. What a redesign proposal should deliver

Ranked by owner interest:

1. **Motion/transition coherence.** The app has a strong signature (400 ms slide-up,
   press-squeeze, easeOutBack pops) but also gaps: no hero/shared-element between
   list art → detail header → player disc; instant tab switches; no track-change
   animation; no list entrance/removal motion. Propose a coherent motion system —
   with durations/curves — that builds on the existing vocabulary and respects §1.2.
2. **Now Playing evolution.** The flagship screen (vinyl disc, flip-to-lyrics,
   morphing pill bar, deferred-blur queue). Proposals for layout, the fancy-mode
   visuals (waveform/pulse), and how visual modes could grow — within the 5 Hz signal
   reality documented in file 06 (live-audio or FFT ideas = new engineering, flag them).
3. **Consistency pass.** One search-field spec, one press-feedback rule, confirmed
   destructive actions, real Material FAB or consistent custom buttons, theme-safe
   colors everywhere, fixed wordmark.
4. **Light/AMOLED parity.** Make all three themes first-class (§2 items 1, 14).
5. **Empty/loading/error states.** Currently minimal (icon + text). Propose a
   consistent, cheap system (no heavy animation libraries).
6. **Onboarding flow tightening** (§2 item 9) — keep the personality (random quips,
   pulse) but reduce dead time.
7. **Accessibility remediation** folded into the above, not as an afterthought.

### Format requested from the designer
- Reference concrete screens/elements using the names in files 03–04.
- Give exact specs (dp, sp, hex or token names, ms, curves) — this pack proves the
  codebase runs on precise literals; vague direction is not actionable.
- Prefer the existing token names (`primary`, `surfaceElevated`, `onPlayerLow`, …)
  and note when a new token is needed.
- Separate clearly: **(A) polish within current constraints**, **(B) proposals that
  need owner approval** (glass expansion, new packages, live-audio, layout-structure
  changes), **(C) engineering prerequisites** (adaptive quality, FFT, etc.).
