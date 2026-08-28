import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/trpc.dart';
import '../models/models.dart';
import '../providers/lists.dart';
import '../providers/session.dart';

void showError(BuildContext context, Object error) {
  final message = error is TrpcException ? error.message : error.toString();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '确定',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? hint,
  String? initial,
  String confirmLabel = '确定',
}) async {
  final controller = TextEditingController(text: initial ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}

class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(error: error, onRetry: onRetry),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final current = error;
    final message = current is TrpcException ? current.message : current.toString();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class ScopeButton extends ConsumerWidget {
  const ScopeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final groups = ref.watch(groupsProvider);
    final current = groups.maybeWhen(
      data: (items) {
        if (session.groupId == null) return '个人空间';
        return items
            .where((item) => item.id == session.groupId)
            .map((item) => item.name)
            .firstOrNull ?? '群组';
      },
      orElse: () => session.groupId == null ? '个人空间' : '群组',
    );

    return TextButton.icon(
      onPressed: () => showScopeSheet(context, ref, groups.valueOrNull ?? const []),
      icon: const Icon(Icons.workspaces_outlined),
      label: Text(current, overflow: TextOverflow.ellipsis),
    );
  }
}

Future<void> showScopeSheet(BuildContext context, WidgetRef ref, List<Group> groups) async {
    final session = ref.read(sessionProvider);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('切换空间')),
              RadioListTile<String?>(
                value: null,
                groupValue: session.groupId,
                title: const Text('个人空间'),
                onChanged: (_) async {
                  await ref.read(sessionProvider.notifier).setGroup();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              for (final group in groups)
                RadioListTile<String?>(
                  value: group.id,
                  groupValue: session.groupId,
                  title: Text(group.name),
                  subtitle: Text(roleLabel(group.role)),
                  onChanged: (_) async {
                    await ref.read(sessionProvider.notifier).setGroup(
                          groupId: group.id,
                          role: group.role,
                        );
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('管理群组'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/groups');
                },
              ),
            ],
          ),
        );
      },
    );
}

String roleLabel(String? role) {
  switch (role) {
    case 'owner':
      return '所有者';
    case 'admin':
      return '管理员';
    case 'editor':
      return '编辑者';
    case 'viewer':
      return '只读';
    default:
      return '成员';
  }
}

IconData typeIcon(String type) {
  switch (type) {
    case 'note':
      return Icons.sticky_note_2_outlined;
    case 'image':
      return Icons.image_outlined;
    case 'file':
      return Icons.insert_drive_file_outlined;
    case 'bookmark':
    case 'url':
      return Icons.bookmark_outline;
    default:
      return Icons.article_outlined;
  }
}

void openTimelineItem(BuildContext context, TimelineItem item) {
  switch (item.type) {
    case 'note':
      context.push('/notes/${item.id}');
    case 'image':
      context.push('/images/${item.id}');
    case 'file':
      context.push('/drive/files/${item.id}');
    case 'bookmark':
      context.push('/bookmarks/${item.id}');
    default:
      break;
  }
}

class SheetAction {
  const SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
}

Future<void> showActions(BuildContext context, List<SheetAction> actions) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final action in actions)
              ListTile(
                leading: Icon(
                  action.icon,
                  color: action.destructive
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
                title: Text(
                  action.label,
                  style: action.destructive
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  action.onTap();
                },
              ),
          ],
        ),
      );
    },
  );
}
