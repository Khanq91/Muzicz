# 02 — Design System (as implemented)

The app has a token-based theme (`ThemeExtension`, accessed as `context.appColors`) with
three presets: **Dark (default)**, **AMOLED**, **Light**. Material 3 is enabled.

> A legacy static color class hard-coded to the Dark palette still exists and is used by
> the Library sort menu and the entire downloader feature — those areas do **not**
> respond to theme changes. (Known issue.)

## 1. Color tokens — all three themes

Alpha notation: `@70%` means the color at 70 % opacity.

### Brand

| Token | Dark | AMOLED | Light | Usage |
|---|---|---|---|---|
| `primary` | `#9D50FF` | `#AA6FFF` | `#7C3AED` | Main purple: active states, play button, sliders, checkmarks |
| `primaryDark` | `#7B2FE0` | `#8840FF` | `#5B21B6` | declared, little use |
| `primaryLight` | `#BB82FF` | `#CC99FF` | `#9D5FF0` | waveform played bars |
| `secondary` | `#9B5CBF` | `#AA70D0` | `#8B5CF6` | gradient partner to primary |
| `tertiary` | `#C25169` | `#D4607A` | `#BE3A5A` | rose accent: favorites, destructive actions |

### Background / surface

| Token | Dark | AMOLED | Light | Usage |
|---|---|---|---|---|
| `background` | `#080808` | `#000000` | `#F8F7FC` | scaffold |
| `surface` | `#111111` | `#090909` | `#FFFFFF` | base surface, queue sheet |
| `surfaceElevated` | `#191919` | `#121212` | `#F3F1FA` | rows, text fields, snackbars, mini player |
| `card` | `#1C1C1E` | `#141414` | `#FFFFFF` | bottom sheets, dialogs, popups, nav bar |
| `cardHover` | `#242426` | `#1C1C1C` | `#EDE9F8` | declared hover |

### Text

| Token | Dark | AMOLED | Light |
|---|---|---|---|
| `textPrimary` | `#FFFFFF` | `#FFFFFF` | `#12101A` |
| `textSecondary` | white @70% | white @80% | `#3D3650` |
| `textTertiary` | white @50% | white @60% | `#706885` |
| `textDisabled` | white @30% | white @33% | `#B0A8C8` |

### Hairlines & glass

| Token | Dark | AMOLED | Light |
|---|---|---|---|
| `divider` | white @9% | white @7% | `#12101A` @10% |
| `border` | white @13% | white @10% | `#12101A` @13% |
| `glassBg` | white @10% | white @8% | **`#7C3AED` @10%** (primary-tinted, not white) |
| `glassBorder` | white @15% | white @13% | `#7C3AED` @15% |

### Accents (Home quick-access gradients)

| Token | Dark | AMOLED | Light |
|---|---|---|---|
| `accentCyan` | `#00BCD4` | `#00D9F5` | `#0097A7` |
| `accentMagenta` | `#E040FB` | `#F050FF` | `#AD1457` |
| `accentPink` | `#E91E63` | `#FF2D6B` | `#C2185B` |

### On-player ladder (white overlays over blurred album art — Now Playing screen)

Always white in every theme (the Now Playing background is always blurred artwork).

| Token | Dark | AMOLED & Light |
|---|---|---|
| `onPlayer` | white 100% | white 100% |
| `onPlayerHigh` | 70% | 80% |
| `onPlayerMedium` | 60% | 67% |
| `onPlayerLow` | 54% | 60% |
| `onPlayerSubtle` | 38% | 44% |
| `onPlayerMinimal` | 24% | 27% |
| `onPlayerGhost` (border) | 12% | 13% |
| `onPlayerGhostBg` | 8% | 9% |

### Scrims

Dark: black @55/50/45/30 % (`scrimDark/Medium/Light/Subtle`). AMOLED slightly darker,
Light slightly lighter.

Error color (all themes, fixed): `#CF6679`.

