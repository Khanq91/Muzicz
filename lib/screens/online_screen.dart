import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import '../theme/app_colors.dart';

class OnlineScreen extends StatelessWidget {
  const OnlineScreen({super.key, this.isEmbedded = false});
  final bool isEmbedded;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  // ← Ẩn back button khi isEmbedded
                  if (!isEmbedded)
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20, color: c.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  if (isEmbedded)
                    const SizedBox(width: 16),
                  Text(
                    'Trực tuyến',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Coming soon hero ───────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
                      child: Column(
                        children: [
                          // Icon
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.primary.withOpacity(0.12),
                              border: Border.all(
                                color: c.primary.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.wifi_rounded,
                              color: c.primary,
                              size: 38,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Đang phát triển',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Tính năng phát nhạc trực tuyến đang được\nxây dựng. Cảm ơn bạn đã chờ đợi!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              color: c.textTertiary,
                              height: 1.65,
                            ),
                          ),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),

                  // ── Planned features preview ──────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Text(
                        'Sắp có',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: c.textTertiary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _FeatureTile(
                          icon: Icons.download_rounded,
                          iconColor: c.secondary,
                          title: 'Tải nhạc từ URL',
                          subtitle: 'TikTok, YouTube, SoundCloud và hơn thế nữa',
                          badge: 'Sớm',
                        ),
                        _FeatureTile(
                          icon: Icons.radio_rounded,
                          iconColor: c.primary,
                          title: 'Radio trực tuyến',
                          subtitle: 'Nghe các kênh radio từ khắp nơi',
                          badge: 'Sắp có',
                        ),
                        _FeatureTile(
                          icon: Icons.search_rounded,
                          iconColor: c.accentCyan,
                          title: 'Tìm kiếm trực tuyến',
                          subtitle: 'Tìm và phát nhạc trực tiếp từ web',
                          badge: 'Đang phát triển',
                        ),
                        _FeatureTile(
                          icon: Icons.sync_rounded,
                          iconColor: c.tertiary,
                          title: 'Đồng bộ danh sách phát',
                          subtitle: 'Đồng bộ playlist với các nền tảng khác',
                          badge: 'Sắp có',
                        ),
                      ]),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feature preview tile ──────────────────────────────────

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badge,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: iconColor.withOpacity(0.12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
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
          const SizedBox(width: 8),
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: c.primary.withOpacity(0.2),
                width: 0.5,
              ),
            ),
            child: Text(
              badge,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: c.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}