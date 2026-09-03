import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:muziczz/core/app_strings.dart';

class SelectionHeader extends StatelessWidget {
  const SelectionHeader({
    super.key,
    required this.count,
    required this.total,
    required this.onToggleSelectAll,
    required this.onCancel,
  });
  final int count;
  final int total;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final allSelected = total > 0 && count >= total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: c.textPrimary, size: 22),
            onPressed: onCancel,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              count == 0
                  ? AppStrings.selectSongs
                  : AppStrings.selectedCount(count),
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: onToggleSelectAll,
            child: Text(
              allSelected ? AppStrings.deselectAll : AppStrings.selectAll,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: c.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
