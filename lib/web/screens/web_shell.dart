import 'package:flutter/material.dart';
import 'floor_plan_screen.dart';
import 'web_scan_screen.dart';

/// Top-level navigation shell for the web app.
///
/// On wide screens (≥ 800 px) a side-rail is shown; on narrow screens
/// a bottom navigation bar is used instead.
class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  int _selectedIndex = 0;

  static const _destinations = [
    _Destination(
      icon: Icons.map_outlined,
      selectedIcon: Icons.map,
      label: 'Floor Plan',
    ),
    _Destination(
      icon: Icons.nfc_outlined,
      selectedIcon: Icons.nfc,
      label: 'Scanner',
    ),
  ];

  static const _screens = [
    FloorPlanScreen(),
    WebScanScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 800;

      if (wide) {
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (i) =>
                    setState(() => _selectedIndex = i),
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Icon(Icons.sensors,
                      color: Theme.of(context).colorScheme.primary, size: 32),
                ),
                destinations: _destinations
                    .map((d) => NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ))
                    .toList(),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _screens[_selectedIndex]),
            ],
          ),
        );
      }

      // Narrow layout.
      return Scaffold(
        body: IndexedStack(index: _selectedIndex, children: _screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          destinations: _destinations
              .map((d) => NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ))
              .toList(),
        ),
      );
    });
  }
}

class _Destination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _Destination(
      {required this.icon, required this.selectedIcon, required this.label});
}
