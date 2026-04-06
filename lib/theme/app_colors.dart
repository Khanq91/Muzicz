import 'package:flutter/material.dart';

import 'app_colors_data.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// AppColors — nguồn màu duy nhất của toàn bộ ứng dụng
///
/// ⚠️  KHÔNG hardcode bất kỳ màu nào trực tiếp vào widget/screen.
///     Mọi màu đều phải khai báo tại đây và tham chiếu qua AppColors.xxx
///
/// Cấu trúc:
///   1. Brand — màu chính (primary, secondary, tertiary)
///   2. Background / Surface — nền và mặt phẳng
///   3. Text — màu chữ
///   4. Divider / Border
///   5. Glass / Frost
///   6. Accent — màu nhấn phụ (dùng trong gradient smart-lists, badges)
///   7. On-Player — màu trắng với opacity dùng trong NowPlayingScreen
///   8. Scrim / Overlay — lớp phủ đen bán trong suốt
///   9. Gradients — tất cả gradient preset
///  10. Dynamic helpers
/// ════════════════════════════════════════════════════════════════════════════
class AppColors {
  AppColors._();

  // static const _d = AppColorPresets.dark;
  //
  // static const Color primary       = _d.primary;
  // static const Color primaryDark   = _d.primaryDark;
  // static const Color primaryLight  = _d.primaryLight;
  // static const Color secondary     = _d.secondary;
  // static const Color secondaryDark = _d.secondaryDark;
  // static const Color tertiary      = _d.tertiary;
  // static const Color tertiaryDark  = _d.tertiaryDark;
  //
  // static const Color background      = _d.background;
  // static const Color surface         = _d.surface;
  // static const Color surfaceElevated = _d.surfaceElevated;
  // static const Color card            = _d.card;
  // static const Color cardHover       = _d.cardHover;
  //
  // static const Color textPrimary   = _d.textPrimary;
  // static const Color textSecondary = _d.textSecondary;
  // static const Color textTertiary  = _d.textTertiary;
  // static const Color textDisabled  = _d.textDisabled;
  //
  // static const Color divider = _d.divider;
  // static const Color border  = _d.border;
  //
  // static const Color glassBg     = _d.glassBg;
  // static const Color glassBorder = _d.glassBorder;
  //
  // static const Color accentCyan    = _d.accentCyan;
  // static const Color accentMagenta = _d.accentMagenta;
  // static const Color accentPink    = _d.accentPink;
  //
  // static const Color onPlayer        = _d.onPlayer;
  // static const Color onPlayerHigh    = _d.onPlayerHigh;
  // static const Color onPlayerMedium  = _d.onPlayerMedium;
  // static const Color onPlayerLow     = _d.onPlayerLow;
  // static const Color onPlayerSubtle  = _d.onPlayerSubtle;
  // static const Color onPlayerMinimal = _d.onPlayerMinimal;
  // static const Color onPlayerGhost   = _d.onPlayerGhost;
  // static const Color onPlayerGhostBg = _d.onPlayerGhostBg;
  //
  // static const Color scrimDark   = _d.scrimDark;
  // static const Color scrimMedium = _d.scrimMedium;
  // static const Color scrimLight  = _d.scrimLight;
  // static const Color scrimSubtle = _d.scrimSubtle;
  //
  // static const LinearGradient primaryGradient        = _d.primaryGradient;
  // static const LinearGradient tertiaryGradient       = _d.tertiaryGradient;
  // static const LinearGradient backgroundGradient     = _d.backgroundGradient;
  // static const LinearGradient recentlyPlayedGradient = _d.recentlyPlayedGradient;
  // static const LinearGradient mostPlayedGradient     = _d.mostPlayedGradient;
  // static const LinearGradient favoritesGradient      = _d.favoritesGradient;
  // static const LinearGradient randomMixGradient      = _d.randomMixGradient;

  // ─────────────────────────────────────────────────────────────────────────
  // 1. BRAND
  // ─────────────────────────────────────────────────────────────────────────

  static const Color primary      = Color(0xFF9D50FF);
  static const Color primaryDark  = Color(0xFF7B2FE0);
  static const Color primaryLight = Color(0xFFBB82FF);

  static const Color secondary     = Color(0xFF9B5CBF);
  static const Color secondaryDark = Color(0xFF7A3D9E);

  static const Color tertiary     = Color(0xFFC25169);
  static const Color tertiaryDark = Color(0xFFA03050);

  // ─────────────────────────────────────────────────────────────────────────
  // 2. BACKGROUND / SURFACE
  // ─────────────────────────────────────────────────────────────────────────

  static const Color background      = Color(0xFF080808);
  static const Color surface         = Color(0xFF111111);
  static const Color surfaceElevated = Color(0xFF191919);
  static const Color card            = Color(0xFF1C1C1E);
  static const Color cardHover       = Color(0xFF242426);

  // ─────────────────────────────────────────────────────────────────────────
  // 3. TEXT
  // ─────────────────────────────────────────────────────────────────────────

  /// Dùng trên nền tối (surface, card, background)
  static const Color textPrimary  = Color(0xFFFFFFFF);        // 100%
  static const Color textSecondary = Color(0xB3FFFFFF);       // 70%
  static const Color textTertiary  = Color(0x80FFFFFF);       // 50%
  static const Color textDisabled  = Color(0x4DFFFFFF);       // 30%

