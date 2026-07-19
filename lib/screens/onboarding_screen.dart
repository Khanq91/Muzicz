import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import 'home_screen.dart';

const _randomTexts = [
  // Thơ / cảm xúc
  'Âm nhạc là tiếng lòng không cần phiên dịch.',
  'Mỗi bài hát là một chiếc thuyền chở ký ức.',
  'Có những nỗi buồn chỉ nhạc mới hiểu được.',
  'Giai điệu đúng lúc — như một cái ôm vô hình.',
  // Hài hước
  'Tại sao nhạc sĩ giỏi mở khóa? Vì họ có nhiều phím! 🎹',
  'Headphone = giáp trụ cách ly khỏi người đời. 🎧',
  'Bài hát yêu thích là bài bạn bỏ play 47 lần trong một ngày.',
  '– Em đang làm gì vậy?\n– Nghe nhạc.\n– Ừ, không cần nói chuyện nữa.',
  // Quotes
  '"Without music, life would be a mistake." — Nietzsche',
  '"Music gives a soul to the universe." — Plato',
  '"One good thing about music, when it hits you, you feel no pain." — Bob Marley',
  '"Music is the shorthand of emotion." — Tolstoy',
  // Có thể bạn chưa biết
  'Có thể bạn chưa biết: Nghe nhạc buồn thực ra giúp não giải phóng dopamine 🎵',
  'Có thể bạn chưa biết: Tim người có xu hướng đồng bộ nhịp với âm nhạc đang nghe.',
  'Có thể bạn chưa biết: Nhạc nền giúp tăng hiệu suất làm việc lặp lại lên ~15%.',
  'Có thể bạn chưa biết: Bạch tuộc có thể "cảm nhận" âm nhạc qua da 🐙',
  // Triết lý nhẹ
  'Âm nhạc không cần lý do. Cứ bật lên và sống.',
  'Bạn không cần hiểu lời — đôi khi chỉ cần cảm nhận.',
  'Playlist của bạn là nhật ký không có chữ.',
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _progressCtrl;
  late final AnimationController _resultCtrl;

  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  Timer? _navigationTimer;
  bool _scanInFlight = false;
  String _randomText = '';

  @override
  void initState() {
    super.initState();

    _randomText = _randomTexts[Random().nextInt(_randomTexts.length)];

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _progressCtrl = AnimationController(vsync: this);

    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pulseScale = Tween(
      begin: 1.0,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _pulseOpacity = Tween(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  Future<void> _startScan({bool showIntroDelay = true}) async {
    if (_scanInFlight) return;
    _navigationTimer?.cancel();
    _scanInFlight = true;

    final musicProvider = context.read<MusicProvider>();
    _resultCtrl.reset();
    _progressCtrl.reset();
    if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true);
    setState(() {});

    // Simulate a minimum progress animation for UX feel
    unawaited(
      _progressCtrl.animateTo(0.3, duration: const Duration(milliseconds: 800)),
    );

    if (showIntroDelay) await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;
    await musicProvider.scanMusic();
    if (!mounted) return;

    _scanInFlight = false;
    _pulseCtrl.stop();
    setState(() {});

    if (musicProvider.status == LibraryStatus.done) {
      await _progressCtrl.animateTo(
        1.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
      );
      if (!mounted || musicProvider.status != LibraryStatus.done) return;
      _resultCtrl.forward();
      _navigationTimer = Timer(const Duration(seconds: 2), _navigateHome);
    } else {
      _progressCtrl.stop();
    }
  }

  void _navigateHome() {
    if (!mounted ||
        context.read<MusicProvider>().status != LibraryStatus.done) {
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder:
            (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _pulseCtrl.dispose();
    _progressCtrl.dispose();
    _resultCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final music = context.watch<MusicProvider>();
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Pulse icon
              ScaleTransition(
                scale: _pulseScale,
                child: AnimatedBuilder(
                  animation: _pulseOpacity,
                  builder:
                      (_, child) =>
                          Opacity(opacity: _pulseOpacity.value, child: child),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          c.primary.withValues(alpha: 0.3),
                          c.primary.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [c.primary, c.secondary],
                          ),
                        ),
                        child: const Icon(
                          Icons.graphic_eq_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              // Random text
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _buildStatus(music),
              ),
              const Spacer(flex: 2),
              // Progress bar
              if (music.status == LibraryStatus.idle ||
                  music.status == LibraryStatus.scanning ||
                  music.status == LibraryStatus.done)
                _AnimatedProgressBar(controller: _progressCtrl),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatus(MusicProvider music) {
    return switch (music.status) {
      LibraryStatus.done => _ResultWidget(
        key: const ValueKey('scan-result'),
        songCount: music.allSongs.length,
        artistCount: music.artistMap.length,
        animation: _resultCtrl,
      ),
      LibraryStatus.permissionDenied => _ScanFailure(
        key: const ValueKey('permission-denied'),
        icon: Icons.library_music_outlined,
        title: 'Cần quyền truy cập nhạc',
        message: 'Muzicz cần quyền đọc tệp âm thanh để tìm nhạc trên thiết bị.',
        onRetry: () => _startScan(showIntroDelay: false),
        onOpenSettings:
            music.permissionPermanentlyDenied ? openAppSettings : null,
      ),
      LibraryStatus.error => _ScanFailure(
        key: const ValueKey('scan-error'),
        icon: Icons.error_outline_rounded,
        title: 'Không thể quét thư viện',
        message: 'Đã có lỗi khi đọc thư viện nhạc. Hãy thử lại.',
        onRetry: () => _startScan(showIntroDelay: false),
      ),
      LibraryStatus.idle || LibraryStatus.scanning => _ScanningText(
        key: const ValueKey('scanning'),
        randomText: _randomText,
      ),
    };
  }
}

class _ScanningText extends StatelessWidget {
  const _ScanningText({super.key, required this.randomText});
  final String randomText;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      children: [
        Text(
          randomText,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: c.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Đang quét nhạc của bạn…',
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chỉ mất vài giây, hứa!',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w300,
            color: c.textDisabled,
          ),
        ),
      ],
    );
  }
}

class _ResultWidget extends StatelessWidget {
  const _ResultWidget({
    super.key,
    required this.songCount,
    required this.artistCount,
    required this.animation,
  });
  final int songCount;
  final int artistCount;
  final AnimationController animation;

  @override
  Widget build(BuildContext context) {
    final slide1 = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    final slide2 = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    final fade1 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.6)),
    );
    final fade2 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: animation, curve: const Interval(0.2, 0.8)),
    );
    final c = context.appColors;
    return Column(
      children: [
        FadeTransition(
          opacity: fade1,
          child: SlideTransition(
            position: slide1,
            child: _ResultRow(
              icon: Icons.music_note_rounded,
              value: '$songCount bài hát',
              color: c.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeTransition(
          opacity: fade2,
          child: SlideTransition(
            position: slide2,
            child: _ResultRow(
              icon: Icons.person_rounded,
              value: '$artistCount nghệ sĩ',
              color: c.tertiary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanFailure extends StatelessWidget {
  const _ScanFailure({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
    this.onOpenSettings,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;
  final Future<bool> Function()? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final errorColor = Theme.of(context).colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Column(
        children: [
          Icon(icon, color: errorColor, size: 42),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: c.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
          if (onOpenSettings != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Mở cài đặt'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _AnimatedProgressBar extends StatelessWidget {
  const _AnimatedProgressBar({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            return LayoutBuilder(
              builder:
                  (_, constraints) => Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 4,
                        width: constraints.maxWidth * controller.value,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [c.primary, c.secondary],
                          ),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: c.primary.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            );
          },
        ),
      ],
    );
  }
}
