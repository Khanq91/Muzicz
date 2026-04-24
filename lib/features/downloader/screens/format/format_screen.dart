// lib/screens/format/format_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/format_option.dart';
import '../../models/playlist_entry.dart';
import '../../models/video_info.dart';
import '../../providers/download_provider.dart';
import '../../services/downloader_storage_service.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/primary_button.dart';

// ── Synthetic format cho tách audio (TikTok / Instagram muxed video) ─────────

const _kExtractAudioFormatId = '__extract_audio__';
const _kMuxedVideoFormatId = '__muxed_video__';

final _kExtractAudioFormat = FormatOption(
  formatId:    _kExtractAudioFormatId,
  ext:         'm4a',
  quality:     'Tách từ video',
  isAudioOnly: true,
);
const _kMuxedVideoFormat = FormatOption(
  formatId:    _kMuxedVideoFormatId,
  ext:         'mp4',
  quality:     'Video gốc',
  isAudioOnly: false,
);

// ── Playlist presets ───────────────────────────────────────

class _PlaylistPreset {
  final String label;
  final String formatId;
  final String ext;
  final String description;
  final bool isAudioOnly;
  final IconData icon;

  const _PlaylistPreset({
    required this.label,
    required this.formatId,
    required this.ext,
    required this.description,
    required this.isAudioOnly,
    required this.icon,
  });
}

const _videoPresets = [
  _PlaylistPreset(
    label: 'Tốt nhất',
    formatId: 'bestvideo+bestaudio/best',
    ext: 'mp4',
    description: 'Chất lượng cao nhất có thể',
    isAudioOnly: false,
    icon: Icons.hd_rounded,
  ),
  _PlaylistPreset(
    label: '1080p',
    formatId: 'bestvideo[height<=1080]+bestaudio/best[height<=1080]',
    ext: 'mp4',
    description: 'Tối đa Full HD',
    isAudioOnly: false,
    icon: Icons.videocam_rounded,
  ),
  _PlaylistPreset(
    label: '720p',
    formatId: 'bestvideo[height<=720]+bestaudio/best[height<=720]',
    ext: 'mp4',
    description: 'HD — dung lượng nhỏ hơn',
    isAudioOnly: false,
    icon: Icons.videocam_outlined,
  ),
  _PlaylistPreset(
    label: '480p',
    formatId: 'bestvideo[height<=480]+bestaudio/best[height<=480]',
    ext: 'mp4',
    description: 'Tiết kiệm dung lượng',
    isAudioOnly: false,
    icon: Icons.sd_rounded,
  ),
];

const _audioPresets = [
  _PlaylistPreset(
    label: 'Audio tốt nhất',
    formatId: 'bestaudio/best',
    ext: 'm4a',
    description: 'Bitrate cao nhất có thể',
    isAudioOnly: true,
    icon: Icons.music_note_rounded,
  ),
  _PlaylistPreset(
    label: 'M4A',
    formatId: 'bestaudio[ext=m4a]/bestaudio',
    ext: 'm4a',
    description: 'Ưu tiên định dạng M4A',
    isAudioOnly: true,
    icon: Icons.audio_file_rounded,
  ),
  _PlaylistPreset(
    label: 'Opus',
    formatId: 'bestaudio[ext=opus]/bestaudio',
    ext: 'opus',
    description: 'Chất lượng cao, dung lượng nhỏ',
    isAudioOnly: true,
    icon: Icons.graphic_eq_rounded,
  ),
];

// ── Screen ─────────────────────────────────────────────────

class FormatScreen extends ConsumerStatefulWidget {
  final VideoInfo videoInfo;
  final List<PlaylistEntry>? selectedEntries;

  const FormatScreen({
    super.key,
    required this.videoInfo,
    this.selectedEntries,
  });

  @override
  ConsumerState<FormatScreen> createState() => _FormatScreenState();
}