  // ─────────────────────────────────────────────────────────────────────────
  // 4. DIVIDER / BORDER
  // ─────────────────────────────────────────────────────────────────────────

  static const Color divider = Color(0x18FFFFFF);   // 9%
  static const Color border  = Color(0x22FFFFFF);   // 13%

  // ─────────────────────────────────────────────────────────────────────────
  // 5. GLASS / FROST
  // ─────────────────────────────────────────────────────────────────────────

  static const Color glassBg     = Color(0x1AFFFFFF);  // 10%
  static const Color glassBorder = Color(0x26FFFFFF);  // 15%

  // ─────────────────────────────────────────────────────────────────────────
  // 6. ACCENT  (màu nhấn phụ — smart-lists, feature tiles, badges)
  //
  //  Được dùng trong:
  //    home_screen.dart   → _QuickSection gradients ("Nghe nhiều nhất", "Random Mix")
  //    online_screen.dart → "Tìm kiếm trực tuyến" feature tile icon color
  // ─────────────────────────────────────────────────────────────────────────

  /// Cyan — Random Mix card, Online search icon
  static const Color accentCyan    = Color(0xFF00BCD4);

  /// Magenta / purple-pink — "Nghe nhiều nhất" card gradient start color
  static const Color accentMagenta = Color(0xFFE040FB);

  /// Hot pink — "Yêu thích" card gradient end color
  static const Color accentPink    = Color(0xFFE91E63);

  // ─────────────────────────────────────────────────────────────────────────
  // 7. ON-PLAYER  (white với opacity — dùng TRONG NowPlayingScreen)
  //
  //  NowPlayingScreen có nền blur tối nên dùng bộ màu riêng này.
  //  KHÔNG dùng Colors.white trực tiếp ở các screen đó.
  // ─────────────────────────────────────────────────────────────────────────

  /// Trắng 100% — tên bài, icon play button
  static const Color onPlayer        = Color(0xFFFFFFFF);

  /// Trắng 70% — tên album, nhãn thời gian, swipe hint
  static const Color onPlayerHigh    = Color(0xB3FFFFFF);

  /// Trắng 60% — subtitle nghệ sĩ trong player
  static const Color onPlayerMedium  = Color(0x99FFFFFF);

  /// Trắng 54% — icon share/volume/queue, border queue button
  static const Color onPlayerLow     = Color(0x8AFFFFFF);

  /// Trắng 38% — icon volume, icon share (extra actions)
  static const Color onPlayerSubtle  = Color(0x61FFFFFF);

  /// Trắng 24% — swipe hint icon/text, progress bar inactive
  static const Color onPlayerMinimal = Color(0x3DFFFFFF);

  /// Trắng 12% — queue button border (không active)
  static const Color onPlayerGhost   = Color(0x1FFFFFFF);

  /// Trắng 8% — queue button background (không active)
  static const Color onPlayerGhostBg = Color(0x14FFFFFF);

  // ─────────────────────────────────────────────────────────────────────────
  // 8. SCRIM / OVERLAY  (lớp phủ đen bán trong suốt)
  //
  //  Dùng để tối hoá ảnh nền (album art, artist header) trước khi render text.
  // ─────────────────────────────────────────────────────────────────────────

  /// 55% — NowPlayingScreen overlay chính
  static const Color scrimDark   = Color(0x8C000000);

  /// 50% — album art gradient overlay
  static const Color scrimMedium = Color(0x80000000);

  /// 45% — ArtistDetailScreen backdrop blur overlay
  static const Color scrimLight  = Color(0x73000000);

  /// 30% — bottom nav shadow, light shadows
  static const Color scrimSubtle = Color(0x4D000000);

  // ─────────────────────────────────────────────────────────────────────────
  // 9. GRADIENTS
  // ─────────────────────────────────────────────────────────────────────────

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  static const LinearGradient tertiaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tertiary, secondary],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0E0A18), background],
  );

  // ── Smart-list card gradients (home_screen → _QuickSection) ──────────────

  /// "Nghe gần đây"
  static const LinearGradient recentlyPlayedGradient = LinearGradient(
    colors: [primary, secondary],
  );

  /// "Nghe nhiều nhất"
  static const LinearGradient mostPlayedGradient = LinearGradient(
    colors: [accentMagenta, secondary],
  );

  /// "Yêu thích"
  static const LinearGradient favoritesGradient = LinearGradient(
    colors: [tertiary, accentPink],
  );

  /// "Random Mix"
  static const LinearGradient randomMixGradient = LinearGradient(
    colors: [accentCyan, primary],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // 10. DYNAMIC HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Tạo gradient động từ màu album art trích xuất (dùng trong NowPlaying nếu muốn)
  static LinearGradient dynamicGradient(Color dominantColor) {
    final hsl = HSLColor.fromColor(dominantColor);
    final darker =
    hsl.withLightness((hsl.lightness - 0.3).clamp(0.0, 1.0)).toColor();
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        dominantColor.withOpacity(0.6),
        darker.withOpacity(0.9),
      ],
    );
  }
}