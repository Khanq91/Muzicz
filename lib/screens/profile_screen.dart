import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../features/downloader/screens/downloader_gateway_screen.dart';
import '../features/music_visual/core/visual_feature_flag.dart';
import '../features/music_visual/providers/visual_mode_provider.dart';
import '../features/music_visual/widgets/visual_mode_selector_sheet.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors_data.dart';
import '../providers/theme_provider.dart';
import '../widgets/mini_player.dart';
import '../widgets/bottom_nav_style_selector_sheet.dart';
import '../widgets/theme_selector_sheet.dart';
import 'hidden_songs_screen.dart';
import 'onboarding_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:muziczz/core/app_strings.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// Đọc một lần cho cả vòng đời app — build() có thể chạy lại nhiều lần.
  static final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final music = context.watch<MusicProvider>();
    final player = context.watch<PlayerProvider>();

    final totalSongs = music.allSongs.length;
    final totalArtists = music.artistMap.length;
    final totalAlbums = music.albumMap.length;

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _ProfileHeader(colors: c)),
                // Stats row
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    child: Row(
                      children: [
                        _StatCard(
                          value: '$totalSongs',
                          label: AppStrings.songs,
                          icon: Icons.music_note_rounded,
                          color: c.primary,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          value: '$totalArtists',
                          label: AppStrings.artist,
                          icon: Icons.person_rounded,
                          color: c.secondary,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          value: '$totalAlbums',
                          label: AppStrings.album,
                          icon: Icons.album_rounded,
                          color: c.tertiary,
                        ),
                      ],
                    ),
                  ),
                ),
                // Section label
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(
                      AppStrings.features,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: c.textTertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                // Action tiles
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _ActionTile(
                          icon: Icons.refresh_rounded,
                          iconColor: c.primary,
                          title: AppStrings.rescanMusic,
                          subtitle: AppStrings.rescanMusicSubtitle,
                          onTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const OnboardingScreen(),
                                ),
                              ),
                          colors: c,
                        ),
                        _ActionTile(
                          icon: Icons.download_rounded,
                          iconColor: c.secondary,
                          title: AppStrings.downloadMusic,
                          subtitle: AppStrings.downloadMusicSubtitle,
                          onTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) => const DownloaderGatewayScreen(),
                                ),
                              ),
                          colors: c,
                        ),
                        _ActionTile(
                          icon: Icons.settings_rounded,
                          iconColor: c.textSecondary,
                          title: AppStrings.settings,
                          subtitle: AppStrings.settingsSubtitle,
                          onTap: () => _showSettings(context, music, c),
                          colors: c,
                        ),
                        FutureBuilder<PackageInfo>(
                          future: _packageInfo,
                          builder: (context, snap) {
                            final version = snap.data?.version;
                            return _ActionTile(
                              icon: Icons.info_outline_rounded,
                              iconColor: c.textTertiary,
                              title: AppStrings.about,
                              subtitle: AppStrings.appVersion(version ?? '…'),
                              onTap: () => _showAbout(context, version),
                              colors: c,
                            );
                          },
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

  void _showSettings(
    BuildContext context,
    MusicProvider music,
    AppColorsData c,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        // Cần watch ThemeProvider bên trong sheet để subtitle cập nhật realtime
        return ChangeNotifierProvider.value(
          value: context.read<ThemeProvider>(),
          child: _SettingsSheet(music: music, parentContext: context),
        );
      },
    );
  }

  void _showAbout(BuildContext context, String? version) {
    showAboutDialog(
      context: context,
      applicationName: AppStrings.appName,
      applicationVersion: version ?? '',
      applicationLegalese: AppStrings.copyright,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Settings sheet — tách thành StatefulWidget để rebuild khi theme đổi
// ════════════════════════════════════════════════════════════════════════════

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.music, required this.parentContext});
  final MusicProvider music;
  final BuildContext parentContext;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final themeProvider = context.watch<ThemeProvider>();
    final themeMode = themeProvider.mode;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            AppStrings.settings,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // ── Giao diện ─────────────────────────────────────────────────
          Text(
            AppStrings.appearance,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: c.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          // Tile tùy chỉnh giao diện
          _SettingsTappableRow(
            icon: themeMode.icon,
            iconColor: c.primary,
            label: AppStrings.colorScheme,
            subtitle: switch (themeMode) {
              AppThemeMode.dark => AppStrings.themeDarkLabel,
              AppThemeMode.amoled => AppStrings.themeAmoledLabel,
              AppThemeMode.light => AppStrings.themeLightLabel,
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Preview dot của theme hiện tại
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: c.primaryGradient,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: c.textDisabled,
                  size: 20,
                ),
              ],
            ),
            // onTap: () {
            //   Navigator.pop(context);
            //   ThemeSelectorSheet.show(context);
            // },
            onTap: () {
              Navigator.pop(context);

              ThemeSelectorSheet.show(widget.parentContext);
            },
            colors: c,
          ),

          const SizedBox(height: 8),

          _SettingsTappableRow(
            icon: Icons.auto_awesome_rounded,
            iconColor: c.secondary,
            label: AppStrings.graphics,
            subtitle: themeProvider.bottomNavStyle.label,
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: c.textDisabled,
              size: 20,
            ),
            onTap: () {
              Navigator.pop(context);
              BottomNavStyleSelectorSheet.show(widget.parentContext);
            },
            colors: c,
          ),

          if (kMusicVisualFeatureEnabled) ...[
            const SizedBox(height: 8),
            _SettingsTappableRow(
              icon: Icons.graphic_eq_rounded,
              iconColor: c.tertiary,
              label: AppStrings.musicVisual,
              subtitle: context.watch<VisualModeProvider>().mode.label,
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: c.textDisabled,
                size: 20,
              ),
              onTap: () {
                Navigator.pop(context);
                VisualModeSelectorSheet.show(widget.parentContext);
              },
              colors: c,
            ),
          ],

          const SizedBox(height: 20),

          // ── Thư viện nhạc ─────────────────────────────────────────────
          Text(
            AppStrings.musicLibrary,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: c.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          _SettingsRow(
            label: AppStrings.filterShortFiles,
            subtitle: AppStrings.filterShortFilesSubtitle,
            value: true,
            onChanged: (_) {},
            colors: c,
          ),

          const SizedBox(height: 8),

          _SettingsTappableRow(
            icon: Icons.visibility_off_rounded,
            iconColor: c.textSecondary,
            label: AppStrings.hiddenSongs,
            subtitle: AppStrings.hiddenSongsSubtitle,
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: c.textDisabled,
              size: 20,
            ),
            onTap: () {
              Navigator.pop(context); // đóng settings sheet
              Navigator.of(widget.parentContext).push(
                MaterialPageRoute(
                  builder:
                      (_) => ChangeNotifierProvider.value(
                        value: widget.music,
                        child: const HiddenSongsScreen(),
                      ),
                ),
              );
            },
            colors: c,
          ),
        ],
      ),
    );
  }
}

