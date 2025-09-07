import 'package:flutter/material.dart';
import '../screens/card_search/card_search_screen.dart';
import '../screens/land_guide/land_guide_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: const Text(
              'Commander\'s Deck',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.today),
            title: const Text('Daily Suggestions'),
            selected: true,
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Search'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CardSearchScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.landscape),
            title: const Text('Land Guide'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const LandGuideScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text('Support Me'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Add navigation to Support screen
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Acknowledgements'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Add navigation to Acknowledgements screen
            },
          ),
        ],
      ),
    );
  }
}