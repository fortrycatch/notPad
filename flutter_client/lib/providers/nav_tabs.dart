import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _orderKey = 'nav_tab_order';
const _enabledKey = 'nav_tab_enabled';

enum HomeTab {
  feed,
  notes,
  todos,
  bookmarks,
  images,
  drive;

  String get path => switch (this) {
        HomeTab.feed => '/feed',
        HomeTab.notes => '/notes',
        HomeTab.todos => '/todos',
        HomeTab.bookmarks => '/bookmarks',
        HomeTab.images => '/images',
        HomeTab.drive => '/drive',
      };

  String get label => switch (this) {
        HomeTab.feed => '动态',
        HomeTab.notes => '笔记',
        HomeTab.todos => '待办',
        HomeTab.bookmarks => '书签',
        HomeTab.images => '图床',
        HomeTab.drive => '网盘',
      };

  IconData get icon => switch (this) {
        HomeTab.feed => Icons.dynamic_feed_outlined,
        HomeTab.notes => Icons.sticky_note_2_outlined,
        HomeTab.todos => Icons.check_circle_outline,
        HomeTab.bookmarks => Icons.bookmark_outline,
        HomeTab.images => Icons.image_outlined,
        HomeTab.drive => Icons.folder_outlined,
      };

  IconData get selectedIcon => switch (this) {
        HomeTab.feed => Icons.dynamic_feed,
        HomeTab.notes => Icons.sticky_note_2,
        HomeTab.todos => Icons.check_circle,
        HomeTab.bookmarks => Icons.bookmark,
        HomeTab.images => Icons.image,
        HomeTab.drive => Icons.folder,
      };

  static HomeTab? fromName(String name) {
    for (final tab in HomeTab.values) {
      if (tab.name == name) return tab;
    }
    return null;
  }
}

class NavTabsState {
  const NavTabsState({
    required this.order,
    required this.enabled,
  });

  static const defaults = NavTabsState(
    order: HomeTab.values,
    enabled: {HomeTab.feed, HomeTab.notes, HomeTab.todos, HomeTab.bookmarks},
  );

  final List<HomeTab> order;
  final Set<HomeTab> enabled;

  List<HomeTab> get visible =>
      order.where(enabled.contains).toList(growable: false);

  NavTabsState copyWith({
    List<HomeTab>? order,
    Set<HomeTab>? enabled,
  }) {
    return NavTabsState(
      order: order ?? this.order,
      enabled: enabled ?? this.enabled,
    );
  }
}

final navTabsProvider = NotifierProvider<NavTabsNotifier, NavTabsState>(
  NavTabsNotifier.new,
);

class NavTabsNotifier extends Notifier<NavTabsState> {
  @override
  NavTabsState build() {
    Future.microtask(_restore);
    return NavTabsState.defaults;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final orderRaw = prefs.getString(_orderKey);
    final enabledRaw = prefs.getString(_enabledKey);
    final order = _parseOrder(orderRaw);
    final enabled = _parseEnabled(enabledRaw, order);
    state = NavTabsState(order: order, enabled: enabled);
  }

  List<HomeTab> _parseOrder(String? raw) {
    final parsed = (raw ?? '')
        .split(',')
        .map((item) => HomeTab.fromName(item.trim()))
        .whereType<HomeTab>()
        .toList();
    for (final tab in HomeTab.values) {
      if (!parsed.contains(tab)) parsed.add(tab);
    }
    return parsed;
  }

  Set<HomeTab> _parseEnabled(String? raw, List<HomeTab> order) {
    if (raw == null) return NavTabsState.defaults.enabled;
    final enabled = raw
        .split(',')
        .map((item) => HomeTab.fromName(item.trim()))
        .whereType<HomeTab>()
        .toSet();
    if (enabled.isEmpty) return {order.first};
    return enabled;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_orderKey, state.order.map((tab) => tab.name).join(','));
    await prefs.setString(
      _enabledKey,
      state.enabled.map((tab) => tab.name).join(','),
    );
  }

  Future<void> toggle(HomeTab tab, bool value) async {
    final next = {...state.enabled};
    if (value) {
      next.add(tab);
      final rest = state.order.where((item) => item != tab);
      state = state.copyWith(enabled: next, order: [...rest, tab]);
    } else {
      if (next.length <= 1) return;
      next.remove(tab);
      state = state.copyWith(enabled: next);
    }
    await _persist();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final visible = [...state.visible];
    if (visible.length < 2) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex < 0 || oldIndex >= visible.length) return;
    if (newIndex < 0 || newIndex >= visible.length) return;
    final item = visible.removeAt(oldIndex);
    visible.insert(newIndex, item);
    final hidden = state.order.where((tab) => !state.enabled.contains(tab));
    state = state.copyWith(order: [...visible, ...hidden]);
    await _persist();
  }
}
