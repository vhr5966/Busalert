/// Home dashboard — the main screen after login.
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

import '../core/theme.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/history/screens/history_screen.dart';
import '../features/map/screens/map_screen.dart';
import '../features/prediction/screens/prediction_screen.dart';
import '../features/tracking/screens/live_tracking_screen.dart';

class HomeDashboard extends ConsumerStatefulWidget {
  const HomeDashboard({super.key});

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard> {
  int _currentIndex = 0;

  // The pages for the bottom navigation
  final List<Widget> _pages = [
    const _DashboardContent(),
    const PredictionScreen(),
    const LiveTrackingScreen(),
    const HistoryScreen(),
    const MapScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Listen for auth state changes — when user signs out, navigate to login
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is AuthUnauthenticated && previous is! AuthInitial) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
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
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Predict',
          ),
          NavigationDestination(
            icon: Icon(Icons.gps_fixed),
            selectedIcon: Icon(Icons.gps_fixed),
            label: 'Track',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
        ],
      ),
    );
  }
}

/// The actual dashboard content with quick-access cards.
class _DashboardContent extends ConsumerWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final userName = authState is AuthAuthenticated ? authState.user.name : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('BusAlert Cardiff'),
        actions: [
          // Profile / Settings
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => _showProfileSheet(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Greeting ────────────────────────────────────────────
            Text(
              'Hello, ${userName.isNotEmpty ? userName : 'Cardiff Bus Rider'}!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'What would you like to do?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),

            // ── Quick Action Cards ──────────────────────────────────
            // These are the primary entry points to the app's features.
            // Each card is tappable and navigates to the relevant screen.

            // Predict delay — 1 tap from here (usability requirement met)
            _QuickActionCard(
              icon: Icons.analytics,
              title: 'Check Delay',
              subtitle: 'Predict delays for any route',
              color: kCardiffBlue,
              onTap: () => _navigateTo(context, 1),
            ),
            const SizedBox(height: 12),

            _QuickActionCard(
              icon: Icons.gps_fixed,
              title: 'Track Journey',
              subtitle: 'Auto-detect boarding & alighting',
              color: kOnTimeGreen,
              onTap: () => _navigateTo(context, 2),
            ),
            const SizedBox(height: 12),

            _QuickActionCard(
              icon: Icons.history,
              title: 'Journey History',
              subtitle: 'View past recorded trips',
              color: kAmberAccent,
              onTap: () => _navigateTo(context, 3),
            ),
            const SizedBox(height: 12),

            _QuickActionCard(
              icon: Icons.map,
              title: 'Stop Map',
              subtitle: 'See stop delays on a map',
              color: Colors.deepPurple,
              onTap: () => _navigateTo(context, 4),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, int tabIndex) {
    // Find the scaffold ancestor and update bottom nav
    // Since we're inside IndexedStack, we use a different approach
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => Scaffold(body: _pagesForTab(tabIndex))),
    );
  }

  Widget _pagesForTab(int index) {
    switch (index) {
      case 1:
        return const PredictionScreen();
      case 2:
        return const LiveTrackingScreen();
      case 3:
        return const HistoryScreen();
      case 4:
        return const MapScreen();
      default:
        return const _DashboardContent();
    }
  }

  void _showProfileSheet(BuildContext context, WidgetRef ref) {
    final authState = ref.read(authProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: kCardiffBlue,
                    radius: 28,
                    child: Text(
                      (user?.name.isNotEmpty == true
                              ? user!.name[0]
                              : '?')
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'User',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        user?.email ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: kDelayRed),
                title: const Text('Sign Out',
                    style: TextStyle(color: kDelayRed)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(authProvider.notifier).logout();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
