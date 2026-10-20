# Lyrics in Muzicz

Open Now Playing → lyrics. The page menu contains search, import, editing,
export, offset, display preferences, AI configuration and translation.

## Sources

- Persistent per-track cache, including manually assigned lyrics and translations.
- Embedded MP3 ID3 USLT/SYLT, FLAC/Ogg Vorbis/Opus comments, and M4A lyrics.
- LRCLIB exact lookup, followed by searches using original, cleaned and
  transliterated metadata. Automatic matching checks title, artist, version
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

## Verification

Service tests cover parsing, imports, embedded metadata, matching, fallback,
cache, request races and AI timestamp preservation/error handling. Widget tests
cover the fullscreen lyrics page at 320 px and 150% text scaling. Android debug
build verifies the Kotlin platform channel and encrypted settings integration.
