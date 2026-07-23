# Upstream Visual Delta Report

## Document Metadata

- Project hiện tại: Wavez.
- Upstream: `https://github.com/XxHuberrr/Mineradio.git`.
- Upstream ref: `upstream/main`.
- Upstream commit được pin khi phân tích: `6b130103f759e5dcd1e133700071c8216b8fa5a6`.
- Wavez ref: `HEAD`.
- Wavez commit được pin khi phân tích: `1c6e36de18150900cd1323279d791ff41e1aaca9`.
- Commit import đầu tiên của Wavez: `411fb58294631dcc09a89576d0e74c33b06a6960`.
- Ngày phân tích: 2026-07-23.
- Phạm vi: read-only Git/tree/source comparison; không sửa code.

## Executive Conclusion

Lượt diff trực tiếp giải quyết thiếu sót attribution của báo cáo forensic trước:

- Beat engine là **upstream-inherited**.
- Main particle shader và toàn bộ preset math là **upstream-inherited**.
- 3D lyrics là **upstream-inherited**.
- 3D playlist shelf/detail manager là **upstream-inherited**.
- Adaptive render quality/DPR là **upstream-inherited**.
- MediaPipe hand gesture system là **upstream-inherited**.
- Main render loop và coordination giữa beat/camera/shelf/lyrics là **upstream-inherited**.

Wavez đã thay đổi mạnh `public/index.html` về nguồn nhạc, route/provider adapter, localization, branding, Home/weather, local playlist và login flow. Tuy nhiên targeted diff không cho thấy Wavez viết lại các thuật toán visual cốt lõi kể trên.

Điểm bằng chứng mạnh nhất: tree `public/index.html`, `desktop/main.js`, `public/desktop-lyrics.html`, `server.js` của commit import đầu tiên Wavez `411fb58` khớp `upstream/main` hiện tại. Diff giữa hai tree ở các file này bằng 0; chênh lệch lúc import chỉ là các file kế hoạch/Zing/test bổ sung và 2 dòng thêm, 1 dòng xóa trong `package.json`.

Vì vậy attribution không còn chỉ dựa trên README hay comment: source visual Wavez bắt đầu từ đúng source upstream được fetch.

## 1. Git Topology and Comparison Method

### 1.1 Remote đã dùng

```text
origin   https://github.com/Khanq91/Wavez.git
upstream https://github.com/XxHuberrr/Mineradio.git
```

Lệnh thực hiện:

```bash
git remote add upstream https://github.com/XxHuberrr/Mineradio.git
git fetch upstream
git rev-parse HEAD
git rev-parse upstream/main
git merge-base HEAD upstream/main
git diff --stat upstream/main HEAD
git diff --numstat upstream/main HEAD -- public/index.html desktop/main.js public/desktop-lyrics.html server.js package.json
git diff --function-context upstream/main HEAD -- public/index.html
git grep -n -E "<target symbols>" upstream/main -- public/index.html
git grep -n -E "<target symbols>" HEAD -- public/index.html
git diff --stat upstream/main 411fb58
git diff --numstat upstream/main 411fb58 -- public/index.html desktop/main.js public/desktop-lyrics.html server.js package.json
```

### 1.2 Không có merge-base

`git merge-base HEAD upstream/main` không trả commit. Hai repository history là unrelated vì Wavez được import bằng một root commit mới thay vì fork Git ancestry.

Do đó cú pháp yêu cầu ban đầu:

```bash
git diff upstream/main...HEAD
```

không có semantics merge-base hợp lệ. Báo cáo dùng tree-to-tree comparison:

```bash
git diff upstream/main HEAD
```

Đây là phép so sánh đúng cho nội dung hai snapshot được pin. Không diễn giải triple-dot như thể hai branch có chung lịch sử.

### 1.3 Kiểm chứng snapshot import

`git diff --stat upstream/main 411fb58` chỉ hiện 14 file fork bổ sung:

