import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../card_search/card_search_screen.dart';
import '../land_guide/land_guide_screen.dart';
import '../support/support_screen.dart';
import '../acknowledgements/acknowledgements_screen.dart';
import '../../widgets/app_drawer.dart';

class NavigationScreen extends StatelessWidget {
  static const String routeDaily = '/daily';
  static const String routeSearch = '/search';
  static const String routeLandGuide = '/land-guide';
  static const String routeSupport = '/support';
  static const String routeAcknowledgements = '/acknowledgements';

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
      case routeDaily:
        return const HomeScreen();
      case routeSearch:
        return const CardSearchScreen();
      case routeLandGuide:
        return const LandGuideScreen();
      case routeSupport:
        return const SupportScreen();
      case routeAcknowledgements:
        return const AcknowledgementsScreen();
      default:
        return const HomeScreen();
    }
  }
}