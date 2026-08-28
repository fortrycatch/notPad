import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/widgets.dart';

class TodoItemPage extends ConsumerStatefulWidget {
  const TodoItemPage({super.key, required this.listId, this.itemId});

  final String listId;
  final String? itemId;

  @override
  ConsumerState<TodoItemPage> createState() => _TodoItemPageState();
}

class _TodoItemPageState extends ConsumerState<TodoItemPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _refs = <TodoRef>[];
  bool _loading = false;
  bool _saving = false;
  bool _dirty = false;

  bool get _isNew => widget.itemId == null;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => _dirty = true);
    _description.addListener(() => _dirty = true);
    if (!_isNew) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(apiProvider).todo.getList(widget.listId);
      final item = list.items.firstWhere((it) => it.id == widget.itemId);
      _title.text = item.title;
      _description.text = item.description;
      _refs
        ..clear()
        ..addAll(item.refs);
      _dirty = false;
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showMessage(context, '请输入标题');
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isNew) {
        await ref.read(apiProvider).todo.createItem(
              listId: widget.listId,
              title: _title.text.trim(),
              description: _description.text,
              refs: List.of(_refs),
            );
      } else {
        await ref.read(apiProvider).todo.updateItem(
              id: widget.itemId!,
              title: _title.text.trim(),
              description: _description.text,
              refs: List.of(_refs),
            );
      }
      ref.invalidate(todoListProvider(widget.listId));
      _dirty = false;
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addRef() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.sticky_note_2_outlined),
                title: const Text('引用笔记'),
                onTap: () => Navigator.pop(context, 'note'),
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('引用图片'),
                onTap: () => Navigator.pop(context, 'image'),
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: const Text('引用文件'),
                onTap: () => Navigator.pop(context, 'file'),
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: const Text('引用书签'),
                onTap: () => Navigator.pop(context, 'bookmark'),
              ),
            ],
          ),
        );
      },
    );
    if (type == null || !mounted) return;
    final picked = await context.push<TodoRef>('/pick/$type');
    if (picked == null) return;
    setState(() {
      _refs.removeWhere((ref) => ref.type == picked.type && ref.refId == picked.refId);
      _refs.add(picked);
      _dirty = true;
    });
  }

  Future<void> _onPop(bool didPop, Object? result) async {
    if (didPop || !_dirty) return;
    final ok = await confirm(
      context,
      title: '放弃更改？',
      message: '未保存的内容将丢失。',
      confirmLabel: '放弃',
      destructive: true,
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: _onPop,
      child: Scaffold(
        appBar: FrostedAppBar(
          title: Text(_isNew ? '新建待办' : '编辑待办'),
          actions: [
            TextButton(
              onPressed: _saving || _loading ? null : _save,
              child: const Text('保存'),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: '标题'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(labelText: '描述'),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('引用'),
                    trailing: TextButton.icon(
                      onPressed: _addRef,
                      icon: const Icon(Icons.add),
                      label: const Text('添加'),
                    ),
                  ),
                  for (final refItem in _refs)
                    ListTile(
                      leading: Icon(typeIcon(refItem.type)),
                      title: Text(refItem.title),
                      subtitle: Text(refItem.type),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _refs.remove(refItem);
                            _dirty = true;
                          });
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
