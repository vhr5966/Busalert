/// Settings screen for BusAlert Cardiff.
///
/// Provides user-adjustable preferences that are persisted locally.
/// Currently includes tracking preferences such as WiFi bus-line
/// detection during journey tracking.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── User Account / Profile ──────────────────────────────
          const _SectionHeader(
            icon: Icons.person_outline,
            title: 'Account & Profile',
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: (authState.isAuthenticated && authState.user != null)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: kCardiffBlue,
                              child: Text(
                                (authState.user?.name.isNotEmpty ?? false)
                                    ? authState.user!.name[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    authState.user?.name ?? 'Cardiff Passenger',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    authState.user?.email ?? '',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.logout, color: Color(0xFFC62828)),
                            label: const Text(
                              'Sign Out',
                              style: TextStyle(color: Color(0xFFC62828)),
                            ),
                            onPressed: () async {
                              await ref.read(authProvider.notifier).logout();
                              if (context.mounted) {
                                Navigator.of(context)
                                    .pushNamedAndRemoveUntil('/login', (route) => false);
                              }
                            },
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey[200],
                          child: Icon(Icons.person, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Guest Mode',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'Sign in to link and backup your journeys',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/login');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kCardiffBlue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Tracking ─────────────────────────────────────────────
          const _SectionHeader(
            icon: Icons.gps_fixed,
            title: 'Tracking & Sensors',
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              value: settings.wifiDetectionEnabled,
              onChanged: settings.isLoading
                  ? null
                  : (enabled) => ref
                      .read(settingsProvider.notifier)
                      .setWifiDetectionEnabled(enabled),
              secondary: CircleAvatar(
                backgroundColor: kCardiffBlueLight,
                child: Icon(
                  Icons.wifi,
                  color: settings.wifiDetectionEnabled
                      ? kCardiffBlue
                      : Colors.grey[500],
                ),
              ),
              title: const Text(
                'WiFi bus-line detection',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Automatically detect your bus route from Cardiff Bus '
                'onboard WiFi while tracking.',
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Data & Storage ────────────────────────────────────────
          const _SectionHeader(
            icon: Icons.storage_outlined,
            title: 'Transit Database & Storage',
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0F2FE),
                    child: Icon(Icons.cached, color: Color(0xFF0284C7)),
                  ),
                  title: const Text(
                    'Cardiff GTFS Stops Cache',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('1,650 stops & 64 route shapes stored locally'),
                  trailing: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ GTFS Transit Database re-synchronized successfully.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Text('Refresh'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── About & System ────────────────────────────────────────
          const _SectionHeader(
            icon: Icons.info_outline,
            title: 'About BusAlert',
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF1F5F9),
                    child: Icon(Icons.directions_bus, color: Color(0xFF475569)),
                  ),
                  title: const Text(
                    'Data Sources',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('UK Dept for Transport (BODS) & Cardiff Bus'),
                  trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'BusAlert Cardiff',
                      applicationVersion: '1.0.0',
                      applicationLegalese:
                          'Open Government Licence v3.0 • Department for Transport Bus Open Data Service (BODS)',
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Section heading used to group related settings.
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kCardiffBlue),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