- `debug-zing.js`
- `find-zing-secret.js`
- `test-zing.js`
- `zing-proxy.js`
- `wavez-plan/**`
- thay đổi rất nhỏ trong package metadata/lockfile

Các file runtime visual chính không có delta:

| File | Upstream → `411fb58` |
| --- | ---: |
| `public/index.html` | 0 dòng |
| `desktop/main.js` | 0 dòng |
| `public/desktop-lyrics.html` | 0 dòng |
| `server.js` | 0 dòng |
| `package.json` | +2 / -1 |

Điều này xác nhận initial Wavez visual source là bản sao exact của upstream snapshot đang so sánh.

## 2. Overall Delta

Tree diff `upstream/main` → Wavez `HEAD`:

```text
62 files changed
11,646 insertions
2,358 deletions
```

Các file runtime trọng tâm:

| File | Insertions | Deletions | Loại thay đổi chính |
| --- | ---: | ---: | --- |
| `public/index.html` | 1,888 | 1,531 | provider, localization, branding, Home/local playlist/login; visual copy/comments |
| `server.js` | 592 | 358 | Zing/YouTube/weather/routes; không phải visual renderer |
| `desktop/main.js` | 100 | 18 | branding/startup/installer/desktop integration |
| `public/desktop-lyrics.html` | 9 | 9 | wording/branding/fallback text |
| `package.json` | 14 | 17 | product/build/dependencies |

Raw line count làm delta trông lớn hơn mức thay đổi thuật toán visual vì nhiều literal/comment tiếng Trung được dịch sang tiếng Việt và music-provider paths được thay.

## 3. Symbol Alignment

Các entry point cốt lõi tồn tại ở cả hai snapshot:

| Subsystem | Upstream line | Wavez line | Kết luận sơ bộ |
| --- | ---: | ---: | --- |
| `renderQualityProfile()` | 3736 | 3789 | Inherited |
| `getRenderPixelRatio()` | 3743 | 3796 | Inherited |
| `beatBandRms()` | 4378 | 4431 | Inherited |
| `processRealtimeBeatEngine()` | 4391 | 4444 | Inherited |
| `scheduleBeatCamera()` | 4615 | 4668 | Inherited |
| `createLyricsParticles()` | 7319 | 7372 | Inherited |
| `updateStageLyrics3D()` | 8980 | 9033 | Inherited |
| `tickLyricsParticles()` | 9295 | 9348 | Inherited |
| `analyzeAudioBeats()` | 10389 | 10443 | Inherited |
| `shelfLayoutProfile()` | 12769 | 12823 | Inherited |
| `makeShelfManager()` | 12964 | 13018 | Inherited core |
| `makeContentListManager()` | 13924 | 13978 | Inherited core |
| `initAudio()` | 17728 | 17745 | Inherited |
| `processHandFrame()` | 24943 | 25083 | Inherited |
| `animate()` | 26620 | 26759 | Inherited core |

Line offset không phải bằng chứng thay đổi thuật toán. Targeted function-context diff được dùng để xem code bên trong từng subsystem.

## 4. Beat Engine Delta

### 4.1 Realtime beat engine

Các symbol sau đã có trong upstream:

- `beatBandRms()`
- `processRealtimeBeatEngine()`
- realtime band buffers/state
- confidence, strength, score, tempo lock và cooldown
- `scheduleBeatCamera()`

Không có hunk thay đổi trong body của `beatBandRms()` hoặc `processRealtimeBeatEngine()` ở targeted diff. Caller trong `animate()` vẫn dùng cùng contract `realtimeBeat.hit`, `low`, `body`, `snap`, `confidence`, `strength`, `score`.

**Verdict:** realtime beat engine nguyên từ upstream; không phải Wavez bổ sung.

### 4.2 Offline beat analysis

`analyzeAudioBeats()` tồn tại trong upstream với cùng:

- fetch/decode toàn bộ audio.
- `OfflineAudioContext` band filters.
- low/body/vocal/snap energy.
- 10 ms frame energy.
- onset positive difference.
- rolling mean/standard deviation threshold.
- sparse camera beat selection.
- MusicTempo worker integration.

