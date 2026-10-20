import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/song_item.dart';
import '../../providers/lyrics_provider.dart';
import '../../providers/music_provider.dart';
import '../../services/lyrics_parser.dart';
import '../../services/lyrics_service.dart';

void lyricsMessage(BuildContext context, Object message) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.toString().replaceFirst('FormatException: ', '')),
      ),
    );
  }
}

Future<void> importLyrics(BuildContext context, SongItem song) async {
  final provider = context.read<LyricsProvider>();
  try {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withReadStream: true,
    );
    if (pick == null) return;
    final file = pick.files.single;
    final maximum = LyricsService.maxBytes(file.extension ?? '');
    if (file.size > maximum) throw const FormatException('File lời quá lớn');
    final stream =
        file.readStream ??
        (file.path != null ? File(file.path!).openRead() : null);
    if (stream == null) throw const FormatException('Không đọc được file');
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (bytes.length + chunk.length > maximum) {
        throw const FormatException('File lời quá lớn');
      }
      bytes.add(chunk);
    }
    final result = LyricsService.importBytes(bytes.takeBytes(), file.name);
    await provider.assign(song, result);
    if (context.mounted) lyricsMessage(context, 'Đã gán lời cho ${song.title}');
  } catch (e) {
    if (context.mounted) lyricsMessage(context, e);
  }
}

Future<void> exportLyrics(
  BuildContext context, {
  bool plain = false,
  bool original = false,
}) async {
  final provider = context.read<LyricsProvider>();
  final document = provider.document, song = provider.song;
  if (document == null || song == null || !document.hasLyrics) return;
  final raw =
      original
          ? document.raw
          : LyricsParser.export(document.lines, synced: !plain);
  final extension =
      original && raw.trimLeft().startsWith('<')
          ? 'ttml'
          : plain || !document.isSynced
          ? 'txt'
          : 'lrc';
  try {
    final saved = await FilePicker.platform.saveFile(
      dialogTitle: 'Lưu lời bài hát',
      fileName:
          '${song.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}.$extension',
      type: FileType.any,
      bytes: Uint8List.fromList(utf8.encode(raw)),
    );
    if (saved != null && context.mounted) {
      lyricsMessage(context, 'Đã xuất lời bài hát');
    }
  } catch (e) {
    if (context.mounted) lyricsMessage(context, e);
  }
}

Future<void> editLyrics(BuildContext context, SongItem song) async {
  final provider = context.read<LyricsProvider>();
  final controller = TextEditingController(text: provider.document?.raw ?? '');
  final text = await showDialog<String>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('Dán / chỉnh sửa lời'),
          content: SizedBox(
            width: 500,
            child: TextField(
              controller: controller,
              maxLines: 14,
              maxLength: 50000,
              decoration: const InputDecoration(
                hintText:
                    '[00:12.500] Lời bài hát…\nHoặc văn bản không đồng bộ',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Lưu'),
            ),
          ],
        ),
  );
  // Dialog route may still be animating after the result resolves.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  controller.dispose();
  if (text == null) return;
  try {
    await provider.assign(
      song,
      LyricsResult.parse(text, source: 'Chỉnh sửa thủ công'),
    );
  } catch (e) {
    if (context.mounted) lyricsMessage(context, e);
  }
}

Future<void> showLyricsSearch(BuildContext context, SongItem song) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => LyricsSearchSheet(song: song),
    );

class LyricsSearchSheet extends StatefulWidget {
  const LyricsSearchSheet({super.key, required this.song});
  final SongItem song;
  @override
  State<LyricsSearchSheet> createState() => _LyricsSearchSheetState();
}

class _LyricsSearchSheetState extends State<LyricsSearchSheet> {
  late final _title = TextEditingController(text: widget.song.title);
  late final _artist = TextEditingController(text: widget.song.artist);
  List<LyricsCandidate>? _results;
  String? _error;
  bool _loading = false, _saving = false;
  int _request = 0;
  @override
  void dispose() {
    _request++;
    _title.dispose();
    _artist.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_title.text.trim().isEmpty) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<LyricsProvider>().search(
        widget.song,
        _title.text,
        _artist.text,
      );
      if (mounted && request == _request) {
        setState(() {
          _results = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _preview(LyricsCandidate candidate) async {
    LyricsResult result;
    try {
      result = candidate.result;
    } catch (e) {
      lyricsMessage(context, e);
      return;
    }
    final selected = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('${candidate.title}\n${candidate.artist}'),
            content: SizedBox(
              width: 440,
              height: 300,
              child: SingleChildScrollView(
                child: Text(
                  candidate.instrumental
                      ? 'Bản nhạc không lời'
                      : result.lines.map((l) => l.text).join('\n'),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Quay lại'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Dùng lời này'),
              ),
            ],
          ),
    );
    if (selected != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await context.read<LyricsProvider>().assign(widget.song, result);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        lyricsMessage(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .86,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.lyrics_rounded)),
            title: const Text('Tìm lời bài hát'),
            subtitle: Text(
              widget.song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: 'Đóng',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Tên bài hát'),
                  onSubmitted: (_) => _search(),
                ),
                TextField(
                  controller: _artist,
                  decoration: const InputDecoration(
                    labelText: 'Nghệ sĩ (có thể bỏ trống)',
                  ),
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loading || _saving ? null : _search,
                        icon: const Icon(Icons.search),
                        label: const Text('Tìm trên LRCLIB'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Nhập file lời',
                      onPressed:
                          _saving
                              ? null
                              : () => importLyrics(context, widget.song),
                      icon: const Icon(Icons.file_open_outlined),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_loading || _saving) const LinearProgressIndicator(),
          Expanded(
            child:
                _error != null
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!),
                      ),
                    )
                    : _results == null
                    ? const Center(
                      child: Text('Tìm online hoặc nhập file LRC / TTML / TXT'),
                    )
                    : _results!.isEmpty
                    ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Không tìm thấy lời. Thử bỏ phần remix, tên kênh hoặc sửa tên nghệ sĩ.',
                        ),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _results!.length,
                      itemBuilder: (_, i) {
                        final item = _results![i];
                        final synced = item.synced.trim().isNotEmpty;
                        return ListTile(
                          enabled: !_saving,
                          leading: Icon(
                            item.instrumental
                                ? Icons.music_off
                                : synced
                                ? Icons.sync
                                : Icons.notes,
                          ),
                          title: Text(item.title),
                          subtitle: Text(
                            '${item.artist} · ${item.album}\n${(item.duration ~/ 60)}:${(item.duration.toInt() % 60).toString().padLeft(2, '0')} · ${item.instrumental
                                ? 'Không lời'
                                : synced
                                ? 'Đồng bộ'
                                : 'Văn bản'}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _preview(item),
                        );
                      },
                    ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Lyrics provided by LRCLIB',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> showLyricsPreferences(BuildContext context) async {
  await context.read<LyricsProvider>().initialize();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const LyricsPreferencesSheet(),
  );
}

