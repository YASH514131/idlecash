import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import 'home_screen.dart';
import 'portfolio_screen.dart';
import 'activity_screen.dart';
import 'settings_screen.dart';

class MainNavScreen extends StatelessWidget {
  const MainNavScreen({super.key});

  static const List<Widget> _screens = [
    HomeScreen(),
    PortfolioScreen(),
    ActivityScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (state.currentTabIndex > 0) {
          context.read<AppState>().setTabIndex(0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black, // Pure pitch black OLED
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: state.currentTabIndex,
            children: _screens,
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF000000), // Pure OLED black matching screenshot
            border: Border(
              top: BorderSide(
                color: Color(0xFF141722),
                width: 0.8,
              ),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: state.currentTabIndex,
            onTap: (index) => context.read<AppState>().setTabIndex(index),
            backgroundColor: Colors.transparent,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedItemColor: Colors.white,
            unselectedItemColor: const Color(0xFF555D73),
            selectedLabelStyle: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home, size: 22),
                activeIcon: Icon(Icons.home, size: 22, color: Colors.white),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.pie_chart_outline, size: 22),
                activeIcon: Icon(Icons.pie_chart, size: 22, color: Colors.white),
                label: 'Portfolio',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shield_outlined, size: 22),
                activeIcon: Icon(Icons.shield, size: 22, color: Colors.white),
                label: 'Activity',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined, size: 22),
                activeIcon: Icon(Icons.settings, size: 22, color: Colors.white),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
