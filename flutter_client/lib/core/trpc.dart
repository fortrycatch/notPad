import 'dart:convert';

import 'package:dio/dio.dart';

class TrpcException implements Exception {
  TrpcException({
    required this.message,
    this.code,
    this.httpStatus,
  });

  final String message;
  final String? code;
  final int? httpStatus;

  bool get isUnauthorized => code == 'UNAUTHORIZED' || httpStatus == 401;

  @override
  String toString() => message;
}

typedef HeaderGetter = String? Function();

class TrpcClient {
  TrpcClient({
    required this.getBaseUrl,
    required this.getToken,
    required this.getGroupId,
  }) : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 60),
            sendTimeout: const Duration(seconds: 60),
            headers: const {'content-type': 'application/json'},
            validateStatus: (status) => status != null && status < 500,
          ),
        );

  final String Function() getBaseUrl;
  final HeaderGetter getToken;
  final HeaderGetter getGroupId;
  final Dio _dio;

  Dio get raw => _dio;

  Future<T> query<T>(
    String procedure, {
    Object? input,
    T Function(Object? json)? parse,
  }) {
    return _call('GET', procedure, input: input, parse: parse);
  }

  Future<T> mutate<T>(
    String procedure, {
    Object? input,
    T Function(Object? json)? parse,
  }) {
    return _call('POST', procedure, input: input, parse: parse);
  }

  Future<T> _call<T>(
    String method,
    String procedure, {
    Object? input,
    T Function(Object? json)? parse,
  }) async {
    final base = getBaseUrl().replaceAll(RegExp(r'/+$'), '');
    final path = '/trpc/$procedure';
    final headers = <String, dynamic>{
      'content-type': 'application/json',
    };
    final token = getToken();
    if (token != null && token.isNotEmpty) {
      headers['token'] = token;
    }
    final groupId = getGroupId();
    if (groupId != null && groupId.isNotEmpty) {
      headers['x-group-id'] = groupId;
    }

    late final Response<dynamic> response;
    try {
      if (method == 'GET') {
        response = await _dio.get<dynamic>(
          '$base$path',
          queryParameters: input == null ? null : {'input': jsonEncode(input)},
          options: Options(headers: headers),
        );
      } else {
        response = await _dio.post<dynamic>(
          '$base$path',
          data: input ?? const <String, dynamic>{},
          options: Options(headers: headers),
        );
      }
    } on DioException catch (error) {
      throw TrpcException(
        message: error.message ?? '网络请求失败',
        httpStatus: error.response?.statusCode,
      );
    }

    final payload = _decode(response.data);
    final data = _unwrap(payload, response.statusCode);
    if (parse != null) return parse(data);
    return data as T;
  }

  Object? _decode(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      return jsonDecode(raw);
    }
    return raw;
  }

  Object? _unwrap(Object? payload, int? status) {
    if (payload is! Map) {
      if (status != null && status >= 400) {
        throw TrpcException(message: '请求失败', httpStatus: status);
      }
      return payload;
    }
    final map = Map<String, dynamic>.from(payload);
    if (map['error'] != null) {
      throw _errorFrom(map['error'], status);
    }
    final result = map['result'];
    if (result is Map) {
      final data = result['data'];
      if (data is Map && data.containsKey('json')) {
        return data['json'];
      }
      return data;
    }
    return map;
  }

  TrpcException _errorFrom(Object? error, int? status) {
    if (error is Map) {
      final wrapped = error['json'] is Map
          ? Map<String, dynamic>.from(error['json'] as Map)
          : Map<String, dynamic>.from(error);
      final data = wrapped['data'];
      String? code;
      int? httpStatus = status;
      if (data is Map) {
        code = data['code']?.toString();
        httpStatus = data['httpStatus'] is num
            ? (data['httpStatus'] as num).toInt()
            : httpStatus;
      }
      return TrpcException(
        message: _humanize(wrapped['message']?.toString() ?? '请求失败'),
        code: code,
        httpStatus: httpStatus,
      );
    }
    return TrpcException(
      message: _humanize(error?.toString() ?? '请求失败'),
      httpStatus: status,
    );
  }

  String _humanize(String message) {
    try {
      final parsed = jsonDecode(message);
      if (parsed is List) {
        final parts = parsed
            .map((item) {
              if (item is Map && item['message'] != null) {
                return item['message'].toString();
              }
              return null;
            })
            .whereType<String>()
            .toList();
        if (parts.isNotEmpty) return parts.join('\n');
      }
    } catch (_) {}
    return message;
  }
}
