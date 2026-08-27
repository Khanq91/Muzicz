# 05 — Animation & Transition Catalog (exhaustive)

Every animation in the main app (downloader excluded). All specs verified in source.
Flutter defaults that apply app-wide: modal bottom sheets 250 ms in / 200 ms out,
barrier black54, drag-to-dismiss on; dialogs fade+scale 150 ms in / 75 ms out;
`MaterialPageRoute` = Android zoom+fade ≈300 ms; no custom page-transitions theme;
no reverse-duration overrides anywhere (pops replay the same curve backwards).

## Master table

| Name | Screen | Trigger | Type | Duration | Curve |
|---|---|---|---|---|---|
| Theme cross-fade | app root | theme change | color lerp | 300 ms | easeInOut |
| Theme flash overlay | app root (global) | theme/nav/visual apply | fade to 45 % black & back | 280 ms ×2 | easeInOut |
| Splash logo scale | Splash | open +200 ms | scale 0.7→1.0 | 900 ms | **easeOutBack** |
| Splash logo fade | Splash | same controller | fade 0→1 | first 60 % of 900 ms | linear |
| Splash text fade | Splash | open +600 ms | fade | 700 ms | easeOut |
| Splash text slide | Splash | open +600 ms | slide (0,0.3)→0 | 700 ms | easeOutCubic |
| Splash EQ bars ×5 | Splash | infinite loop | height 4→24/32/40 | 380/460/540/620/700 ms ping-pong | easeInOut |
| Splash → next | Splash | startup done | route fade | 600 ms | linear |
| Welcome content | Welcome | open | fade + slide (0,0.2)→0 | 800 ms | easeOut / easeOutCubic |
| CTA press squeeze | Welcome (pattern) | tap down/up | scale 1→0.96 | 120 ms | easeInOut |
| Pulse icon | Onboarding | loop while scanning | scale 1↔1.12 + opacity 0.5↔1 | 1200 ms ping-pong | easeInOut |
| Status swap | Onboarding | scan state change | AnimatedSwitcher fade | 400 ms | linear |
| Progress phase 1 / 2 | Onboarding | scan start / done | width →30 % / →100 % | 800 / 600 ms | linear / easeOut |
| Result rows stagger | Onboarding | scan done | fade+slide (0,0.3)→0 | 600 ms; intervals 0–0.6 & 0.2–0.8 | easeOutCubic |
| Onboarding → Home | Onboarding | +2 s | route fade | 500 ms | linear |
| Home tab switch | Home shell | nav tap | **none** (IndexedStack) | 0 | — |
| Search bar tint | Home | scroll >0 | container color | 200 ms | linear |
| Quick card press | Home | tap down/up | scale 1→0.95 | 120 ms | easeInOut |
| Nav pill resize+fill | Bottom nav | tab tap | container | 300 ms | easeOutCubic |
| Nav icon pop | Bottom nav | tab tap | scale 1→1.08 | 250 ms | **easeOutBack** |
| Nav label reveal | Bottom nav | tab tap | AnimatedSize | 260 ms | easeOutCubic |
| Mini progress line | MiniPlayer | position tick | width | 500 ms | linear |
| Mini play/pause bg | MiniPlayer | buffering | color primary↔primary@50 % | 150 ms | linear |
| Mini play/pause icon | MiniPlayer | isPlaying | switcher + scale | 150 ms | linear |
| Mini prev/next press | MiniPlayer | tap | scale 1→0.85, fwd **then** rev (≈240 ms total, action after) | 120 ms ×2 | easeInOut |
| → NowPlaying (all 9 sites) | app-wide | play/tap | route slide (0,1)→0 | 400 ms | easeOutCubic |
| NowPlaying appear | NowPlaying | open | fade whole content | 400 ms | easeOut |
| Cover rotation (normal) | NowPlaying | loop while playing | 360° rotation | 20 s/rev | linear |
| Cover pulse (fancy) | NowPlaying | audio amplitude | scale 1→1.055 per step | 140 ms | easeOutCubic |
| Art ↔ lyrics flip | NowPlaying | tap | 3D rotateY 0→π, perspective | 400 ms | easeInOutCubic |
| Lyric line style | NowPlaying | active line change | AnimatedDefaultTextStyle 13/w400→15/w700 | 250 ms | easeOut |
| Lyric auto-scroll | NowPlaying | line change | animateTo centered | 350 ms | easeOutCubic |
| Queue panel | NowPlaying | swipe up / button | AnimatedPositioned −60 %→0; blur deferred to onEnd | 350 ms | easeOutCubic |
| Queue reorder settle | NowPlaying | drag row | ReorderableListView default | 250 ms | easeInOut |
| Pill bar morph | NowPlaying | tap ⋯/✕ | width 64→280 + bg/border/shadow | 300 ms | easeOutCubic |
| Pill content crossfade | NowPlaying | same | two AnimatedOpacity layers | 200 ms | linear |
| Play button press | NowPlaying | tap | scale 1→0.92 | 120 ms | easeInOut |
| Play/pause icon | NowPlaying | isPlaying | switcher + scale | 150 ms | linear |
| Secondary icon press | NowPlaying | tap | scale 1→0.85 | 100 ms | easeInOut |
| Favorite heart | NowPlaying | toggle | switcher + scale | 200 ms | linear |
| Seek release hold | NowPlaying | drag end | 100 ms delayed release of drag value (anti snap-back) | 100 ms | — |
| Speed chip | Speed sheet | tap | container fill/border | 150 ms | linear |
| Library tab crossfade | Library | tab tap | switcher fade (no swipe!) | 200 ms | easeOut in / easeIn out |
| Scan bar reveal | Library | scanning | height 0→2 | 300 ms | linear |
| Scope hint reveal | Library | typing | height 0→28 | 200 ms | easeOut |
| Tab count badge | Library | count change | container | 200 ms | linear |
| Row bg tint | MusicListTile | active/selected | container | 200 ms | linear |
| Selection overlay | MusicListTile | select toggle | container tint + icon swap | 180 ms | linear |
| Playlist checkbox | AddToPlaylist sheet | toggle | 26 dp circle fill/border | 200 ms | easeOut |
| Selector option card | selector sheets | tap | fill/border | 200 ms | linear |
| Selector check pop | selector sheets | select | scale 0→1 | 180 ms | **easeOutBack** |
| "Áp dụng" fade | selector sheets | pending change | opacity 0↔1 | 200 ms | linear |
| Apply sequencing | selector sheets | apply | haptic → pop → 180 ms wait → apply | 180 ms | — |
| Collapsing headers | Album/Artist/Playlist detail | scroll | SliverAppBar parallax/fade | scroll-linked | — |
| Waveform playhead | NowPlaying (fancy) | position tick (~5 Hz) | CustomPainter clip repaint | per tick | — |
| Amplitude envelope | fancy mode | position tick | attack 0.58 / release 0.16 one-pole | per tick | — |

