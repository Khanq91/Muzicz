# 01 — App Overview & Flows

**App:** Muzicz Audio · Flutter · version `2.0.0+18` · UI language: Vietnamese
**Typeface:** Google Fonts **Outfit** everywhere (no other family).
**Orientation:** portrait only (both ways up). Landscape never allowed.
**System UI:** transparent status + navigation bars, edge-to-edge drawing; screens
compensate with `SafeArea` individually. Status bar icons light (assumes dark boot theme).

## 1. Boot sequence (exact order)

1. Liquid-glass renderer initialized (`liquid_glass_widgets` 0.22.1).
2. Background audio + media notification initialized (non-dismissible while playing).
3. Orientation locked to portrait.
4. Transparent system bars, edge-to-edge mode.
5. App runs with two state systems side by side: **Riverpod** (used only by the
   downloader feature) and **provider/ChangeNotifier** (everything else).
6. Five global providers above `MaterialApp`: MusicProvider (library),
   PlayerProvider (playback), LyricsProvider, VisualModeProvider, ThemeProvider.
7. `MaterialApp`: no named routes for the main app (`home: SplashScreen`);
   theme cross-fade 300 ms `easeInOut`; a global `ThemeSwitchWrapper` overlay wraps
   every route (see §5). Only downloader routes (`/dl/*`) are named.

## 2. Startup flow with branches

```
COLD START
  └─ SplashScreen (minimum 1300 ms)
       ├─ first run (never completed a scan) ──fade 600 ms──▶ WelcomeScreen
       └─ returning user ──fade 600 ms──▶ HomeScreen
             (a silent background library rescan starts immediately, not awaited)

WelcomeScreen
  └─ tap "Quét nhạc trên máy" (gradient CTA) ──push, Material default──▶ OnboardingScreen
     (push, not replace — Welcome stays on the stack)

OnboardingScreen  (the library-scan screen; ALSO reused as the app-wide "rescan" screen)
  ⏱ hard 5-second intro delay (skipped on retry) → OS permission prompt appears ~5 s in
  ├─ scan OK → progress bar completes (600 ms) → result rows stagger in (600 ms)
  │            → 2 s dwell → pushReplacement, fade 500 ms ──▶ HomeScreen
  ├─ permission denied → blocked; "Thử lại" button; "Mở cài đặt" only if permanently denied
  └─ scan error → blocked; "Thử lại" only
```

Minimum time on the Onboarding screen when entered fresh ≈ **7.6 s**
(5 s intro + scan + 0.6 s progress + 2 s result dwell).

First-run flag is cleared **only after a successful scan** — a user who never completes
a scan sees Welcome again on every launch.

## 3. Main shell

`HomeScreen` is a persistent 3-tab shell using an `IndexedStack` (all tabs stay alive,
**instant** tab switch, no animation):

| Tab | Icon | Label | Content |
|---|---|---|---|
| 0 | home_rounded | "Home" | Home feed (greeting, search, quick-access cards, smart lists) |
| 1 | language_rounded | "Trực tuyến" | Static "coming soon" placeholder |
| 2 | library_music_rounded | "Thư viện" | Library with 5 sub-tabs (Songs / Playlists / Albums / Artists / Folders) |

Vertical order at the bottom of the screen: **content → MiniPlayer (68 dp, only when a
song is loaded) → bottom navigation bar**.

Bottom nav has two user-selectable styles ("Đồ họa" setting):
- **"Bình thường" (normal, default)** — a floating card pill; mini player is a solid
  container that occupies layout space (pushes content up).
- **"Xịn xò" (fancy)** — real refractive liquid glass bar; mini player becomes a glass
  card and **floats over** full-bleed content (shell switches from Column to Stack).

## 4. Complete navigation map

