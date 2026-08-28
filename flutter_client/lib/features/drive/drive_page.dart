import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/list_toolbar.dart';
import '../../widgets/widgets.dart';
import '../home/app_drawer.dart';

class DrivePage extends ConsumerStatefulWidget {
  const DrivePage({super.key, this.folderId});

  final String? folderId;

  @override
  ConsumerState<DrivePage> createState() => _DrivePageState();
}

class _DrivePageState extends ConsumerState<DrivePage> {
  String _sort = 'time_desc';
  String _search = '';
  bool _searching = false;
  bool _uploading = false;
  final _searchController = TextEditingController();

  DriveQuery get _query => DriveQuery(
        folderId: widget.folderId,
        sort: _sort,
        search: _search,
      );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(driveProvider(_query));
    final canEdit = ref.watch(sessionProvider).canEdit;
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: ListSearchAppBar(
        title: async.valueOrNull?.currentFolder?.name ?? '网盘',
        leading: widget.folderId == null ? const DrawerMenuButton() : null,
        searching: _searching,
        searchController: _searchController,
        searchHint: '搜索当前目录',
        searchActive: _search.isNotEmpty,
        onSearch: (value) => setState(() => _search = value),
        onOpenSearch: () => setState(() => _searching = true),
        onCloseSearch: () => setState(() {
          _searching = false;
          _search = _searchController.text.trim();
        }),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'folder') {
                _createFolder();
              } else {
                setState(() => _sort = value);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'time_desc', child: Text('最新')),
              const PopupMenuItem(value: 'time', child: Text('最早')),
              const PopupMenuItem(value: 'name', child: Text('名称')),
              if (canEdit) const PopupMenuItem(value: 'folder', child: Text('新建文件夹')),
            ],
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? ShellFab(
              enabled: widget.folderId == null,
              child: FloatingActionButton(
                heroTag: 'drive-fab',
                onPressed: _uploading ? null : _upload,
                child: _uploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
              ),
            )
          : null,
      body: AsyncBody(
        value: async,
        onRetry: () => ref.read(driveProvider(_query).notifier).refresh(),
        builder: (data) {
          if (data.folders.isEmpty && data.files.isEmpty) {
            return EmptyView(
              icon: Icons.folder_off_outlined,
              message: _search.isNotEmpty ? '没有符合条件的文件' : '空文件夹',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(driveProvider(_query).notifier).refresh(),
            child: ListView(
              children: [
                for (final folder in data.folders)
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(folder.name),
                    onTap: () => context.push('/drive/folders/${folder.id}'),
                    onLongPress: canEdit ? () => _folderActions(folder) : null,
                  ),
                for (final file in data.files)
                  ListTile(
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(file.name),
                    subtitle: Text('${formatBytes(file.size)} · ${formatDateTime(file.createdAt)}'),
                    onTap: () => context.push('/drive/files/${file.id}', extra: file),
                    onLongPress: canEdit ? () => _fileActions(file) : null,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _createFolder() async {
    final name = await promptText(context, title: '新建文件夹', hint: '文件夹名');
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(apiProvider).fileDrive.createFolder(
            name: name.trim(),
            parentId: widget.folderId,
          );
      ref.invalidate(driveProvider(_query));
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) showMessage(context, '无法读取文件');
      return;
    }
    setState(() => _uploading = true);
    try {
      final mime = lookupMimeType(file.name, headerBytes: bytes) ?? 'application/octet-stream';
      final api = ref.read(apiProvider);
      final slot = await api.fileDrive.getUploadUrl(
        filename: file.name,
        type: mime,
        folderId: widget.folderId,
      );
      await api.uploadBytes(url: slot.url, bytes: bytes, contentType: mime);
      await api.fileDrive.addFile(
        name: file.name,
        filename: slot.filename,
        folderId: widget.folderId,
        mimeType: mime,
      );
      ref.invalidate(driveProvider(_query));
      ref.invalidate(timelineProvider);
      if (mounted) showMessage(context, '上传完成');
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _folderActions(DriveFolder folder) {
    return showActions(context, [
      SheetAction(
        icon: Icons.edit_outlined,
        label: '重命名',
        onTap: () => _renameFolder(folder),
      ),
    ]);
  }

  Future<void> _fileActions(DriveFile file) {
    return showActions(context, [
      SheetAction(
        icon: Icons.open_in_new,
        label: '打开',
        onTap: () => context.push('/drive/files/${file.id}', extra: file),
      ),
      SheetAction(
        icon: Icons.edit_outlined,
        label: '重命名',
        onTap: () => _renameFile(file),
      ),
    ]);
  }

  Future<void> _renameFolder(DriveFolder folder) async {
    final name = await promptText(context, title: '重命名文件夹', initial: folder.name);
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(apiProvider).fileDrive.renameFolder(folder.id, name.trim());
      ref.invalidate(driveProvider(_query));
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _renameFile(DriveFile file) async {
    final name = await promptText(context, title: '重命名文件', initial: file.name);
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(apiProvider).fileDrive.renameFile(file.id, name.trim());
      ref.invalidate(driveProvider(_query));
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }
}

class DriveFilePage extends ConsumerWidget {
  const DriveFilePage({super.key, required this.id, this.initial});

  final int id;
  final DriveFile? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = initial;
    return Scaffold(
      appBar: FrostedAppBar(title: Text(file?.name ?? '文件')),
      body: file == null
          ? FutureBuilder(
              future: ref.read(apiProvider).fileDrive.getDownloadUrl(id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!;
                return _body(context, ref, data.name, data.url, null);
              },
            )
          : _body(context, ref, file.name, file.publicUrl, file),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    String name,
    String? url,
    DriveFile? file,
  ) {
    return ListView(
      children: [
        ListTile(title: const Text('名称'), subtitle: Text(name)),
        if (file != null)
          ListTile(title: const Text('大小'), subtitle: Text(formatBytes(file.size))),
        if (file != null)
          ListTile(title: const Text('类型'), subtitle: Text(file.mimeType)),
        ListTile(
          title: const Text('下载 / 打开'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () async {
            try {
              final target = url ?? (await ref.read(apiProvider).fileDrive.getDownloadUrl(id)).url;
              await launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication);
            } catch (error) {
              if (context.mounted) showError(context, error);
            }
          },
        ),
        ListTile(
          title: const Text('收藏'),
          trailing: const Icon(Icons.star_outline),
          onTap: () async {
            try {
              final api = ref.read(apiProvider);
              final state = await api.bookmark.isBookmarked(type: 'file', refId: '$id');
              if (state.bookmarked && state.id != null) {
                await api.bookmark.remove(state.id!);
                if (context.mounted) showMessage(context, '已取消收藏');
              } else {
                await api.bookmark.add(type: 'file', title: name, refId: '$id');
                if (context.mounted) showMessage(context, '已收藏');
              }
            } catch (error) {
              if (context.mounted) showError(context, error);
            }
          },
        ),
      ],
    );
  }
}
