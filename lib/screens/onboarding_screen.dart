import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import 'home_screen.dart';
import 'package:muziczz/core/app_strings.dart';

const _randomTexts = AppStrings.onboardingQuotes;

/// First scan: the quote screen stays up at least this long.
const _firstRunIntro = Duration(seconds: 5);

/// Rescan / retry: just enough for the progress bar not to flash.
const _rescanMinimum = Duration(seconds: 1);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.isFirstRun = false});

  /// First launch (pushed from Welcome): the finished scan replaces the
  /// whole stack with Home. A rescan pops back to the screen that asked.
  final bool isFirstRun;

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
  bool _showScanningStatus = true;
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
    _showScanningStatus = true;

    final musicProvider = context.read<MusicProvider>();
    _resultCtrl.reset();
    _progressCtrl.reset();
    if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true);
    setState(() {});

    // Simulate a minimum progress animation for UX feel
    unawaited(
      _progressCtrl.animateTo(0.3, duration: const Duration(milliseconds: 800)),
    );

    // The scan starts right away; the delay only sets a floor on how soon
    // the result may replace the scanning copy (like AppStartupService's
    // minimum splash). The 5 s intro is for the first scan only.
    final minimum = Future<void>.delayed(
      showIntroDelay && !musicProvider.hasScannedOnce
          ? _firstRunIntro
          : _rescanMinimum,
    );
    await Future.wait([minimum, musicProvider.scanMusic()]);
    if (!mounted) return;

    _scanInFlight = false;
    _showScanningStatus = false;
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
      _navigationTimer = Timer(const Duration(seconds: 2), _leaveOnboarding);
    } else {
      _progressCtrl.stop();
    }
  }

  void _leaveOnboarding() {
    if (!mounted ||
        context.read<MusicProvider>().status != LibraryStatus.done) {
      return;
    }
    final navigator = Navigator.of(context);
    // Rescan: every caller push()es this screen, so go back to it instead
    // of stacking a second Home on top.
    if (!widget.isFirstRun && navigator.canPop()) {
      navigator.pop();
      return;
    }
    // First run: [Welcome, Onboarding] becomes [Home]; back must exit the
    // app rather than return to Welcome.
    navigator.pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder:
            (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
      (_) => false,
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
                // FadeTransition drives an OpacityLayer on the compositor;
                // Opacity inside AnimatedBuilder rebuilt and saveLayer'd on
                // every tick of the repeating pulse.
                child: FadeTransition(
                  opacity: _pulseOpacity,
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
              if (_showScanningStatus ||
                  music.status == LibraryStatus.idle ||
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
    if (_showScanningStatus) {
      return _ScanningText(
        key: const ValueKey('scanning'),
        randomText: _randomText,
      );
    }

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
        title: AppStrings.needPermissionTitle,
        message: AppStrings.needPermissionBody,
        onRetry: () => _startScan(showIntroDelay: false),
        onOpenSettings:
            music.permissionPermanentlyDenied ? openAppSettings : null,
      ),
      LibraryStatus.error => _ScanFailure(
        key: const ValueKey('scan-error'),
        icon: Icons.error_outline_rounded,
        title: AppStrings.scanFailedTitle,
        message: AppStrings.scanFailedBody,
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
          AppStrings.scanning,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.scanningHint,
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
              value: AppStrings.songCount(songCount),
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
              value: AppStrings.artistCount(artistCount),
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
            label: const Text(AppStrings.retry),
          ),
          if (onOpenSettings != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text(AppStrings.openSettings),
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