```
HomeScreen (shell)
  ├─ Home tab
  │    ├─ tap song row / search result ──400 ms slide-up──▶ NowPlayingScreen
  │    ├─ tap Quick Access card → starts playback ONLY (no navigation)
  │    ├─ tap ⟳ refresh / empty-state CTA ──Material──▶ OnboardingScreen (rescan)
  │    └─ tap avatar ──Material──▶ ProfileScreen
  ├─ Online tab — no outbound navigation
  └─ Library tab (5 sub-tabs, cross-fade 200 ms between them, NOT swipeable)
       ├─ Songs: tap ──slide-up──▶ NowPlaying · long-press → multi-select mode
       ├─ Playlists: tap ──Material──▶ PlaylistDetailScreen
       ├─ Albums: tap grid tile ──Material──▶ AlbumDetailScreen
       ├─ Artists: tap row ──Material──▶ ArtistDetailScreen
       └─ Folders: tap → plays folder + ──slide-up──▶ NowPlaying

MiniPlayer (Home / standalone Library / Profile)
  ├─ tap ──400 ms slide-up──▶ NowPlayingScreen
  ├─ swipe left/right (velocity ±300) → next/previous track (no navigation)
  └─ tap ✕ → confirm dialog "Dừng phát nhạc?" (only if playing)

Album/Artist/Playlist detail → any play action ──slide-up──▶ NowPlayingScreen

NowPlayingScreen
  ├─ swipe down (>400 px/s) / chevron → pop
  ├─ swipe up → in-screen queue panel (not a modal sheet)
  ├─ swipe left/right → next/prev track (disabled while lyrics showing)
  ├─ tap cover → 3D flip to lyrics
  ├─ album-name row → album bottom sheet
  └─ ⋮ menu → favorite / add-to-playlist / edit metadata / hide / share / info

ProfileScreen
  ├─ "Quét lại nhạc" ──▶ OnboardingScreen
  ├─ "Tải nhạc" ──▶ Downloader feature (OUT OF SCOPE)
  ├─ "Cài đặt" → settings bottom sheet
  │     ├─ "Bộ màu sắc" → ThemeSelectorSheet (Dark/AMOLED/Light)
  │     ├─ "Đồ họa" → BottomNavStyleSelectorSheet (normal/fancy glass)
  │     ├─ "Music Visual" → VisualModeSelectorSheet (normal/fancy visuals)
  │     └─ "Bài hát đã ẩn" ──▶ HiddenSongsScreen
  └─ "Về ứng dụng" → stock About dialog
```

### Route transition recipes (only three custom ones exist)

| Recipe | Spec | Used for |
|---|---|---|
| **Player slide-up** | 400 ms, slide from bottom `(0,1)→(0,0)`, `easeOutCubic` | every path into NowPlayingScreen (9 call sites) |
| **Startup fades** | 600 ms fade (Splash→next), 500 ms fade (Onboarding→Home), linear | startup only |
| **Everything else** | plain `MaterialPageRoute` → Android default zoom+fade ≈300 ms | all detail screens, Profile, rescan |

No Hero animations exist anywhere in the app (two code comments say "Hero header" but
no `Hero` widget is present). No deep links, no route guards, no `go_router`.

## 5. Global theme-switch behavior

Changing theme, nav style, or visual mode triggers a **full-screen black flash overlay**:
280 ms fade in + 280 ms fade out (`easeInOut`), peaking at **45 % black**, masking the
300 ms theme lerp underneath. Selector sheets pop first, wait 180 ms, then apply — so
the sheet exit, the flash, and the theme lerp chain without fighting each other.

## 6. Timing cheat-sheet

| Moment | Duration |
|---|---|
| Splash minimum | 1300 ms |
| Splash logo entrance | 900 ms (starts t=200) |
| Splash text entrance | 700 ms (starts t=600) |
| Splash → next fade | 600 ms |
| Welcome content entrance | 800 ms |
| Button press scale (app-wide pattern) | 120 ms down + 120 ms up |
| Onboarding intro delay | **5000 ms** |
| Onboarding fake progress | 800 ms → 30 %, then 600 ms → 100 % |
| Onboarding result stagger | rows at 0–360 ms and 120–480 ms |
| Onboarding result dwell | 2000 ms |
| → NowPlaying slide-up | 400 ms easeOutCubic |
| Theme cross-fade | 300 ms easeInOut |
| Theme flash overlay | 280 ms × 2, peak 45 % black |
| Mini-player progress tween | 500 ms |
| Play/pause icon morph | 150 ms |

## 7. Content model (what data every screen shows)

**Song:** title, artist (fallback "Unknown Artist"), album (fallback "Unknown Album"),
album art (queried from device MediaStore by albumId; may be null → placeholder icon),
duration formatted `MM:SS`, file path, date added, play count (tracked), favorite flag.

**Playlist:** name, ordered song list, optional custom cover image, created date;
derived song count and total duration (`"3h 24m"` / `"45m"` format).

Album art everywhere uses `keepOldArtwork: true` — when a track changes, the previous
artwork stays painted until the new one decodes (no flash), but there is **no crossfade**.

## 8. Known flow-level quirks a designer should know

1. Repeated rescans **stack Home instances** (Onboarding is pushed but exits via
   pushReplacement to a *new* HomeScreen).
2. The Onboarding 5-second delay happens *before* the permission prompt.
3. Onboarding progress is **fake** (0→30 %→100 %), unrelated to real scan progress.
4. Welcome's secondary "continue without scanning" button is commented out — first-run
   users cannot get past Welcome except by scanning.
5. Wordmark inconsistency: splash says "**Muzicz**", welcome says "**Muzic**".
6. About dialog says version "1.0.0" while the app is 2.0.0, and misspells the name
   as "Muzizc Audio".
