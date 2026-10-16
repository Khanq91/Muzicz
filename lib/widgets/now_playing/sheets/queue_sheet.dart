import 'dart:math' as math;
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../../core/app_strings.dart';
import '../../../models/song_item.dart';
import '../../../providers/music_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../theme/app_colors_data.dart';
import 'sleep_timer_sheet.dart';
import 'song_info_sheet.dart';

/// Flutter adaptation of PixelPlayer's QueueBottomSheet: lazy rows, explicit
/// drag handles, swipe removal, undo, source badge and floating controls.
class QueueSheet extends StatefulWidget {
  const QueueSheet({
    super.key,
    required this.onClose,
    required this.useBlur,
    this.scrollController,
  });
  final VoidCallback onClose;
  final bool useBlur;
  final ScrollController? scrollController;

  @override
  State<QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends State<QueueSheet> {
  late final ScrollController _scroll =
      widget.scrollController ?? ScrollController();
  bool _menuOpen = false;
  bool _busy = false;
  final Set<int> _dismissed = {};
  int? _dragging;

  @override
  void dispose() {
    if (widget.scrollController == null) _scroll.dispose();
    super.dispose();
  }

  void _locate() {
    setState(() => _menuOpen = false);
    if (!_scroll.hasClients) return;
    final target = (context.read<PlayerProvider>().currentQueueIndex * 82.0)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context) ||
        (target - _scroll.offset).abs() > 1640) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _remove(int index) async {
    if (_busy) return;
    final player = context.read<PlayerProvider>();
    final song = player.queue[index];
    setState(() {
      _busy = true;
      _dismissed.add(index);
    });
    try {
      await player.removeFromQueue(index);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${song.title} • Đã xóa khỏi hàng chờ',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () async {
              try {
                await player.undoQueueRemoval();
              } catch (_) {
                if (mounted) _error();
              }
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted) _error();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _dismissed.clear();
        });
      }
    }
  }

  void _error() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Không thể cập nhật hàng chờ. Vui lòng thử lại.'),
    ),
  );

  Future<void> _clear() async {
    setState(() => _menuOpen = false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Xóa hàng chờ?'),
            content: const Text(
              'Dừng phát và xóa tất cả bài hát khỏi hàng chờ.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(AppStrings.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Xóa'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<PlayerProvider>().stopAndClear();
    if (mounted) widget.onClose();
  }

  void _save() {
    setState(() => _menuOpen = false);
    final songs = List<SongItem>.of(context.read<PlayerProvider>().queue);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.appColors.surface,
      builder: (_) => _SaveQueueSheet(songs: songs),
    );
  }

  void _options(int index) {
    final player = context.read<PlayerProvider>();
    final song = player.queue[index];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.appColors.surface,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text(AppStrings.songInfo),
                  onTap: () {
                    Navigator.pop(ctx);
                    showSongInfoSheet(context, song);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text(AppStrings.removeFromQueue),
                  onTap: () {
                    Navigator.pop(ctx);
                    _remove(index);
                  },
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final player = context.watch<PlayerProvider>();
    final reduced = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduced ? Duration.zero : const Duration(milliseconds: 180);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Material(
        color: c.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) > 250) widget.onClose();
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      children: [
                        Semantics(
                          button: true,
                          label: AppStrings.collapseQueue,
                          child: Tooltip(
                            message: AppStrings.collapseQueue,
                            excludeFromSemantics: true,
                            child: InkWell(
                              onTap: widget.onClose,
                              child: SizedBox(
                                width: 64,
                                height: 16,
                                child: Center(
                                  child: Container(
                                    width: 42,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: c.textDisabled.withValues(
                                        alpha: .4,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: _locate,
                                    child: Text(
                                      'Next up',
                                      style: TextStyle(
                                        fontSize: 32,
                                        height: 1.2,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${player.queue.length} tracks lined up.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: c.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                margin: const EdgeInsets.only(top: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: c.surfaceElevated,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.queue_music_rounded,
                                      size: 18,
                                      color: c.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        player.queueSourceName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: c.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.surfaceElevated,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child:
                        player.queue.isEmpty
                            ? Center(
                              child: Text(
                                'Hàng chờ trống',
                                style: TextStyle(color: c.textSecondary),
                              ),
                            )
                            : Scrollbar(
                              controller: _scroll,
                              thumbVisibility: true,
                              child: ReorderableListView.builder(
                                scrollController: _scroll,
                                buildDefaultDragHandles: false,
                                itemExtent: 82,
                                padding: EdgeInsets.fromLTRB(
                                  12,
                                  14,
                                  24,
                                  100 + MediaQuery.paddingOf(context).bottom,
                                ),
                                itemCount: player.queue.length,
                                onReorderStart: (index) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _dragging = index);
                                },
                                onReorderEnd:
                                    (_) => setState(() => _dragging = null),
                                onReorderItem: (from, to) async {
                                  if (_busy) return;
                                  setState(() => _busy = true);
                                  try {
                                    await player.reorderQueue(
                                      from,
                                      from < to ? to + 1 : to,
                                    );
                                  } catch (_) {
                                    if (mounted) _error();
                                  } finally {
                                    if (mounted) setState(() => _busy = false);
                                  }
                                },
                                proxyDecorator:
                                    (
                                      child,
                                      index,
                                      animation,
                                    ) => AnimatedBuilder(
                                      animation: animation,
                                      child: child,
                                      builder:
                                          (_, child) => Transform.scale(
                                            scale:
                                                reduced
                                                    ? 1
                                                    : 1 +
                                                        .025 *
                                                            Curves.easeOut
                                                                .transform(
                                                                  animation
                                                                      .value,
                                                                ),
                                            child: Material(
                                              color: Colors.transparent,
                                              elevation: 6 * animation.value,
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              child: child,
                                            ),
                                          ),
                                    ),
                                itemBuilder: (_, index) {
                                  final song = player.queue[index];
                                  final active =
                                      index == player.currentQueueIndex;
                                  // Index distinguishes repeated occurrences of the same track.
                                  return Padding(
                                    key: ValueKey('${song.id}:$index'),
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Dismissible(
                                      key: ValueKey('swipe:${song.id}:$index'),
                                      direction:
                                          _busy || _dragging != null
                                              ? DismissDirection.none
                                              : DismissDirection.horizontal,
                                      movementDuration: duration,
                                      confirmDismiss: (_) async {
                                        await _remove(index);
                                        return false;
                                      },
                                      background: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                        decoration: BoxDecoration(
                                          color: c.error.withValues(alpha: .15),
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.delete_outline_rounded,
                                          color: c.error,
                                        ),
                                      ),
                                      secondaryBackground: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                        decoration: BoxDecoration(
                                          color: c.error.withValues(alpha: .15),
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.delete_outline_rounded,
                                          color: c.error,
                                        ),
                                      ),
                                      child: AnimatedOpacity(
                                        duration: duration,
                                        opacity:
                                            _dismissed.contains(index) ? 0 : 1,
                                        child: Material(
                                          color: c.surface,
                                          borderRadius: BorderRadius.circular(
                                            active ? 48 : 24,
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: InkWell(
                                            onTap:
                                                _busy
                                                    ? null
                                                    : () => player.skipToIndex(
                                                      index,
                                                    ),
                                            child: Row(
                                              children: [
                                                if (!active)
                                                  ReorderableDragStartListener(
                                                    index: index,
                                                    enabled: !_busy,
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                          ),
                                                      child: Icon(
                                                        Icons
                                                            .drag_indicator_rounded,
                                                        size: 22,
                                                        color: c.textSecondary,
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  const SizedBox(width: 16),
                                                SizedBox(
                                                  width: 48,
                                                  height: 48,
                                                  child: RepaintBoundary(
                                                    child: QueryArtworkWidget(
                                                      id: song.albumId,
                                                      type: ArtworkType.ALBUM,
                                                      artworkBorder:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      keepOldArtwork: true,
                                                      nullArtworkWidget: Icon(
                                                        Icons
                                                            .music_note_rounded,
                                                        size: 38,
                                                        color: c.textDisabled,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        song.title,
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          color:
                                                              active
                                                                  ? c.primary
                                                                  : c.textPrimary,
                                                        ),
                                                      ),
                                                      Text(
                                                        song.artist,
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color:
                                                              active
                                                                  ? c.primary
                                                                      .withValues(
                                                                        alpha:
                                                                            .7,
                                                                      )
                                                                  : c.textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (active)
                                                  _QueueEqualizer(
                                                    playing: player.isPlaying,
                                                    color: c.primary,
                                                  ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                      ),
                                                  child: IconButton.filledTonal(
                                                    tooltip: 'Tùy chọn bài hát',
                                                    style: IconButton.styleFrom(
                                                      minimumSize: const Size(
                                                        36,
                                                        40,
                                                      ),
                                                      backgroundColor:
                                                          active
                                                              ? c.tertiary
                                                                  .withValues(
                                                                    alpha: .22,
                                                                  )
                                                              : c.surfaceElevated,
                                                    ),
                                                    onPressed:
                                                        _busy
                                                            ? null
                                                            : () =>
                                                                _options(index),
                                                    icon: Icon(
                                                      Icons.more_vert_rounded,
                                                      color: c.textPrimary,
                                                      size: 22,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                  ),
                ),
              ],
            ),
            if (_menuOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _menuOpen = false),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          c.background.withValues(alpha: .05),
                          c.background.withValues(alpha: .95),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12 + MediaQuery.paddingOf(context).bottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSize(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    child:
                        _menuOpen
                            ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: _locate,
                                  icon: const Icon(Icons.my_location_rounded),
                                  label: const Text('Bài đang phát'),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: _clear,
                                  icon: const Icon(Icons.clear_all_rounded),
                                  label: const Text('Xóa hàng chờ'),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed:
                                      player.queue.isEmpty ? null : _save,
                                  icon: const Icon(Icons.playlist_add_rounded),
                                  label: const Text('Lưu thành danh sách phát'),
                                ),
                                const SizedBox(height: 12),
                              ],
                            )
                            : const SizedBox.shrink(),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            c.surfaceElevated,
                            c.textDisabled,
                            .15,
                          ),
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(50),
                            right: Radius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _control(
                              Icons.shuffle_rounded,
                              AppStrings.shufflePlay,
                              player.shuffleEnabled,
                              () => player.toggleShuffle(),
                            ),
                            const SizedBox(width: 8),
                            _control(
                              player.repeatMode == RepeatMode.one
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                              AppStrings.repeat,
                              player.repeatMode != RepeatMode.none,
                              () => player.cycleQueueRepeat(),
                            ),
                            const SizedBox(width: 8),
                            _control(
                              Icons.timer_rounded,
                              AppStrings.sleepTimerTitle,
                              player.sleepTimerActive,
                              () => showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: c.surface,
                                builder:
                                    (_) => const SafeArea(
                                      child: SleepTimerSheet(),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 70,
                        height: 64,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: c.tertiary.withValues(alpha: .25),
                            foregroundColor: c.textPrimary,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(8),
                                right: Radius.circular(50),
                              ),
                            ),
                          ),
                          onPressed:
                              () => setState(() => _menuOpen = !_menuOpen),
                          child: AnimatedRotation(
                            turns: _menuOpen ? .25 : 0,
                            duration: duration,
                            child: Icon(
                              _menuOpen
                                  ? Icons.close_rounded
                                  : Icons.more_horiz_rounded,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _control(
    IconData icon,
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    final c = context.appColors;
    return IconButton.filledTonal(
      tooltip: label,
      isSelected: active,
      onPressed: onTap,
      style: IconButton.styleFrom(
        fixedSize: const Size(48, 48),
        backgroundColor: active ? c.primary : c.background,
        foregroundColor:
            active ? Theme.of(context).colorScheme.onPrimary : c.textSecondary,
      ),
      icon: Icon(icon),
    );
  }
}

class _QueueEqualizer extends StatefulWidget {
  const _QueueEqualizer({required this.playing, required this.color});
  final bool playing;
  final Color color;
  @override
  State<_QueueEqualizer> createState() => _QueueEqualizerState();
}

class _QueueEqualizerState extends State<_QueueEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _QueueEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.playing && !MediaQuery.disableAnimationsOf(context)) {
      if (!_animation.isAnimating) _animation.repeat();
    } else {
      _animation.stop();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox(
      width: 24,
      height: 22,
      child: AnimatedBuilder(
        animation: _animation,
        builder:
            (_, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(
                3,
                (i) => Container(
                  width: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  height:
                      widget.playing
                          ? 5 +
                              14 *
                                  (.5 +
                                      .5 *
                                          math.sin(
                                            _animation.value * math.pi * 2 +
                                                i * 2,
                                          ))
                          : 5,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
      ),
    ),
  );
}

class _SaveQueueSheet extends StatefulWidget {
  const _SaveQueueSheet({required this.songs});
  final List<SongItem> songs;
  @override
  State<_SaveQueueSheet> createState() => _SaveQueueSheetState();
}

class _SaveQueueSheetState extends State<_SaveQueueSheet> {
  final _name = TextEditingController(text: 'Hàng chờ hiện tại');
  final _query = TextEditingController();
  late final Set<int> _selected = widget.songs.map((s) => s.id).toSet();
  bool _saving = false;
  @override
  void dispose() {
    _name.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered =
        widget.songs
            .where(
              (s) => '${s.title} ${s.artist}'.toLowerCase().contains(
                _query.text.toLowerCase(),
              ),
            )
            .toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Lưu hàng chờ thành playlist',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                IconButton(
                  tooltip: 'Chọn tất cả',
                  onPressed:
                      _saving
                          ? null
                          : () => setState(() {
                            if (_selected.length ==
                                widget.songs.map((s) => s.id).toSet().length) {
                              _selected.clear();
                            } else {
                              _selected.addAll(widget.songs.map((s) => s.id));
                            }
                          }),
                  icon: const Icon(Icons.select_all_rounded),
                ),
              ],
            ),
            TextField(
              controller: _name,
              enabled: !_saving,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Tên danh sách phát',
              ),
            ),
            TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Tìm bài hát',
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final song = filtered[i];
                  return CheckboxListTile(
                    value: _selected.contains(song.id),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onChanged:
                        _saving
                            ? null
                            : (value) => setState(() {
                              if (value == true) {
                                _selected.add(song.id);
                              } else {
                                _selected.remove(song.id);
                              }
                            }),
                  );
                },
              ),
            ),
            FilledButton(
              onPressed:
                  _saving || _selected.isEmpty || _name.text.trim().isEmpty
                      ? null
                      : () async {
                        setState(() => _saving = true);
                        final music = context.read<MusicProvider>();
                        try {
                          final playlist = await music.createPlaylist(
                            _name.text.trim(),
                          );
                          for (final song in widget.songs.where(
                            (s) => _selected.contains(s.id),
                          )) {
                            await music.addToPlaylist(playlist.id, song);
                          }
                          if (context.mounted) Navigator.pop(context);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Không thể lưu danh sách phát.'),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
              child: Text(_saving ? 'Đang lưu…' : AppStrings.save),
            ),
          ],
        ),
      ),
    );
  }
}
