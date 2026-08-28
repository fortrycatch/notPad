import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api.dart';
import '../core/trpc.dart';
import '../models/models.dart';

const _tokenKey = 'auth_token';
const _baseUrlKey = 'base_url';
const _groupIdKey = 'group_id';

String defaultBaseUrl() {
  if (!kIsWeb && Platform.isAndroid) {
    return 'http://10.0.2.2:4000';
  }
  return 'http://127.0.0.1:4000';
}

@immutable
class Session {
  const Session({
    required this.ready,
    required this.baseUrl,
    this.token,
    this.user,
    this.groupId,
    this.groupRole,
  });

  final bool ready;
  final String baseUrl;
  final String? token;
  final UserProfile? user;
  final String? groupId;
  final String? groupRole;

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  bool get canEdit =>
      groupId == null ||
      groupRole == 'owner' ||
      groupRole == 'admin' ||
      groupRole == 'editor';

  bool get isAdmin =>
      groupId != null && (groupRole == 'owner' || groupRole == 'admin');

  bool get isOwner => groupId != null && groupRole == 'owner';

  Session copyWith({
    bool? ready,
    String? baseUrl,
    String? token,
    UserProfile? user,
    String? groupId,
    String? groupRole,
    bool clearToken = false,
    bool clearUser = false,
    bool clearGroup = false,
  }) {
    return Session(
      ready: ready ?? this.ready,
      baseUrl: baseUrl ?? this.baseUrl,
      token: clearToken ? null : (token ?? this.token),
      user: clearUser ? null : (user ?? this.user),
      groupId: clearGroup ? null : (groupId ?? this.groupId),
      groupRole: clearGroup ? null : (groupRole ?? this.groupRole),
    );
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, Session>(
  SessionNotifier.new,
);

final apiProvider = Provider<Api>((ref) {
  return Api(
    TrpcClient(
      getBaseUrl: () => ref.read(sessionProvider).baseUrl,
      getToken: () => ref.read(sessionProvider).token,
      getGroupId: () => ref.read(sessionProvider).groupId,
    ),
  );
});

class SessionNotifier extends Notifier<Session> {
  final _storage = const FlutterSecureStorage();

  @override
  Session build() {
    Future.microtask(restore);
    return Session(ready: false, baseUrl: defaultBaseUrl());
  }

  Api get _api => ref.read(apiProvider);

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(_baseUrlKey) ?? defaultBaseUrl();
    final groupId = prefs.getString(_groupIdKey);
    final token = await _storage.read(key: _tokenKey);
    state = state.copyWith(baseUrl: baseUrl, groupId: groupId);

    if (token == null || token.isEmpty) {
      state = state.copyWith(ready: true, clearToken: true, clearUser: true);
      return;
    }

    try {
      final ok = await _api.auth.verifyToken(token);
      if (!ok) {
        await _storage.delete(key: _tokenKey);
        state = state.copyWith(ready: true, clearToken: true, clearUser: true);
        return;
      }
      state = state.copyWith(token: token);
      final user = await _api.auth.getProfile();
      String? role;
      if (groupId != null && groupId.isNotEmpty) {
        try {
          final group = await _api.group.getById(groupId);
          role = group.role;
        } catch (_) {
          await prefs.remove(_groupIdKey);
          state = state.copyWith(ready: true, user: user, clearGroup: true);
          return;
        }
      }
      state = state.copyWith(
        ready: true,
        token: token,
        user: user,
        groupId: groupId,
        groupRole: role,
      );
    } on TrpcException catch (error) {
      if (error.isUnauthorized) {
        await _storage.delete(key: _tokenKey);
        state = state.copyWith(ready: true, clearToken: true, clearUser: true);
        return;
      }
      state = state.copyWith(ready: true, token: token);
    } catch (_) {
      state = state.copyWith(ready: true, token: token);
    }
  }

  Future<void> setBaseUrl(String url) async {
    final normalized = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, normalized);
    state = state.copyWith(baseUrl: normalized);
  }

  Future<void> applyAuth(AuthResult result) async {
    if (!result.success || result.token == null) {
      throw TrpcException(message: result.message ?? '登录失败');
    }
    await _storage.write(key: _tokenKey, value: result.token);
    state = state.copyWith(token: result.token, user: result.user);
    try {
      final user = await _api.auth.getProfile();
      state = state.copyWith(ready: true, user: user);
    } catch (_) {
      state = state.copyWith(ready: true);
    }
  }

  Future<void> refreshProfile() async {
    final user = await _api.auth.getProfile();
    state = state.copyWith(user: user);
  }

  Future<void> setGroup({String? groupId, String? role}) async {
    final prefs = await SharedPreferences.getInstance();
    if (groupId == null || groupId.isEmpty) {
      await prefs.remove(_groupIdKey);
      state = state.copyWith(clearGroup: true);
      return;
    }
    await prefs.setString(_groupIdKey, groupId);
    state = state.copyWith(groupId: groupId, groupRole: role);
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_groupIdKey);
    state = state.copyWith(
      ready: true,
      clearToken: true,
      clearUser: true,
      clearGroup: true,
    );
  }
}
