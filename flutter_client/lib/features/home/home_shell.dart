import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/lists.dart';
import '../../providers/nav_tabs.dart';
import '../../widgets/frosted.dart';
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
        extendBody: true,
        drawer: const AppDrawer(),
        drawerEnableOpenDragGesture: true,
        drawerEdgeDragWidth: 28,
        body: Stack(
          children: [
            widget.navigationShell,
            const _DrawerSwipeEdge(),
          ],
        ),
        bottomNavigationBar: destinations.isEmpty
            ? null
            : FrostedNavigationBar(
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

class _DrawerSwipeEdge extends StatelessWidget {
  const _DrawerSwipeEdge();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: 28,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          if (details.primaryDelta != null && details.primaryDelta! > 6) {
            HomeDrawerController.open(context);
          }
        },
      ),
    );
  }
}
