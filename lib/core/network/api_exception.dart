import 'package:dio/dio.dart';

/// A failure the UI can act on.
///
/// The backend's envelope is `{ success, error, code }`, and `code` is the part
/// that matters: the app branches on codes like `PATTERN_NOT_APPROVED` or
/// `INSUFFICIENT_STOCK` to show the right recovery, while `message` is what the
/// operator reads. Both are preserved rather than collapsed into a string.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.code,
    this.statusCode,
    this.details,
    this.kind = ApiErrorKind.unknown,
  });

  final String message;
  final String? code;
  final int? statusCode;

  /// Extra payload the server attached — e.g. `blocking_parts` on a 422, which
  /// the "mark built" flow renders as a list.
  final Map<String, dynamic>? details;

  final ApiErrorKind kind;

  bool get isOffline => kind == ApiErrorKind.network;
  bool get isAuth => kind == ApiErrorKind.unauthorized;
  bool get isForbidden => kind == ApiErrorKind.forbidden;
  bool get isConflict => statusCode == 409;
  bool get isValidation => statusCode == 400 || statusCode == 422;

  /// Builds the exception from whatever Dio threw, mapping the backend envelope
  /// when there is one and falling back to a message an operator can act on
  /// when there is not.
  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    final data = response?.data;

    // The envelope. Parsed first so a real server message always wins over a
    // generic transport description.
    if (data is Map<String, dynamic>) {
      final serverMessage = data['error'];
      if (serverMessage is String && serverMessage.isNotEmpty) {
        return ApiException(
          message: serverMessage,
          code: data['code'] as String?,
          statusCode: response?.statusCode,
          details: {
            for (final entry in data.entries)
              if (entry.key != 'success' && entry.key != 'error' && entry.key != 'code')
                entry.key: entry.value,
          },
          kind: _kindFor(response?.statusCode, e.type),
        );
      }
    }

    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout =>
        const ApiException(
          message: 'The server did not respond. Check the plant network and try again.',
          code: 'TIMEOUT',
          kind: ApiErrorKind.timeout,
        ),
      DioExceptionType.receiveTimeout => const ApiException(
          message: 'The server is taking too long. Your entry has not been lost — try again.',
          code: 'TIMEOUT',
          kind: ApiErrorKind.timeout,
        ),
      DioExceptionType.connectionError => const ApiException(
          message: 'No connection to the server. You can keep working — entries are saved on this device.',
          code: 'OFFLINE',
          kind: ApiErrorKind.network,
        ),
      DioExceptionType.badCertificate => const ApiException(
          message: 'The server certificate was rejected. Contact IT.',
          code: 'BAD_CERT',
          kind: ApiErrorKind.network,
        ),
      DioExceptionType.cancel => const ApiException(
          message: 'Request cancelled.',
          code: 'CANCELLED',
          kind: ApiErrorKind.cancelled,
        ),
      DioExceptionType.badResponse => ApiException(
          message: _messageForStatus(response?.statusCode),
          code: 'HTTP_${response?.statusCode ?? 0}',
          statusCode: response?.statusCode,
          kind: _kindFor(response?.statusCode, e.type),
        ),
      // `unknown`, `transformTimeout`, and anything a future Dio adds.
      _ => ApiException(
          message: e.message ?? 'Something went wrong talking to the server.',
          code: 'UNKNOWN',
          kind: ApiErrorKind.unknown,
        ),
    };
  }

  static String _messageForStatus(int? status) => switch (status) {
        400 => 'That request was not valid.',
        401 => 'Your session has expired. Please sign in again.',
        403 => 'Your role does not allow this.',
        404 => 'That record no longer exists.',
        409 => 'Someone else changed this first. Refresh and try again.',
        413 => 'That file is too large.',
        422 => 'That cannot be done right now.',
        429 => 'Too many attempts. Wait a moment and try again.',
        final int s when s >= 500 =>
          'The server had a problem. Nothing you entered has been lost.',
        _ => 'Something went wrong talking to the server.',
      };

  static ApiErrorKind _kindFor(int? status, DioExceptionType type) {
    if (status == 401) return ApiErrorKind.unauthorized;
    if (status == 403) return ApiErrorKind.forbidden;
    if (status == 404) return ApiErrorKind.notFound;
    if (status != null && status >= 500) return ApiErrorKind.server;
    if (status != null && status >= 400) return ApiErrorKind.client;
    if (type == DioExceptionType.connectionError) return ApiErrorKind.network;
    return ApiErrorKind.unknown;
  }

  /// A typed view of `details` for the common case of a blocked machine build.
  List<Map<String, dynamic>> get blockingParts {
    final raw = details?['blocking_parts'];
    if (raw is List) return raw.whereType<Map<String, dynamic>>().toList();
    return const [];
  }

  @override
  String toString() => 'ApiException($code/$statusCode): $message';
}

enum ApiErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  client,
  server,
  cancelled,
  unknown,
}
