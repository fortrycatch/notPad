import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/lists.dart';
import '../../providers/nav_tabs.dart';
import 'app_drawer.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    ref.watch(groupsProvider);
    final nav = ref.watch(navTabsProvider);
    final current = HomeTab.values[widget.navigationShell.currentIndex];
    final destinations = [
      ...nav.visible,
      if (!nav.visible.contains(current)) current,
    ];
    final selectedIndex = destinations.indexOf(current).clamp(0, destinations.length - 1);

    return HomeDrawerController(
      openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const AppDrawer(),
        body: widget.navigationShell,
        bottomNavigationBar: destinations.isEmpty
            ? null
            : NavigationBar(
                selectedIndex: selectedIndex,
                labelBehavior: destinations.length > 4
                    ? NavigationDestinationLabelBehavior.onlyShowSelected
                    : NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: (index) {
                  final tab = destinations[index];
                  widget.navigationShell.goBranch(
                    tab.index,
                    initialLocation: tab.index == widget.navigationShell.currentIndex,
                  );
                },
                destinations: [
                  for (final tab in destinations)
                    NavigationDestination(
                      icon: Icon(tab.icon),
                      selectedIcon: Icon(tab.selectedIcon),
                      label: tab.label,
                    ),
                ],
              ),
      ),
    );
  }
}
