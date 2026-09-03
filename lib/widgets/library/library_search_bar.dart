import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:provider/provider.dart';
import '../../providers/music_provider.dart';
import 'package:muziczz/core/app_strings.dart';

/// Ô tìm kiếm + dòng chỉ báo phạm vi. Chỉ widget này rebuild theo text (qua
/// ValueListenableBuilder trên controller) thay vì setState() rỗng cả màn hình
/// (header, TabBar, tab content) trên mỗi phím gõ.
class LibrarySearchBar extends StatelessWidget {
  const LibrarySearchBar({super.key, required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final songCount = context.select<MusicProvider, int>(
      (m) => m.allSongs.length,
    );
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasSearchText = value.text.isNotEmpty;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: TextField(
                controller: controller,
                onChanged:
                    (q) =>
                        context.read<MusicProvider>().setLibrarySearchQuery(q),
                style: GoogleFonts.outfit(color: c.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: AppStrings.librarySearchHint,
                  hintStyle: GoogleFonts.outfit(
                    color: c.textDisabled,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: c.textTertiary,
                    size: 20,
                  ),
                  suffixIcon:
                      hasSearchText
                          ? IconButton(
                            tooltip: AppStrings.clearSearch,
                            onPressed: () {
                              controller.clear();
                              context
                                  .read<MusicProvider>()
                                  .setLibrarySearchQuery('');
                            },
                            icon: Icon(
                              Icons.close_rounded,
                              color: c.textTertiary,
                              size: 18,
                            ),
                          )
                          : null,
                  filled: true,
                  fillColor: c.surfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.primary, width: 1),
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: hasSearchText ? 28 : 0,
              curve: Curves.easeOut,
              child:
                  hasSearchText
                      ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.storage_rounded,
                              size: 12,
                              color: c.textDisabled,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              AppStrings.searchLocalLibrary(songCount),
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: c.textDisabled,
                              ),
                            ),
                          ],
                        ),
                      )
                      : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}
