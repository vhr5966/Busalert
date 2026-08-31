/// Home dashboard — the main screen.
///
/// Provides quick-access cards to each major feature and serves as the
/// shell for bottom navigation.
///
/// Usability requirement: The delay prediction feature must be reachable
/// within 2 taps from here — tapping the "Check Delay" card on this
/// screen is 1 tap.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/screens/home_explore_screen.dart';
import '../features/map/screens/unified_transit_map_screen.dart';
import '../features/prediction/screens/prediction_screen.dart';
import '../features/profile/screens/profile_history_screen.dart';
import '../widgets/quick_search_bar.dart';

class HomeDashboard extends ConsumerStatefulWidget {
  const HomeDashboard({super.key});

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard> {
  int _currentIndex = 0;

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return HomeExploreScreen(
          key: const ValueKey('home_explore_tab'),
          onNavigateTab: (tab) => setState(() => _currentIndex = tab),
        );
      case 1:
        return const PredictionScreen(key: ValueKey('prediction_tab'));
      case 2:
        return const UnifiedTransitMapScreen(key: ValueKey('unified_map_tab'));
      case 3:
        return const ProfileHistoryScreen(key: ValueKey('profile_tab'));
      default:
        return HomeExploreScreen(
          key: const ValueKey('home_explore_tab'),
          onNavigateTab: (tab) => setState(() => _currentIndex = tab),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BusAlert Cardiff'),
          centerTitle: false,
          actions: [
            QuickSearchBar(
              onNavigate: (tabIndex) {
                setState(() => _currentIndex = tabIndex);
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => Navigator.of(context).pushNamed('/settings'),
            ),
          ],
        ),
        body: _buildPage(_currentIndex),
        bottomNavigationBar: SafeArea(
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights),
                label: 'Predict',
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: 'Map',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
