import 'package:flutter/material.dart';

import '../styles/colors.dart';

enum CardBadgeDensity { compact, regular, large }

class CardBadgesOverlay extends StatelessWidget {
  final bool hasDoubleFacedImages;
  final bool isBanned;
  final bool isGameChanger;
  final CardBadgeDensity density;
  final VoidCallback? onDoubleFacedTap;
  final bool isDoubleFacedFlipped;

  const CardBadgesOverlay({
    super.key,
    required this.hasDoubleFacedImages,
    required this.isBanned,
    required this.isGameChanger,
    this.density = CardBadgeDensity.regular,
    this.onDoubleFacedTap,
    this.isDoubleFacedFlipped = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _BadgeSizeConfig.fromDensity(density);

    return Stack(
      children: [
        if (hasDoubleFacedImages)
          Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: onDoubleFacedTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: config.doubleFacedDiameter,
                height: config.doubleFacedDiameter,
                decoration: BoxDecoration(
                  color:
                      context.uiColors.purple.withAlpha((0.85 * 255).round()),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AnimatedRotation(
                    turns: isDoubleFacedFlipped ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      '↻',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: config.doubleFacedFontSize,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (isBanned)
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: config.bannedWidth,
              height: config.cornerHeight,
              decoration: BoxDecoration(
                color: context.uiColors.red,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(2),
                  bottomRight: Radius.circular(config.cornerRadius),
                ),
              ),
              child: Center(
                child: Text(
                  'BAN',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: config.cornerFontSize,
                    height: 1,
                  ),
                ),
              ),
            ),
          )
        else if (isGameChanger)
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: config.gameChangerWidth,
              height: config.cornerHeight,
              decoration: BoxDecoration(
                color: AppColors.gameChangerOrange,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(2),
                  bottomRight: Radius.circular(config.cornerRadius),
                ),
              ),
              child: Center(
                child: Text(
                  'GC',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: config.cornerFontSize,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BadgeSizeConfig {
  final double doubleFacedDiameter;
  final double doubleFacedFontSize;
  final double bannedWidth;
  final double gameChangerWidth;
  final double cornerHeight;
  final double cornerFontSize;
  final double cornerRadius;

  const _BadgeSizeConfig({
    required this.doubleFacedDiameter,
    required this.doubleFacedFontSize,
    required this.bannedWidth,
    required this.gameChangerWidth,
    required this.cornerHeight,
    required this.cornerFontSize,
    required this.cornerRadius,
  });

  factory _BadgeSizeConfig.fromDensity(CardBadgeDensity density) {
    switch (density) {
      case CardBadgeDensity.compact:
        return const _BadgeSizeConfig(
          doubleFacedDiameter: 20,
          doubleFacedFontSize: 10,
          bannedWidth: 22,
          gameChangerWidth: 16,
          cornerHeight: 14,
          cornerFontSize: 7,
          cornerRadius: 6,
        );
      case CardBadgeDensity.large:
        return const _BadgeSizeConfig(
          doubleFacedDiameter: 56,
          doubleFacedFontSize: 18,
          bannedWidth: 30,
          gameChangerWidth: 22,
          cornerHeight: 22,
          cornerFontSize: 10,
          cornerRadius: 8,
        );
      case CardBadgeDensity.regular:
        return const _BadgeSizeConfig(
          doubleFacedDiameter: 56,
          doubleFacedFontSize: 18,
          bannedWidth: 26,
          gameChangerWidth: 20,
          cornerHeight: 20,
          cornerFontSize: 10,
          cornerRadius: 8,
        );
    }
  }
}
