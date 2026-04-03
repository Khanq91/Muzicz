// lib/features/downloader/screens/downloader_gateway_screen.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../providers/music_provider.dart';
import '../../../screens/onboarding_screen.dart';
import '../../../theme/app_colors.dart';
import 'analyze_screen_bridge.dart';

class DownloaderGatewayScreen extends StatefulWidget {
  const DownloaderGatewayScreen({super.key});

  @override
  State<DownloaderGatewayScreen> createState() =>
      _DownloaderGatewayScreenState();
}

class _DownloaderGatewayScreenState extends State<DownloaderGatewayScreen>
    with SingleTickerProviderStateMixin {
  bool _isOnline = false;
  late StreamSubscription<List<ConnectivityResult>> _connectSub;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _checkConnectivity();
    _connectSub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (mounted) setState(() => _isOnline = online);
    });
  }

  @override
  void dispose() {
    _connectSub.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = results.any((r) => r != ConnectivityResult.none);
      });
    }
  }

  void _goToDownloader() {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) => const AnalyzeScreenBridge(),
      transitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ));
  }

  void _goToRescan() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const OnboardingScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Column(
            children: [
              // ── App bar ────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Tải nhạc',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Status card ─────────────────────
                      _NetworkStatusCard(isOnline: _isOnline),
                      const SizedBox(height: 20),

                      // ── Info text ───────────────────────
                      _InfoCard(isOnline: _isOnline),
                      const SizedBox(height: 32),

                      // ── Nút tải từ URL ──────────────────
                      _GatewayButton(
                        icon: Icons.link_rounded,
                        label: 'Tải nhạc từ URL',
                        subtitle: 'YouTube · TikTok · Instagram và hơn thế nữa',
                        gradient: AppColors.primaryGradient,
                        enabled: _isOnline,
                        disabledReason: 'Cần kết nối mạng để tải nhạc',
                        onTap: _goToDownloader,
                      ),
                      const SizedBox(height: 14),

                      // ── Nút quét lại ────────────────────
                      _GatewayButton(
                        icon: Icons.refresh_rounded,
                        label: 'Quét lại thư viện',
                        subtitle: 'Cập nhật nhạc từ bộ nhớ thiết bị',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5C6BC0), Color(0xFF9B5CBF)],
                        ),
                        enabled: true,
                        onTap: _goToRescan,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Network status card ────────────────────────────────────────────────────

class _NetworkStatusCard extends StatelessWidget {
  const _NetworkStatusCard({required this.isOnline});
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final color = isOnline
        ? const Color(0xFF34C759)
        : const Color(0xFFFF3B30);
    final label = isOnline ? 'Đang kết nối mạng' : 'Không có mạng';
    final icon  = isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  isOnline
                      ? 'Sẵn sàng tải nhạc'
                      : 'Kết nối Wi-Fi hoặc dữ liệu di động để tiếp tục',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          // Dot indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info card ──────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.isOnline});
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Lưu ý',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.download_rounded,
            text: 'File tải về được lưu vào thư mục Downloads (Có thể tùy chỉnh) trên thiết bị.',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.audio_file_rounded,
            text: 'Hỗ trợ tách audio M4A từ video — không mất chất lượng.',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.wifi_rounded,
            text: 'Tải nhạc từ URL yêu cầu kết nối Internet.',
            highlight: !isOnline,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.folder_rounded,
            text: 'Quét lại thư viện không cần mạng — chỉ đọc từ bộ nhớ máy.',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    this.highlight = false,
  });
  final IconData icon;
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight
        ? const Color(0xFFFF9500)
        : AppColors.textTertiary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: color,
              height: 1.5,
              fontWeight:
              highlight ? FontWeight.w500 : FontWeight.w300,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Gateway button ─────────────────────────────────────────────────────────

class _GatewayButton extends StatefulWidget {
  const _GatewayButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.enabled,
    required this.onTap,
    this.disabledReason,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final LinearGradient gradient;
  final bool enabled;
  final VoidCallback onTap;
  final String? disabledReason;

  @override
  State<_GatewayButton> createState() => _GatewayButtonState();
}

class _GatewayButtonState extends State<_GatewayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: widget.enabled ? 1.0 : 0.45,
      child: GestureDetector(
        onTapDown:  widget.enabled ? (_) => _ctrl.forward()  : null,
        onTapUp:    widget.enabled ? (_) async {
          await _ctrl.reverse();
          widget.onTap();
        } : null,
        onTapCancel: widget.enabled ? () => _ctrl.reverse() : null,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: widget.enabled
                  ? widget.gradient
                  : const LinearGradient(
                colors: [Color(0xFF2A2A2A), Color(0xFF222222)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: widget.enabled
                  ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.enabled
                            ? widget.subtitle
                            : (widget.disabledReason ?? widget.subtitle),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.75),
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}