import 'package:flutter/material.dart';
import '../styles/colors.dart';


class AppDrawer extends StatelessWidget {
  final String currentPage;

  const AppDrawer({
    super.key,
     this.currentPage = 'daily',
  });

@override
Widget build(BuildContext context) {
  return Drawer(
      backgroundColor: AppColors.drawerBackground,  // Updated to use AppColors
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
            isSelected: currentPage == 'daily',
            onTap: () {
              Navigator.pop(context);
              if (currentPage != 'daily') {
                Navigator.pushReplacementNamed(context, '/daily');
              }
            },
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.search,
            title: 'Search',
            isSelected: currentPage == 'search',
            onTap: () {
              Navigator.pop(context);
              if(currentPage != 'search')
              {
                if (currentPage != '/daily') {
                  Navigator.pushReplacementNamed(context, '/search');
                }
                else{   
                  Navigator.pushNamed(context, '/search');
                }
                }
              
            },
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.landscape,
            title: 'Land Guide',
            isSelected: currentPage == 'land_guide',
            onTap: () {
              Navigator.pop(context);
              if(currentPage != 'land_guide')
              {
                if (currentPage != '/daily') {
                  Navigator.pushReplacementNamed(context, '/land-guide');
                }
                else
                {
                  Navigator.pushNamed(context, '/land-guide');
                }
              }
              
            },
          ),
        const Divider(
          color: AppColors.lightGrey,
          thickness: 1,
          height: 16,
          indent: 8,
          endIndent: 8,
        ),
        _buildDrawerItem(
          context: context,
          icon: Icons.favorite,
          title: 'Support Me',
          isSelected: currentPage == 'support',
          onTap: () {
            Navigator.pop(context);
            if (currentPage != 'support') { 
              if (currentPage != '/daily') {
                Navigator.pushReplacementNamed(context, '/support');
              }
              else{
                Navigator.pushNamed(context, '/support');
              }
            }
          },
        ),
        _buildDrawerItem(
          context: context,
          icon: Icons.info,
          title: 'Acknowledgements',
          isSelected: currentPage == 'acknowledgements',
          onTap: () {
            Navigator.pop(context);
            if (currentPage != 'acknowledgements') {
              if (currentPage != '/daily') {
                Navigator.pushReplacementNamed(context, '/acknowledgements');
              }
              else{
                Navigator.pushNamed(context, '/acknowledgements');
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
              : AppColors.lightGrey,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: AppColors.lightGrey,
          highlightColor: AppColors.darkGrey,
          child: ListTile(
            leading: Icon(
              icon,
              color: isSelected
                  ? AppColors.red
                  : AppColors.darkGrey,  // Changed to darkGrey
            ),
            title: Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? AppColors.red
                    : AppColors.darkGrey,  // Changed to darkGrey
              ),
            ),
            selected: isSelected,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}