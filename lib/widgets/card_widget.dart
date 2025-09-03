import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/mtg_card.dart';

class CardWidget extends StatelessWidget {
  final MTGCard card;

  const CardWidget({
    super.key,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Image
          if (card.imageUrl != null)
            AspectRatio(
              aspectRatio: 5 / 7, // Standard MTG card ratio
              child: CachedNetworkImage(
                imageUrl: card.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.error,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          else
            AspectRatio(
              aspectRatio: 5 / 7,
              child: Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
                    ], // <- This closing bracket was missing
      ),
    );
  }
}
