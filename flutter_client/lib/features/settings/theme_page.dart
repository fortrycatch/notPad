import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../providers/theme.dart';
import '../../widgets/widgets.dart';

const _presets = [
  (label: '猛男粉', value: '#ff9edd'),
  (label: '胖次蓝', value: '#00a1d6'),
  (label: '早苗绿', value: '#43a047'),
  (label: '咸蛋黄', value: '#ffb300'),
  (label: '基佬紫', value: '#7b1fa2'),
  (label: '姨妈红', value: '#d32f2f'),
  (label: '高级黑', value: '#455a64'),
  (label: '原谅绿', value: '#8bc34a'),
  (label: '土豪金', value: '#c0a060'),
  (label: '橙汁儿', value: '#ff9800'),
];

class ThemePage extends ConsumerStatefulWidget {
  const ThemePage({super.key});

  @override
  ConsumerState<ThemePage> createState() => _ThemePageState();
}

class _ThemePageState extends ConsumerState<ThemePage> {
  final _custom = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final current = ref.watch(themeColorProvider);
    final currentHex = colorToHex(current).toLowerCase();
    final preset = _presets.where((item) => item.value == currentHex).firstOrNull;
    final inGroup = session.groupId != null;
    final canEdit = !inGroup || session.isAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text('主题色')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            inGroup ? '当前空间：群组' : '当前空间：个人',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in _presets)
                _Swatch(
                  color: parseHexColor(item.value)!,
                  selected: currentHex == item.value,
                  label: item.label,
                  onTap: canEdit ? () => _save(item.value) : null,
                ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _custom,
            enabled: canEdit && !_saving,
            maxLength: 7,
            decoration: const InputDecoration(
              labelText: '自定义色值',
              hintText: '#ff9edd',
              counterText: '',
            ),
            onSubmitted: (_) => _applyCustom(),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: canEdit && !_saving ? _applyCustom : null,
            child: const Text('应用'),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: current),
            title: Text(preset?.label ?? '自定义'),
            subtitle: Text(currentHex),
            trailing: currentHex == colorToHex(defaultPrimaryColor).toLowerCase()
                ? null
                : TextButton(
                    onPressed: canEdit && !_saving ? _reset : null,
                    child: const Text('恢复默认'),
                  ),
          ),
          if (!canEdit)
            Text(
              '群组主题色仅管理员可改',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Future<void> _applyCustom() async {
    final hex = _custom.text.trim();
    if (parseHexColor(hex) == null) {
      showMessage(context, '请输入 #RRGGBB 格式的颜色');
      return;
    }
    await _save(hex);
    _custom.clear();
  }

  Future<void> _reset() => _save('');

  Future<void> _save(String color) async {
    setState(() => _saving = true);
    try {
      final session = ref.read(sessionProvider);
      if (session.groupId != null) {
        await ref.read(apiProvider).group.updateMeta(
              groupId: session.groupId!,
              meta: {'primaryColor': color},
            );
        ref.invalidate(groupsProvider);
      } else {
        await ref.read(apiProvider).auth.updateMeta({'primaryColor': color});
        await ref.read(sessionProvider.notifier).refreshProfile();
      }
      if (mounted) showMessage(context, color.isEmpty ? '已恢复默认主题色' : '主题色已更新');
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.label,
    this.onTap,
  });

  final Color color;
  final bool selected;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.black26,
              width: selected ? 3 : 1,
            ),
          ),
        ),
      ),
    );
  }
}
