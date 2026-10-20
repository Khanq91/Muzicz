# Lyrics in Muzicz

Open Now Playing → lyrics. The bottom toolbar menu contains search, import, editing,
export, offset, display preferences, AI configuration and translation.

## Sources

- Persistent per-track cache, including manually assigned lyrics and translations.
- Android TagLib properties (`LYRICS`, `SYNCEDLYRICS`, `TTML`,
  `UNSYNCEDLYRICS`), preferring valid synchronized fields over plain fields.
  The bounded Dart reader remains a fallback for MP3 ID3 USLT/SYLT,
  FLAC/Ogg Vorbis/Opus comments, and M4A lyrics.
- LRCLIB exact lookup, followed by searches using original, cleaned and
  transliterated metadata, simplified collaborators, smart titles and title-only
  queries. Automatic matching checks title, artist, version
  markers and duration; manual search lets the listener preview and choose.
- Adjacent LRC/TTML/TXT files and a library sidecar scan.
- File import, pasted text, editing, original-format export and LRC/TXT export.

Preferences select embedded-first, online-first or local-first order. Saved
lyrics take precedence until refreshed or cleared. Muzicz stores assignments in
its own application directory and does not rewrite audio files.

## Display

Fullscreen scrolling lyrics, line highlighting, enhanced LRC/TTML word timing,
translation/romanization supplied by TTML, tap-to-seek, per-track timing offset,
font size, alignment, blur, immersive mode and an optional keep-awake flag.
Word highlighting requires word timestamps in the source; LRCLIB usually
provides line timestamps.

The full-screen layout follows PixelPlayer's `LyricsSheet`: rotating cover
in a fixed track capsule, top/bottom fades, 78dp morphing play/pause button,
50dp wavy seek capsule, bottom back/synced/static/more toolbar and inline
timing controls. Horizontal swipes change tracks. Seeking previews lyrics
without committing audio seeks until release. Colors use Muzicz theme tokens.

The entry/exit uses PixelPlayer's 220/180ms slides (1/5 and 1/6 screen height)
and 160/120ms fades. Track changes fade/scale over 300ms; the cover rotates
once every eight seconds and pauses in place. Animated lyrics are optional,
as in PixelPlayer: scale 1.1/.95/.85, padding 32/16/8, opacity 1/.6/.3,
distance-based blur capped at 10, and a stiffness-50/damping-ratio-.5 spring.
Autoscroll targets viewport center minus 32dp and uses 450ms normally or the
line interval clamped to 250–2000ms in animated mode. Immersive mode enlarges
text by 1.4 and hides the controls. Left/center/right alignment is supported.

## AI

Configure Gemini or an OpenAI-compatible HTTPS endpoint, API key, model and
target language from the lyrics menu. Models can be fetched or entered manually.
The Android configuration is encrypted using AndroidKeyStore and stored outside
Android backup directories.

Translation sends batches of lyric text to the chosen service only when invoked.
The response must contain every requested line in order. Original line and word
timestamps are retained, with translation stored separately as TTML. The dialog
supports cancellation and preview; Apply saves to the originally selected song,
even if playback has since changed.

API usage may incur charges under the listener's service account. Tests use
mock responses and do not validate a real account, quota or model.

## PixelPlayer-specific boundary

PixelPlayer also retrieves AMLLDB lyrics for tracks already identified by a
NetEase song ID. Muzicz currently has a local-file SongItem model without
NetEase IDs or its streaming integration, so that ID-based source is not
enabled here. TTML from that source can still be imported. The implementation
does not claim arbitrary audio fingerprint recognition or guaranteed lyrics
for tracks with missing/incorrect metadata.

This is a Flutter port, not a binary copy of the Compose UI. In particular,
native predictive-back effects and PixelPlayer's NetEase integration are not
ported. Android transliteration uses ICU rather than PixelPlayer's separate
language romanizers. Import/export use Muzicz's platform file picker.
TagLib is pinned to 1.0.5 with Kotlin 2.2.21 for the existing SDK 36 build;
PixelPlayer's 1.0.6 requires SDK 37 and additionally supports Matroska.

## Verification

Service tests cover parsing, imports, embedded metadata, matching, fallback,
cache, request races and AI timestamp preservation/error handling. Widget tests
cover the fullscreen lyrics page at 320 px and 150% text scaling. Android debug
build verifies the Kotlin platform channel and encrypted settings integration.

### Reported untagged remix regression

The supplied `Anh Đau Từ Lúc Em Đi ... (Duzme Remix) ... Official Lyrics.m4a`
contains only the MP4 encoder tag (`Google`), no title/artist/lyrics tags,
and lasts 323.361 seconds. The old search sent the full filename as a title;
its token-coverage matcher rejected the shorter LRCLIB title.

The regression fixture contains LRCLIB metadata only, with synthetic lyric
text inserted by the test. It verifies smart-title fallback, whole-phrase
matching, rejection of the 374-second original and selection of synchronized
remix lyrics. A live service check returned 78 timed lines.

Run offline checks:

```sh
flutter test test/services/lyrics_test.dart test/services/lyrics_ai_test.dart test/screens/queue_and_lyrics_test.dart
```

Optional real-network smoke check (not part of ordinary tests):

```sh
flutter test --dart-define=LYRICS_LIVE=true test/services/lyrics_live_test.dart
```

UI tests exercise mode switching and animated layout at 320px with 150% text.
`LYRICS_SCREENSHOT=true` saves a preview in `build/lyrics-review`;
`LYRICS_FONT_PATH` can point to the Flutter SDK's `roboto-regular.ttf`
(beside `materialicons-regular.otf`) for a readable local render.
Device animation/performance and native metadata extraction still require an
Android device; no ADB device was connected during this review.
