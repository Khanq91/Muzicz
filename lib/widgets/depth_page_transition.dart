import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Slide/fade with a recessed background for Navigator push/pop, not tab swaps.
class DepthPageTransition extends StatelessWidget {
  const DepthPageTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
    this.blur = 12,
    this.radius = 32,
    this.dim = .4,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;
  final double blur, radius, dim;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      child: RepaintBoundary(child: child),
      builder: (context, content) {
        final popping = animation.status == AnimationStatus.reverse;
        final entering = const Cubic(.2, 0, 0, 1).transform(animation.value);
        final behind = const Cubic(
          .2,
          0,
          0,
          1,
        ).transform(secondaryAnimation.value);
        final departure = 1 - animation.value;
        final x =
            popping ? departure * departure * departure : (1 - entering) / 3;
        final scale =
            (popping ? 1 - .15 * (1 - entering) : 1.0) * (1 - .05 * behind);
        final rounding = radius * (1 - entering + behind).clamp(0.0, 1.0);
        return FractionalTranslation(
          translation: Offset(x - behind * .25, 0),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: popping ? 1 : entering,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(rounding),
                child: ImageFiltered(
                  enabled: behind > 0 && blur > 0,
                  imageFilter: ImageFilter.blur(
                    sigmaX: blur * behind,
                    sigmaY: blur * behind,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      content!,
                      IgnorePointer(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: dim * behind),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class DepthPageTransitionsBuilder extends PageTransitionsBuilder {
  const DepthPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 450);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 350);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => DepthPageTransition(
    animation: animation,
    secondaryAnimation: secondaryAnimation,
    child: child,
  );
}

/// Startup keeps its fade, but participates as the background of later pushes.
class DepthFadePageRoute<T> extends MaterialPageRoute<T> {
  DepthFadePageRoute({required super.builder, required this.duration});
  final Duration duration;

  @override
  Duration get transitionDuration => duration;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => DepthPageTransition(
    animation: const AlwaysStoppedAnimation(1),
    secondaryAnimation: secondaryAnimation,
    child:
        MediaQuery.disableAnimationsOf(context)
            ? child
            : FadeTransition(opacity: animation, child: child),
  );
}