## 2. Gradients (all LinearGradient, 2 stops)

| Name | Direction | Dark | Usage |
|---|---|---|---|
| `primaryGradient` | topLeft→bottomRight | `#9D50FF`→`#9B5CBF` | progress fill, playlist covers, avatars, logo |
| `tertiaryGradient` | topLeft→bottomRight | `#C25169`→`#9B5CBF` | declared |
| `backgroundGradient` | top→bottom | `#0E0A18`→`#080808` | NowPlaying & detail-header base |
| `recentlyPlayedGradient` | L→R | `#9D50FF`→`#9B5CBF` | Home card 1 |
| `mostPlayedGradient` | L→R | `#E040FB`→`#9B5CBF` | Home card 2 |
| `favoritesGradient` | L→R | `#C25169`→`#E91E63` | Home card 3 |
| `randomMixGradient` | L→R | `#00BCD4`→`#9D50FF` | Home card 4 |
| `avatarButton` | L→R | `#9D50FF`→`#C25169` | Home avatar (NOT theme-adapted) |

AMOLED/Light variants swap in their preset's brand colors; backgroundGradient becomes
`#0A0515`→`#000000` (AMOLED) / `#F0EDF9`→`#F8F7FC` (Light).

## 3. Typography

Single family **Outfit** (google_fonts 6.3.2, fetched at runtime; no fonts bundled,
no fallback family declared). Weights used: w300 / w400 / w500 / w600 / w700.

Theme text roles overridden: displayLarge w700 ls−1.0; displayMedium w600 ls−0.5;
titleLarge w600 ls−0.2; titleMedium w500; bodyLarge w400 textSecondary;
bodyMedium w300 textSecondary; labelSmall w300 ls+0.3 textTertiary.

The app overwhelmingly styles text **inline** rather than via the text theme.
De-facto scale in use:

| Context | Size / weight | Color |
|---|---|---|
| Screen titles (Library, Online) | 20 / w700 | textPrimary |
| Home title "Muzicz Audio" | 24 / w700, ls −0.5 | textPrimary |
| AppBar title | 18 / w600 | textPrimary |
| Section headers ("Truy cập nhanh") | 18 / w600 | textPrimary |
| Sheet titles | 17–18 / w700 | textPrimary |
| Dialog titles | 16 / w600–700 | textPrimary |
| List tile title | 15 / w500 (w600 active) | textPrimary (primary active) |
| Tab labels | 14 / w600 sel, w400 unsel | primary / textTertiary |
| Body / dialog body | 14 / w400, line-height 1.5–1.6 | textSecondary/Tertiary |
| Nav labels | 13 / w600 | primary |
| List subtitles | 12 / w300–400 | textTertiary |
| Micro labels / badges | 10–11 / w300–600 | varies |
| NowPlaying track title | 22 / w700, ls −0.3 | onPlayer |
| NowPlaying eyebrow "ĐANG PHÁT" | 10 / w300, ls +2.5 | onPlayerLow |

## 4. Shape, spacing, motion scales (de-facto — there is NO token file; all literals)

- **Radius:** 2 (drag handle) · 6 (badge) · 8 · 10 (thumbnails, snackbars) · 12 (list
  tiles, buttons) · 14 (cards, popups) · 16 (dialogs, option tiles) · 18 (mini player,
  nav pill) · 20/22 (sheets, glass superellipse) · 24 (bottom sheets top) · 26 (nav bar).
- **Spacing:** 2–8 micro · 10–16 standard · 20 screen gutters · 24–40 section breaks.
  Screen horizontal gutter is typically 16–20; NowPlaying uses 28.
- **Motion:** 100–200 ms micro-interactions · 250–320 ms layout/theme · 350–400 ms
  panels/routes · 500 ms progress smoothing.
  Curves: `easeOutCubic` for movement, `easeOutBack` for pop-in confirmations,
  `easeInOut` for press squeezes. (Full catalog: file 05.)
