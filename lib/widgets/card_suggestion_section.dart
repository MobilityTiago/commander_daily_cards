import 'package:flutter/material.dart';
import 'package:commander_daily_cards/models/cards/mtg_card.dart';

class CardSuggestionSection extends StatelessWidget {
  final MTGCard? card;
  final Color accentColor;

  const CardSuggestionSection({
    super.key,
    required this.card,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (card == null) {
      return Card(
        child: Container(
          height: MediaQuery.of(context).size.width * 1.4, // Maintain card aspect ratio
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.filter_list_off,
                  size: 48,
                  color: Theme.of(context).disabledColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'No cards match your filters',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Try adjusting your filter settings',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Card Image
          AspectRatio(
            aspectRatio: 0.716,
            child: Image.network(
              card!.imageUrl ?? '',
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.broken_image),
                );
              },
            ),
          ),
                   // Game Changer Indicator
          if (card!.gameChanger)
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: const Text(
                  'GC',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}