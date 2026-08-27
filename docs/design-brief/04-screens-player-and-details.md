# 04 — Screens: Now Playing, Details & Profile

Tokens and shared widgets: see `02-design-system.md`. Sizes dp, type sp.

---

## 1. NOW PLAYING — the flagship screen

### 1.1 Entry / exit
Always entered via the shared 400 ms bottom slide-up (easeOutCubic), full-screen,
opaque. **No hero morph** from the mini-player artwork. On mount the entire foreground
fades in (400 ms easeOut) while the page slides. Exit: chevron-down (32, onPlayer),
system back, or a downward fling >400 px/s anywhere.

### 1.2 Background
Three full-bleed layers: backgroundGradient → current album art (cover-fit, old art
persists until the new one decodes — no crossfade) → **40-sigma blur** → flat black@55 %
scrim. Result: a soft color wash from the cover with guaranteed white-text contrast.

### 1.3 Layout (top → bottom, SafeArea column)
TopBar · 8 · FlipCard (art ↔ lyrics) · 28 · SongInfo · 20 · ProgressSection ·
ReactiveWaveform (0 dp normal / 48 dp fancy) · 20 · Controls · 16 · ExpandablePillBar ·
20 · SwipeHint. Queue panel overlays from the bottom (in-Stack, not a modal).

### 1.4 Top bar
- Left: chevron-down 32 onPlayer (pop).
- Center: eyebrow "ĐANG PHÁT" 10/w300 ls+2.5 onPlayerLow; below, a tappable underlined
  album name 12/w500 onPlayerHigh + a 9 dp chevron → opens the **album sheet**
  (DraggableScrollableSheet 0.4–0.92, initial 0.6: album header + track list with
  track numbers, equalizer icon on the playing row; tap plays in album context).
- Right: ⋮ popup (card bg, r14) — Favorite toggle · Thêm vào danh sách phát ·
  Sửa thông tin (edit-metadata sheet: two filled fields + Hủy/Lưu) · Ẩn khỏi thư viện
  (confirm dialog; confirming also pops the player) · Chia sẻ (snackbar stub) ·
  Thông tin bài hát (info sheet).

### 1.5 Cover art
A **circle** (vinyl styling), diameter = 70 % of screen width (≈273 on a 390-wide
phone), ClipOval. Two shadows: primary@30 % blur 60 offset(0,20) — a large purple
bloom — plus black@50 % blur 40 offset(0,16). Null art → primaryGradient disc with a
white@54 music-note icon 80.

Behavior by visual mode (see file 06 for internals):
- **Normal:** continuous rotation, one revolution / 20 s, linear; pauses in place when
  playback pauses.
- **Fancy:** rotation stops; the disc **pulses with the music** — scale 1.000→1.055
  (max +5.5 %), each step eased 140 ms easeOutCubic, driven by a precomputed amplitude
  envelope (fast attack / slow release). Shadows breathe with it.

Tap the disc → 3D flip to lyrics.

### 1.6 Lyrics (back of the flip card)
True 3D Y-axis flip: 400 ms easeInOutCubic with perspective; face swaps at 90°.
Light haptic on flip; auto-flips back when the track changes.

Lyrics view = same circular footprint, black@75 % fill. States: loading (24 dp primary
spinner + caption) / not found ("Không có lời bài hát") / error / list.
List: generously inset to stay inside the circle; each line animates 250 ms easeOut
between styles — active 15/w700 white, past 13 white@38, upcoming 13 white@60,
lh 1.5. Instrumental breaks show three 4 dp primary dots while active. Auto-scroll
centers the active line, 350 ms easeOutCubic (line height constant 52).

### 1.7 Song info row (28 dp gutters)
Title 22/w700 ls−0.3 onPlayer, 1 line ellipsis (**no marquee**). Subtitle
"{artist} · {album}" 14/w300 onPlayerMedium. Right: playlist-add icon 26 onPlayerLow;
favorite icon 26 (filled tertiary when on) with a 200 ms scale-swap + selection haptic.

### 1.8 Seek bar (28 dp gutters)
Local slider theme: white active track, white24 inactive, white thumb r6, overlay r16,
track 3 dp. While dragging, the thumb and elapsed label track the finger; on release it
seeks and holds the drag value 100 ms to avoid snap-back. Time labels 12 onPlayerLow,
MM:SS both sides. **No volume control anywhere** (hardware keys only).

### 1.9 Transport controls (spaceEvenly)
shuffle 24 (primary when on) · previous 36 white · **play/pause: 72 dp white circle**
(white@25 % blur-20 halo; glyph 38 colored the page background — a knockout; 150 ms
scale-swap between play/pause; press squeeze 1→0.92, 120 ms; medium haptic) ·
next 36 white · repeat 24 (repeat-one icon + primary when single-repeat).
Secondary icons squeeze 1→0.85 in 100 ms; all fire selection haptics.

### 1.10 Expandable pill bar
A single morphing pill, centered: collapsed **64×52** (ghost fill white@8 %, border
white@12 %, "⋯" icon) ⇄ expanded **280×52** (surfaceElevated@90 %, shadow) — 300 ms
easeOutCubic, contents crossfade 200 ms. Expanded row (5 items): Lyrics · Queue ·
Speed · Sleep timer · close. Active items get a primary@20 % circle + primary icon.

- **Speed sheet**: 7 chips (0.5–2.0×), 72×48 r12; selected = primary@18 % + 1.5 dp
  primary border; "1.0" reads "Bình thường"; "Đặt lại" appears when ≠1.
- **Sleep timer sheet**: status banner when armed (primary@12 % fill, bedtime icon,
  live countdown 15/w700 primary; "Hủy hẹn giờ" in tertiary) + six pill chips
  (5/10/15/30/45/60 phút).

