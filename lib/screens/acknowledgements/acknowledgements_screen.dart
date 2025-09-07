import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/app_bar.dart';

class AcknowledgementsScreen extends StatelessWidget {
  const AcknowledgementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommanderAppBar(
        title: 'Acknowledgements',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAcknowledgementCard(
            title: 'Scryfall API',
            description: 'This app uses the Scryfall API to provide Magic: The Gathering card data.',
            url: 'https://scryfall.com/',
          ),
          const SizedBox(height: 16),
          _buildAcknowledgementCard(
            title: 'Card Artwork',
            description: 'All card artwork is property of Wizards of the Coast LLC.',
            url: 'https://www.wizards.com/',
          ),
          const SizedBox(height: 16),
          _buildAcknowledgementCard(
            title: 'Open Source Libraries',
            description: 'This app is built with Flutter and uses several open source packages.',
            url: 'https://github.com/yourusername/commander_daily_cards',
          ),
        ],
      ),
    );
  }

  Widget _buildAcknowledgementCard({
    required String title,
    required String description,
    required String url,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              child: const Text('Visit Website'),
            ),
          ],
        ),
      ),
    );
  }
}