Wavez diff trong vùng này chủ yếu là:

- dịch message/status/comment.
- đổi `fetchBeatPrefetchAudioUrl()`/provider route để bài Zing không chịu rule NetEase và URL có thể đi qua proxy/fallback.

Không tìm thấy thay đổi công thức beat-map cốt lõi.

**Verdict:** offline beat algorithm upstream-inherited; Wavez thay adapter lấy audio URL.

## 5. Particle Shader Delta

Main vertex shader, uniforms, ripple logic và preset branches đã có trong upstream:

- `SILK`
- `TUNNEL`
- `ORBIT`
- `VOID`
- các mode/preset còn lại trong shader
- cover/previous-cover color mix
- depth/edge texture
- `uBass`, `uMid`, `uTreble`, `uIntensity`
- mouse/hand uniforms
- ripple accumulation

Targeted shader diff cho thấy các expression và magic constants giữ nguyên, ví dụ:

```glsl
float K = uIntensity * 1.6;
pos.z = rippleZ * 1.30 + midDisp + trebleJ + bassBreath + depthZ;
```

Các dòng thay đổi trong shader block là comment localization, không phải GLSL behavior.

Wavez visual-adjacent additions ngoài shader:

- CSS source color/tag cho Zing và YouTube.
- branding/splash padding.
- About modal.
- translated FX labels.

**Verdict:** shader math/presets là upstream; Wavez không thay shader algorithm trong delta đã kiểm.

## 6. 3D Lyrics Delta

Các hệ thống upstream đã có:

- `createLyricsParticles()`.
- CanvasTexture/text geometry.
- previous/current/next lyric meshes.
- word/line progress handling.
- `updateStageLyrics3D()`.
- camera-facing/world transform.
- shelf/detail avoidance.
- `tickLyricsParticles()`.
- desktop overlay synchronization.

Targeted diff quanh `tickLyricsParticles()` không thay timing/progress logic. Hunk gần đó chỉ đổi comment của ripple system. `updateStageLyrics3D()` không có algorithm hunk riêng.

Wavez thay đổi input/source layer:

- thêm `/api/zing/lyric`.
- nhận diện provider `zing`.
- Zing hiện đưa LRC vào `lyric`; `yrc` rỗng.
- Việt hóa fallback/no-lyric message.

Điều này làm **dữ liệu lyric** khác nhưng không làm 3D lyric renderer trở thành code fork-specific.

**Verdict:** 3D lyrics renderer upstream-inherited; provider adapter và Vietnamese lyric source là Wavez-specific.

## 7. 3D Playlist Shelf Delta

Upstream đã có:

- `shelfLayoutProfile()`.
- responsive 3D card positions.
- `makeShelfManager()`.
- visible-radius/windowing.
- CanvasTexture cards.
- raycasting/click/wheel/key routing.
- center interpolation/inertia.
- `makeContentListManager()`.
- detail panel/card recycling.

Wavez thay đổi trong các manager:

- Vietnamese labels/status.
- provider/source labels.
- playlist/song data đi qua Zing/local/YouTube adapters ở các call site và playlist panel.
- Home public access/login gates.
- local playlist behavior và provider-prefixed IDs.

Không tìm thấy rewrite đối với layout profile, interpolation, raycast, window radius hoặc mesh/card architecture.

**Verdict:** 3D shelf/detail mechanics upstream-inherited; content/provider integration là fork-specific.

## 8. Adaptive Quality Delta

Upstream đã có:

- `renderQualityProfile()`.
- `getRenderPixelRatio()`.
- pixel-budget based DPR cap.
- `sampleRenderPerf()`.
- adaptive frame skip.
- performance profiles `eco`, `balanced`, `high`, `ultra`.
- render-loop integration.

Targeted diff không có body change cho `renderQualityProfile()` hoặc `getRenderPixelRatio()`. Các profile/budget công thức giữ nguyên.

