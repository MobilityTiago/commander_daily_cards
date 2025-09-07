import 'package:commander_deck/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/app_bar.dart';
import '../../styles/colors.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(currentPage: '/support'),
      appBar: const CommanderAppBar(
        title: 'Support Me',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Support the Development',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'If you find this app useful, consider supporting its development. '
                    'Your support helps maintain and improve the app.',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final url = Uri.parse('https://ko-fi.com/jogamos');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.coffee),
                    label: const Text('Buy Me a Coffee'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Subscribe on YouTube',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Support by subscribing to my YouTube channel where I share '
                    'MTG Commander and also board game content.',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final url = Uri.parse('https://www.youtube.com/@top10boardgames');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.youtubeRed,
                    ),
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: const Text('Visit Channel', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Follow on Instagram',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Follow me on Instagram for MTG content, board game photos '
                    'and behind the scenes development updates.',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final url = Uri.parse('https://www.instagram.com/jogamostodos/');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.instagramPink,
                    ),
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    label: const Text('Follow on Instagram', 
                      style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}