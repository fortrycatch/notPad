import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/session.dart';
import '../../widgets/widgets.dart';

class TagManagerPage extends ConsumerStatefulWidget {
  const TagManagerPage({
    super.key,
    required this.title,
    required this.listTags,
    required this.createTag,
    required this.deleteTag,
    this.loadSelected,
    this.onToggle,
  });

  final String title;
  final Future<List<TagItem>> Function() listTags;
  final Future<TagItem> Function(String name) createTag;
  final Future<void> Function(int id) deleteTag;
  final Future<Set<int>> Function()? loadSelected;
  final Future<void> Function(int tagId, bool add)? onToggle;

  @override
  ConsumerState<TagManagerPage> createState() => _TagManagerPageState();
}

class _TagManagerPageState extends ConsumerState<TagManagerPage> {
  List<TagItem> _tags = const [];
  Set<int> _selected = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tags = await widget.listTags();
      final selected = widget.loadSelected == null ? _selected : await widget.loadSelected!();
      if (mounted) {
        setState(() {
          _tags = tags;
          _selected = selected;
        });
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = ref.watch(sessionProvider).canEdit;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: _create,
              child: const Icon(Icons.add),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tags.isEmpty
              ? const EmptyView(icon: Icons.label_outline, message: '还没有标签')
              : ListView.separated(
                  itemCount: _tags.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final tag = _tags[index];
                    return ListTile(
                      title: Text(tag.name),
                      trailing: widget.onToggle == null
                          ? (canEdit
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete(tag.id),
                                )
                              : null)
                          : Checkbox(
                              value: _selected.contains(tag.id),
                              onChanged: canEdit
                                  ? (value) => _toggle(tag.id, value ?? false)
                                  : null,
                            ),
                    );
                  },
                ),
    );
  }

  Future<void> _create() async {
    final name = await promptText(context, title: '新建标签', hint: '标签名');
    if (name == null || name.trim().isEmpty) return;
    try {
      await widget.createTag(name.trim());
      await _load();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _delete(int id) async {
    final ok = await confirm(
      context,
      title: '删除标签',
      message: '不会删除原内容。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) return;
    try {
      await widget.deleteTag(id);
      await _load();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _toggle(int id, bool add) async {
    try {
      await widget.onToggle?.call(id, add);
      setState(() {
        if (add) {
          _selected.add(id);
        } else {
          _selected.remove(id);
        }
      });
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }
}
