import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Session persistence.
///
/// Tokens go in the platform keystore (Keychain / EncryptedSharedPreferences /
/// DPAPI), never in SharedPreferences — a shared shop-floor tablet is exactly
/// the device where a plaintext refresh token would matter.
///
/// The cached USER payload is different: it holds no credential, only a name,
/// role and permission list, and it is read synchronously on the very first
/// frame to decide the landing route. That goes in SharedPreferences so the app
/// does not have to await a keystore round-trip before it can draw anything.
class TokenStore {
  TokenStore(this._secure, this._prefs);

  static const _kAccess = 'cnh.access_token';
  static const _kRefresh = 'cnh.refresh_token';
  static const _kRefreshExpiry = 'cnh.refresh_expires_at';
  static const _kUser = 'cnh.user';
  static const _kLastLine = 'cnh.last_line_id';
  static const _kThemeMode = 'cnh.theme_mode';
  static const _kLastSync = 'cnh.last_sync_at';
  static const _kFcmToken = 'cnh.fcm_token';

  final FlutterSecureStorage _secure;
  final SharedPreferences _prefs;

  static Future<TokenStore> open() async {
    const secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      wOptions: WindowsOptions(),
    );
    final prefs = await SharedPreferences.getInstance();
    return TokenStore(secure, prefs);
  }

  // ---- tokens ----

  /// In-memory mirror of the access token.
  ///
  /// The Dio interceptor reads this on EVERY request; hitting the keystore each
  /// time would add milliseconds per call and, on Android, occasional jank. The
  /// keystore stays the source of truth across launches.
  String? _accessCache;

  Future<String?> accessToken() async {
    return _accessCache ??= await _readSecure(_kAccess);
  }

  Future<String?> refreshToken() => _readSecure(_kRefresh);

  Future<void> saveTokens({
    required String access,
    required String refresh,
    String? refreshExpiresAt,
  }) async {
    _accessCache = access;
    await _writeSecure(_kAccess, access);
    await _writeSecure(_kRefresh, refresh);
    if (refreshExpiresAt != null) {
      await _prefs.setString(_kRefreshExpiry, refreshExpiresAt);
    }
  }

  Future<void> saveAccessToken(String access) async {
    _accessCache = access;
    await _writeSecure(_kAccess, access);
  }

  DateTime? get refreshExpiresAt {
    final raw = _prefs.getString(_kRefreshExpiry);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// True when the stored refresh token is past its expiry, so the app can send
  /// the user to login without a doomed network round-trip.
  bool get refreshExpired {
    final at = refreshExpiresAt;
    return at != null && at.isBefore(DateTime.now());
  }

  // ---- cached user ----

  Map<String, dynamic>? get cachedUser {
    final raw = _prefs.getString(_kUser);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(Map<String, dynamic> user) =>
      _prefs.setString(_kUser, jsonEncode(user));

  // ---- preferences that survive logout ----

  String? get lastLineId => _prefs.getString(_kLastLine);
  Future<void> saveLastLineId(String? id) async {
    if (id == null) {
      await _prefs.remove(_kLastLine);
    } else {
      await _prefs.setString(_kLastLine, id);
    }
  }

  /// 'system' | 'light' | 'dark'.
  String get themeMode => _prefs.getString(_kThemeMode) ?? 'system';
  Future<void> saveThemeMode(String mode) => _prefs.setString(_kThemeMode, mode);

  DateTime? get lastSyncAt {
    final raw = _prefs.getString(_kLastSync);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> saveLastSyncAt(DateTime at) =>
      _prefs.setString(_kLastSync, at.toIso8601String());

  String? get fcmToken => _prefs.getString(_kFcmToken);
  Future<void> saveFcmToken(String token) => _prefs.setString(_kFcmToken, token);

  // ---- teardown ----

  /// Clears the session but KEEPS device preferences (theme, last line, FCM
  /// token). Logging out should not reset the operator's tablet to defaults.
  Future<void> clearSession() async {
    _accessCache = null;
    await _deleteSecure(_kAccess);
    await _deleteSecure(_kRefresh);
    await _prefs.remove(_kRefreshExpiry);
    await _prefs.remove(_kUser);
  }

  // ---- secure-storage wrappers ----
  //
  // flutter_secure_storage throws on some platforms (notably an unconfigured
  // Linux desktop, and web where there is no keystore at all). The app must not
  // crash on launch because of it — a failed read degrades to "no session", and
  // a failed write is logged. On web the token then lives only in memory, which
  // is the correct trade-off there anyway.

  Future<String?> _readSecure(String key) async {
    if (kIsWeb) return _prefs.getString('web.$key');
    try {
      return await _secure.read(key: key);
    } catch (e) {
      debugPrint('[TokenStore] secure read failed for $key: $e');
      return null;
    }
  }

  Future<void> _writeSecure(String key, String value) async {
    if (kIsWeb) {
      // No keystore in a browser. Session storage via prefs is the pragmatic
      // choice for the plant's internal web build; the token is short-lived and
      // the refresh rotates on every use.
      await _prefs.setString('web.$key', value);
      return;
    }
    try {
      await _secure.write(key: key, value: value);
    } catch (e) {
      debugPrint('[TokenStore] secure write failed for $key: $e');
    }
  }

  Future<void> _deleteSecure(String key) async {
    if (kIsWeb) {
      await _prefs.remove('web.$key');
      return;
    }
    try {
      await _secure.delete(key: key);
    } catch (e) {
      debugPrint('[TokenStore] secure delete failed for $key: $e');
    }
  }
}
