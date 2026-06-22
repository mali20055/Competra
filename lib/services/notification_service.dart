import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../router/app_router.dart';
import '../router/route_paths.dart';

/// Arka planda (uygulama kapalı/uyur durumda) gelen mesajlar için en üst düzey
/// (top-level) işleyici. Firebase, bu fonksiyonu kendi izole'sinde çağırdığından
/// sınıf üyesi olamaz ve `@pragma('vm:entry-point')` ile işaretlenmelidir.
///
/// Burada ağır iş yapılmaz; bildirim sistem tepsisinde otomatik gösterilir.
/// Tıklama yönlendirmesi, uygulama öne geldiğinde [FirebaseMessaging.onMessageOpenedApp]
/// (veya soğuk başlatmada [FirebaseMessaging.instance.getInitialMessage]) ile ele alınır.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Bilinçli olarak boş: arka plan bildirimi OS tarafından gösterilir.
  debugPrint('Arka plan bildirimi alındı: ${message.messageId}');
}

/// Firebase Cloud Messaging (FCM) push bildirimlerini yöneten servis.
///
/// Sorumlulukları:
///   * İzin isteme (iOS / Android 13+).
///   * FCM token'ı alıp `users/{uid}` belgesine `fcmToken` olarak yazma.
///   * Token yenilendiğinde ve oturum değiştiğinde token'ı güncel tutma.
///   * Ön planda gelen bildirimi bir SnackBar ile gösterme.
///   * Bildirime tıklanınca payload'a göre ilgili ekrana yönlendirme.
class NotificationService {
  const NotificationService._();

  /// Ön planda bildirim göstermek (SnackBar) için global messenger anahtarı.
  /// [MaterialApp.scaffoldMessengerKey]'e bağlanır.
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Aktif token-yenileme aboneliği. [initialize] tekrar çağrılırsa (örn.
  /// hot-restart) önceki abonelik iptal edilip yenisi kurulur; böylece aynı
  /// olaya birden çok kez tepki verilmez.
  static StreamSubscription<String>? _tokenRefreshSub;

  /// Aktif oturum-değişimi aboneliği (aynı hot-restart güvenliği için).
  static StreamSubscription<User?>? _authStateSub;

  /// `Firebase.initializeApp` sonrasında bir kez çağrılmalıdır.
  static Future<void> initialize() async {
    // Hot-restart güvenliği: initialize() tekrar çağrılırsa önceki
    // subscription'ları iptal et (mükerrer dinleyici / token yazımını önle).
    if (_tokenRefreshSub != null) {
      await _tokenRefreshSub!.cancel();
      _tokenRefreshSub = null;
    }
    if (_authStateSub != null) {
      await _authStateSub!.cancel();
      _authStateSub = null;
    }

    // Arka plan mesaj işleyicisini kaydet.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // İzin iste (iOS'ta zorunlu, Android 13+ için POST_NOTIFICATIONS runtime izni).
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // iOS'ta uygulama ön plandayken de bildirimin OS tarafından gösterilmesi.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Mevcut token'ı al ve (oturum açıksa) kaydet.
    await _syncToken();

    // Token yenilendiğinde otomatik güncelle.
    _tokenRefreshSub = _messaging.onTokenRefresh.listen(_saveToken);

    // Oturum değiştiğinde (giriş/çıkış) token'ı ilgili kullanıcıya bağla.
    _authStateSub = _auth.authStateChanges().listen((_) => _syncToken());

    // Ön planda gelen bildirim.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Arka planda iken bildirime tıklanıp uygulama öne getirildiğinde.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageNavigation);

    // Uygulama tamamen kapalıyken bildirime tıklanarak açıldıysa (soğuk başlatma).
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageNavigation(initialMessage);
    }
  }

  /// Mevcut FCM token'ını alır ve oturum açık (ve anonim olmayan) kullanıcı için
  /// Firestore'a yazar.
  static Future<void> _syncToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }
  }

  /// FCM token'ını `users/{uid}` belgesine `fcmToken` alanı olarak yazar.
  /// Oturum yoksa veya misafir (anonim) kullanıcıdaysa hiçbir şey yapmaz.
  static Future<void> _saveToken(String token) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      await _firestore.collection('users').doc(user.uid).set(
        {
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('FCM token kaydedilemedi: $e');
    }
  }

  /// Ön planda gelen bildirimi bir SnackBar ile gösterir; "Göster" eylemi
  /// payload'a göre ilgili ekrana yönlendirir.
  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title;
    final body = notification?.body;
    final text = [title, body].where((e) => e != null && e.isNotEmpty).join('\n');
    if (text.isEmpty) return;

    final messenger = messengerKey.currentState;
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        action: SnackBarAction(
          label: 'Göster',
          onPressed: () => _handleMessageNavigation(message),
        ),
      ),
    );
  }

  /// Bildirim payload'ındaki [RemoteMessage.data] alanlarına göre yönlendirir:
  ///   * `type == 'friendRequest'`        → /social
  ///   * `type == 'tournamentComplete'`   → /tournament/:id/wrapped
  ///   * `tournamentId` mevcutsa          → /tournament/:id
  static void _handleMessageNavigation(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    final tournamentId = data['tournamentId'] as String?;

    final router = AppRouter.router;

    if (type == 'friendRequest') {
      router.go(RoutePaths.social);
      return;
    }

    if (type == 'tournamentComplete' &&
        tournamentId != null &&
        tournamentId.isNotEmpty) {
      router.go('/tournament/$tournamentId/wrapped');
      return;
    }

    if (tournamentId != null && tournamentId.isNotEmpty) {
      router.go('/tournament/$tournamentId');
    }
  }
}
