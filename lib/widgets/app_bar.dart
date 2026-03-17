import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/card_service.dart';
import '../styles/colors.dart';

class CommanderAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Title shown for the current page.
  final String title;

  /// Optional image URL to show as the background for the bar.
  /// If null, the app will fall back to using the daily suggestion card art.
  final String? backgroundImageUrl;

  final VoidCallback? onFilterPressed;
  final VoidCallback? onRefreshPressed;
  final bool showFilterButton;
  final bool showRefreshButton;

  const CommanderAppBar({
    super.key,
    required this.title,
    this.backgroundImageUrl,
    this.onFilterPressed,
    this.onRefreshPressed,
    this.showFilterButton = false,
    this.showRefreshButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      flexibleSpace: AppBarBackground(imageUrl: backgroundImageUrl),
      actions: [
        if (showRefreshButton)
          IconButton(
            onPressed: onRefreshPressed,
            icon: const Icon(Icons.refresh),
          ),
        if (showFilterButton)
          IconButton(
            onPressed: onFilterPressed,
            icon: const Icon(Icons.filter_alt),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// A shared background widget that renders a card art image + a dark overlay.
class AppBarBackground extends StatelessWidget {
  final String? imageUrl;

  const AppBarBackground({
    super.key,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final cardService = Provider.of<CardService>(context);

    final card = imageUrl != null
        ? null
        : (cardService.dailyAppBarCard ??
            cardService.dailyRegularCard ??
            cardService.dailyGameChangerCard ??
            cardService.dailyRegularLand ??
            cardService.dailyGameChangerLand);

    final backgroundUrl = imageUrl ?? card?.imageUris?.artCrop;
    if (backgroundUrl == null || backgroundUrl.isEmpty) {
      return Container(color: AppColors.darkGrey);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          backgroundUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.darkGrey,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.5),
                Colors.black.withValues(alpha: 0.5),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
