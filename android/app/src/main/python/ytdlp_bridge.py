# android/app/src/main/python/ytdlp_bridge.py

import yt_dlp
import json
import os

# ─── Global progress state ───────────────────────────────────────────────────
_progress = {
    "status": "idle",
    "percent": 0.0,
    "speed": "",
    "eta": "",
    "filename": "",
    "error": "",
}

def get_progress():
    return json.dumps(_progress)

def reset_progress():
    global _progress
    _progress = {
        "status": "idle",
        "percent": 0.0,
        "speed": "",
        "eta": "",
        "filename": "",
        "error": "",
    }


# ─── JSON helper ─────────────────────────────────────────────────────────────
def _safe_json(obj):
    if isinstance(obj, dict):
        return {k: _safe_json(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_safe_json(i) for i in obj]
    if isinstance(obj, (str, int, float, bool)) or obj is None:
        return obj
    return str(obj)


# ─── Analyze ─────────────────────────────────────────────────────────────────
def analyze(url: str) -> str:
    flat_opts = {
        "quiet":        True,
        "no_warnings":  True,
        "ignoreerrors": True,
        "extract_flat": "in_playlist",
    }
    try:
        with yt_dlp.YoutubeDL(flat_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            if info is None:
                return json.dumps({"error": "Không lấy được thông tin"})

            all_entries   = [e for e in (info.get("entries") or []) if e is not None]
            valid_entries = [e for e in all_entries if e.get("id")]
            skipped       = len(all_entries) - len(valid_entries)
            is_playlist   = info.get("_type") == "playlist" or bool(all_entries)

            if is_playlist:
                result = {
                    "success":        True,
                    "_type":          "playlist",
                    "title":          info.get("title", "Playlist"),
                    "thumbnail":      (info.get("thumbnails") or [{}])[-1].get("url"),
                    "playlist_count": len(valid_entries),
                    "skipped_count":  skipped,
                    "formats":        [],
                }
                return json.dumps(_safe_json(result))

        video_opts = {
            "quiet":        True,
            "no_warnings":  True,
            "ignoreerrors": True,
            "extract_flat": False,
            "noplaylist":   True,
        }
        with yt_dlp.YoutubeDL(video_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            if info is None:
                return json.dumps({"error": "Không lấy được thông tin"})

            formats = []
            for f in (info.get("formats") or []):
                formats.append({
                    "format_id":       f.get("format_id", ""),
                    "ext":             f.get("ext", ""),
                    "resolution":      f.get("resolution") or f.get("format_note", ""),
                    "format_note":     f.get("format_note", ""),
                    "filesize":        f.get("filesize"),
                    "filesize_approx": f.get("filesize_approx"),
                    "vcodec":          f.get("vcodec", ""),
                    "acodec":          f.get("acodec", ""),
                    "fps":             f.get("fps"),
                    "tbr":             f.get("tbr"),
                    "abr":             f.get("abr"),
                    "height":          f.get("height"),
                    "width":           f.get("width"),
                })

            result = {
                "title":         info.get("title", ""),
                "duration":      info.get("duration", 0),
                "thumbnail":     info.get("thumbnail", ""),
                "uploader":      info.get("uploader", ""),
                "formats":       formats,
                "skipped_count": 0,
            }
            return json.dumps(_safe_json(result))

    except Exception as e:
        return json.dumps({"error": str(e)})


# ─── Download ─────────────────────────────────────────────────────────────────
def _make_progress_hook():
    def hook(d):
        global _progress
        status = d.get("status", "")

        if status == "downloading":
            downloaded = d.get("downloaded_bytes", 0) or 0
            total      = d.get("total_bytes") or d.get("total_bytes_estimate") or 1
            percent    = round(downloaded / total * 100, 1) if total else 0.0

            _progress = {
                "status":   "downloading",
                "percent":  percent,
                "speed":    d.get("_speed_str", "").strip(),
                "eta":      d.get("_eta_str", "").strip(),
                "filename": d.get("filename", ""),
                "error":    "",
            }

        elif status == "finished":
            filename = d.get("filename", "")
            print(f"[YTDLP_BRIDGE] hook: finished → filename={filename}")
            _progress["status"]   = "finished"
            _progress["percent"]  = 100.0
            _progress["filename"] = filename

        elif status == "error":
            _progress["status"] = "error"
            _progress["error"]  = str(d.get("error", "Unknown error"))
            print(f"[YTDLP_BRIDGE] hook: error → {_progress['error']}")

    return hook


def download(url: str, format_id: str, output_path: str = "") -> str:
    print(f"[YTDLP_BRIDGE] download() called")
    print(f"[YTDLP_BRIDGE]   url       = {url}")
    print(f"[YTDLP_BRIDGE]   format_id = {format_id}")
    print(f"[YTDLP_BRIDGE]   output_path = {output_path}")

    reset_progress()

    if not output_path:
        output_path = os.environ["HOME"]
        print(f"[YTDLP_BRIDGE]   output_path fallback to HOME = {output_path}")

    # Đảm bảo thư mục tồn tại
    os.makedirs(output_path, exist_ok=True)
    print(f"[YTDLP_BRIDGE]   output_path exists: {os.path.isdir(output_path)}")

    actual_format = format_id
    is_extract_audio = format_id in ("__extract_m4a__", "__extract_mp3__", "__extract_audio__")

    if is_extract_audio:
        actual_format = "bestvideo+bestaudio/best"
        print(f"[YTDLP_BRIDGE]   extract_audio mode → actual_format = {actual_format}")

    outtmpl = os.path.join(output_path, "%(title)s.%(ext)s")
    print(f"[YTDLP_BRIDGE]   outtmpl = {outtmpl}")

    skipped_videos = []

    ydl_opts = {
        "format":              actual_format,
        "outtmpl":             outtmpl,
        "quiet":               False,   # ← bật để thấy log yt-dlp trong console
        "no_warnings":         False,   # ← bật để thấy warnings
        "merge_output_format": "mp4",
        "progress_hooks":      [_make_progress_hook()],
        "postprocessor_hooks": [],
        "ignoreerrors":        True,
        "noplaylist":          is_extract_audio,
        # verbose log
        "verbose":             True,
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            original_report_error = ydl.report_error
            def patched_report_error(message, *args, **kwargs):
                print(f"[YTDLP_BRIDGE]   report_error: {message}")
                skipped_videos.append({"error": str(message)})
            ydl.report_error = patched_report_error

            print(f"[YTDLP_BRIDGE] Starting extract_info (download=True)...")
            info = ydl.extract_info(url, download=True)

            if info is None:
                print(f"[YTDLP_BRIDGE] extract_info returned None!")
                return json.dumps({"success": False, "error": "Không tải được"})

            print(f"[YTDLP_BRIDGE] extract_info done. _type={info.get('_type')}, title={info.get('title')}")

            if info.get("_type") == "playlist":
                entries = [e for e in (info.get("entries") or []) if e]
                print(f"[YTDLP_BRIDGE] Playlist: {len(entries)} downloaded, {len(skipped_videos)} skipped")
                return json.dumps({
                    "success":      True,
                    "title":        info.get("title", ""),
                    "downloaded":   len(entries),
                    "skipped":      len(skipped_videos),
                    "skipped_list": skipped_videos,
                    "path":         output_path,
                })

            # Single video
            raw_filename = ydl.prepare_filename(info)
            print(f"[YTDLP_BRIDGE] prepare_filename → {raw_filename}")

            # Fix: prepare_filename() không account cho merge_output_format
            # File thực tế luôn là .mp4 sau khi merge
            merge_fmt = ydl_opts.get("merge_output_format", "")
            filename = raw_filename

            if merge_fmt:
                base, old_ext = os.path.splitext(raw_filename)
                merged_filename = base + "." + merge_fmt
                if os.path.isfile(merged_filename):
                    filename = merged_filename

            # Fallback sang progress hook
            if not os.path.isfile(filename) and _progress.get("filename") and os.path.isfile(_progress["filename"]):
                filename = _progress["filename"]

            # Fallback lấy file từ info nếu yt-dlp trả về
            if not os.path.isfile(filename) and "requested_downloads" in info:
                for req in info["requested_downloads"]:
                    if req.get("filepath") and os.path.isfile(req["filepath"]):
                        filename = req["filepath"]
                        break

            # Kiểm tra file có thực sự tồn tại không
            file_exists = os.path.isfile(filename)
            print(f"[YTDLP_BRIDGE] File exists on disk: {file_exists} → {filename}")

            if not file_exists:
                try:
                    files_in_dir = os.listdir(output_path)
                    print(f"[YTDLP_BRIDGE] Files in output dir: {files_in_dir}")
                except Exception as e:
                    print(f"[YTDLP_BRIDGE] Cannot list dir: {e}")
                return json.dumps({
                    "success": False,
                    "error": f"File không tồn tại sau khi tải: có thể do thiếu quyền ghi vào {output_path}"
                })

            result = {
                "success": True,
                "path":    filename,
                "title":   info.get("title", ""),
                "skipped": 0,
            }
            print(f"[YTDLP_BRIDGE] Returning success: {result}")
            return json.dumps(result)

    except Exception as e:
        print(f"[YTDLP_BRIDGE] Exception: {e}")
        import traceback
        traceback.print_exc()
        _progress["status"] = "error"
        _progress["error"]  = str(e)
        return json.dumps({"success": False, "error": str(e)})


def get_playlist_entries(url: str) -> str:
    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "ignoreerrors": True,
        "extract_flat": "in_playlist",
    }
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            if info is None:
                return json.dumps({"success": False, "error": "Không lấy được thông tin"})

            entries = []
            for e in (info.get("entries") or []):
                if e is None or not e.get("id"):
                    continue
                entries.append({
                    "id":        e.get("id", ""),
                    "title":     e.get("title") or e.get("id", ""),
                    "thumbnail": e.get("thumbnail") or (e.get("thumbnails", [{}])[-1].get("url") if e.get("thumbnails") else None),
                    "duration":  e.get("duration"),
                    "url":       e.get("url") or e.get("webpage_url") or f"https://www.youtube.com/watch?v={e.get('id', '')}",
                    "uploader":  e.get("uploader") or e.get("channel", ""),
                })

            return json.dumps(_safe_json({
                "success": True,
                "title":   info.get("title", "Playlist"),
                "total":   len(entries),
                "entries": entries,
            }))

    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})