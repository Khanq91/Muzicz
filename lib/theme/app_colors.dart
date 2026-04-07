import 'package:flutter/material.dart';

import 'app_colors_data.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// AppColors — nguồn màu duy nhất của toàn bộ ứng dụng
///
/// ⚠️  KHÔNG hardcode bất kỳ màu nào trực tiếp vào widget/screen.
///
/// ── Cách dùng đúng (theme-aware) ──────────────────────────────────────────
///   final c = context.appColors;   // dynamic, phản ứng với theme change
///   Container(color: c.background)
///
/// ── Backward compat (chỉ dùng trong widgets không cần đổi theme) ──────────
///   AppColors.primary   // static dark, KHÔNG reactive
///
/// ════════════════════════════════════════════════════════════════════════════
class AppColors {
  AppColors._();

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

  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textTertiary  = Color(0x80FFFFFF);
  static const Color textDisabled  = Color(0x4DFFFFFF);

  // ─────────────────────────────────────────────────────────────────────────
  // 4. DIVIDER / BORDER
  // ─────────────────────────────────────────────────────────────────────────

  static const Color divider = Color(0x18FFFFFF);
  static const Color border  = Color(0x22FFFFFF);

  // ─────────────────────────────────────────────────────────────────────────
  // 5. GLASS / FROST
  // ─────────────────────────────────────────────────────────────────────────

  static const Color glassBg     = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x26FFFFFF);

  // ─────────────────────────────────────────────────────────────────────────
  // 6. ACCENT
  // ─────────────────────────────────────────────────────────────────────────

  static const Color accentCyan    = Color(0xFF00BCD4);
  static const Color accentMagenta = Color(0xFFE040FB);
  static const Color accentPink    = Color(0xFFE91E63);

  // ─────────────────────────────────────────────────────────────────────────
  // 7. ON-PLAYER
  // ─────────────────────────────────────────────────────────────────────────

  static const Color onPlayer        = Color(0xFFFFFFFF);
  static const Color onPlayerHigh    = Color(0xB3FFFFFF);
  static const Color onPlayerMedium  = Color(0x99FFFFFF);
  static const Color onPlayerLow     = Color(0x8AFFFFFF);
  static const Color onPlayerSubtle  = Color(0x61FFFFFF);
  static const Color onPlayerMinimal = Color(0x3DFFFFFF);
  static const Color onPlayerGhost   = Color(0x1FFFFFFF);
  static const Color onPlayerGhostBg = Color(0x14FFFFFF);

  // ─────────────────────────────────────────────────────────────────────────
  // 8. SCRIM / OVERLAY
  // ─────────────────────────────────────────────────────────────────────────

  static const Color scrimDark   = Color(0x8C000000);
  static const Color scrimMedium = Color(0x80000000);
  static const Color scrimLight  = Color(0x73000000);
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

  static const LinearGradient recentlyPlayedGradient = LinearGradient(
    colors: [primary, secondary],
  );

  static const LinearGradient mostPlayedGradient = LinearGradient(
    colors: [accentMagenta, secondary],
  );

  static const LinearGradient favoritesGradient = LinearGradient(
    colors: [tertiary, accentPink],
  );

  static const LinearGradient randomMixGradient = LinearGradient(
    colors: [accentCyan, primary],
  );

  static const LinearGradient avatarButton = LinearGradient(
      colors: [primary, tertiary]
  );

  // ─────────────────────────────────────────────────────────────────────────
  // 10. DYNAMIC HELPERS
  // ─────────────────────────────────────────────────────────────────────────

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