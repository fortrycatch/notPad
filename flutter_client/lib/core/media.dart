const defaultImageHost = 'https://monika.jkloli.net/'; //TODO 以后从服务端获取

String resolveMediaUrl(String url, {String host = defaultImageHost}) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  final base = host.endsWith('/') ? host : '$host/';
  return '$base${trimmed.replaceFirst(RegExp(r'^/+'), '')}';
}

String thumbnailUrl(String url, {int width = 480}) {
  final full = resolveMediaUrl(url);
  if (full.isEmpty) return full;
  final sep = full.contains('?') ? '&' : '?';
  return '$full${sep}x-oss-process=image/resize,w_$width';
}
