import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/widgets.dart';

class BookmarkCreatePage extends ConsumerStatefulWidget {
  const BookmarkCreatePage({super.key});

  @override
  ConsumerState<BookmarkCreatePage> createState() => _BookmarkCreatePageState();
}

class _BookmarkCreatePageState extends ConsumerState<BookmarkCreatePage> {
  final _url = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _fetching = false;
  bool _saving = false;
  String? _content;

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final url = _url.text.trim();
    if (url.isEmpty) {
      showMessage(context, '请输入链接');
      return;
    }
    setState(() => _fetching = true);
    try {
      final preview = await ref.read(apiProvider).bookmark.fetchUrl(url);
      _title.text = preview.title;
      _description.text = preview.description;
      _content = preview.content;
      if (preview.url.isNotEmpty) _url.text = preview.url;
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showMessage(context, '请输入标题');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).bookmark.add(
            type: 'url',
            title: _title.text.trim(),
            description: _description.text,
            content: _content,
            url: _url.text.trim(),
          );
      ref.invalidate(bookmarksProvider(const BookmarksQuery()));
      ref.invalidate(timelineProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加书签'),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: '链接',
              suffixIcon: IconButton(
                onPressed: _fetching ? null : _fetch,
                icon: _fetching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: '标题'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: '摘要'),
          ),
        ],
      ),
    );
  }
}
