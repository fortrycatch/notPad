import 'package:flutter/material.dart';

class ListSearchAppBar extends StatefulWidget implements PreferredSizeWidget {
  const ListSearchAppBar({
    super.key,
    required this.title,
    this.leading,
    required this.searching,
    required this.searchController,
    required this.searchHint,
    required this.onSearch,
    required this.onOpenSearch,
    required this.onCloseSearch,
    this.showSearch = true,
    this.searchActive = false,
    this.filterActive = false,
    this.onFilter,
    this.actions = const [],
  });

  final String title;
  final Widget? leading;
  final bool searching;
  final TextEditingController searchController;
  final String searchHint;
  final ValueChanged<String> onSearch;
  final VoidCallback onOpenSearch;
  final VoidCallback onCloseSearch;
  final bool showSearch;
  final bool searchActive;
  final bool filterActive;
  final VoidCallback? onFilter;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<ListSearchAppBar> createState() => _ListSearchAppBarState();
}

class _ListSearchAppBarState extends State<ListSearchAppBar> {
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onText);
  }

  @override
  void didUpdateWidget(covariant ListSearchAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController.removeListener(_onText);
      widget.searchController.addListener(_onText);
    }
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onText);
    super.dispose();
  }

  void _onText() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (widget.searching) {
      return AppBar(
        leading: IconButton(
          tooltip: '关闭搜索',
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onCloseSearch,
        ),
        title: TextField(
          controller: widget.searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: Theme.of(context).textTheme.titleLarge,
          decoration: InputDecoration(
            hintText: widget.searchHint,
            border: InputBorder.none,
            isDense: true,
          ),
          onChanged: (value) {
            if (value.trim().isEmpty) widget.onSearch('');
          },
          onSubmitted: (value) => widget.onSearch(value.trim()),
        ),
        actions: [
          if (widget.searchController.text.isNotEmpty)
            IconButton(
              tooltip: '清除',
              icon: const Icon(Icons.close),
              onPressed: () {
                widget.searchController.clear();
                widget.onSearch('');
              },
            ),
        ],
      );
    }

    return AppBar(
      leading: widget.leading,
      title: Text(widget.title),
      actions: [
        if (widget.showSearch)
          IconButton(
            tooltip: '搜索',
            onPressed: widget.onOpenSearch,
            icon: Badge(
              isLabelVisible: widget.searchActive,
              child: const Icon(Icons.search),
            ),
          ),
        if (widget.onFilter != null)
          IconButton(
            tooltip: '筛选',
            onPressed: widget.onFilter,
            icon: Badge(
              isLabelVisible: widget.filterActive,
              child: const Icon(Icons.filter_list),
            ),
          ),
        ...widget.actions,
      ],
    );
  }
}

Future<void> showListFilterSheet({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext context, VoidCallback refresh) content,
  bool canClear = false,
  VoidCallback? onReset,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          void refresh() => setSheetState(() {});
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                      ),
                      if (canClear)
                        TextButton(
                          onPressed: () {
                            if (onReset != null) onReset();
                            Navigator.of(sheetContext).pop();
                          },
                          child: const Text('清除'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  content(context, refresh),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class FilterChipWrap extends StatelessWidget {
  const FilterChipWrap({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: children,
    );
  }
}
