import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/session.dart';
import '../../widgets/widgets.dart';

class ServerPage extends ConsumerStatefulWidget {
  const ServerPage({super.key});

  @override
  ConsumerState<ServerPage> createState() => _ServerPageState();
}

class _ServerPageState extends ConsumerState<ServerPage> {
  late final TextEditingController _controller;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(sessionProvider).baseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _controller.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      showMessage(context, '请输入以 http 开头的地址');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).setBaseUrl(url);
      if (mounted) {
        showMessage(context, '已保存');
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('服务器地址')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'API 根地址',
              hintText: 'http://10.0.2.2:4000',
              helperText: '模拟器请用 10.0.2.2，真机请填局域网 IP',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
