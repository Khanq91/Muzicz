import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/mini_player.dart';
import 'onboarding_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.watch<PlayerProvider>();

    final totalSongs = music.allSongs.length;
    final totalArtists = music.artistMap.length;
    final totalAlbums = music.albumMap.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header with gradient
                SliverToBoxAdapter(
                  child: _ProfileHeader(),
                ),
                // Stats row
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    child: Row(
                      children: [
                        _StatCard(
                          value: '$totalSongs',
                          label: 'Bài hát',
                          icon: Icons.music_note_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          value: '$totalArtists',
                          label: 'Nghệ sĩ',
                          icon: Icons.person_rounded,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          value: '$totalAlbums',
                          label: 'Album',
                          icon: Icons.album_rounded,
                          color: AppColors.tertiary,
                        ),
                      ],
                    ),
                  ),
                ),
                // Action section title
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(
                      'Chức năng',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                // Action buttons
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _ActionTile(
                          icon: Icons.refresh_rounded,
                          iconColor: AppColors.primary,
                          title: 'Quét lại nhạc',
                          subtitle: 'Cập nhật thư viện từ bộ nhớ máy',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const OnboardingScreen(),
                              ),
                            );
                          },
                        ),
                        _ActionTile(
                          icon: Icons.download_rounded,
                          iconColor: AppColors.secondary,
                          title: 'Tải nhạc',
                          subtitle: 'Tính năng sắp có',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tính năng đang được phát triển'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          disabled: true,
                        ),
                        _ActionTile(
                          icon: Icons.settings_rounded,
                          iconColor: AppColors.textSecondary,
                          title: 'Cài đặt',
                          subtitle: 'Tùy chỉnh ứng dụng',
                          onTap: () {
                            _showSettings(context, music);
                          },
                        ),
                        _ActionTile(
                          icon: Icons.info_outline_rounded,
                          iconColor: AppColors.textTertiary,
                          title: 'Về ứng dụng',
                          subtitle: 'Nocturne Audio v1.0.0',
                          onTap: () => _showAbout(context),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
          if (player.currentSong != null) const MiniPlayer(),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context, MusicProvider music) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Text(
              'Cài đặt',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Thư viện nhạc',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            _SettingsRow(
              label: 'Lọc file dưới 30 giây',
              subtitle: 'Bỏ qua nhạc chuông, thông báo',
              value: true,
              onChanged: (_) {},
            ),
            const SizedBox(height: 20),
            Text(
              'Giao diện',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            _SettingsRow(
              label: 'Album art xoay khi phát',
              subtitle: 'Hiệu ứng đĩa vinyl',
              value: true,
              onChanged: (_) {},
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Nocturne Audio',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2024 Nocturne Audio',
    );
  }
}

// ── Profile header ────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          // Background glow
          Positioned(
            top: -30,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button row
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20, color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Avatar + name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                        ),
                        child: const Icon(Icons.person_rounded,
                            color: Colors.white, size: 36),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thính giả',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Nocturne Audio',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action tile ───────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.disabled = false,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: iconColor.withOpacity(0.15),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: AppColors.textDisabled, size: 20),
          onTap: disabled ? null : onTap,
        ),
      ),
    );
  }
}

// ── Settings toggle row ───────────────────────────────────

class _SettingsRow extends StatefulWidget {
  const _SettingsRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<_SettingsRow> {
  late bool _val;

  @override
  void initState() {
    super.initState();
    _val = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(widget.label,
            style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary)),
        subtitle: Text(widget.subtitle,
            style: GoogleFonts.outfit(
                fontSize: 12, color: AppColors.textTertiary)),
        trailing: Switch(
          value: _val,
          onChanged: (v) {
            setState(() => _val = v);
            widget.onChanged(v);
          },
          activeColor: AppColors.primary,
        ),
      ),
    );
  }
}
