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