**Verdict:** adaptive quality không phải Wavez bổ sung; nó thuộc upstream snapshot.

## 9. Gesture System Delta

Upstream đã chứa:

- MediaPipe Hands/camera flow.
- landmark smoothing.
- palm center/span normalization.
- openness/grip state.
- pinch/fist/open detection.
- ray-plane/local coordinate mapping.
- inertia rotation.
- hand skeleton HUD.

Trong `processHandFrame()` delta chỉ thấy:

- comment dịch sang tiếng Việt.
- HUD labels tiếng Việt.

Các threshold và motion math giữ nguyên, gồm pinch distance, openness gate, grip threshold, smoothing factor và inertia.

**Verdict:** gesture system upstream-inherited; Wavez chỉ localize presentation trong phần đã kiểm.

## 10. Main Loop and Coordination Delta

Upstream `animate()` đã phối hợp:

1. adaptive frame skip/perf sample.
2. Web Audio sampling.
3. realtime beat detection.
4. beat-map/camera scheduling.
5. ripple/float/shelf update.
6. lyric timing.
7. cinematic/free camera.
8. particle/skull layers.
9. 3D lyric transform.
10. desktop overlay sync.
11. renderer output.

Wavez vẫn giữ ordering này. Các call `processRealtimeBeatEngine()`, `scheduleBeatCamera()`, `tickLyricsParticles()`, `updateStageLyrics3D()` tồn tại cùng vai trò.

Delta sau/vòng quanh main loop chủ yếu là startup/Home/login/provider logic và localized comments.

**Verdict:** coordination architecture cũng là upstream-inherited.

## 11. Desktop Lyrics Delta

`public/desktop-lyrics.html` có raw delta +9/-9. Nội dung thay đổi là wording/branding/fallback text; render loop, state bridge và canvas drawing architecture giữ nguyên.

`desktop/main.js` có thay đổi branding/startup handling, nhưng `createDesktopLyricsWindow()` và IPC concept vẫn là upstream.

**Verdict:** desktop lyrics overlay architecture upstream-inherited; Wavez-specific phần presentation/integration nhỏ.

## 12. Fork-specific Visual-adjacent Changes

Các thay đổi thực sự thuộc Wavez nhưng không phải rewrite visual core:

| Khu vực | Delta Wavez |
| --- | --- |
| Source identity | CSS tags/colors cho Zing/YouTube |
| Search/Home | Zing-only search, Vietnamese Home/weather card |
| Playback | Zing/YouTube URL and fallback notice |
| Lyrics input | `/api/zing/lyric`, provider routing, Vietnamese fallback |
| Playlist content | Zing/local provider IDs và loaders |
| Branding | Wavez wordmark, icon, About/Credits |
| Localization | UI/HUD/FX labels/comments sang tiếng Việt |
| Login | legacy NetEase/QQ modal disabled |
| Local music | local playlist + YouTube integration |

Các thay đổi này ảnh hưởng dữ liệu và UI bao quanh visual, nhưng không chuyển ownership của shader/beat/3D/gesture algorithms sang fork.

## 13. Commit-history Corroboration

Sau root import `411fb58`, các commit chạm `public/index.html` tập trung vào:

- wire Zing search/stream/lyric.
- Zing playlist detail.
- YouTube fallback.
- Vietnamese Home/weather.
- localization.
- branding/About.
- public Zing Home access.
- local playlist.
- legacy login cleanup.

Không có commit message hoặc targeted diff cho thấy một subsystem visual core mới được thêm sau import.

Commit history chỉ là corroboration; bằng chứng chính vẫn là tree diff.

## 14. Attribution Matrix

