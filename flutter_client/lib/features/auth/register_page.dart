import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/trpc.dart';
import '../../providers/session.dart';
import '../../widgets/widgets.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _userId = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _userId.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final result = await ref.read(apiProvider).auth.register(
            userId: _userId.text.trim(),
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
          );
      if (!result.success) {
        throw TrpcException(message: result.message ?? '注册失败');
      }
      await ref.read(sessionProvider.notifier).applyAuth(result);
      if (mounted) context.go('/feed');
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _userId,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '用户 ID',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? '请输入用户 ID' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '昵称',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? '请输入昵称' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '邮箱',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return '请输入邮箱';
                if (!value.contains('@')) return '邮箱格式不正确';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: '密码（至少 6 位）',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) {
                if (value == null || value.length < 6) return '密码长度至少 6 位';
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('创建账号'),
            ),
          ],
        ),
      ),
    );
  }
}
