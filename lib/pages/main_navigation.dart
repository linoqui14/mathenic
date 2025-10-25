import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'camera.dart';
import 'result_page.dart';
import 'profile_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return CameraPage(
          onNavigateToTab: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        );
      case 1:
        return ResultPage(
          onNavigateToCamera: () {
            setState(() {
              _currentIndex = 0;
            });
          },
        );
      case 2:
        return const ProfilePage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Scaffold(
      body: _buildCurrentPage(), // Replace IndexedStack
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(0),
        padding: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            indicatorColor: primaryColor.withOpacity(0.2),
            height: 65,
            elevation: 0,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.camera_alt_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.camera_alt, color: primaryColor),
                label: 'Camera',
              ),
              NavigationDestination(
                icon: Icon(Icons.list_alt_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.list_alt, color: primaryColor),
                label: 'Result',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline, color: Colors.grey),
                selectedIcon: Icon(Icons.person, color: primaryColor),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
      extendBody: true,
    );
  }
}