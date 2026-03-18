import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../models/cards/card_enums.dart';
import '../services/symbol_service.dart';

class ManaSymbolLabel extends StatelessWidget {
  final MTGColor color;
  final double iconSize;
  final TextStyle? textStyle;

  const ManaSymbolLabel({
    super.key,
    required this.color,
    this.iconSize = 16,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final symbolService = context.watch<SymbolService>();
    final token = '{${color.symbol}}';
    final symbol = symbolService.symbolByToken(token);
    final svgData = symbolService.svgDataByToken(token);

    if (symbol == null || svgData == null || svgData.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        symbolService.requestRefreshOnMiss(token);
      });
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSymbolIcon(svgData),
        const SizedBox(width: 6),
        Text(
          color.displayName,
          style: textStyle,
        ),
      ],
    );
  }

  Widget _buildSymbolIcon(String? svgData) {
    if (svgData == null || svgData.isEmpty) {
      return _buildLetterFallback();
    }

    return SvgPicture.string(
      svgData,
      width: iconSize,
      height: iconSize,
    );
  }

  Widget _buildLetterFallback() {
    return Container(
      width: iconSize,
      height: iconSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade500),
        borderRadius: BorderRadius.circular(iconSize / 2),
      ),
      child: Text(
        color.symbol,
        style: TextStyle(
          fontSize: iconSize * 0.55,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
