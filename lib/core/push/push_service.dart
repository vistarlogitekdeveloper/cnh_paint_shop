import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// ---------------------------------------------------------------------------
/// Push notifications.
///
/// What the SRS asks for: a red shortage or an approval decision buzzes the
/// Supervisor's and Planner's phones, and tapping it opens the item.
///
/// Every entry point here is failure-tolerant. Firebase may be unconfigured (no
/// google-services.json on a dev machine), permission may be denied, or the
/// device may have no Play Services at all — and in all three cases the app must
/// carry on. Push is a courtesy channel; the Alerts screen is the source of
/// truth. A plant that cannot record a receipt because a notification SDK failed
/// to start would be a far worse outcome than a missed buzz.
/// ---------------------------------------------------------------------------

/// Background handler. Must be a top-level function — the isolate that runs it
/// has no access to the app's object graph.
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  // Deliberately does nothing beyond existing. Registering a handler is what
  // makes Android deliver data-only messages while the app is killed; the work
  // happens when the user taps and the app opens.
  debugPrint('[push] background: ${message.messageId}');
}

abstract final class PushService {
  static bool _available = false;
  static void Function(String route)? _go;
  static Future<void> Function(String token)? _registerToken;
  static VoidCallback? _onForegroundMessage;

  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  /// The channel the backend targets (`android.notification.channelId`).
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'cnh_alerts',
    'Shortage alerts',
    description: 'Critical part shortages and approval decisions.',
    // High: a red alert means a machine is about to be unbuildable, which is
    // exactly the case that justifies interrupting someone.
    importance: Importance.high,
  );

  static bool get isAvailable => _available;

  /// Sets up Firebase + the local-notification channel. Safe to call when
  /// Firebase is not configured; it simply leaves push disabled.
  static Future<void> initialise() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[push] Firebase not configured — notifications disabled ($e)');
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[push] permission denied by the user');
        // Still marked available: the token can be registered and the user may
        // grant permission later in system settings.
      }

      // Android needs the channel created before a notification can use it.
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final route = response.payload;
          if (route != null && route.isNotEmpty) _go?.call(route);
        },
      );

      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      _available = true;
      debugPrint('[push] ready');
    } catch (e) {
      debugPrint('[push] initialisation failed — notifications disabled ($e)');
    }
  }

  /// Wires the router and the token registrar. Called once the app graph exists.
  static void attachRouter({
    required void Function(String route) go,
    required Future<void> Function(String token) registerToken,
  }) {
    _go = go;
    _registerToken = registerToken;

    if (!_available) return;

    final messaging = FirebaseMessaging.instance;

    // The current token, plus every rotation. Firebase rotates tokens on
    // reinstall and occasionally on its own, so listening is not optional —
    // a stale token means silent alerts.
    messaging.getToken().then((token) {
      if (token != null) _registerToken?.call(token);
    }).catchError((Object e) {
      // Returning null keeps the handler's type as FutureOr<String?>, matching
      // getToken()'s own. A bare debugPrint would make it FutureOr<void>.
      debugPrint('[push] getToken failed: $e');
      return null;
    });

    messaging.onTokenRefresh.listen((token) {
      _registerToken?.call(token);
    });

    // Foreground: Android does NOT show a system notification for a message
    // received while the app is open, so it is presented locally.
    FirebaseMessaging.onMessage.listen((message) {
      _onForegroundMessage?.call();
      _showLocal(message);
    });

    // Tapped while backgrounded.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // Tapped while terminated — the message that launched the app.
    messaging.getInitialMessage().then((message) {
      if (message != null) _handleTap(message);
    });
  }

  /// Registers a callback for "a push arrived while the app was open", so the
  /// screens can refresh instead of showing stale counters behind the banner.
  static void onMessage(VoidCallback callback) => _onForegroundMessage = callback;

  static void _handleTap(RemoteMessage message) {
    final route = message.data['route'];
    if (route is String && route.isNotEmpty) {
      _go?.call(route);
    }
  }

  static Future<void> _showLocal(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    try {
      await _local.show(
        // A stable-ish id from the message so the same alert replaces itself
        // rather than stacking.
        message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            // Long text: a shortage message names the part, the machine and the
            // rack, which will not fit on one collapsed line.
            styleInformation: BigTextStyleInformation(notification.body ?? ''),
          ),
          iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        payload: message.data['route']?.toString(),
      );
    } catch (e) {
      debugPrint('[push] local display failed: $e');
    }
  }

  /// Unregisters this device — called on logout so a shared tablet stops buzzing
  /// for the operator who has gone home.
  static Future<String?> currentToken() async {
    if (!_available) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }
}
