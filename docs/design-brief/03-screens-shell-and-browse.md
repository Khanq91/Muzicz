# 03 — Screens: Startup, Shell & Browse

Color/typography tokens and shared widgets (MusicListTile, MiniPlayer, bottom nav,
AddToPlaylistSheet, selector sheets) are specified in `02-design-system.md`.
All copy is Vietnamese; English glosses in parentheses. Sizes in dp, type in sp.

---

## 1. Splash

Background `background` with a static 260 dp radial primary@8 % glow disc centered.

- **Logo** (96 dp circle, primaryGradient fill, primary@40 % glow shadow, white
  headphones icon 48): scales 0.7→1.0 with easeOutBack overshoot + fades in, 900 ms,
  starting at t=200 ms.
- **Wordmark**: "Muzicz" 36/w700 ls−1.0 + "AUDIO" 13/w300 ls+6 textTertiary — fades and
  slides up 30 % of own height, 700 ms, starting t=600 ms.
- **Equalizer loader** (bottom, 60 dp up): 5 bars, 4 dp wide, 6 dp gaps, vertical
  primary→primaryLight@50 % gradient; heights ping-pong 4 → 24/32/40/24/32 dp with
  staggered periods 380/460/540/620/700 ms — never synchronized.
- Exits after ≥1300 ms via 600 ms fade to Welcome (first run) or Home.

## 2. Welcome (first run only)

Background + two static corner glows: 300 dp primary@12 % bleeding off top-left,
250 dp tertiary@8 % off bottom-right. Whole content block fades + slides up (800 ms).

Centered column: logo 64 · "Muzic" 28/w700 (⚠ hard-coded white — invisible on Light
theme; also missing the final "z") · "AUDIO" 11/w300 ls+5 · 2-line tagline 14/w300
textTertiary lh1.6 ("Trải nghiệm âm nhạc trong tầm tay. Tất cả từ bộ sưu tập của bạn.").

CTA: full-width 56 dp gradient pill (primary→secondary, radius 16, primary@35 % blur-20
shadow) — "Quét nhạc trên máy" with search icon; press squeezes to 0.96 (120 ms), and
the action fires only after the release animation. A secondary outlined "skip" button
is commented out.

## 3. Onboarding / Scan (also the app-wide rescan screen)

Centered column, 32 dp gutters:
- **Pulse icon**: 100 dp radial halo (primary 30 %→5 %) containing a 64 dp gradient
  disc with a white graphic-eq icon. Scale 1.0↔1.12 and opacity 0.5↔1.0, 1200 ms
  ping-pong, frozen when the scan ends.
- **Status block** (400 ms cross-fade between 4 states):
  1. *Scanning*: one random quip out of 20 (poetic/humor/quotes/facts — some contain
     emoji) 18/w400 textSecondary; "Đang quét nhạc của bạn…" 15/w600; "Chỉ mất vài
     giây, hứa!" 13/w300 textDisabled.
  2. *Success*: two stat rows stagger in (music-note icon primary + "N bài hát"
     22/w600; person icon tertiary + "M nghệ sĩ") — row 2 lags 120 ms.
  3. *Permission denied*: error icon `#CF6679` 42 · "Cần quyền truy cập nhạc" 20/w600 ·
     explainer 14 · "Thử lại" FilledButton (+ "Mở cài đặt" OutlinedButton only when
     permanently denied).
  4. *Error*: same layout, "Không thể quét thư viện".
- **Progress bar**: 4 dp track (divider) with a glowing primary→secondary gradient
  fill (primary@40 % blur-6). Fake progress: →30 % over 800 ms at start, →100 % over
  600 ms on success; frozen on failure. Hidden in the two failure states.
- On success: 2 s dwell → 500 ms fade to Home.

## 4. Home tab

`CustomScrollView`, bouncing physics, no pull-to-refresh.