class _FormatScreenState extends ConsumerState<FormatScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  FormatOption?    _selectedFormat;
  _PlaylistPreset? _selectedPreset;
  bool _isAudioTab = true;

  String? _pendingOutputPath;

  bool get _isPlaylist => widget.videoInfo.type == VideoType.playlist;

  String get _currentPath =>
      _pendingOutputPath ?? DownloaderStorageService.instance.downloadPath;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _isPlaylist ? 1 : 0,
    );
    _isAudioTab = !_isPlaylist;

    if (_isPlaylist) {
      _selectedPreset = _videoPresets[1];
    } else {
      _selectedFormat = widget.videoInfo.bestAudioFormat ?? _kExtractAudioFormat;
    }

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _isAudioTab = _tabController.index == 0;
          if (_isPlaylist) {
            _selectedPreset =
            _isAudioTab ? _audioPresets.first : _videoPresets[1];
          } else {
            if (_isAudioTab) {
              _selectedFormat =
                  widget.videoInfo.bestAudioFormat ?? _kExtractAudioFormat;
            } else {
              _selectedFormat = _bestVideoFormat;
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<FormatOption> get _audioFormats {
    final list = widget.videoInfo.audioFormats.toList();
    list.sort((a, b) => (b.bitrate ?? 0).compareTo(a.bitrate ?? 0));
    return list;
  }

  List<FormatOption> get _videoFormats {
    final formats = widget.videoInfo.videoFormats;
    final Map<int, FormatOption> byHeight = {};
    for (final f in formats) {
      final h = f.height ?? 0;
      if (!byHeight.containsKey(h) ||
          (byHeight[h]!.filesize ?? 0) < (f.filesize ?? 0)) {
        byHeight[h] = f;
      }
    }
    return byHeight.values.toList()
      ..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
  }

  FormatOption? get _bestVideoFormat =>
      _videoFormats.isNotEmpty ? _videoFormats.first : null;

  bool get _isMuxedOnly =>
      _audioFormats.isEmpty && _videoFormats.isNotEmpty;

  Future<void> _showPathPickerSheet() async {
    final base = await DownloaderStorageService.instance.getExternalBasePath();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FormatFolderSheet(
        basePath: base,
        currentPath: _currentPath,
        onSelect: (path) {
          setState(() => _pendingOutputPath = path);
        },
        onCustomPick: () async {
          await DownloaderStorageService.instance.requestStoragePermission();
          final picked = await FilePicker.platform.getDirectoryPath(
            dialogTitle: 'Chọn thư mục lưu',
            initialDirectory: _currentPath,
          );
          if (picked != null && mounted) {
            setState(() => _pendingOutputPath = picked);
          }
        },
      ),
    );
  }

  Future<void> _startDownload() async {
    // Lưu path vào SharedPreferences đúng lúc user confirm download
    if (_pendingOutputPath != null) {
      await DownloaderStorageService.instance.setAndSavePath(_pendingOutputPath!);
    }

    final notifier = ref.read(downloadProvider.notifier);

    if (_isPlaylist) {
      if (_selectedPreset == null) return;
      final format = FormatOption(
        formatId:    _selectedPreset!.formatId,
        ext:         _selectedPreset!.ext,
        quality:     _selectedPreset!.label,
        isAudioOnly: _selectedPreset!.isAudioOnly,
      );

      final entries = widget.selectedEntries;
      if (entries != null && entries.isNotEmpty) {
        for (final entry in entries) {
          notifier.enqueue(
            info: VideoInfo(
              id:           entry.id,
              title:        entry.title,
              thumbnail:    entry.thumbnail,
              duration:     entry.duration,
              platform:     widget.videoInfo.platform,
              type:         VideoType.video,
              formats:      [],
              url:          entry.url,
              uploader:     entry.uploader,
              skippedCount: null,
            ),
            format: format,
          );
        }
      } else {
        notifier.enqueuePlaylist(
          playlistInfo: widget.videoInfo,
          format: format,
        );
      }
    } else {
      if (_selectedFormat == null) return;
      notifier.enqueue(
        info:   widget.videoInfo,
        format: _selectedFormat!,
      );
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.download,
          (route) => route.settings.name == AppRoutes.analyze,
    );
  }

  bool get _canDownload =>
      _isPlaylist ? _selectedPreset != null : _selectedFormat != null;

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: AppShell(
        appBar: AppBar(
          title: const Text('Chọn định dạng'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        child: Column(
          children: [
            _VideoPreviewCard(info: widget.videoInfo),

            if (widget.videoInfo.skippedCount != null &&
                widget.videoInfo.skippedCount! > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFFF9500).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 15, color: Color(0xFFFF9500)),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.videoInfo.skippedCount} video không khả dụng sẽ bị bỏ qua',
                        style: const TextStyle(
                            color: Color(0xFFFF9500), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _FormatTabBar(controller: _tabController),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: _isPlaylist
                    ? [
                  _PlaylistPresetList(
                    presets:  _audioPresets,
                    selected: _selectedPreset,
                    onSelect: (p) =>
                        setState(() => _selectedPreset = p),
                  ),
                  _PlaylistPresetList(
                    presets:  _videoPresets,
                    selected: _selectedPreset,
                    onSelect: (p) =>
                        setState(() => _selectedPreset = p),
                  ),
                ]
                    : [
                  // ── Audio tab ──
                  ListView(
                    padding:
                    const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    children: _isMuxedOnly
                        ? [
                      _ExtractAudioTile(
                        selectedFormatId:
                        _selectedFormat?.formatId,
                        onSelectAudio: () => setState(() =>
                        _selectedFormat =
                            _kExtractAudioFormat),
                        onSelectVideo: () => setState(() =>
                        _selectedFormat = _kMuxedVideoFormat),
                      ),
                    ]
                        : _audioFormats.isEmpty
                        ? [
                      const _EmptyLabel(
                          label:
                          'Không có định dạng audio')
                    ]
                        : _audioFormats
                        .map(
                          (f) => _FormatTile(
                        format: f,
                        isSelected:
                        _selectedFormat?.formatId ==
                            f.formatId,
                        onTap: () => setState(
                                () => _selectedFormat = f),
                      ),
                    )
                        .toList(),
                  ),
                  // ── Video tab ──
                  ListView(
                    padding:
                    const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    children: _videoFormats.isEmpty
                        ? [
                      const _EmptyLabel(
                          label: 'Không có định dạng video')
                    ]
                        : _videoFormats
                        .map(
                          (f) => _FormatTile(
                        format: f,
                        isSelected:
                        _selectedFormat?.formatId ==
                            f.formatId,
                        onTap: () =>
                            setState(() => _selectedFormat = f),
                      ),
                    )
                        .toList(),
                  ),
                ],
              ),
            ),

            _BottomDownloadBar(
              selectedFormat: _selectedFormat,
              selectedPreset: _selectedPreset,
              isPlaylist:     _isPlaylist,
              playlistCount:  widget.videoInfo.playlistCount,
              currentPath:    _currentPath,
              onPickFolder:   _showPathPickerSheet,
              onDownload:     _canDownload ? _startDownload : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Folder Option model (private, dùng trong sheet) ────────

class _FolderOption {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final String path;

  const _FolderOption({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.path,
  });
}

// ── Format Folder Sheet ────────────────────────────────────

class _FormatFolderSheet extends StatelessWidget {
  final String basePath;
  final String currentPath;
  final void Function(String) onSelect;
  final VoidCallback onCustomPick;

  const _FormatFolderSheet({
    required this.basePath,
    required this.currentPath,
    required this.onSelect,
    required this.onCustomPick,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      _FolderOption(
        icon: Icons.music_note_rounded,
        label: 'Music',
        sublabel: 'Music/',
        color: AppColors.primary,
        path: '$basePath/Music',
      ),
      _FolderOption(
        icon: Icons.download_rounded,
        label: 'MuziczModule',
        sublabel: 'Download/MuziczModule/',
        color: const Color(0xFF34C759),
        path: '$basePath/Download/MuziczModule',
      ),
      _FolderOption(
        icon: Icons.video_library_rounded,
        label: 'Videos',
        sublabel: 'Movies/',
        color: const Color(0xFFFF9F0A),
        path: '$basePath/Movies',
      ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Lưu vào thư mục',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Chọn nơi lưu file sau khi tải',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Quick options
            ...options.map((opt) {
              final isSelected = currentPath == opt.path;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onSelect(opt.path);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? opt.color.withOpacity(0.1)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? opt.color.withOpacity(0.4)
                          : AppColors.border,
                      width: isSelected ? 1.2 : 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: opt.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child:
                        Icon(opt.icon, color: opt.color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opt.label,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              opt.sublabel,
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary, size: 18),
                    ],
                  ),
                ),
              );
            }),

            // Custom pick option
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                onCustomPick();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border:
                  Border.all(color: AppColors.border, width: 0.8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.folder_open_rounded,
                          color: AppColors.textSecondary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chọn đường dẫn',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Duyệt thư mục tùy chỉnh',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textTertiary, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Extract Audio Tile ─────────────────────────────────────

class _MuxedOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _MuxedOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withOpacity(0.5)
                : AppColors.border,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.2)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: 20,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textTertiary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textTertiary, fontSize: 12)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textTertiary,
                  width: isSelected ? 0 : 1.5,
                ),
                gradient: isSelected ? AppColors.primaryGradient : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                  color: Colors.white, size: 13)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtractAudioTile extends StatelessWidget {
  final String? selectedFormatId;
  final VoidCallback onSelectAudio;
  final VoidCallback onSelectVideo;

  const _ExtractAudioTile({
    required this.selectedFormatId,
    required this.onSelectAudio,
    required this.onSelectVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.primary.withOpacity(0.2), width: 0.8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.primary.withOpacity(0.8)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Video này chỉ có định dạng muxed (video+audio). Chọn định dạng bạn muốn lưu.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        _MuxedOptionTile(
          icon: Icons.audio_file_rounded,
          title: 'Chỉ Audio (M4A)',
          subtitle:
          'Tải video → tách lấy âm thanh · không mất chất lượng',
          isSelected: selectedFormatId == _kExtractAudioFormatId,
          onTap: onSelectAudio,
        ),
      ],
    );
  }
}