- **Elevation:** almost none. Depth = soft colored shadows (primary @6–8 %, black @30 %,
  blur 16–32) + 0.5 dp hairline borders.
- **Haptics:** selectionClick on transport/toggles, lightImpact on flips/close,
  mediumImpact on long-press/apply/play.

## 5. Component themes (global)

| Component | Config |
|---|---|
| AppBar | transparent, elevation 0, no scrolled-under tint |
| TabBar | 2 dp primary underline indicator |
| Slider | track 3 dp, thumb r6, overlay r16, active primary (white on NowPlaying) |
| Divider | 0.5 dp, `divider` color |
| Card / PopupMenu | `card` bg, radius 14 |
| BottomSheet | `card` bg, top radius 24 |
| Switch | primary thumb + primary@35% track when on |
| Dialogs / Snackbars / Buttons / Inputs | **no global theme** — styled inline everywhere.
  Convention: dialogs = card bg radius 16; snackbars = surfaceElevated, floating,
  radius 10, 2 s, bottom margin 80 (16 when no mini player); text fields = filled
  surfaceElevated, radius 10–14, borderless at rest, 1 dp primary border on focus |

Ripple: `InkRipple`; list rows use splash primary@10 % / highlight primary@5 %.

## 6. Liquid glass — EXACTLY as shipped (scope is frozen; see file 07)

Package: `liquid_glass_widgets` **0.22.1** (the only glass package). Impeller enabled
on Android. Initialized and wrapped at app root.

### 6.1 Package-driven glass: exactly 2 UI surfaces, both opt-in via "Đồ họa → Xịn xò"

**A. Bottom navigation** — `GlassTabBar.bottom`: quality **premium**, masking **high**,
bar height 64, radius 26, padding 20/12, icon-label spacing 7, indicator primary@14 %,
interaction glow primary, per-tab glow colors (primary / secondary / tertiary).
Only the selected tab shows its label.

**B. Mini player** — `GlassCard`: height 68, margin 12/0/12/12,
`LiquidRoundedSuperellipse(borderRadius: 22)` (squircle), quality premium, own render
layer, settings: glassColor glassBg@5 %, **thickness 30, blur 3, lightIntensity 0.42,
chromaticAberration 0.012, ambientStrength 0.10, ambientRim 0.12, refractiveIndex 1.24,
saturation 1.35, glowIntensity 0.9** — a refractive slab that bends/saturates content
scrolling beneath, with rim light.

When fancy is on, the shell switches to a Stack so content runs full-bleed under the
floating glass mini player. Quality is **hard-coded premium** (a deliberate, recorded
user decision — no minimal/standard tiers, no adaptive quality, no restart dialog).

### 6.2 Manual BackdropFilter blurs: 4 shipped sites

| Site | Sigma | Notes |
|---|---|---|
| Now Playing background | **40** | full-screen album art blur + black@55 % scrim |
| Now Playing queue sheet | **10** | **deferred**: blur only activates after the slide-in finishes (solid @95 % while sliding → frosted @75 % once open) — the clearest deliberate blur-cost mitigation in the app |
| Artist detail header | **20** | artwork blur + scrimLight tint |
| Downloader glass cards | 12 | out of scope |

### 6.3 "Fake glass" (glass tokens as flat fills, no blur): 3 sites
Selector-sheet icon chips (44×44, glassBg fill + glassBorder) ×2, and the Welcome
secondary button (unused). A generic `GlassContainer` widget (blur 12) exists but is
**dead code** — referenced nowhere.

### 6.4 Planned but NOT implemented (from the liquid-glass plan doc)
App-wide glass mode; user-facing quality tiers; restart-required flow; glass
Scaffold/Button/Slider/Switch/ListTile/TextField/ProgressIndicator; adaptive quality;
a frame-timing performance advisor with auto-downgrade dialog. **None of this exists.**
Treat these as ideas that were considered, not as roadmap.

## 7. Shared component library (exact specs)

