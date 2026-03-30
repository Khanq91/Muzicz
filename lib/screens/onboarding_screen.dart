import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/app_colors.dart';
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

  bool _scanDone = false;
  int _songCount = 0;
  int _artistCount = 0;
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

    _pulseScale = Tween(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pulseOpacity = Tween(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  Future<void> _startScan() async {
    final musicProvider = context.read<MusicProvider>();

    // Simulate a minimum progress animation for UX feel
    _progressCtrl.animateTo(0.3, duration: const Duration(milliseconds: 800));

    await Future.delayed(const Duration(seconds: 5));
    await musicProvider.scanMusic();

    _progressCtrl.animateTo(
      1.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
    );

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    setState(() {
      _scanDone = true;
      _songCount = musicProvider.allSongs.length;
      _artistCount = musicProvider.artistMap.length;
    });

    _pulseCtrl.stop();
    _resultCtrl.forward();

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _progressCtrl.dispose();
    _resultCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                  builder: (_, child) => Opacity(
                    opacity: _pulseOpacity.value,
                    child: child,
                  ),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.3),
                          AppColors.primary.withOpacity(0.05),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.primary, AppColors.secondary],
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
                child: _scanDone
                    ? _ResultWidget(
                        songCount: _songCount,
                        artistCount: _artistCount,
                        animation: _resultCtrl,
                      )
                    : _ScanningText(randomText: _randomText),
              ),
              const Spacer(flex: 2),
              // Progress bar
              _AnimatedProgressBar(controller: _progressCtrl),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanningText extends StatelessWidget {
  const _ScanningText({required this.randomText});
  final String randomText;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          randomText,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Đang quét nhạc của bạn…',
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chỉ mất vài giây, hứa!',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w300,
            color: AppColors.textDisabled,
          ),
        ),
      ],
    );
  }
}

class _ResultWidget extends StatelessWidget {
  const _ResultWidget({
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
    ).animate(CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));

    final slide2 = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    ));

    final fade1 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.6),
      ),
    );
    final fade2 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.2, 0.8),
      ),
    );

    return Column(
      children: [
        FadeTransition(
          opacity: fade1,
          child: SlideTransition(
            position: slide1,
            child: _ResultRow(
              icon: Icons.music_note_rounded,
              value: '$songCount bài hát',
              color: AppColors.primary,
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
              color: AppColors.tertiary,
            ),
          ),
        ),
      ],
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
            color: AppColors.textPrimary,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            return LayoutBuilder(
              builder: (_, constraints) => Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 4,
                    width: constraints.maxWidth * controller.value,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
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
