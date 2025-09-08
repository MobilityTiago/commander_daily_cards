import 'package:commander_deck/screens/navigation/navigation_screen.dart';
import 'package:flutter/material.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/app_drawer.dart';

class LandGuideScreen extends StatelessWidget {
  const LandGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      drawer: AppDrawer(currentPage: NavigationScreen.routeLandGuide),
      appBar: CommanderAppBar(
        title: 'Land Guide',
      ),
      body: Center(
        child: Text(
          'Land Guide Screen - Coming Soon',
          style: TextStyle(color: Color(0xFF2A2A2A)),
        ),
      ),
    );
  }
}