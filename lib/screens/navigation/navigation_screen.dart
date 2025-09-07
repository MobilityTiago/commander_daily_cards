import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../card_search/card_search_screen.dart';
import '../land_guide/land_guide_screen.dart';
import '../support/support_screen.dart';
import '../acknowledgements/acknowledgements_screen.dart';
import '../../widgets/app_drawer.dart';

class NavigationScreen extends StatelessWidget {
  final String currentRoute;

  const NavigationScreen({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(currentPage: currentRoute),
      body: _buildScreen(),
    );
  }

  Widget _buildScreen() {
    switch (currentRoute) {
      case '/daily':
        return const HomeScreen();
      case '/search':
        return const CardSearchScreen();
      case '/land-guide':
        return const LandGuideScreen();
      case '/support':
        return const SupportScreen();
      case '/acknowledgements':
        return const AcknowledgementsScreen();
      default:
        return const HomeScreen();
    }
  }
}