import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../storage/token_store.dart';
import 'api_exception.dart';

/// The typed HTTP client for the CNH Paint Shop module.
///
/// Owns three things the rest of the app should never have to think about:
///   1. Attaching the bearer token.
///   2. Refreshing it ONCE on a 401 and replaying the original request, with
///      concurrent 401s sharing that single refresh (see [_refreshGate]).
///   3. Unwrapping the `{ success, data, meta }` envelope so callers get `data`.
class ApiClient {
  ApiClient({required this._tokens, Dio? dio, this.onSessionExpired})
    : _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: Env.connectTimeout,
      receiveTimeout: Env.receiveTimeout,
      sendTimeout: Env.connectTimeout,
      contentType: Headers.jsonContentType,
      // Non-2xx is handled by our own error mapping rather than by Dio's
      // validateStatus throwing before we can read the envelope.
      validateStatus: (status) => status != null && status < 500,
      headers: {'Accept': 'application/json'},
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );

    if (Env.isDebug) {
      _dio.interceptors.add(
        LogInterceptor(
          request: false,
          requestHeader: false,
          requestBody: false,
          responseHeader: false,
          // Response bodies are large (a matrix page is thousands of numbers);
          // logging them floods the console and hides everything else.
          responseBody: false,
          logPrint: (o) => debugPrint('[api] $o'),
        ),
      );
    }
  }

  final Dio _dio;
  final TokenStore _tokens;

  /// Called when the refresh token is dead and the user must sign in again.
  final VoidCallback? onSessionExpired;

  Dio get raw => _dio;

  /// A single in-flight refresh, shared by every request that 401s while it runs.
  ///
  /// Without this, a screen that fires five parallel requests on load would
  /// trigger five refreshes. Because the backend ROTATES refresh tokens and
  /// revokes the whole family when a revoked one is replayed, four of those five
  /// would present an already-used token and log the user out — the exact bug
  /// that makes token rotation feel broken.
  Future<bool>? _refreshGate;

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Auth endpoints must not carry a stale bearer: /auth/refresh in particular
    // would then be rejected by the server's `kind == 'access'` assertion.
    final path = options.path;
    final skipAuth =
        path.startsWith('/auth/login') ||
        path.startsWith('/auth/refresh') ||
        path.startsWith('/healthz');

    if (!skipAuth) {
      final token = await _tokens.accessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  void _onResponse(Response response, ResponseInterceptorHandler handler) {
    // A 4xx arrives here (not in onError) because of validateStatus above.
    // Convert it into a DioException so there is ONE error path.
    final status = response.statusCode ?? 0;
    if (status >= 400) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        ),
        true,
      );
      return;
    }
    handler.next(response);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final status = error.response?.statusCode;
    final path = error.requestOptions.path;

    final isRetryable401 =
        status == 401 &&
        !path.startsWith('/auth/login') &&
        !path.startsWith('/auth/refresh') &&
        error.requestOptions.extra['retried'] != true;

    if (!isRetryable401) {
      handler.next(error);
      return;
    }

    final refreshed = await _refreshOnce();
    if (!refreshed) {
      await _tokens.clearSession();
      onSessionExpired?.call();
      handler.next(error);
      return;
    }

    // Replay the original request with the new token. `retried` guards against
    // an infinite loop if the new token is also rejected.
    try {
      final options = error.requestOptions;
      options.extra['retried'] = true;
      final token = await _tokens.accessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      final response = await _dio.fetch(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// Refreshes the access token, coalescing concurrent callers onto one attempt.
  Future<bool> _refreshOnce() {
    return _refreshGate ??= _doRefresh().whenComplete(
      () => _refreshGate = null,
    );
  }

  Future<bool> _doRefresh() async {
    final refresh = await _tokens.refreshToken();
    if (refresh == null || _tokens.refreshExpired) return false;

    try {
      // A BARE Dio: going through `_dio` would run this call through the same
      // interceptor and risk recursing on its own 401.
      final bare = Dio(
        BaseOptions(
          baseUrl: Env.apiBaseUrl,
          connectTimeout: Env.connectTimeout,
          receiveTimeout: Env.connectTimeout,
          contentType: Headers.jsonContentType,
        ),
      );
      final response = await bare.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refresh},
      );

      final data = response.data?['data'];
      if (data is! Map) return false;

      final access = data['access_token'];
      final newRefresh = data['refresh_token'];
      if (access is! String || newRefresh is! String) return false;

      await _tokens.saveTokens(
        access: access,
        refresh: newRefresh,
        refreshExpiresAt: data['refresh_expires_at'] as String?,
      );
      if (data['user'] is Map<String, dynamic>) {
        await _tokens.saveUser(data['user'] as Map<String, dynamic>);
      }
      return true;
    } catch (e) {
      debugPrint('[api] refresh failed: $e');
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Verbs. Each returns the ENVELOPE's `data`, already unwrapped, so callers do
  // not repeat `response.data['data']` a hundred times.
  // -------------------------------------------------------------------------

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    return _send<T>(
      () => _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: _clean(query),
        cancelToken: cancelToken,
      ),
    );
  }

  /// The full envelope, for endpoints whose `meta` the caller needs (paging,
  /// register totals, request counts).
  Future<ApiEnvelope<T>> getEnvelope<T>(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: _clean(query),
        cancelToken: cancelToken,
      );
      final body = response.data ?? const {};
      return ApiEnvelope<T>(
        data: body['data'] as T,
        meta: body['meta'] as Map<String, dynamic>?,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    return _send<T>(
      () => _dio.post<Map<String, dynamic>>(
        path,
        data: body,
        queryParameters: _clean(query),
        cancelToken: cancelToken,
      ),
    );
  }

  /// Multipart POST.
  ///
  /// Separate from [post] because BaseOptions pins contentType to JSON for
  /// every other call in the app; a form has to override it explicitly, and the
  /// boundary is Dio's to generate.
  Future<T> postForm<T>(
    String path,
    FormData form, {
    CancelToken? cancelToken,
  }) async {
    return _send<T>(
      () => _dio.post<Map<String, dynamic>>(
        path,
        data: form,
        cancelToken: cancelToken,
        options: Options(contentType: 'multipart/form-data'),
      ),
    );
  }

  Future<T> patch<T>(String path, {Object? body}) async {
    return _send<T>(() => _dio.patch<Map<String, dynamic>>(path, data: body));
  }

  Future<T> put<T>(String path, {Object? body}) async {
    return _send<T>(() => _dio.put<Map<String, dynamic>>(path, data: body));
  }

  Future<T> delete<T>(String path) async {
    return _send<T>(() => _dio.delete<Map<String, dynamic>>(path));
  }

  /// Downloads a report as bytes, with the filename the server suggested.
  ///
  /// Returns bytes rather than writing a file so the caller decides: share
  /// sheet on mobile, browser download on web.
  Future<({List<int> bytes, String filename, String contentType})> download(
    String path, {
    Map<String, dynamic>? query,
    String fallbackFilename = 'report.xlsx',
    ProgressCallback? onProgress,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        queryParameters: _clean(query),
        onReceiveProgress: onProgress,
        options: Options(
          responseType: ResponseType.bytes,
          // A binary endpoint can still answer with a JSON error envelope; let
          // it through so the message can be surfaced rather than saved as a
          // corrupt file.
          validateStatus: (s) => s != null && s < 500,
          headers: {'Accept': '*/*'},
        ),
      );

      if ((response.statusCode ?? 500) >= 400) {
        throw ApiException(
          message: 'That report could not be generated.',
          statusCode: response.statusCode,
          code: 'REPORT_FAILED',
        );
      }

      final disposition = response.headers.value('content-disposition');
      return (
        bytes: response.data ?? const <int>[],
        filename: _filenameFrom(disposition) ?? fallbackFilename,
        contentType:
            response.headers.value('content-type') ??
            'application/octet-stream',
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<T> _send<T>(
    Future<Response<Map<String, dynamic>>> Function() call,
  ) async {
    try {
      final response = await call();
      final body = response.data;
      if (body == null) {
        // 204, or an endpoint that answers with nothing. `null as T` is correct
        // for a `Future<void>`/nullable T and would throw for a non-nullable
        // one — which is the honest outcome, since there is no value to give.
        return null as T;
      }
      return body['data'] as T;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Drops null query params so the URL does not carry `?lineId=null`, which the
  /// backend would try to parse as a UUID.
  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final out = <String, dynamic>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String && value.isEmpty) continue;
      out[entry.key] = value;
    }
    return out.isEmpty ? null : out;
  }

  static String? _filenameFrom(String? contentDisposition) {
    if (contentDisposition == null) return null;
    final match = RegExp(
      'filename="?([^";]+)"?',
    ).firstMatch(contentDisposition);
    return match?.group(1);
  }
}

/// `{ data, meta }` for endpoints whose paging or totals the caller needs.
class ApiEnvelope<T> {
  const ApiEnvelope({required this.data, this.meta});

  final T data;
  final Map<String, dynamic>? meta;

  int? get total => (meta?['total'] as num?)?.toInt();
  bool get hasMore => meta?['has_more'] == true;
  int? get page => (meta?['page'] as num?)?.toInt();
  int? get pages => (meta?['pages'] as num?)?.toInt();
}