// ── Playlist Preset List ───────────────────────────────────

class _PlaylistPresetList extends StatelessWidget {
  final List<_PlaylistPreset> presets;
  final _PlaylistPreset? selected;
  final ValueChanged<_PlaylistPreset> onSelect;

  const _PlaylistPresetList({
    required this.presets,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children: presets
          .map((p) => _PresetTile(
        preset:     p,
        isSelected: selected?.formatId == p.formatId,
        onTap:      () => onSelect(p),
      ))
          .toList(),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final _PlaylistPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetTile({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withOpacity(0.5)
                : AppColors.border,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.2)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                preset.icon,
                size: 20,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.label,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preset.description,
                    style: const TextStyle(
                        color: AppColors.textTertiary, fontSize: 12),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textTertiary,
                  width: isSelected ? 0 : 1.5,
                ),
                gradient: isSelected ? AppColors.primaryGradient : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                  color: Colors.white, size: 13)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Download Bar ────────────────────────────────────

class _BottomDownloadBar extends StatelessWidget {
  final FormatOption? selectedFormat;
  final _PlaylistPreset? selectedPreset;
  final bool isPlaylist;
  final int? playlistCount;
  final String currentPath;
  final VoidCallback onPickFolder;
  final VoidCallback? onDownload;

  const _BottomDownloadBar({
    required this.selectedFormat,
    required this.selectedPreset,
    required this.isPlaylist,
    required this.playlistCount,
    required this.currentPath,
    required this.onPickFolder,
    required this.onDownload,
  });

  String get _infoText {
    if (isPlaylist && selectedPreset != null) {
      return '${playlistCount ?? "?"} video · ${selectedPreset!.label} · ${selectedPreset!.ext.toUpperCase()}';
    }
    if (!isPlaylist && selectedFormat != null) {
      return switch (selectedFormat!.formatId) {
        '__extract_audio__' =>
        'Tải video → tách audio M4A (file MP4 sẽ bị xóa)',
        '__muxed_video__' => 'Giữ nguyên video MP4',
        _ =>
        '${selectedFormat!.displayLabel} · ${selectedFormat!.formattedFilesize}',
      };
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
        border: const Border(
            top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Folder path row
          GestureDetector(
            onTap: onPickFolder,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border:
                Border.all(color: AppColors.border, width: 0.6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_rounded,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentPath,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.edit_rounded,
                      size: 13, color: AppColors.textTertiary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          if (_infoText.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    _infoText,
                    style: const TextStyle(
                        color: AppColors.textTertiary, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          PrimaryButton(
            label: isPlaylist ? 'Tải playlist' : 'Bắt đầu tải',
            icon: Icons.download_rounded,
            onPressed: onDownload,
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────

class _EmptyLabel extends StatelessWidget {
  final String label;
  const _EmptyLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(label,
            style: const TextStyle(
                color: AppColors.textTertiary, fontSize: 14)),
      ),
    );
  }
}

class _VideoPreviewCard extends StatelessWidget {
  final VideoInfo info;
  const _VideoPreviewCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (info.thumbnail != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: info.thumbnail!,
                  width: 80,
                  height: 52,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 80,
                    height: 52,
                    color: AppColors.surfaceElevated,
                    child: const Icon(Icons.broken_image_rounded,
                        color: AppColors.textTertiary, size: 20),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info.type == VideoType.playlist
                        ? '${info.playlistCount ?? "?"} video'
                        : info.platform.displayName,
                    style: const TextStyle(
                        color: AppColors.textTertiary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatTabBar extends StatelessWidget {
  final TabController controller;
  const _FormatTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textTertiary,
        labelStyle:
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.music_note_rounded, size: 16),
                SizedBox(width: 6),
                Text('Audio'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_rounded, size: 16),
                SizedBox(width: 6),
                Text('Video'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  final FormatOption format;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatTile({
    required this.format,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withOpacity(0.5)
                : AppColors.border,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textTertiary,
                  width: isSelected ? 0 : 1.5,
                ),
                gradient: isSelected ? AppColors.primaryGradient : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                  color: Colors.white, size: 13)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    format.displayLabel,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (format.filesize != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      format.formattedFilesize,
                      style: const TextStyle(
                          color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.2)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                format.ext.toUpperCase(),
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primaryLight
                      : AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}