import 'package:flutter/material.dart';
import 'home/models_tab.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'home/pair_tab.dart';
import 'home/system_tab.dart';

/// The main application container with bottom navigation.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const ModelsTab(),
    const PairTab(),
    const SystemTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: AppColors.brandOrange,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
        selectedLabelStyle: GoogleFonts.changa(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
        unselectedLabelStyle: GoogleFonts.changa(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.0,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded, size: 20),
            activeIcon: Icon(Icons.dashboard_rounded, size: 22),
            label: 'MODELS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline_rounded, size: 20),
            activeIcon: Icon(Icons.add_circle_rounded, size: 22),
            label: 'PAIR',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined, size: 20),
            activeIcon: Icon(Icons.settings_rounded, size: 22),
            label: 'SYSTEM',
          ),
        ],
      ),
    );
  }
}
