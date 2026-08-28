import 'package:intl/intl.dart';

final _dateTime = DateFormat('yyyy-MM-dd HH:mm');
final _date = DateFormat('yyyy-MM-dd');

String formatDateTime(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return DateFormat('HH:mm').format(local);
  }
  if (local.year == now.year) {
    return DateFormat('MM-dd HH:mm').format(local);
  }
  return _dateTime.format(local);
}

String formatRelativeTime(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 8 &&
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return '${diff.inHours} 小时前';
  }
  return formatDateTime(value);
}

String formatDayLabel(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  if (local.year == now.year) return DateFormat('M月d日').format(local);
  return DateFormat('yyyy年M月d日').format(local);
}

String formatDate(DateTime value) => _date.format(value.toLocal());

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
