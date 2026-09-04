# Muzicz — Việc cần test tay trên máy thật
_Tạo 2026-09-03 trong session review. Mỗi mục: làm theo bước, ghi kết quả ngay dưới mục đó (hoặc báo cho Claude Code) để chốt việc tiếp theo trong `plan/REVIEW_PLAN.md`._

## 1. Downloader: preset video có ra file có tiếng không? (chốt câu hỏi 3 của REVIEW_PLAN)
**Tại sao phải test:** các preset "Tốt nhất / 1080p / 720p / 480p" dùng selector `bestvideo+bestaudio` (`lib/features/downloader/screens/format/format_screen.dart:63-96`). yt-dlp sẽ tải hình và tiếng thành 2 file rồi cần ffmpeg để ghép, nhưng APK chỉ cài yt-dlp (`android/app/build.gradle.kts`, khối chaquopy pip). Dự đoán: ra `Tên video.f137.mp4` (không tiếng) + `Tên video.f140.m4a` rời, hoặc app báo lỗi. Ngoài ra tab "Video" đang liệt kê cả stream chỉ-có-hình (`video_info.dart:140`), nên chọn dòng "1080p" trong tab cũng có thể ra mp4 câm.

**Bước test (máy thật, có mạng):**
1. Hồ sơ → Tải nhạc từ URL (Gateway) → Analyze: dán link 1 video YouTube ngắn (1-2 phút) có bản 1080p.
2. Format: chọn preset **1080p** → Bắt đầu tải. Chờ xong, mở Summary.
3. Mở thư mục tải (mặc định `Download/MuziczModule` hoặc thư mục đã chọn) bằng app Files:
   - [ ] Có đúng 1 file `.mp4`? Hay 2 file (`.f137.mp4` + `.f140.m4a`, hoặc `.mp4` + `.m4a` cùng tên)?
   - [ ] Mở file `.mp4` bằng trình phát ngoài: **có tiếng không?**
   - [ ] Summary báo "thành công" hay lỗi? Lỗi thì ghi nguyên văn.
4. Lặp lại với preset **720p**, và với tab **Video** chọn thủ công dòng "720p" (không qua preset). Ghi kết quả từng lần.
5. (Tuỳ chọn) Preset **Audio / m4a**: vẫn ra `.m4a` nghe được như Phase 6 đã test?

**Ghi kết quả (2026-09-04, Claude Code chạy trên emulator Pixel_9_Pro API 37 + host, APK debug build từ HEAD 825a569, yt-dlp 2026.8.19 trong APK):**
- Video test: `https://youtu.be/Z4C82eyhwgU` (Caminandes 2, 2:26, có 1080p). Với video ĐƠN, màn Format không có preset — preset 1080p/720p chỉ hiện cho playlist; tab Video liệt kê từng stream.
- Tab Video, dòng 1080p (format 137): ra đúng 1 file `＂Caminandes 2： Gran Dillama＂ - Blender Animated Short.mp4` 52.740.343 byte = đúng kích thước stream 137. Soi atom MP4: chỉ 1 track `vide` (avc1), **không có track audio** → mp4 câm. Summary báo "Tải thành công". Log: `Downloading 1 format(s): 137` (không hề thử ghép).
- Tab Video, dòng 720p (format 136): yt-dlp thấy file cùng tên đã có → `[download] 100% of 50.30MiB` sau 27 ms, KHÔNG tải, task báo xong trỏ vào file 1080p cũ (tái hiện `outtmpl_collision` của Phase 12).
- Preset 1080p/720p (`bestvideo[height<=N]+bestaudio/best[height<=N]`): mô phỏng trên host với cùng yt-dlp 2026.8.19, không ffmpeg (giống APK) → `WARNING: You have requested merging of multiple formats but ffmpeg is not installed. The formats won't be merged` → 2 file rời `.f399.mp4`/`.f398.mp4` (video-only, av01) + `.f251.webm` (audio opus). Chú ý `bestaudio` chọn **webm/opus** chứ không phải m4a.
- Audio (tab Audio, m4a 129kbps = format 140): không chạy lại được trong session này vì app bị ANR khi khởi động lại (xem ghi chú ngoài phạm vi Phase 10). Phase 6 đã test OK.
- **Phát hiện quyết định:** yt-dlp 2026.8.19 cảnh báo `No supported JavaScript runtime could be found ... YouTube extraction without a JS runtime has been deprecated, and some formats may be missing`. Không có JS runtime (deno/node/bun/quickjs — Chaquopy trên Android không có cái nào) thì YouTube **không trả về stream muxed nào** (18/22 biến mất; `-j` xác nhận 0 format có cả vcodec lẫn acodec). Tab Video còn lẫn 2 dòng "Default, low/high · mp4" = format 233/234 (HLS audio-only, `vcodec=none`, `acodec=null`) do lọc `!isAudioOnly`.
- Kết luận cho câu 3 REVIEW_PLAN: phương án B (chỉ hiện stream có cả hình lẫn tiếng) với YouTube = tab Video TRỐNG; phương án A cần ffmpeg binary cho arm64/x86_64 (+ vài chục MB). Đề xuất C: tải `bestvideo[ext=mp4]+bestaudio[ext=m4a]` (yt-dlp để lại 2 file `.fNNN.mp4` + `.fNNN.m4a`) rồi ghép bằng `MediaMuxer` phía Kotlin (app đã có `AudioExtractor.kt` dùng MediaExtractor/MediaMuxer) — không thêm dung lượng, không cần ffmpeg; giữ B làm bộ lọc cho các site khác vẫn có muxed. Xem `REVIEW_PLAN.md` câu hỏi 3.

**Sau khi có kết quả:**
- File câm / tách 2 file → chọn A hoặc B ở REVIEW_PLAN câu 3 (khuyên B: chỉ hiện stream có sẵn cả hình lẫn tiếng) rồi mở session Phase 12.
- File có tiếng bình thường → ghi lại cách yt-dlp ghép được (có ffmpeg ở đâu?), bỏ mục `video_merge_no_ffmpeg` khỏi Phase 12, chỉ giữ `video_only_formats`.

## 2. Phase 8: thanh tiến trình sau khi ấn X trên mini player (đã sửa ở commit e7e83e5, chưa test máy)
1. Phát 1 bài → mở Now Playing → vuốt xuống đóng → ấn X trên mini player.
2. Phát bài khác (Home hoặc Library).
   - [ ] Thanh tiến trình mini player chạy từ 0:00.
   - [ ] Mở Now Playing: slider + thời gian chạy; lời bài hát (nếu có) tự cuộn; chế độ Fancy: waveform/bìa nhịp theo nhạc.
3. Lặp lại 2-3 lần, thử cả khi ấn X lúc đang phát (có hộp thoại xác nhận) và lúc đã tạm dừng.

**Ghi kết quả:** …

## 3. Sau Phase 10 (đã làm 2026-09-04, chưa test máy): hết hàng chờ + Phát tiếp theo
- [ ] Phát playlist ngắn 2-3 bài, repeat tắt, để chạy hết: nút về "play", thanh về 0:00 ở bài đầu; shuffle bật thì bài đầu là bài ngẫu nhiên mới; bấm play nghe từ đó.
- [ ] Menu bài hát: "Phát tiếp theo" → bài đó đứng ngay sau bài đang phát trong hàng chờ; "Thêm vào hàng chờ" → đứng cuối.

**Ghi kết quả:** …
