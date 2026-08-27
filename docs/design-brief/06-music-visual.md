# 06 — Music Visual Feature

The audio-reactive layer of the app. It is deliberately small, isolated, and opt-in.

## 1. Modes

Exactly **two** modes, chosen in Profile → Cài đặt → "Music Visual" (a selector sheet
following the shared pattern — see file 02 §7.5). Persisted; default is Normal.
A build-time kill switch (`kMusicVisualFeatureEnabled`, currently on) can remove every
entry point of the feature at compile time.

| | **Bình thường** (Normal, default) | **Xịn xò** (Fancy, opt-in) |
|---|---|---|
| Cover art | rotates continuously, 360° per **20 s**, pauses in place | rotation stopped; **amplitude-driven scale pulse** |
| Waveform strip | absent (zero height, zero cost) | 48 dp strip under the seek bar |
| Extraction / controllers | none created at all | per-track waveform extraction + 2 lightweight controllers |

⚠ The sheet's description for Fancy still reads "đang phát triển" (under development) —
stale copy; the effects are implemented.

## 2. The waveform strip (fancy mode)

**What it looks like:** a 48 dp-tall band aligned to the seek bar's 28 dp gutters.
**512 hairline bars** (≈0.75 dp wide with ~42 % gaps — they read as a dense field, not
discrete bars), **mirrored about the horizontal center line**, minimum 2 dp tall so
silence reads as a thin continuous center line. Flat colors, no gradients:
- Played portion: solid `primaryLight` (`#BB82FF` dark theme).
- Unplayed: white at ~17 % effective opacity.
- The played/unplayed boundary is a **hard vertical wipe** at the playhead; a bar
  straddling it is partially colored, which keeps progression looking smooth.

States: loading = a 2 dp indeterminate line; failed = a quiet static equalizer icon
(no error text, no retry).

**It is not interactive** — you cannot seek by touching it. Seeking stays on the
slider above.

**Where the data comes from:** the local audio file is decoded **once per track**
(native side, 100 waveform pixels/second), downsampled to 512 columns using **peak**
values, then **normalized to the track's own peak** — every track's loudest moment
touches full height, so quiet and loud tracks look equally tall. Results are cached on
disk per song (`{songId}_v1.wave`, atomic writes, corrupted files auto-deleted,
in-flight de-duplication so the waveform and the cover pulse share one decode).
⚠ The cache has **no size cap / eviction** — it grows forever (known, unaddressed).

Extraction is debounced 150 ms after a track change so rapid skipping never starts
decodes; a generation counter discards stale results.

## 3. The cover pulse (fancy mode)

Uniform **scale only** — no glow, rotation, color, or opacity change.
`scale = 1 + amplitude × 0.055` → range **1.000–1.055** (≈15 dp of diameter at peak on
a 273 dp disc). Each step animates 140 ms easeOutCubic. The cover's two shadows scale
with it, so the purple bloom subtly breathes.

The amplitude is sampled from the same precomputed 512-column envelope at the current
playhead (linear interpolation between columns), then shaped:
1. **Noise gate:** anything below 6 % amplitude is squashed to 0 (quiet passages sit
   perfectly still), remainder stretched back to 0–1.
2. **Fast attack / slow release:** one-pole smoothing, factor **0.58 rising** /
   **0.16 falling** — snappy onset, natural decay.
3. **Dead-band:** changes <0.001 emit nothing (no rebuilds during steady passages).
4. Pause snaps amplitude to 0 instantly.

## 4. Update rate — the key perf fact

**Everything the user sees is precomputed from the file; nothing listens to live
audio.** The whole system is driven by the player position stream at roughly **5 Hz**
(~200 ms ticks). The playhead wipe advances in visible ~200 ms steps (no interpolation);
the cover pulse feels smooth because each 5 Hz step is eased over 140 ms.

Implemented perf hygiene worth preserving in any redesign:
- Both visual subtrees live in their own `RepaintBoundary`.
- The waveform repaints at the **painter** level (a ValueNotifier playhead) — widgets
  never rebuild per tick.
- Controllers are per-widget, never in global app state — high-frequency signals can
  never rebuild the rest of the player UI (this was the plan's #1 identified risk).
- Normal mode constructs nothing: no subscriptions, no timers, no file I/O.
- Paint objects hoisted; no shaders, no saveLayer, no paths — just 1024 drawLine calls.

## 5. Planned but NOT implemented

- **Adaptive quality profile** (frame-timing-driven low/medium/high with hysteresis) —
  the largest missing piece; the plan mandated it before any particle/shader work.
- Cache eviction/LRU. Rolling (dynamic) peak normalization. Frequency-band mapping
  (bass/mid/treble — needs FFT). Beat detection. Particles/shaders. iOS support.

## 6. Android Visualizer POC (dev-only; do not design around it)

A hidden, Android-only debug screen reachable from the visual selector sheet only
while Fancy is active. It validates capturing **live** audio via Android's Visualizer:
its own separate player + file picker, capture 1024 bytes @ ~10 Hz, reduced natively
to RMS + peak scalars, streamed to Flutter. **It renders no graphics** — six numeric
telemetry rows (RMS, peak, packet count, packet rate, sequence gaps, sample rate).

It is the only code that touches the microphone permission (requested only from its
own "Realtime RMS" sub-toggle; choosing "Xịn xò" never prompts). It is deliberately
isolated from the production player — tests enforce this. Treat it as engineering
groundwork for possible future live-reactive visuals, not a user feature.

## 7. Design implications

- Any proposal to make visuals feel "more live" must contend with the 5 Hz signal:
  either interpolate/ease at the widget level (as the pulse does), or move to the live
  Visualizer path — which requires the microphone permission and the not-yet-passed
  stability gate from the POC.
- Any richer visual (particles, bands, beats) needs FFT and/or adaptive quality that
  do not exist yet — such proposals are welcome but must be flagged as new engineering
  with a performance plan (see file 07).
- The 48 dp waveform strip only exists in Fancy mode; Normal-mode layout has no gap
  there. A redesign that always reserves the space (or animates it in/out) would
  change the Normal layout — call it out explicitly if proposed.
