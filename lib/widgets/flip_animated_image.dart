import 'dart:math' as math;

import 'package:flutter/material.dart';

class FlipAnimatedImage extends StatelessWidget {
  final String? imageUrl;
  final bool isFlipped;
  final BoxFit fit;
  final Widget placeholder;
  final Duration duration;

  const FlipAnimatedImage({
    super.key,
    required this.imageUrl,
    required this.isFlipped,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.duration = const Duration(milliseconds: 280),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (child, animation) {
        final rotation = Tween<double>(
          begin: isFlipped ? -math.pi / 2 : math.pi / 2,
          end: 0,
        ).animate(animation);

        return AnimatedBuilder(
          animation: rotation,
          child: child,
          builder: (context, child) {
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(rotation.value),
              child: child,
            );
          },
        );
      },
      child: imageUrl != null
          ? Image.network(
              imageUrl!,
              key: ValueKey(imageUrl),
              fit: fit,
            )
          : KeyedSubtree(
              key: const ValueKey('flip-image-placeholder'),
              child: placeholder,
            ),
    );
  }
}
