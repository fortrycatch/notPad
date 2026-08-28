import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'session.dart';

const _keyPrefix = 'todo_selected_list_id';

String _storageKey(String? groupId) =>
    groupId == null ? _keyPrefix : '${_keyPrefix}_$groupId';

final selectedTodoListProvider =
    NotifierProvider<SelectedTodoListNotifier, String?>(SelectedTodoListNotifier.new);

class SelectedTodoListNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.listen(sessionProvider.select((session) => session.groupId), (_, _) {
      Future.microtask(_restore);
    });
    Future.microtask(_restore);
    return null;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_storageKey(ref.read(sessionProvider).groupId));
  }

  Future<void> select(String? id) async {
    state = id;
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey(ref.read(sessionProvider).groupId);
    if (id == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, id);
    }
  }

  String? resolve(List<TodoList> lists) {
    if (lists.isEmpty) return null;
    if (state != null && lists.any((list) => list.id == state)) return state;
    return lists.first.id;
  }
}