### 7.1 MusicListTile — the universal song row
Used on Home, Library Songs, Album/Artist/Playlist detail.
- Padding H16/V10, radius 12. Background animates 200 ms:
  transparent → primary@8 % (currently playing) → primary@14 % (selected).
- 48×48 album art, radius 10, surfaceElevated base; **1.5 dp primary border when
  active**; null art → music-note icon.
- Selection mode: 180 ms overlay on the art — primary@65 % + white check_circle when
  selected, black@35 % + circle outline when not; duration text hidden.
- Title 15 (w600+primary when active, else w500+textPrimary), 1 line ellipsis.
- Subtitle `"{artist} · {album}"` 12/w300 textTertiary. Trailing: duration 12/w300
  textDisabled (or custom).
- Long-press: medium haptic → context bottom sheet (card, top radius 20): grab handle
  36×4, song header, divider, then 4 actions — favorite toggle (heart, tertiary when
  on), add to playlist, play next (+snackbar), song info (5-row detail sheet with a
  fixed 90 dp label column).

### 7.2 MiniPlayer
68 dp bar; two surfaces (solid surfaceElevated r18 vs glass squircle r22 — §6.1).
Contents: 44×44 art r10 · title 14/w600 + artist 12/w300 · prev/next (22 dp icons,
press scale 1→0.85 in 120 ms forward-then-reverse) · play/pause = 36 dp primary circle
(150 ms icon scale-swap; spinner + 50 % dim while buffering) · close = 24 dp ghost
circle. Bottom edge: 2 dp progress line, primaryGradient fill animating width 500 ms.
Gestures: tap → NowPlaying; horizontal fling ±300 → skip; ✕ → confirm dialog if playing.

### 7.3 Bottom navigation (normal style)
Floating pill: card bg, radius 26, 0.5 border, shadows black@30 %/blur24 +
primary@6 %/blur32; inset 20 dp sides, 12 dp above home indicator.
Item: animated pill 300 ms easeOutCubic (padding+fill primary@14 %); icon 22 dp scales
to 1.08 in 250 ms easeOutBack; label appears only on the active tab via AnimatedSize
260 ms. Inactive tabs are icon-only.

### 7.4 AddToPlaylistSheet (YouTube-style)
Card bg, top radius 24, max 72 % height. Handle 36×4. Header "Lưu vào danh sách"
17/w700 + song title. Prominent "Tạo danh sách mới" button (primary@6 % fill, primary@45 %
border, radius 14, 38 dp circle icon chip). Search field appears at ≥3 playlists.
Rows: 46×46 cover r10 (gradient square for empty playlists), animated 26 dp circular
checkbox (200 ms easeOut: primary fill + white check ↔ ghost outline). Toggling does
NOT close the sheet; a floating snackbar confirms each change.

### 7.5 Selector sheets (Theme / Nav style / Music Visual — one shared pattern)
Card bg, top radius 24, handle, header (18/w700 title + 13 subtitle), and a right-side
**"Áp dụng"** button that fades in (200 ms) only when the selection differs from the
active value. Option cards: AnimatedContainer 200 ms — selected = primary@10 % fill +
1.5 dp primary border; unselected = surfaceElevated + 0.5 dp border; radius 16.
"Hiện tại" badge (10/w600 primary on primary@15 %) marks the applied option.
Check icon pops in with AnimatedScale 0→1, 180 ms **easeOutBack**.
Apply flow: medium haptic → pop sheet → wait 180 ms → apply (then the global 560 ms
black flash + 300 ms theme lerp play).
Theme selector options carry a 52×52 miniature "phone" swatch of each palette.

### 7.6 Empty states (shared pattern)
Centered icon 48–52 dp textDisabled · 12–16 gap · message 14, line-height 1.6,
textTertiary · optional primary FilledButton CTA (radius 12). **No illustrations,
no shimmer/skeletons anywhere** — loading is always a spinner or a 2 dp linear bar.
