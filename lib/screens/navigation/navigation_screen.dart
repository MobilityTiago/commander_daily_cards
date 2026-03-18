import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../card_search/card_search_screen.dart';
import '../land_guide/land_guide_screen.dart';
import '../brackets/brackets_screen.dart';
import '../more/more_screen.dart';
import '../../widgets/bottom_nav_bar.dart';

/// Root navigation widget that manages the primary bottom tabs.
///
/// The app uses a single [NavigationScreen] instance as the home of the app.
/// Changing tabs updates the selected index without pushing new routes.
class NavigationScreen extends StatefulWidget {
  static const String routeDaily = '/daily';
  static const String routeSearch = '/search';
  static const String routeLandGuide = '/land-guide';
  static const String routeBrackets = '/brackets';
  static const String routeMore = '/more';
  static const String routeSupport = '/support';
  static const String routeAcknowledgements = '/acknowledgements';

  final String initialRoute;

  const NavigationScreen({
    super.key,
    required this.initialRoute,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  static const _routes = [
    NavigationScreen.routeDaily,
    NavigationScreen.routeSearch,
    NavigationScreen.routeLandGuide,
    NavigationScreen.routeBrackets,
    NavigationScreen.routeMore,
  ];

  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = _routes.indexOf(widget.initialRoute);
    if (_currentIndex == -1) {
      _currentIndex = 0;
    }
  }

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
          CardSearchScreen(),
          LandGuideScreen(),
          BracketsScreen(),
          MoreScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
      ),
    );
  }
}