### 1.11 Queue panel
Not a modal — an AnimatedPositioned panel inside the screen Stack: height 60 % of
screen, slides up 350 ms easeOutCubic. **Blur is deferred**: solid surface@95 % while
sliding, switches to a 10-sigma frosted surface@75 % only after landing. Top radius 24,
hairline top border. Header "Hàng chờ phát" 15/w700 + count + collapse chevron.
List is **drag-to-reorder** (the only reorder UI in the app): rows = 40 dp art r8 ·
title 14 (primary/w600 for the current track, tinted row primary@8 %, equalizer icon) ·
artist 12 · ✕ removes from queue. Tap a row jumps to it.
Bottom hint when closed: faint chevron-up + "Hàng chờ" 11 at white@24 %.

### 1.12 Gestures
| Gesture | Result |
|---|---|
| fling down >400 | dismiss |
| fling up <−400 (queue closed) | open queue |
| fling left/right ±300 | next / previous (ignored while lyrics showing) |
| tap disc / lyrics | flip |

Track changes are **instant swaps** — no slide/crossfade animation on the artwork.

### 1.13 Empty state
If nothing is playing, the screen is just background + the chevron back button.

---

## 2. Album detail

Standard Material push from the Albums grid. `CustomScrollView`, bouncing.

- **Collapsing header**: SliverAppBar expanded 280, pinned; back arrow hard-coded
  white. Layers: backgroundGradient → full-bleed album art (deliberately low filter
  quality — reads soft) → black@50 % scrim → centered sharp 120×120 cover (r14, black
  shadow) → centered info: album name 22/w700 white ls−0.3 (2 lines) + "{artist} ·
  {n} bài hát" 13/w300 white70. No collapsed title; the collapsed bar is an empty
  strip + back arrow.
- **Actions**: "Phát tất cả" (46 dp gradient primary→secondary, r12) + "Ngẫu nhiên"
  (flat surfaceElevated) side by side; then "Shuffle Loop" + 40×46 info button →
  explainer dialog. ⚠ These buttons have **no press feedback** (plain GestureDetector).
- Count label 13 textTertiary, then MusicListTile rows (tap → play from that song →
  NowPlaying), 40 dp tail. No empty/loading/error branches.

## 3. Artist detail

Sibling of Album detail with three differences:
- Header uses a genuine **20-sigma blur** over the artist artwork + scrimLight tint,
  and a centered **100 dp circular avatar** with a 2 dp primary border and a primary@30 %
  blur-20 glow (fallback: gradient + first letter 36/w700).
- Info: artist name 24/w700 (⚠ no maxLines — very long names wrap) + "{n} bài hát ·
  {m} album" 13/w300.
- **Album carousel** (only when >1 album): "Album" 16/w700, a 148 dp-tall rail of
  120-wide cards (art 120×100 r10 + name 12/w600 + "{n} bài" 11); tapping a card plays
  that album immediately → NowPlaying.
Then "Tất cả bài hát ({n})" 16/w700 + MusicListTile list.
⚠ Assumes a non-empty song list (would crash on empty).

## 4. Hidden songs

Plain AppBar screen ("Bài hát đã ẩn" 18/w700). Empty state: eye-off icon 52 +
"Không có bài hát nào bị ẩn". Rows: 44 dp placeholder square (hidden songs never show
real art) · title 14/w500 · artist 12 · "Khôi phục" text button (restore icon 16 +
label 13/w500 primary) → confirm dialog → row disappears with **no removal animation**.

## 5. Profile

Pushed from the Home avatar. Scroll body + MiniPlayer pinned at the bottom.

- **Header**: decorative 200 dp primary@12 % radial glow bleeding off the top-right;
  back arrow; identity row — 72 dp primaryGradient avatar circle (white person icon 36)
  + "Thính giả" 22/w700 + "Nocturne Audio" 13/w300 (both hard-coded; no editable profile).
- **Stats row**: three tinted stat cards (accent@10 % fill, accent@20 % border, r16):
  Bài hát (primary) / Nghệ sĩ (secondary) / Album (tertiary) — icon 22, value 22/w700,
  label 12/w300.
- Eyebrow "Chức năng" 13/w500 ls+0.5, then four action tiles (surfaceElevated r14,
  0.5 border; 42 dp tinted icon chip; title 15/w500 + subtitle 12 + chevron):
  Quét lại nhạc · Tải nhạc · Cài đặt · Về ứng dụng (⚠ about dialog says "Muzizc Audio
  v1.0.0 © 2026").

**Settings sheet** (card, top r20): group "Giao diện" — Bộ màu sắc (live theme icon +
subtitle + a 12 dp gradient swatch dot) / Đồ họa (nav style) / Music Visual (only when
the feature flag is on); group "Thư viện nhạc" — a "Lọc file dưới 30 giây" switch
(⚠ **decorative**: hard-coded on, does nothing) and "Bài hát đã ẩn" → Hidden songs.
Each row: surfaceElevated r12, 36 dp tinted icon chip, label 14/w500 + subtitle 12.
The three selector sheets follow the shared pattern in `02-design-system.md` §7.5.

---

## 6. Cross-cutting dialog/sheet conventions

- Dialogs: card bg, radius 16, title w600, body 14 lh1.6 textSecondary, cancel in
  textTertiary, confirm in primary (or tertiary when destructive). Default Material
  fade+scale (150 ms in / 75 ms out), barrier black54.
- Bottom sheets: card bg, top radius 20–24, 36×4 grab handle, default slide
  (250 ms in / 200 ms out), drag-to-dismiss on.
- Snackbars: floating, surfaceElevated, radius 10, 2 s, bottom margin 80 to clear the
  mini player.
