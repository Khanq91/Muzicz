import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/song_item.dart';
import '../../providers/lyrics_provider.dart';
import '../../services/lyrics_ai_service.dart';
import '../../services/lyrics_service.dart';
import 'lyrics_tools.dart';

Future<void> showLyricsAiSettings(BuildContext context) async {
  try {
    final config = await LyricsAiService.readConfig();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AiSettings(config),
    );
  } catch (_) {
    if (context.mounted) {
      lyricsMessage(context, 'Không mở được cấu hình AI trên thiết bị này.');
    }
  }
}

class _AiSettings extends StatefulWidget {
  const _AiSettings(this.config);
  final LyricsAiConfig config;
  @override
  State<_AiSettings> createState() => _AiSettingsState();
}

class _AiSettingsState extends State<_AiSettings> {
  late final _url = TextEditingController(text: widget.config.baseUrl);
  late final _key = TextEditingController(text: widget.config.apiKey);
  late final _model = TextEditingController(text: widget.config.model);
  late final _language = TextEditingController(text: widget.config.language);
  late var _provider = widget.config.provider;
  final _service = LyricsAiService();
  bool _busy = false;
  String? _error;
  List<String> _models = [];
  LyricsAiConfig get _config => LyricsAiConfig(
    provider: _provider,
    baseUrl: _url.text.trim(),
    apiKey: _key.text.trim(),
    model: _model.text.trim(),
    language: _language.text.trim(),
  );
  @override
  void dispose() {
    _service.dispose();
    for (final c in [_url, _key, _model, _language]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error =
                  e is FormatException
                      ? e.message.toString()
                      : e is LyricsAiException
                      ? e.message
                      : 'Không lưu/đọc được cấu hình AI.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      16,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dịch lyrics bằng AI',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Lời bài hát sẽ được gửi đến dịch vụ bạn chọn khi bấm Dịch. Dịch vụ có thể tính phí theo tài khoản API của bạn. API key được mã hóa trên thiết bị.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<LyricsAiProvider>(
            initialValue: _provider,
            decoration: const InputDecoration(labelText: 'Dịch vụ'),
            items: const [
              DropdownMenuItem(
                value: LyricsAiProvider.gemini,
                child: Text('Google Gemini'),
              ),
              DropdownMenuItem(
                value: LyricsAiProvider.compatible,
                child: Text('API tương thích OpenAI'),
              ),
            ],
            onChanged:
                _busy
                    ? null
                    : (value) => setState(() {
                      _provider = value!;
                      _url.text =
                          value == LyricsAiProvider.gemini
                              ? 'https://generativelanguage.googleapis.com/v1beta'
                              : 'https://api.openai.com/v1';
                      _model.clear();
                      _models = [];
                    }),
          ),
          TextField(
            controller: _url,
            enabled: !_busy,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Base URL'),
          ),
          TextField(
            controller: _key,
            enabled: !_busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'API key'),
          ),
          TextField(
            controller: _model,
            enabled: !_busy,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Model',
              hintText: 'Nhập ID hoặc tải danh sách',
            ),
          ),
          TextButton.icon(
            onPressed:
                _busy
                    ? null
                    : () => _run(() async {
                      final models = await _service.models(_config);
                      if (mounted) {
                        setState(() {
                          _models = models;
                          if (models.isEmpty) {
                            _error =
                                'Không có model. Bạn có thể nhập ID trực tiếp.';
                          }
                        });
                      }
                    }),
            icon: const Icon(Icons.refresh),
            label: const Text('Tải danh sách model'),
          ),
          if (_models.isNotEmpty)
            DropdownButtonFormField<String>(
              isExpanded: true,
              hint: const Text('Chọn model'),
              items:
                  _models
                      .toSet()
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(m, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
              onChanged: _busy ? null : (m) => _model.text = m ?? '',
            ),
          TextField(
            controller: _language,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Ngôn ngữ bản dịch'),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          FilledButton(
            onPressed:
                _busy
                    ? null
                    : () => _run(() async {
                      await LyricsAiService.saveConfig(_config);
                      if (context.mounted) Navigator.pop(context);
                    }),
            child: const Text('Lưu cấu hình'),
          ),
          TextButton(
            onPressed:
                _busy
                    ? null
                    : () => _run(() async {
                      await LyricsAiService.clearConfig();
                      if (mounted) {
                        setState(() {
                          _key.clear();
                          _model.clear();
                          _models = [];
                        });
                      }
                    }),
            child: const Text('Xóa API key và cấu hình đã lưu'),
          ),
        ],
      ),
    ),
  );
}

Future<void> translateLyrics(BuildContext context, SongItem song) async {
  final provider = context.read<LyricsProvider>();
  final original = provider.document;
  if (original == null || !original.hasLyrics) return;
  try {
    final config = await LyricsAiService.readConfig();
    try {
      config.validate();
    } on FormatException {
      if (context.mounted) await showLyricsAiSettings(context);
      return;
    }
    if (!context.mounted) return;
    final result = await showDialog<LyricsResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TranslationDialog(config, original, song.title),
    );
    if (result == null) return;
    await provider.assign(song, result);
    if (context.mounted) {
      lyricsMessage(context, 'Đã lưu bản dịch cho ${song.title}');
    }
  } catch (_) {
    if (context.mounted) {
      lyricsMessage(context, 'Không thể dịch/lưu lời. Kiểm tra cấu hình AI.');
    }
  }
}

class _TranslationDialog extends StatefulWidget {
  const _TranslationDialog(this.config, this.original, this.title);
  final LyricsAiConfig config;
  final LyricsResult original;
  final String title;
  @override
  State<_TranslationDialog> createState() => _TranslationDialogState();
}

class _TranslationDialogState extends State<_TranslationDialog> {
  final _service = LyricsAiService();
  LyricsResult? _result;
  String? _error;
  double? _progress;
  @override
  void initState() {
    super.initState();
    _translate();
  }

  Future<void> _translate() async {
    try {
      final result = await _service.translate(
        widget.config,
        widget.original,
        progress: (done, total) {
          if (mounted) setState(() => _progress = done / total);
        },
      );
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error =
                  e is LyricsAiException ? e.message : 'Không dịch được lời.',
        );
      }
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      _result == null ? 'Dịch · ${widget.title}' : 'Xem trước bản dịch',
    ),
    content: SizedBox(
      width: double.maxFinite,
      child:
          _result == null
              ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error == null) LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 16),
                  Text(_error ?? 'Đang dịch sang ${widget.config.language}…'),
                ],
              )
              : ListView.builder(
                shrinkWrap: true,
                itemCount: _result!.lines.length,
                itemBuilder:
                    (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_result!.lines[i].text),
                          Text(
                            _result!.lines[i].translation ?? '',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
              ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      if (_result != null)
        FilledButton(
          onPressed: () => Navigator.pop(context, _result),
          child: const Text('Áp dụng'),
        ),
    ],
  );
}
