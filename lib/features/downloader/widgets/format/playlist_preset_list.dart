import 'package:flutter/material.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'playlist_preset.dart';

class PlaylistPresetList extends StatelessWidget {
  final List<PlaylistPreset> presets;
  final PlaylistPreset? selected;
  final ValueChanged<PlaylistPreset> onSelect;

  const PlaylistPresetList({
    super.key,
    required this.presets,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children:
          presets
              .map(
                (p) => _PresetTile(
                  preset: p,
                  isSelected: selected?.formatId == p.formatId,
                  onTap: () => onSelect(p),
                ),
              )
              .toList(),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final PlaylistPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetTile({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? c.primary.withValues(alpha: 0.12)
                  : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? c.primary.withValues(alpha: 0.5)
                    : c.border,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? c.primary.withValues(alpha: 0.2)
                        : c.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                preset.icon,
                size: 20,
                color: isSelected ? c.primary : c.textTertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.label,
                    style: TextStyle(
                      color:
                          isSelected
                              ? c.textPrimary
                              : c.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preset.description,
                    style: TextStyle(
                      color: c.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isSelected ? c.primary : c.textTertiary,
                  width: isSelected ? 0 : 1.5,
                ),
                gradient: isSelected ? c.primaryGradient : null,
              ),
              child:
                  isSelected
                      ? Icon(
                        Icons.check_rounded,
                        color: c.onPlayer,
                        size: 13,
                      )
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}
