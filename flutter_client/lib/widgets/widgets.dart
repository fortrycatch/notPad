import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/trpc.dart';
import '../models/models.dart';

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
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _PromptDialog(
      title: title,
      hint: hint,
      initial: initial,
      confirmLabel: confirmLabel,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    this.hint,
    this.initial,
    required this.confirmLabel,
  });

  final String title;
  final String? hint;
  final String? initial;
  final String confirmLabel;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
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
