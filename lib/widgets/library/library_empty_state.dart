import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:muziczz/core/app_strings.dart';

class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.showSearchTip = false,
    this.searchQuery = '',
    this.onScanTap,
    this.onClearSearch,
  });
  final IconData icon;
  final String message;
  final bool showSearchTip;
  final String searchQuery;
  final VoidCallback? onScanTap;

  /// Clears both the search field and the provider query; the owner of the
  /// TextEditingController supplies it. Shown with [showSearchTip].
  final VoidCallback? onClearSearch;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: c.textDisabled, size: 52),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: c.textTertiary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          if (onScanTap != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onScanTap,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: Text(
                AppStrings.scanNow,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: c.onPlayer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
          if (showSearchTip) ...[
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: c.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Column(
                children: [
                  Text(
                    AppStrings.searchSuggestions,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: c.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.searchTip,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: c.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onClearSearch,
              icon: Icon(Icons.close_rounded, size: 16, color: c.primary),
              label: Text(
                AppStrings.clearSearch,
                style: GoogleFonts.outfit(
                  color: c.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
