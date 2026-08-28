import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/list_toolbar.dart';
import '../../widgets/widgets.dart';
import '../home/app_drawer.dart';

class BookmarksPage extends ConsumerStatefulWidget {
  const BookmarksPage({super.key});

  @override
  ConsumerState<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends ConsumerState<BookmarksPage> {
  String _sort = 'time_desc';
  String _search = '';
  int? _tagId;
  String? _type;
  bool _searching = false;
  final _searchController = TextEditingController();

  BookmarksQuery get _query => BookmarksQuery(
        sort: _sort,
        search: _search,
        tagId: _tagId,
        type: _type,
      );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bookmarksProvider(_query));
    final tags = ref.watch(bookmarkTagsProvider);
    final canEdit = ref.watch(sessionProvider).canEdit;
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: ListSearchAppBar(
        title: '书签',
        leading: const DrawerMenuButton(),
        searching: _searching,
        searchController: _searchController,
        searchHint: '搜索书签',
        searchActive: _search.isNotEmpty,
        filterActive: _tagId != null || _type != null,
        onSearch: (value) => setState(() => _search = value),
        onOpenSearch: () => setState(() => _searching = true),
        onCloseSearch: () => setState(() {
          _searching = false;
          _search = _searchController.text.trim();
        }),
        onFilter: () => _showFilters(tags.valueOrNull ?? const []),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'tags') {
                context.push('/bookmarks/tags');
                return;
              }
              setState(() => _sort = value);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'time_desc', child: Text('最新')),
              PopupMenuItem(value: 'time', child: Text('最早')),
              PopupMenuItem(value: 'name', child: Text('名称')),
              PopupMenuItem(value: 'tags', child: Text('管理标签')),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => context.push('/bookmarks/create'),
              child: const Icon(Icons.add),
            )
          : null,
      body: AsyncBody(
        value: async,
        onRetry: () => ref.read(bookmarksProvider(_query).notifier).refresh(),
        builder: (data) {
          if (data.items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.read(bookmarksProvider(_query).notifier).refresh(),
              child: ListView(
                children: [
                  const SizedBox(height: 160),
                  EmptyView(
                    icon: Icons.bookmark_outline,
                    message: _search.isNotEmpty || _tagId != null || _type != null
                        ? '没有符合条件的书签'
                        : '还没有书签',
                  ),
                ],
              ),
            );
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 240) {
                ref.read(bookmarksProvider(_query).notifier).loadMore();
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: () => ref.read(bookmarksProvider(_query).notifier).refresh(),
              child: ListView.separated(
                itemCount: data.items.length + (data.loadingMore ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index >= data.items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final item = data.items[index];
                  return ListTile(
                    leading: Icon(typeIcon(item.type)),
                    title: Text(item.title),
                    subtitle: Text(
                      [
                        formatDateTime(item.createdAt),
                        if (item.description.isNotEmpty) item.description,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => context.push('/bookmarks/${item.id}'),
                    onLongPress: () => _actions(item),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showFilters(List<TagItem> tags) {
    return showListFilterSheet(
      context: context,
      title: '筛选书签',
      canClear: _tagId != null || _type != null,
      onReset: () => setState(() {
        _tagId = null;
        _type = null;
      }),
      content: (context, refresh) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('类型', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            FilterChipWrap(
              children: [
                for (final entry in const [
                  (null, '全部'),
                  ('url', '链接'),
                  ('note', '笔记'),
                  ('image', '图片'),
                  ('file', '文件'),
                ])
                  FilterChip(
                    label: Text(entry.$2),
                    selected: _type == entry.$1,
                    onSelected: (_) {
                      setState(() => _type = entry.$1);
                      refresh();
                    },
                  ),
              ],
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('标签', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              FilterChipWrap(
                children: [
                  FilterChip(
                    label: const Text('全部'),
                    selected: _tagId == null,
                    onSelected: (_) {
                      setState(() => _tagId = null);
                      refresh();
                    },
                  ),
                  for (final tag in tags)
                    FilterChip(
                      label: Text(tag.name),
                      selected: _tagId == tag.id,
                      onSelected: (_) {
                        setState(() => _tagId = tag.id);
                        refresh();
                      },
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _actions(Bookmark item) async {
    final canEdit = ref.read(sessionProvider).canEdit;
    await showActions(context, [
      SheetAction(
        icon: Icons.open_in_new,
        label: '打开',
        onTap: () => context.push('/bookmarks/${item.id}'),
      ),
      if (canEdit)
        SheetAction(
          icon: Icons.delete_outline,
          label: '删除',
          destructive: true,
          onTap: () => _delete(item.id),
        ),
    ]);
  }

  Future<void> _delete(int id) async {
    final ok = await confirm(
      context,
      title: '删除书签',
      message: '删除后无法恢复。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(apiProvider).bookmark.remove(id);
      ref.invalidate(bookmarksProvider(_query));
      if (mounted) showMessage(context, '已删除');
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }
}
