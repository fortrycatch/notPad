import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'lists.dart';
import 'session.dart';

const defaultPrimaryColor = Color(0xFFFF9EDD);

Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  var value = hex.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('#')) value = value.substring(1);
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return null;
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return null;
  return Color(parsed);
}

String colorToHex(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0')}';
}

final themeColorProvider = Provider<Color>((ref) {
  final session = ref.watch(sessionProvider);
  if (session.groupId != null) {
    final groups = ref.watch(groupsProvider).valueOrNull ?? const <Group>[];
    final group = groups.where((item) => item.id == session.groupId).firstOrNull;
    final groupColor = parseHexColor(group?.primaryColor);
    if (groupColor != null) return groupColor;
  }
  return parseHexColor(session.user?.primaryColor) ?? defaultPrimaryColor;
});
