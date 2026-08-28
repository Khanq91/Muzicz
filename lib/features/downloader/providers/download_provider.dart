// lib/providers/download_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/download_task.dart';
import '../models/format_option.dart';
import '../models/video_info.dart';
import '../services/downloader_storage_service.dart';
import '../services/ytdlp_service.dart';

final downloadGatewayProvider = Provider<DownloadGateway>(
  (ref) => YtdlpService.instance,
);

final downloadStorageGatewayProvider = Provider<DownloadStorageGateway>(
  (ref) => DownloaderStorageService.instance,
);

final downloadOutputDirectoryProvider =
    AsyncNotifierProvider<OutputDirectoryNotifier, String>(
      OutputDirectoryNotifier.new,
    );

/// Root of external storage (`/storage/emulated/0`) the quick-pick folder
/// sheets build their `Music/`, `Download/…`, `Movies/` options from.
final downloadExternalBasePathProvider = FutureProvider<String>(
  (ref) => ref.watch(downloadStorageGatewayProvider).getExternalBasePath(),
);

/// Owns the download output directory as Riverpod state, so every
/// `ref.read`/`ref.watch` sees the folder the user picked most recently
/// instead of the value cached on first read from the storage singleton.
///
/// Loading the saved folder and asking for storage access happen in [build],
/// so nothing can read a path before the storage service is initialised: the
/// analyze screen shows "Đang khởi động…" while this is [AsyncLoading] and the
/// init error when it is [AsyncError].
class OutputDirectoryNotifier extends AsyncNotifier<String> {
  DownloadStorageGateway get _storage =>
      ref.read(downloadStorageGatewayProvider);

  @override
  Future<String> build() async {
    final storage = ref.watch(downloadStorageGatewayProvider);
    await storage.init();
    await storage.requestStoragePermission();
    return storage.downloadPath;
  }

  /// Persists [path] through the storage service and publishes it.
  Future<void> setPath(String path) async {
    await _storage.setAndSavePath(path);
    // setAndSavePath keeps the previous folder when [path] cannot be created,
    // so publish what the service actually holds rather than [path].
    state = AsyncData(_storage.downloadPath);
  }

  /// Opens the system directory picker. With [save] the chosen folder is
  /// persisted and published right away; without it the caller keeps the
  /// path pending (format screen saves only when the download starts).
  /// Returns null when the user cancels.
  Future<String?> pickDirectory({
    bool save = true,
    String? initialDirectory,
  }) async {
    final picked = await _storage.pickDirectory(
      initialDirectory: initialDirectory ?? state.value,
    );
    if (picked != null && save) await setPath(picked);
    return picked;
  }

  /// Opens the current output directory in the system file manager.
  Future<void> openFolder() => _storage.openDownloadFolder();
}

/// Dart dispatches the visible queue to the Android foreground service.
/// The service owns the actual concurrency limit (currently one task).
final downloadDispatchLimitProvider = Provider<int>((ref) => 64);

// ── State ──────────────────────────────────────────────────

class DownloadState {
  final List<DownloadTask> tasks;

  const DownloadState({this.tasks = const []});

  /// Đang chạy (downloading hoặc preparing)
  List<DownloadTask> get activeTasks =>
      tasks.where((t) => t.status.isActive).toList();

  /// Đang xếp hàng chờ
  List<DownloadTask> get queuedTasks =>
      tasks
          .where(
            (t) =>
                t.status == DownloadStatus.queued ||
                t.status == DownloadStatus.waitingToRetry,
          )
          .toList();

  /// Đã xong (done, error, cancelled)
  List<DownloadTask> get finishedTasks =>
      tasks.where((t) => t.status.isFinished).toList();

  int get successCount =>
      tasks.where((t) => t.status == DownloadStatus.done).length;

  int get errorCount =>
      tasks.where((t) => t.status == DownloadStatus.error).length;

  int get totalCount => tasks.length;

  /// True khi không còn task nào active/queued
  bool get allFinished =>
      tasks.isNotEmpty && tasks.every((t) => t.status.isFinished);

  DownloadState copyWith({List<DownloadTask>? tasks}) =>
      DownloadState(tasks: tasks ?? this.tasks);
}

// ── Notifier ───────────────────────────────────────────────

class DownloadNotifier extends Notifier<DownloadState> {
  final _uuid = const Uuid();

  /// Map taskId → StreamSubscription (để cancel)
  final Map<String, StreamSubscription<DownloadTask>> _subs = {};
  final Map<String, Future<bool>> _cancellations = {};
  var _disposed = false;
  // final Map<String, FakeProgress> _fakeMap = {};