**(a) Header** (padding 20/16/12/8): left — time-of-day greeting ("Chào buổi sáng/
chiều/tối") 14/w300 textTertiary over "Muzicz Audio" 24/w700 ls−0.5. Right — rescan
button (40×40; refresh icon 22 textTertiary; becomes an 18 dp primary spinner while
scanning; only shown after the first successful scan) and a 40 dp avatar circle
(avatarButton gradient, white person icon) → Profile.

**(b) Pinned search bar** (64 dp persistent header): backdrop animates transparent →
background@95 % the moment content scrolls beneath (200 ms). Field: filled
surfaceElevated, radius 14, hint "Tìm bài hát, nghệ sĩ, album…" 15 textDisabled,
search prefix, clear suffix when non-empty, 1 dp primary border on focus.

**(c) Body — 3 exclusive states:**
1. *Search active*: flat list of MusicListTiles; empty-results state (search-off icon
   48, "Không tìm thấy kết quả", hint line).
2. *Initial scan*: centered 28 dp primary spinner + "Đang tải thư viện nhạc…".
3. *Normal*: Quick Access + Smart Lists + 120 dp bottom clearance.

**(d) Quick Access** — "Truy cập nhanh" 18/w600, then a 160 dp-tall horizontal rail of
four 140×160 cards, radius 18, margin-right 12:

| Card | Icon | Gradient | Data |
|---|---|---|---|
| "Nghe gần đây" | history | `#9D50FF→#9B5CBF` | last played, max 20 |
| "Nghe nhiều nhất" | trending_up | `#E040FB→#9B5CBF` | most played |
| "Yêu thích" | favorite | `#C25169→#E91E63` | favorites |
| "Random Mix" | shuffle | `#00BCD4→#9D50FF` | 20 shuffled |

Card layers: gradient base → first song's album art ghosted at 25 % opacity → bottom
scrim (transparent→black@50 %) → content (icon 28 white@90 % top; title 13/w600 white +
"{n} bài" 11/w300 white@70 % bottom). Press: scale 1.0→0.95, 120 ms. **Tap plays the
list but does not navigate** — only the mini player appears.

**(e) Smart lists** — up to two groups, 5 MusicListTiles each: "Mới thêm gần đây"
(recently added) and "Chưa từng nghe" (never played). Both empty → shared empty state
with "Quét thư viện ngay" CTA.

No dedicated error UI — scan errors surface as the empty state.

## 5. Online tab (placeholder)

Fully static "coming soon" page. Hero: 88 dp circle primary@12 % fill + primary@20 %
border with a wifi icon 38 primary; "Đang phát triển" 22/w700; 2-line explainer
14/w300 lh1.65. Eyebrow "Sắp có" 13/w500 ls+0.5. Then four non-tappable feature tiles
(surfaceElevated, radius 14, 0.5 border): 42 dp tinted icon chip (secondary/primary/
accentCyan/tertiary at 12 %) + title 15/w500 + subtitle 12 + a small primary badge
pill ("Sớm"/"Sắp có"/"Đang phát triển", 10/w500). Zero states, zero animation.

## 6. Library tab

Hand-rolled header (no AppBar): back arrow (standalone mode only) · "Thư viện" 20/w700
· 18 dp scanning spinner when relevant · sort popup (A→Z / Mới thêm / Thời lượng;
⚠ uses the static dark palette, doesn't re-color on Light).

Below: a 2 dp scan LinearProgressIndicator that grows in (300 ms) while scanning;
a search field (filled, radius 12, hint "Tìm trong thư viện…" — slightly tighter than
Home's); a search-scope hint row that expands 0→28 dp when typing ("Tìm trong thư viện
cục bộ · N bài" 11 textDisabled).

**Tab bar**: scrollable, left-aligned, 5 tabs with animated count badges (primary@15 %
pill, 10/w600): Bài hát · DS Phát · Album · Nghệ sĩ · Thư mục. Content **cross-fades**
200 ms on tab tap — there is no swipe between tabs.

- **Songs**: pull-to-refresh (triggers full rescan). MusicListTile rows; tap plays the
  sorted list from that song → NowPlaying; long-press enters selection mode.
- **Playlists**: see §7.
- **Albums**: 2-column grid, gap 16, cells 0.78 aspect — square art radius 12 (album
  icon 40 placeholder) + name 13/w600 1-line + "{n} bài" 11. Tap → Album detail.
- **Artists**: ListTile rows — 48 dp circular artist art (placeholder: first letter
  18/w700 primary on surfaceElevated) · name 15/w500 · "{n} bài hát" 12 · chevron.
- **Folders**: rows with a 48 dp primary@15 % rounded square + folder icon primary;
  tap plays the whole folder immediately → NowPlaying.
- Each tab has the shared empty state with a "Quét ngay" CTA (Songs adds a search-tip
  card + "Xóa tìm kiếm" when a query yields nothing).

**Selection mode** (long-press, medium haptic): search/tab bar disappear; header
becomes ✕ · "{n} bài đã chọn" 17/w600 · "Chọn tất cả"; a bottom action bar (card bg,
top hairline) offers Playlist / Yêu thích (primary) / Ẩn (tertiary, destructive).
Rows show the checkbox overlay on their art. Actions confirm via floating snackbars;
Hide asks first ("Ẩn {n} bài hát?" — file gốc không bị xóa); bulk-add opens a 60 %-height
playlist sheet.

## 7. Playlists

**Playlists tab**: list of tiles — 52 dp cover (4 variants: custom image; gradient
square + playlist icon when empty; single album art; **2×2 mosaic** of first four
arts) · name 15/w600 · "{n} bài · 1h 23m" 12 · ⋮ menu with a single destructive
"Xóa" (deletes immediately, ⚠ no confirmation). A custom 56 dp gradient FAB
(primaryGradient circle, ⚠ fully-opaque primary glow shadow, no ripple/press feedback)
opens the create dialog. Tap tile → Playlist detail.

**Playlist detail**: collapsing SliverAppBar (expanded 260, pinned; ⚠ white back/edit
icons sit on `background` when collapsed — invisible on Light theme). Header layers:
backgroundGradient → cover (custom at 100 % or first song's art at 40 %) → bottom scrim
into background@95 % → name 26/w700 white + "{n} bài hát" 14/w300 white@70 %.

Actions: "Phát tất cả" (46 dp gradient button, radius 12) + "Ngẫu nhiên" (flat
surfaceElevated) side by side; below, "Shuffle Loop" full-width + a 40×46 info button
opening an explainer dialog. List header "{n} bài hát" + "Thêm bài" link (primary).

Song list: MusicListTiles in playlist order; trailing is a remove-circle icon that
deletes from the playlist instantly (no confirm); long-press still opens the standard
context menu. ⚠ No drag-to-reorder despite a code comment claiming it.

"Thêm bài" sheet: DraggableScrollableSheet (70 % initial, 40–95 %) listing songs not
yet in the playlist; tapping adds one song and closes. Rename via the app-bar edit icon.
