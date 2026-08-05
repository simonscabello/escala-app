import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static bool _isTopLevel(String path) =>
      path == '/agenda' || path == '/equipe';

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final showNav = _isTopLevel(path);
    final isAgenda = path.startsWith('/agenda');

    return Scaffold(
      body: child,
      bottomNavigationBar: showNav
          ? NavigationBar(
              selectedIndex: isAgenda ? 0 : 1,
              onDestinationSelected: (index) {
                if (index == 0) {
                  context.go('/agenda');
                  return;
                }

                context.go('/equipe');
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month_rounded),
                  label: 'Agenda',
                ),
                NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  selectedIcon: Icon(Icons.groups_rounded),
                  label: 'Equipe',
                ),
              ],
            )
          : null,
    );
  }
}