## Signature motion patterns

1. **Press-squeeze** — nearly every custom button scales down 0.85–0.96 over
   100–120 ms easeInOut on tap-down and fires its action only after the reverse
   completes (adds ~120–240 ms latency to every tap — a deliberate feel choice).
2. **easeOutBack pop** — reserved for confirmations and state arrival: nav icon,
   selector check marks, splash logo.
3. **The 400 ms easeOutCubic bottom slide** — the app's one signature route
   transition, duplicated inline at 9 call sites.
4. **Deferred blur** — the queue sheet slides opaque, then frosts once landed
   (perf-driven staging worth preserving in any redesign).
5. **Chained apply** — sheet pops (200 ms) → 180 ms gap → 560 ms black flash +
   300 ms theme lerp.

## Notable absences (opportunities, but see constraints file first)

- **No Hero transitions anywhere** — album art never morphs list → detail → player.
- **No marquee** — long titles ellipsize.
- **No shimmer/skeletons, Lottie, Rive, flutter_animate** — loaders are plain spinners.
- **No swipe-between-tabs** (Home = IndexedStack instant, Library = fade-only).
- **No Dismissible** swipe-to-delete; removal is via buttons/menus.
- **No list-item entrance/stagger animations** (except the Onboarding result rows).
- **No animated track-change** in the player (artwork swaps instantly).
- **No press feedback** on detail-screen action buttons and the playlist FAB.
- **No removal animations** in lists (rows vanish on rebuild).
- **No custom route transitions** besides the three recipes (slide-up + two fades).
