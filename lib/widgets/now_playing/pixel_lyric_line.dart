import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../../models/lyric_line.dart';
import '../../providers/lyrics_provider.dart';
import '../../theme/app_colors_data.dart';

/// Compose's very-low-stiffness / medium-bouncy spring used by PixelPlayer.
class LyricsSpringCurve extends Curve {
  const LyricsSpringCurve();
  @override
  double transformInternal(double t) => SpringSimulation(
    SpringDescription.withDampingRatio(mass: 1, stiffness: 50, ratio: .5),
    0,
    1,
    0,
  ).x(t * 1.6);
}

class PixelLyricLine extends StatelessWidget {
  const PixelLyricLine({
    super.key,
    required this.line,
    required this.index,
    required this.provider,
    required this.plain,
    required this.immersive,
    this.onTap,
  });
  final LyricLine line;
  final int index;
  final LyricsProvider provider;
  final bool plain, immersive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final timed = !plain && provider.isSynced;
    final distance = (index - provider.currentIndex).abs();
    final active = timed && distance == 0;
    final animated = timed && provider.animated;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final alignment =
        provider.alignment == 'right'
            ? Alignment.centerRight
            : provider.center
            ? Alignment.center
            : Alignment.centerLeft;
    final textAlign =
        provider.alignment == 'right'
            ? TextAlign.right
            : provider.center
            ? TextAlign.center
            : TextAlign.left;
    final scale =
        !animated
            ? 1.0
            : active
            ? (immersive ? 1.02 : 1.1)
            : distance == 1
            ? .95
            : .85;
    final padding =
        !animated
            ? 12.0
            : active
            ? 32.0
            : distance == 1
            ? 16.0
            : 8.0;
    final opacity =
        !animated || active
            ? 1.0
            : distance == 1
            ? .6
            : .3;
    final blur =
        animated && provider.blur && !active
            ? (distance * provider.blurStrength).clamp(0.0, 10.0)
            : 0.0;
    final color =
        !timed
            ? c.textPrimary
            : active
            ? c.primary
            : c.textPrimary.withValues(alpha: .45);
    final fontSize = provider.fontSize * (immersive ? 1.4 : 1);
    final style = TextStyle(
      fontFamily: 'Roboto',
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.4,
      color: color,
    );
    final motion = reduced ? Duration.zero : const Duration(milliseconds: 1600);
    Widget text = Text(
      line.text.isEmpty ? '•••' : line.text,
      textAlign: textAlign,
    );
    if (timed && line.words.isNotEmpty) {
      text = Text.rich(
        TextSpan(
          children: [
            for (var i = 0; i < line.words.length; i++)
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: AnimatedScale(
                  scale:
                      animated && active && i <= provider.currentWord ? 1.1 : 1,
                  duration:
                      animated
                          ? motion
                          : reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                  curve: animated ? const LyricsSpringCurve() : Curves.linear,
                  child: AnimatedOpacity(
                    opacity:
                        animated && !(active && i <= provider.currentWord)
                            ? .55
                            : 1,
                    duration:
                        reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                    child: AnimatedDefaultTextStyle(
                      duration:
                          reduced
                              ? Duration.zero
                              : const Duration(milliseconds: 250),
                      style: style.copyWith(
                        color:
                            active && i <= provider.currentWord
                                ? c.primary
                                : c.textPrimary.withValues(alpha: .45),
                      ),
                      child: Text(line.words[i].text),
                    ),
                  ),
                ),
              ),
          ],
        ),
        textAlign: textAlign,
      );
    }
    final content = Column(
      crossAxisAlignment:
          provider.alignment == 'right'
              ? CrossAxisAlignment.end
              : provider.center
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
      children: [
        text,
        if (provider.romanization && line.romanization != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              line.romanization!,
              textAlign: textAlign,
              style: TextStyle(
                fontSize: fontSize * .75,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        if (provider.translation && line.translation != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              line.translation!,
              textAlign: textAlign,
              style: TextStyle(
                fontSize: fontSize * .75,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
      ],
    );
    return Padding(
      padding:
          !animated || immersive
              ? EdgeInsets.zero
              : EdgeInsets.only(
                left: provider.center || provider.alignment == 'right' ? 36 : 0,
                right: provider.alignment == 'right' ? 0 : 36,
              ),
      child: AnimatedPadding(
        padding: EdgeInsets.symmetric(vertical: padding, horizontal: 2),
        duration:
            animated
                ? motion
                : reduced
                ? Duration.zero
                : const Duration(milliseconds: 200),
        curve: animated ? const LyricsSpringCurve() : Curves.linear,
        child: Semantics(
          button: onTap != null,
          selected: active,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedScale(
              scale: scale,
              alignment: alignment,
              duration: motion,
              curve: const LyricsSpringCurve(),
              child: AnimatedOpacity(
                opacity: opacity,
                duration:
                    reduced ? Duration.zero : const Duration(milliseconds: 400),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: blur),
                  duration:
                      reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 400),
                  builder:
                      (_, value, child) => ImageFiltered(
                        enabled: value > 0,
                        imageFilter: ImageFilter.blur(
                          sigmaX: value,
                          sigmaY: value,
                        ),
                        child: child,
                      ),
                  child: AnimatedDefaultTextStyle(
                    style: style,
                    duration:
                        reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 250),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
