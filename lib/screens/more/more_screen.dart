import 'package:flutter/material.dart';
import '../../widgets/app_bar.dart';
import '../navigation/navigation_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommanderAppBar(
        title: 'More',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text('Support Me'),
            subtitle: const Text('Help keep development going'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, NavigationScreen.routeSupport);
            },
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Acknowledgements'),
            subtitle: const Text('Credits and attributions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, NavigationScreen.routeAcknowledgements);
            },
          ),
        ],
      ),
    );
  }
}
