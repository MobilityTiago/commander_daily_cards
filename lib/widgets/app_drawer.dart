import 'package:flutter/material.dart';
import '../styles/colors.dart';
import '../screens/navigation/navigation_screen.dart';

class AppDrawer extends StatelessWidget {
  final String currentPage;

  const AppDrawer({
    super.key,
    this.currentPage = NavigationScreen.routeDaily,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.drawerBackground,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.black,
            ),
            child: Center(
              child: Image.asset(
                'assets/images/commander_deck.png',
                fit: BoxFit.contain,
                height: 80,
              ),
            ),
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.today,
            title: 'Daily Suggestions',
            isSelected: currentPage == NavigationScreen.routeDaily,
            onTap: () {
              Navigator.pop(context);
              if (currentPage != NavigationScreen.routeDaily) {
                Navigator.pushReplacementNamed(context, NavigationScreen.routeDaily);
              }
            },
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.search,
            title: 'Search',
            isSelected: currentPage == NavigationScreen.routeSearch,
            onTap: () {
              Navigator.pop(context);
              if (currentPage != NavigationScreen.routeSearch) {
                if (currentPage != NavigationScreen.routeDaily) {
                  Navigator.pushReplacementNamed(context, NavigationScreen.routeSearch);
                } else {
                  Navigator.pushNamed(context, NavigationScreen.routeSearch);
                }
              }
            },
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.landscape,
            title: 'Land Guide',
            isSelected: currentPage == NavigationScreen.routeLandGuide,
            onTap: () {
              Navigator.pop(context);
              if (currentPage != NavigationScreen.routeLandGuide) {
                if (currentPage != NavigationScreen.routeDaily) {
                  Navigator.pushReplacementNamed(context, NavigationScreen.routeLandGuide);
                } else {
                  Navigator.pushNamed(context, NavigationScreen.routeLandGuide);
                }
              }
            },
          ),
          const Divider(
            color: AppColors.white,
            thickness: 1,
            height: 16,
            indent: 8,
            endIndent: 8,
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.favorite,
            title: 'Support Me',
            isSelected: currentPage == NavigationScreen.routeSupport,
            onTap: () {
              Navigator.pop(context);
              if (currentPage != NavigationScreen.routeSupport) {
                if (currentPage != NavigationScreen.routeDaily) {
                  Navigator.pushReplacementNamed(context, NavigationScreen.routeSupport);
                } else {
                  Navigator.pushNamed(context, NavigationScreen.routeSupport);
                }
              }
            },
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.info,
            title: 'Acknowledgements',
            isSelected: currentPage == NavigationScreen.routeAcknowledgements,
            onTap: () {
              Navigator.pop(context);
              if (currentPage != NavigationScreen.routeAcknowledgements) {
                if (currentPage != NavigationScreen.routeDaily) {
                  Navigator.pushReplacementNamed(context, NavigationScreen.routeAcknowledgements);
                } else {
                  Navigator.pushNamed(context, NavigationScreen.routeAcknowledgements);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.darkRed
              : AppColors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: AppColors.lightGrey,
          highlightColor: AppColors.lightGrey,
          hoverColor: AppColors.lightGrey,
          child: ListTile(
            leading: Icon(
              icon,
              color: isSelected
                  ? AppColors.red
                  : AppColors.darkGrey,
            ),
            title: Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? AppColors.red
                    : AppColors.darkGrey,
              ),
            ),
            selected: isSelected,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            hoverColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}