class LyricsPreferencesSheet extends StatefulWidget {
  const LyricsPreferencesSheet({super.key});
  @override
  State<LyricsPreferencesSheet> createState() => _LyricsPreferencesSheetState();
}

class _LyricsPreferencesSheetState extends State<LyricsPreferencesSheet> {
  bool _scanning = false;
  String? _progress;
  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LyricsProvider>();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .85,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tùy chọn lời bài hát',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const CloseButton(),
            ],
          ),
          DropdownButtonFormField<LyricsSourcePreference>(
            initialValue: lp.sourcePreference,
            decoration: const InputDecoration(labelText: 'Nguồn ưu tiên'),
            items: const [
              DropdownMenuItem(
                value: LyricsSourcePreference.embeddedFirst,
                child: Text('Lời nhúng → Online → File đi kèm'),
              ),
              DropdownMenuItem(
                value: LyricsSourcePreference.apiFirst,
                child: Text('Online → Lời nhúng → File đi kèm'),
              ),
              DropdownMenuItem(
                value: LyricsSourcePreference.localFirst,
                child: Text('File đi kèm → Lời nhúng → Online'),
              ),
            ],
            onChanged: (v) {
              if (v != null) lp.preferences(source: v);
            },
          ),
          const SizedBox(height: 18),
          Text('Cỡ chữ: ${lp.fontSize.round()}'),
          Slider(
            value: lp.fontSize,
            min: 18,
            max: 42,
            divisions: 24,
            onChanged: (v) => lp.preferences(size: v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Căn giữa'),
            value: lp.center,
            onChanged: (v) => lp.preferences(centered: v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Làm mờ dòng chưa hát'),
            value: lp.blur,
            onChanged: (v) => lp.preferences(blurred: v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hiện bản dịch có trong lời'),
            value: lp.translation,
            onChanged: (v) => lp.preferences(translations: v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hiện phiên âm có trong lời'),
            value: lp.romanization,
            onChanged: (v) => lp.preferences(romanized: v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Chế độ tập trung'),
            subtitle: const Text('Ẩn điều khiển sau 5 giây; chạm để hiện lại'),
            value: lp.immersive,
            onChanged: (v) => lp.preferences(immersiveMode: v),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.folder_open),
            title: const Text('Quét file lời trong thư viện'),
            subtitle: Text(
              _progress ??
                  'Ghép .lrc / .ttml / .txt cùng tên file nhạc; giữ lời đã lưu.',
            ),
            trailing:
                _scanning
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(),
                    )
                    : null,
            onTap:
                _scanning
                    ? null
                    : () async {
                      final songs =
                          context.read<MusicProvider>().allSongs.toList();
                      setState(() => _scanning = true);
                      final count = await lp.scanSidecars(
                        songs,
                        progress: (done, total) {
                          if (mounted) {
                            setState(() => _progress = '$done / $total');
                          }
                        },
                      );
                      if (mounted) {
                        setState(() {
                          _scanning = false;
                          _progress = 'Đã tìm và lưu lời cho $count bài';
                        });
                      }
                    },
          ),
        ],
      ),
    );
  }
}

Future<void> showLyricsOffset(
  BuildContext context,
) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  builder:
      (context) => Consumer<LyricsProvider>(
        builder:
            (context, lp, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Đồng bộ thời gian',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${lp.offsetMs >= 0 ? '+' : ''}${lp.offsetMs} ms',
                    style: const TextStyle(fontSize: 30),
                  ),
                  const Text(
                    'Số dương: lời xuất hiện sớm hơn.\nChạm một dòng để tua đến câu đó.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final amount in [-500, -100, 100, 500])
                        FilledButton.tonal(
                          onPressed: () => lp.setOffset(lp.offsetMs + amount),
                          child: Text('${amount > 0 ? '+' : ''}$amount'),
                        ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => lp.setOffset(0),
                    child: const Text('Đặt lại 0 ms'),
                  ),
                ],
              ),
            ),
      ),
);
