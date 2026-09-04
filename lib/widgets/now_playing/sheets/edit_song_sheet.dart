import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:provider/provider.dart';
import '../../../models/song_item.dart';
import '../../../providers/music_provider.dart';
import 'package:muziczz/core/app_strings.dart';

/// Mở sheet "Sửa thông tin" (tên bài / nghệ sĩ) cho [song].
void showEditSongSheet(BuildContext context, SongItem song) {
  final c = context.appColors;
  showModalBottomSheet(
    context: context,
    backgroundColor: c.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => EditSongSheet(song: song),
  );
}

class EditSongSheet extends StatefulWidget {
  const EditSongSheet({super.key, required this.song});
  final SongItem song;

  @override
  State<EditSongSheet> createState() => _EditSongSheetState();
}

class _EditSongSheetState extends State<EditSongSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _artistCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.song.title);
    _artistCtrl = TextEditingController(text: widget.song.artist);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final song = widget.song;
    final t = _titleCtrl.text.trim();
    final a = _artistCtrl.text.trim();
    if (t.isNotEmpty) {
      context.read<MusicProvider>().updateSongMeta(
        song.id,
        t,
        a.isEmpty ? song.artist : a,
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.editInfo,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _metaField(context, AppStrings.songTitle, _titleCtrl, isLast: false),
          const SizedBox(height: 12),
          _metaField(context, AppStrings.artist, _artistCtrl, isLast: true),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppStrings.cancel,
                    style: GoogleFonts.outfit(color: c.textTertiary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: c.primary),
                  onPressed: _save,
                  child: Text(
                    AppStrings.save,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaField(
    BuildContext context,
    String label,
    TextEditingController ctrl, {
    required bool isLast,
  }) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 12, color: c.textTertiary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          // Enter moves to the next field; Done on the last field saves.
          textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
          onSubmitted: isLast ? (_) => _save() : null,
          style: GoogleFonts.outfit(color: c.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: c.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.primary, width: 1),
            ),
          ),
        ),
      ],
    );
  }
}
