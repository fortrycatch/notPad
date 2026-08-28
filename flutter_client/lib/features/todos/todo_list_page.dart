import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/widgets.dart';

class TodoListPage extends StatelessWidget {
  const TodoListPage({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FrostedAppBar(title: Text('待办')),
      body: TodoChecklistView(listId: listId),
    );
  }
}

class TodoChecklistView extends ConsumerStatefulWidget {
  const TodoChecklistView({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<TodoChecklistView> createState() => _TodoChecklistViewState();
}

class _TodoChecklistViewState extends ConsumerState<TodoChecklistView> {
  final _holding = <String>{};

  String get listId => widget.listId;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(todoListProvider(listId));
    final canEdit = ref.watch(sessionProvider).canEdit;
    final list = async.valueOrNull;
    final doneCount = list?.items.where((item) => item.done).length ?? 0;
    final total = list?.items.length ?? 0;

    return AsyncBody(
        value: async,
        onRetry: () => ref.invalidate(todoListProvider(listId)),
        builder: (data) {
          if (data.items.isEmpty) {
            return const EmptyView(icon: Icons.checklist_outlined, message: '还没有待办');
          }
          final pending = data.items
              .where((item) => !item.done || _holding.contains(item.id))
              .toList();
          final done = data.items
              .where((item) => item.done && !_holding.contains(item.id))
              .toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(todoListProvider(listId)),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                if (total > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Text(
                      doneCount == 0 ? '共 $total 项' : '已完成 $doneCount / $total',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                for (final item in pending)
                  _ChecklistRow(
                    key: ValueKey(item.id),
                    item: item,
                    done: item.done || _holding.contains(item.id),
                    canEdit: canEdit,
                    onToggle: () => _toggle(item),
                    onOpen: () => context.push('/todos/$listId/items/${item.id}'),
                    onDelete: () => _delete(item),
                  ),
                if (done.isNotEmpty)
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      title: Text('已完成 · ${done.length}'),
                      children: [
                        for (final item in done)
                          _ChecklistRow(
                            key: ValueKey(item.id),
                            item: item,
                            done: true,
                            canEdit: canEdit,
                            onToggle: () => _toggle(item),
                            onOpen: () => context.push('/todos/$listId/items/${item.id}'),
                            onDelete: () => _delete(item),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
    );
  }

  Future<void> _toggle(TodoItem item) async {
    final next = !item.done;
    if (next) {
      HapticFeedback.lightImpact();
      setState(() => _holding.add(item.id));
      unawaited(
        ref.read(todoListProvider(listId).notifier).setDone(item.id, true).catchError((Object error) {
          if (!mounted) return;
          setState(() => _holding.remove(item.id));
          showError(context, error);
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 420));
      if (mounted) setState(() => _holding.remove(item.id));
      return;
    }
    try {
      await ref.read(todoListProvider(listId).notifier).setDone(item.id, false);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _delete(TodoItem item) async {
    final ok = await confirm(
      context,
      title: '删除待办',
      message: '删除后无法恢复。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(todoListProvider(listId).notifier).removeItem(item.id);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }
}

class _ChecklistRow extends StatefulWidget {
  const _ChecklistRow({
    super.key,
    required this.item,
    required this.done,
    required this.canEdit,
    required this.onToggle,
    required this.onOpen,
    required this.onDelete,
  });

  final TodoItem item;
  final bool done;
  final bool canEdit;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  State<_ChecklistRow> createState() => _ChecklistRowState();
}

class _ChecklistRowState extends State<_ChecklistRow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: widget.done ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant _ChecklistRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.done != widget.done) {
      if (widget.done) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = [
      if (widget.item.description.isNotEmpty) widget.item.description,
      if (widget.item.refs.isNotEmpty) '${widget.item.refs.length} 个引用',
    ].join(' · ');

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutBack.transform(_controller.value.clamp(0.0, 1.0));
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: widget.done ? 0.62 : 1,
                      child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            onTap: widget.onOpen,
            onLongPress: widget.canEdit
                ? () => showActions(context, [
                      SheetAction(
                        icon: Icons.edit_outlined,
                        label: '编辑',
                        onTap: widget.onOpen,
                      ),
                      SheetAction(
                        icon: Icons.delete_outline,
                        label: '删除',
                        destructive: true,
                        onTap: widget.onDelete,
                      ),
                    ])
                : null,
            leading: IconButton(
              tooltip: widget.done ? '标为未完成' : '完成',
              onPressed: widget.canEdit ? widget.onToggle : null,
              icon: CustomPaint(
                size: const Size.square(24),
                painter: _CheckPainter(
                  progress: t,
                  border: scheme.outline,
                  fill: scheme.primary,
                  check: scheme.onPrimary,
                ),
              ),
            ),
            title: Text(
              widget.item.title,
              style: TextStyle(
                decoration: widget.done ? TextDecoration.lineThrough : TextDecoration.none,
                color: widget.done ? scheme.onSurfaceVariant : null,
              ),
            ),
            subtitle: subtitle.isEmpty
                ? null
                : Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({
    required this.progress,
    required this.border,
    required this.fill,
    required this.check,
  });

  final double progress;
  final Color border;
  final Color fill;
  final Color check;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 1;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Color.lerp(border, fill, progress.clamp(0, 1))!;
    canvas.drawCircle(center, radius, outline);
    if (progress > 0) {
      canvas.drawCircle(
        center,
        radius * progress.clamp(0, 1),
        Paint()..color = fill.withValues(alpha: progress.clamp(0, 1)),
      );
      if (progress > 0.35) {
        final checkProgress = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
        final path = Path()
          ..moveTo(size.width * 0.28, size.height * 0.52)
          ..lineTo(size.width * 0.44, size.height * 0.68)
          ..lineTo(size.width * 0.74, size.height * 0.34);
        final metrics = path.computeMetrics().first;
        canvas.drawPath(
          metrics.extractPath(0, metrics.length * checkProgress),
          Paint()
            ..color = check
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.border != border ||
      oldDelegate.fill != fill ||
      oldDelegate.check != check;
}
