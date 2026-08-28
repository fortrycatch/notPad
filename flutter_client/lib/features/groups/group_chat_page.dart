import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/widgets.dart';

class GroupChatPage extends ConsumerStatefulWidget {
  const GroupChatPage({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends ConsumerState<GroupChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  CancelToken? _sseCancel;
  StreamSubscription<String>? _sseSub;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _sseCancel?.cancel();
    _sseSub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final items = await ref.read(apiProvider).groupChat.list(groupId: widget.groupId);
      if (mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(items);
          _loading = false;
        });
        _jumpToEnd();
      }
      _connectSse();
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        showError(context, error);
      }
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _loadOlder() async {
    if (_loadingMore || _messages.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final older = await ref.read(apiProvider).groupChat.list(
            groupId: widget.groupId,
            beforeId: _messages.first.id,
          );
      if (mounted && older.isNotEmpty) {
        setState(() => _messages.insertAll(0, older));
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _connectSse() async {
    final session = ref.read(sessionProvider);
    if (session.token == null) return;
    _sseCancel?.cancel();
    _sseCancel = CancelToken();
    try {
      final response = await ref.read(apiProvider).client.raw.get<ResponseBody>(
            '${session.baseUrl}/api/group-chat/stream',
            queryParameters: {
              'token': session.token,
              'groupId': widget.groupId,
            },
            options: Options(
              responseType: ResponseType.stream,
              headers: const {'accept': 'text/event-stream'},
            ),
            cancelToken: _sseCancel,
          );
      final stream = response.data?.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      if (stream == null) return;
      _sseSub = stream.listen((line) {
        if (!line.startsWith('data:')) return;
        final raw = line.substring(5).trim();
        if (raw.isEmpty) return;
        try {
          final json = jsonDecode(raw);
          if (json is Map && json['type'] == 'message' && json['message'] != null) {
            final message = ChatMessage.fromJson(json['message']);
            if (!mounted) return;
            if (_messages.any((item) => item.id == message.id)) return;
            setState(() => _messages.add(message));
            _jumpToEnd();
          }
        } catch (_) {}
      });
    } catch (_) {
      // SSE 失败时仍可用发送后本地追加。
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final message = await ref.read(apiProvider).groupChat.send(
            groupId: widget.groupId,
            content: text,
          );
      _input.clear();
      if (_messages.any((item) => item.id == message.id)) return;
      setState(() => _messages.add(message));
      _jumpToEnd();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupProvider(widget.groupId));
    final canPost = group.valueOrNull?.role != 'viewer';
    final myId = ref.watch(sessionProvider).user?.id;
    return Scaffold(
      appBar: FrostedAppBar(title: Text(group.valueOrNull?.name ?? '群聊')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.pixels <= 40) _loadOlder();
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_loadingMore && index == 0) {
                          return const Padding(
                            padding: EdgeInsets.all(8),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final item = _messages[_loadingMore ? index - 1 : index];
                        final mine = item.userId == myId;
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                            ),
                            child: Card(
                              color: mine
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!mine)
                                      Text(
                                        item.userName.isEmpty ? item.userId : item.userName,
                                        style: Theme.of(context).textTheme.labelSmall,
                                      ),
                                    Text(item.content),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (canPost)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: '发送消息',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            )
          else
            const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('只读成员不能发言'),
              ),
            ),
        ],
      ),
    );
  }
}
