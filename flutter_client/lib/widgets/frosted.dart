import 'dart:ui';

import 'package:flutter/material.dart';

class FrostedSurface extends StatelessWidget {
  const FrostedSurface({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.62),
          ),
          child: child ?? const SizedBox.expand(),
        ),
      ),
    );
  }
}

class FrostedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FrostedAppBar({
    super.key,
    this.leading,
    this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.bottom,
  });

  final Widget? leading;
  final Widget? title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading,
      title: title,
      actions: actions,
      automaticallyImplyLeading: automaticallyImplyLeading,
      bottom: bottom,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      forceMaterialTransparency: true,
      flexibleSpace: const FrostedSurface(),
    );
  }
}

class ShellFab extends StatelessWidget {
  const ShellFab({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final nav = NavigationBarTheme.of(context).height ?? 80;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: nav + safe + 8),
      child: child,
    );
  }
}

class FrostedNavigationBar extends StatelessWidget {
  const FrostedNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
    this.labelBehavior,
  });

  final int selectedIndex;
  final List<NavigationDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final NavigationDestinationLabelBehavior? labelBehavior;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
        ),
      ),
      child: FrostedSurface(
        child: NavigationBar(
          selectedIndex: selectedIndex,
          destinations: destinations,
          onDestinationSelected: onDestinationSelected,
          labelBehavior: labelBehavior,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),
    );
  }
}
