import 'package:flutter/material.dart';

/// A shared bottom navigation bar used across the app.
///
/// The app uses named routes (via [NavigationScreen]) to switch between tabs.
class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white70,
      backgroundColor: Colors.black,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.today),
          label: 'Daily',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Search',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.landscape),
          label: 'Land',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.military_tech),
          label: 'Brackets',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.public),
          label: 'Content',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.more_horiz),
          label: 'More',
        ),
      ],
    );
  }
}