// ── Tappable settings row (dùng cho Giao diện) ───────────────────────────────

class _SettingsTappableRow extends StatelessWidget {
  const _SettingsTappableRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    required this.colors,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  final AppColorsData colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: iconColor.withValues(alpha: 0.15),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile header ─────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.colors});
  final AppColorsData colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
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
                    c.primary.withValues(alpha: 0.12),
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
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: c.textPrimary,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: c.primaryGradient,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.listener,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            AppStrings.profileTagline,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: c.textTertiary,
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

// ── Stat card ──────────────────────────────────────────────────────────────

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
    final c = context.appColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
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
                color: c.textPrimary,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: c.textTertiary,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action tile ────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.colors,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final AppColorsData colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Opacity(
      opacity: 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: iconColor.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: c.textPrimary,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.outfit(fontSize: 12, color: c.textTertiary),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: c.textDisabled,
            size: 20,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

// ── Settings toggle row ────────────────────────────────────────────────────

class _SettingsRow extends StatefulWidget {
  const _SettingsRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.colors,
  });
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppColorsData colors;

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
    final c = widget.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(
          widget.label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: c.textPrimary,
          ),
        ),
        subtitle: Text(
          widget.subtitle,
          style: GoogleFonts.outfit(fontSize: 12, color: c.textTertiary),
        ),
        trailing: Switch(
          value: _val,
          onChanged: (v) {
            setState(() => _val = v);
            widget.onChanged(v);
          },
          activeThumbColor: c.primary,
        ),
      ),
    );
  }
}
