import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:muziczz/core/app_strings.dart';

class SelectionActionBar extends StatelessWidget {
  const SelectionActionBar({
    super.key,
    required this.count,
    required this.onAddToPlaylist,
    required this.onFavorite,
    required this.onHide,
  });
  final int count;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onFavorite;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final enabled = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionBarBtn(
            icon: Icons.playlist_add_rounded,
            label: AppStrings.playlist,
            onTap: enabled ? onAddToPlaylist : null,
          ),
          _ActionBarBtn(
            icon: Icons.favorite_rounded,
            label: AppStrings.favorites,
            onTap: enabled ? onFavorite : null,
          ),
          _ActionBarBtn(
            icon: Icons.visibility_off_rounded,
            label: AppStrings.hide,
            onTap: enabled ? onHide : null,
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

class _ActionBarBtn extends StatelessWidget {
  const _ActionBarBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final enabled = onTap != null;
    final color =
        !enabled
            ? c.textDisabled
            : isDestructive
            ? c.tertiary
            : c.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