  @override
  DownloadState build() {
    _disposed = false;
    scheduleMicrotask(_restoreDownloads);
    // Tasks enqueued or restored before the output directory finished loading
    // stay queued; dispatch them as soon as the folder is known.
    ref.listen<AsyncValue<String>>(downloadOutputDirectoryProvider, (_, next) {
      if (next.hasValue) _processQueue();
    });
    ref.onDispose(() {
      _disposed = true;
      for (final sub in _subs.values) {
        sub.cancel();
      }
      _subs.clear();
    });
    return const DownloadState();
  }

  // ── Public API ─────────────────────────────────────────

  /// Thêm một video đơn vào hàng đợi
  Future<void> enqueue({
    required VideoInfo info,
    required FormatOption format,
  }) async {
    _addTask(_createTask(info: info, format: format));
    _processQueue();
  }

  /// Thêm nhiều video và chỉ process queue sau khi toàn bộ task đã được tạo.
  Future<void> enqueueBatch({
    required Iterable<VideoInfo> infos,
    required FormatOption format,
  }) async {
    final tasks = [
      ...state.tasks,
      for (final info in infos) _createTask(info: info, format: format),
    ];
    state = state.copyWith(tasks: tasks);
    _processQueue();
  }

  /// Thêm toàn bộ playlist vào hàng đợi
  Future<void> enqueuePlaylist({
    required VideoInfo playlistInfo,
    required FormatOption format,
  }) async {
    // Lấy danh sách URL entries từ libytdlp.so
    // (playlistInfo.url đã là playlist URL)
    // Tạo 1 task tổng cho playlist — mỗi item sẽ thành 1 task riêng
    // Ta dùng libytdlp.so tải playlist trực tiếp, nó tự xử lý từng video

    final task = DownloadTask(
      id: _uuid.v4(),
      title:
          '${playlistInfo.title} (${playlistInfo.playlistCount ?? "?"} video)',
      url: playlistInfo.url,
      formatId: format.formatId,
      ext: format.ext,
      thumbnail: playlistInfo.thumbnail,
      status: DownloadStatus.queued,
    );

    _addTask(task);
    _processQueue();
  }

  /// Hủy task queued ngay hoặc chờ native xác nhận task active đã dừng.
  Future<bool> cancel(String taskId) {
    final task = _findTask(taskId);
    if (task == null || !task.canCancel) return Future.value(false);

    if (task.status == DownloadStatus.queued && !_subs.containsKey(taskId)) {
      _updateTask(taskId, (t) => t.copyWith(status: DownloadStatus.cancelled));
      _processQueue();
      return Future.value(true);
    }

    return _cancellations.putIfAbsent(taskId, () => _cancelActive(taskId));
  }

  Future<bool> _cancelActive(String taskId) async {
    try {
      return await ref.read(downloadGatewayProvider).cancel(taskId);
    } finally {
      _cancellations.remove(taskId);
    }
  }

  /// Retry task lỗi
  Future<void> retry(String taskId) async {
    final task = _findTask(taskId);
    if (task == null || !task.canRetry) return;

    _updateTask(
      taskId,
      (t) => t.copyWith(
        status: DownloadStatus.queued,
        progress: 0,
        speed: '',
        eta: '',
        errorMessage: null,
      ),
    );

    _processQueue();
  }

  /// Xóa task khỏi danh sách (chỉ khi đã finished)
  void remove(String taskId) {
    final current = state.tasks.toList();
    current.removeWhere((t) => t.id == taskId && t.status.isFinished);
    state = state.copyWith(tasks: current);
    final gateway = ref.read(downloadGatewayProvider);
    if (gateway is PersistentDownloadHistoryGateway) {
      final historyGateway = gateway as PersistentDownloadHistoryGateway;
      unawaited(historyGateway.removeFinishedDownload(taskId));
    }
  }

  /// Xóa tất cả task đã xong
  void clearFinished() {
    final current = state.tasks.where((t) => !t.status.isFinished).toList();
    state = state.copyWith(tasks: current);
    final gateway = ref.read(downloadGatewayProvider);
    if (gateway is PersistentDownloadHistoryGateway) {
      final historyGateway = gateway as PersistentDownloadHistoryGateway;
      unawaited(historyGateway.clearFinishedDownloads());
    }
  }

  // ── Queue management ───────────────────────────────────

