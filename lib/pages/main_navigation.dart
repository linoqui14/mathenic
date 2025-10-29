import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
  int _currentIndex = 1;

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return ResultPage(
          onNavigateToCamera: () {
            setState(() {
              _currentIndex = 1;
            });
          },
        );
      case 1:
        return CameraPage(
          onNavigateToTab: (index) {
            setState(() {
              _currentIndex = index;
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
        child: ClipRRect(
          child: NavigationBar(
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                );
              }
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.grey,
              );
            }),
            labelPadding: const EdgeInsets.only(bottom: 7),
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            indicatorColor: Colors.transparent,
            height: 65,
            elevation: 0,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: FaIcon(FontAwesomeIcons.keyboard, color: Colors.grey, size: 20),
                selectedIcon: FaIcon(FontAwesomeIcons.keyboard, color: primaryColor, size: 25),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Stack(
                  alignment: Alignment.center,
                  children: [
                    FaIcon(FontAwesomeIcons.cameraRetro, color: Colors.grey, size: 20),
                    Container(
                      margin: const EdgeInsets.only(top: 2.5),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.cyan,
                        shape: BoxShape.circle,
                      ),
                    )
                  ],
                ),
                selectedIcon: Stack(
                  alignment: Alignment.center,
                  children: [
                    FaIcon(FontAwesomeIcons.camera, color: primaryColor, size: 25),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.cyan,
                        shape: BoxShape.circle,
                      ),
                    )
                  ],
                ),
                label: 'Camera',
              ),
              NavigationDestination(
                icon: FaIcon(FontAwesomeIcons.faceSmile, color: Colors.grey, size: 20),
                selectedIcon: FaIcon(FontAwesomeIcons.faceSmile, color: primaryColor, size: 25),
                label: 'Profile',
              ),
            ],
          )
        ),
      ),
      // extendBody: true,
    );
  }
}