| Subsystem | Upstream ownership | Wavez delta | Confidence |
| --- | --- | --- | --- |
| Web Audio graph | Có | Provider URL compatibility | CONFIRMED |
| Realtime beat engine | Có | Không thấy algorithm delta | CONFIRMED |
| Offline beat map | Có | URL adapter/status localization | CONFIRMED |
| Beat camera | Có | Không thấy algorithm delta | CONFIRMED |
| Particle shader | Có | Comment/localized surrounding UI | CONFIRMED |
| Ripple system | Có | Comment localization | CONFIRMED |
| 3D lyrics | Có | Zing LRC adapter/fallback text | CONFIRMED |
| 3D shelf | Có | Provider/content/labels | CONFIRMED |
| Detail manager | Có | Provider routes/content | CONFIRMED |
| Adaptive DPR/quality | Có | Không thấy core delta | CONFIRMED |
| Gesture system | Có | Vietnamese HUD/comments | CONFIRMED |
| Main render loop | Có | Startup/provider-adjacent changes | CONFIRMED |
| Desktop lyrics overlay | Có | Branding/text | CONFIRMED |
| Zing/YouTube visuals identity | Không | Wavez addition | CONFIRMED |
| Weather/Home Vietnamese experience | Không | Wavez addition | CONFIRMED |

## 15. Important Nuance

“Inherited” không có nghĩa Wavez không có công sức kỹ thuật. Fork đã thực hiện integration đáng kể để:

- thay music source mà không phá Web Audio/beat analysis.
- chuẩn hóa provider records cho queue/shelf/player.
- proxy Range audio để seek/analyze.
- duy trì lyric flow với LRC Việt Nam.
- thêm fallback YouTube.
- giữ visual coordination hoạt động sau localization và login cleanup.

Nhưng về attribution thuật toán visual, các hệ thống cốt lõi phải được credit cho Mineradio/XxHuberrr.

## 16. Limitations

- Report pin `upstream/main` tại commit cụ thể; upstream có thể đổi sau ngày phân tích.
- Không chạy pixel-by-pixel screenshot regression giữa hai app.
- Không profile runtime upstream và Wavez side-by-side.
- Không dùng blame cross-repo vì histories unrelated.
- Một số function lớn có nhiều string/comment/provider changes; kết luận “không rewrite core” dựa trên targeted function-context diff, không phải tuyên bố hai file byte-identical ở HEAD.
- Upstream main hiện khớp Wavez import runtime tree; nếu upstream force-push hoặc tag lịch sử khác, cần pin lại commit/hash.

## 17. Final Answer to the Missing Questions

1. **Beat engine có nguyên từ upstream không?** Có. Realtime và offline beat algorithms đều đã tồn tại trong exact upstream snapshot được import.
2. **Shader nào đã được fork chỉnh?** Không tìm thấy shader algorithm được Wavez chỉnh; shader diff quan sát được là comment localization.
3. **3D lyrics thay đổi gì?** Renderer/timing/world transform giữ từ upstream; Wavez đổi lyric provider/input sang Zing LRC.
4. **3D shelf thay đổi gì?** 3D mechanics giữ từ upstream; Wavez đổi content/provider integration và labels.
5. **Adaptive quality là upstream hay fork?** Upstream.
6. **Gesture system thuộc phiên bản nào?** Đã có trong upstream snapshot `6b130103` và trong Wavez root import `411fb58`; Wavez localize HUD/comment.
7. **Fork bổ sung visual core mới không?** Không tìm thấy trong phạm vi targeted diff. Fork bổ sung visual-adjacent provider identity, Home/weather, fallback notices, branding và localization.

## 18. Recommended Attribution Wording

Wording nên dùng trong tài liệu:

> Wavez kế thừa hệ thống music visual cốt lõi từ Mineradio của XxHuberrr, gồm Web Audio/beat analysis, Three.js particle shaders, cinematic camera, 3D lyrics, 3D playlist shelf, adaptive rendering và MediaPipe gesture. Wavez tập trung thay nguồn nhạc sang Zing MP3/YouTube fallback, Việt hóa trải nghiệm, bổ sung Home/weather/local-playlist integration và duy trì tương thích giữa provider mới với visual pipeline kế thừa.

Không nên mô tả beat engine, shader, shelf, 3D lyrics, gesture hoặc adaptive quality là subsystem do Wavez tự tạo.
