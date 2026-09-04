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

**Ghi kết quả:**
- 1080p preset: …
- 720p preset: …
- Tab Video, dòng 720p: …
- Audio: …

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
