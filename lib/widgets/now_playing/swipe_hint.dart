import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:muziczz/core/app_strings.dart';

class SwipeHint extends StatelessWidget {
  const SwipeHint({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Semantics(
      button: true,
      label: AppStrings.openQueue,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Icon(
              Icons.keyboard_arrow_up_rounded,
              color: c.onPlayerMinimal,
              size: 20,
            ),
            Text(
              AppStrings.queueShort,
              style: GoogleFonts.outfit(fontSize: 11, color: c.onPlayerMinimal),
            ),
          ],
        ),
      ),
    );
  }
}