  Future<void> _restoreDownloads() async {
    final gateway = ref.read(downloadGatewayProvider);
    if (gateway is! RestorableDownloadGateway) return;

    final restorableGateway = gateway as RestorableDownloadGateway;
    final restored = await restorableGateway.restoreDownloads();
    if (_disposed || restored.isEmpty) return;

    final byId = <String, DownloadTask>{
      for (final task in restored) task.id: task,
      for (final task in state.tasks) task.id: task,
    };
    state = state.copyWith(tasks: byId.values.toList());

    for (final task in restored.where((task) => !task.status.isFinished)) {
      _updateTask(
        task.id,
        (current) => current.copyWith(status: DownloadStatus.queued),
      );
    }
    _processQueue();
  }

  void _processQueue() {
    final outputDir = ref.read(downloadOutputDirectoryProvider);
    // Folder still resolving: the listener in build() re-runs this once it is.
    if (outputDir.isLoading) return;

    final available = ref.read(downloadDispatchLimitProvider) - _subs.length;
    if (available <= 0) return;

    final queued =
        state.queuedTasks
            .where((task) => !_subs.containsKey(task.id))
            .take(available)
            .toList();
    for (final task in queued) {
      _startDownload(task, outputDir);
    }
  }

  void _startDownload(DownloadTask task, AsyncValue<String> outputDir) {
    if (_subs.containsKey(task.id)) return;

    final currentTask = _findTask(task.id);
    if (currentTask == null || currentTask.status != DownloadStatus.queued) {
      return;
    }

    // Reserve đồng bộ trước khi mở stream để lần process queue kế tiếp
    // không thể chọn lại cùng task trong lúc chờ event bất đồng bộ đầu tiên.
    _updateTask(
      task.id,
      (current) => current.copyWith(status: DownloadStatus.preparing),
    );

    // START: FAKE PROCESS ---------------------------------------------
    // final fake = FakeProgress();
    // fake.start((progress) {
    //   if (!_subs.containsKey(task.id)) return;
    //
    //   _updateTask(task.id, (t) => t.copyWith(progress: progress));
    // });
    //
    // _fakeMap[task.id] = fake;
    // END: FAKE PROCESS  ---------------------------------------------

    late final Stream<DownloadTask> stream;
    try {
      // requireValue rethrows the storage init error, which then lands on the
      // task as "Không thể bắt đầu tải" instead of silently using a fallback.
      stream = ref
          .read(downloadGatewayProvider)
          .download(task, outputDir: outputDir.requireValue);
    } catch (error) {
      _updateTask(
        task.id,
        (current) => current.copyWith(
          status: DownloadStatus.error,
          errorMessage: 'Không thể bắt đầu tải: $error',
        ),
      );
      _processQueue();
      return;
    }

    final sub = stream.listen(
      (updatedTask) async {
        _replaceTask(updatedTask);

        // Khi task xong → xử lý queue tiếp (TASK PROCESS RIEAL
        // if (updatedTask.status.isFinished) {
        //   _subs.remove(task.id);
        //   _processQueue();
        // }

        if (updatedTask.status == DownloadStatus.done) {
          // Audio extraction now belongs to the foreground service so it can
          // finish even when the Flutter activity is detached.
          _subs.remove(task.id);
          _processQueue();
        } else if (updatedTask.status.isFinished) {
          // _fakeMap[task.id]?.dispose();
          // _fakeMap.remove(task.id);
          _subs.remove(task.id);
          _processQueue();
        }
        // // TASK PROCESS FAKE
        // if (updatedTask.status.isFinished) {
        //   // Future.delayed(const Duration(milliseconds: 100), () {
        //   //   _fakeMap[task.id]?.complete((progress) {
        //   //     _updateTask(task.id, (t) => t.copyWith(progress: progress));
        //   //   });
        //   _fakeMap[task.id]?.complete((progress) {
        //     if (!_subs.containsKey(task.id)) return;
        //
        //     _updateTask(task.id, (t) => t.copyWith(progress: progress));
        //   });
        //
        //     _fakeMap.remove(task.id);
        //   // });
        //
        //   _subs.remove(task.id);
        //   _processQueue();
        // }
      },
      onError: (_) {
        // START: FAKE PROCESS ---------------------------------------------
        // _fakeMap[task.id]?.dispose();
        // _fakeMap.remove(task.id);
        // END: FAKE PROCESS ---------------------------------------------

        _updateTask(
          task.id,
          (t) => t.copyWith(
            status: DownloadStatus.error,
            errorMessage: 'Stream error',
          ),
        );
        _subs.remove(task.id);
        _processQueue();
      },
    );

    _subs[task.id] = sub;
  }

