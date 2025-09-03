import 'package:flutter/material.dart';
import '../models/mtg_card.dart';
import 'card_widget.dart';

class CardSuggestionSection extends StatelessWidget {
  final String title;
  final MTGCard? card;
  final Color accentColor;

  const CardSuggestionSection({
    super.key,
    required this.title,
    required this.card,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (card != null)
          CardWidget(card: card!)
        else
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'No card available',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
      ],
    );
  }
}