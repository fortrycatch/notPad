import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/widgets.dart';

class NoteEditPage extends ConsumerStatefulWidget {
  const NoteEditPage({super.key, this.id});

  final String? id;

  @override
  ConsumerState<NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends ConsumerState<NoteEditPage> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  bool _loading = false;
  bool _saving = false;
  bool _dirty = false;

  bool get _isNew => widget.id == null;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => _dirty = true);
    _content.addListener(() => _dirty = true);
    if (!_isNew) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final note = await ref.read(apiProvider).notepad.getNoteById(widget.id!);
      _title.text = note.title;
      _content.text = note.content;
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
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_isNew) {
        final note = await ref.read(apiProvider).notepad.createNote(
              title: _title.text.trim(),
              content: _content.text,
            );
        ref.invalidate(notesProvider(const NotesQuery()));
        ref.invalidate(timelineProvider);
        _dirty = false;
        if (mounted) {
          Navigator.of(context).pop();
          showMessage(context, '已创建');
        }
        ref.invalidate(noteProvider(note.id));
      } else {
        await ref.read(apiProvider).notepad.updateNote(
              id: widget.id!,
              title: _title.text.trim(),
              content: _content.text,
            );
        ref.invalidate(noteProvider(widget.id!));
        ref.invalidate(notesProvider(const NotesQuery()));
        ref.invalidate(timelineProvider);
        _dirty = false;
        if (mounted) {
          showMessage(context, '已保存');
          Navigator.of(context).pop();
        }
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
          title: Text(_isNew ? '新建笔记' : '编辑笔记'),
          actions: [
            TextButton(
              onPressed: _saving || _loading ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
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
                    decoration: const InputDecoration(
                      hintText: '标题',
                      border: InputBorder.none,
                    ),
                    style: Theme.of(context).textTheme.headlineSmall,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const Divider(),
                  TextField(
                    controller: _content,
                    decoration: const InputDecoration(
                      hintText: '开始书写…',
                      border: InputBorder.none,
                    ),
                    minLines: 16,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                  ),
                ],
              ),
      ),
    );
  }
}