  // Future<void> _extractAudio(DownloadTask task) async {
  //   final result = await YtdlpService.instance.extractAudioNative(
  //     inputPath: task.outputPath!,
  //   );
  //
  //   _updateTask(task.id, (t) => t.copyWith(
  //     status:      result.success ? DownloadStatus.done : DownloadStatus.error,
  //     outputPath:  result.outputPath ?? t.outputPath,
  //     errorMessage: result.error,
  //     speed:       '',
  //     progress:    result.success ? 1.0 : t.progress,
  //     completedAt: result.success ? DateTime.now() : null,
  //   ));
  // }

  // Trong _startDownload(), sau khi stream báo done
  // void _startDownload(DownloadTask task) {
  //   final stream = YtdlpService.instance.download(
  //     task,
  //     outputDir: StorageService.instance.downloadPath,
  //   );
  //
  //   final sub = stream.listen(
  //         (updatedTask) async {
  //       _replaceTask(updatedTask);
  //
  //       if (updatedTask.status == DownloadStatus.done) {
  //         // ✅ Kiểm tra có cần extract audio không
  //         if (_needsExtract(updatedTask) && updatedTask.outputPath != null) {
  //           await _extractAudio(updatedTask);
  //         }
  //         _subs.remove(task.id);
  //         _processQueue();
  //       } else if (updatedTask.status.isFinished) {
  //         _subs.remove(task.id);
  //         _processQueue();
  //       }
  //     },
  //     onError: (_) {
  //       _updateTask(task.id, (t) => t.copyWith(
  //         status: DownloadStatus.error,
  //         errorMessage: 'Stream error',
  //       ));
  //       _subs.remove(task.id);
  //       _processQueue();
  //     },
  //   );
  //
  //   _subs[task.id] = sub;
  // }
  //
  // bool _needsExtract(DownloadTask task) =>
  //     task.formatId == '__extract_m4a__' ||
  //         task.formatId == '__extract_mp3__';
  //
  // Future<void> _extractAudio(DownloadTask task) async {
  //   // Hiện trạng thái "Đang xử lý audio"
  //   _updateTask(task.id, (t) => t.copyWith(
  //     status: DownloadStatus.preparing,
  //     speed: 'Đang tách audio...',
  //   ));
  //
  //   final result = task.formatId == '__extract_mp3__'
  //       ? await AudioExtractService.instance.extractMp3(
  //     inputPath: task.outputPath!,
  //   )
  //       : await AudioExtractService.instance.extractAudio(
  //     inputPath: task.outputPath!,
  //     outputExt: 'm4a',
  //   );
  //
  //   _updateTask(task.id, (t) => t.copyWith(
  //     status: result.success ? DownloadStatus.done : DownloadStatus.error,
  //     outputPath: result.outputPath ?? t.outputPath,
  //     errorMessage: result.error,
  //     speed: '',
  //     completedAt: DateTime.now(),
  //   ));
  // }

  // ── Task CRUD helpers ──────────────────────────────────

  DownloadTask _createTask({
    required VideoInfo info,
    required FormatOption format,
  }) {
    return DownloadTask(
      id: _uuid.v4(),
      title: info.title,
      url: info.url,
      formatId: format.formatId,
      ext: format.ext,
      thumbnail: info.thumbnail,
      status: DownloadStatus.queued,
    );
  }

  void _addTask(DownloadTask task) {
    state = state.copyWith(tasks: [...state.tasks, task]);
  }

  void _replaceTask(DownloadTask updated) {
    final tasks =
        state.tasks.map((t) {
          return t.id == updated.id ? updated : t;
        }).toList();
    state = state.copyWith(tasks: tasks);
  }

  void _updateTask(String id, DownloadTask Function(DownloadTask) updater) {
    final tasks =
        state.tasks.map((t) {
          return t.id == id ? updater(t) : t;
        }).toList();
    state = state.copyWith(tasks: tasks);
  }

  DownloadTask? _findTask(String id) {
    try {
      return state.tasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}

// ── Providers ──────────────────────────────────────────────

final downloadProvider = NotifierProvider<DownloadNotifier, DownloadState>(
  DownloadNotifier.new,
);

/// Shorthand: lấy 1 task theo id (dùng trong item widget)
final downloadTaskProvider = Provider.family<DownloadTask?, String>((ref, id) {
  return ref
      .watch(downloadProvider)
      .tasks
      .cast<DownloadTask?>()
      .firstWhere((t) => t?.id == id, orElse: () => null);
});

/// Đếm task đang active (dùng cho badge trên Download tab)
final activeDownloadCountProvider = Provider<int>((ref) {
  return ref.watch(downloadProvider).activeTasks.length;
});
