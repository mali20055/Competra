import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_providers.dart';

/// Kullanıcıya gösterilebilir, Türkçe mesaj taşıyan kimlik doğrulama hatası.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// FirebaseAuth + Firestore üzerinde kullanıcı adı + e-posta tabanlı kimlik
/// doğrulama.
///
/// Kullanıcı, kullanıcı adıyla giriş yapar; e-posta gerçek adrestir ve şifre
/// sıfırlama için kullanılır. `usernames/{kullanıcıadı}` belgesi hem
/// benzersizliği garanti eder hem de kullanıcı adı → e-posta eşlemesini tutar.
/// Eski (e-postasız) hesaplar için sentetik `<ad>@competra.internal` adresine
/// düşülür (geriye dönük uyumluluk).
class AuthService {
  AuthService(this._auth, this._firestore, this._storage);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const String _emailDomain = 'competra.internal';

  /// Kullanıcı adına karşılık gelen giriş e-postasını çözer. Belge yoksa `null`.
  ///
  /// `usernames` artık yalnızca oturum açık kullanıcılarca okunabildiğinden
  /// (enumerasyon/e-posta sızıntısı koruması), oturum yoksa geçici bir anonim
  /// oturum açılıp arama sonrası kapatılır. (Üretimde bu çözüm bir Cloud
  /// Function -callable- ile değiştirilmelidir.)
  Future<String?> _emailForUsername(String username) async {
    final key = username.trim().toLowerCase();
    if (key.isEmpty) return null;

    final alreadySignedIn = _auth.currentUser != null;
    if (!alreadySignedIn) {
      await _auth.signInAnonymously();
    }
    try {
      final doc = await _firestore.collection('usernames').doc(key).get();
      if (!doc.exists) return null;
      final email = doc.data()?['email'] as String?;
      if (email != null && email.isNotEmpty) return email;
      // Eski hesaplar: sentetik e-posta.
      return '$key@$_emailDomain';
    } finally {
      // Yalnızca arama için açtığımız geçici anonim oturumu kapat.
      if (!alreadySignedIn && (_auth.currentUser?.isAnonymous ?? false)) {
        await _auth.signOut();
      }
    }
  }

  /// Yeni hesap oluşturur: kullanıcı adı benzersizliğini kontrol eder,
  /// gerçek e-posta ile FirebaseAuth kaydını açar ve Firestore'da
  /// `users/{uid}` + `usernames/{kullanıcıadı}` belgelerini yazar.
  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final uname = username.trim();
    final key = uname.toLowerCase();
    final mail = email.trim();
    final usernameRef = _firestore.collection('usernames').doc(key);

    // 1) FirebaseAuth hesabı oluştur. `usernames` artık yalnızca oturum açık
    //    kullanıcılarca okunabildiğinden, benzersizlik kontrolünü hesap
    //    oluştuktan (oturum açıldıktan) SONRA yaparız.
    final UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: mail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e));
    }

    final uid = cred.user!.uid;

    // 2) Kullanıcı adı benzersizlik kontrolü (artık oturum açık).
    final existing = await usernameRef.get();
    if (existing.exists) {
      // Oluşturulan yetim auth hesabını geri al.
      await cred.user?.delete();
      throw const AuthException('Bu kullanıcı adı zaten alınmış.');
    }

    // 3) Firestore belgelerini tek batch'te yaz. `usernames` belgesi yalnızca
    //    create ile yazılabildiğinden (update kuralı yok), iki kullanıcı aynı
    //    adı eşzamanlı seçerse ikincinin batch'i reddedilir → yetim hesap geri
    //    alınıp dostça hata gösterilir (yarış durumu koruması).
    final batch = _firestore.batch();
    batch.set(usernameRef, {
      'uid': uid,
      'username': uname,
      'email': mail,
    });
    batch.set(_firestore.collection('users').doc(uid), {
      'username': uname,
      'usernameLower': key,
      'email': mail,
      'isAnonymous': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    try {
      await batch.commit();
    } catch (_) {
      await cred.user?.delete();
      throw const AuthException('Bu kullanıcı adı zaten alınmış.');
    }
  }

  /// Kullanıcı adı + şifre ile giriş yapar.
  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    final email = await _emailForUsername(username);
    if (email == null) {
      throw const AuthException('Kullanıcı adı veya şifre hatalı.');
    }
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  /// Kullanıcı adına bağlı e-postaya şifre sıfırlama bağlantısı gönderir.
  Future<void> sendPasswordReset(String username) async {
    final email = await _emailForUsername(username);
    if (email == null) {
      throw const AuthException(
        'Bu kullanıcı adına ait bir hesap bulunamadı.',
      );
    }
    if (email.endsWith('@$_emailDomain')) {
      throw const AuthException(
        'Bu hesabın kayıtlı bir e-postası yok; sıfırlama yapılamıyor.',
      );
    }
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  /// Google ile giriş yapar. Başarılıysa `true`, kullanıcı iptal ederse `false`
  /// döner. Giriş sonrası `users/{uid}` belgesi yoksa oluşturulur.
  Future<bool> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return false; // kullanıcı iptal etti

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      final user = cred.user;
      if (user != null) {
        await _ensureUserDocument(user);
      }
      return true;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e));
    } catch (_) {
      throw const AuthException('Google ile giriş yapılamadı.');
    }
  }

  /// Misafir (anonim) oturum açar.
  Future<void> signInAsGuest() async {
    try {
      await _auth.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  /// Sosyal giriş sonrası `users/{uid}` belgesi yoksa oluşturur.
  Future<void> _ensureUserDocument(User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;

    final displayName = user.displayName ?? '';
    final email = user.email ?? '';
    final username = displayName.isNotEmpty
        ? displayName
        : (email.contains('@') ? email.split('@').first : 'Oyuncu');

    await ref.set({
      'username': username,
      'usernameLower': username.toLowerCase(),
      'email': email,
      'photoUrl': user.photoURL ?? '',
      'isAnonymous': false,
      'provider': 'google',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Hesabı kalıcı olarak siler: önce yeniden kimlik doğrulaması yapar, sonra
  /// kullanıcının Firestore verilerini ve Storage fotoğraflarını, en son da
  /// FirebaseAuth hesabını siler.
  ///
  /// E-posta/şifre hesapları için [password] zorunludur (yeniden kimlik
  /// doğrulama). Google hesapları için Google yeniden oturum penceresi açılır;
  /// misafir (anonim) hesaplarda yeniden kimlik doğrulama atlanır.
  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('Oturum bulunamadı, lütfen tekrar giriş yap.');
    }
    final uid = user.uid;

    // 1) Yeniden kimlik doğrulama (auth.delete 'requires-recent-login' ister).
    await _reauthenticate(user, password);

    // 2) Firestore kullanıcı verilerini sil.
    await _deleteUserData(uid);

    // 3) Storage profil/kapak fotoğraflarını sil (yoksa sessizce geçilir).
    await _deleteUserStorage(uid);

    // 4) FirebaseAuth hesabını sil.
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  /// Hesabın giriş yöntemine göre yeniden kimlik doğrulaması yapar.
  Future<void> _reauthenticate(User user, String? password) async {
    final providers = user.providerData.map((p) => p.providerId).toSet();

    // Misafir (anonim) hesapta sağlayıcı yoktur; yeniden doğrulama gerekmez.
    if (user.isAnonymous && providers.isEmpty) return;

    try {
      if (providers.contains('google.com')) {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          throw const AuthException('Hesap silme iptal edildi.');
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
      } else {
        final email = user.email;
        if (email == null || email.isEmpty) {
          throw const AuthException(
            'Bu hesabın e-postası yok; silme işlemi yapılamıyor.',
          );
        }
        if (password == null || password.isEmpty) {
          throw const AuthException('Hesabı silmek için şifreni girmelisin.');
        }
        final credential =
            EmailAuthProvider.credential(email: email, password: password);
        await user.reauthenticateWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  /// Kullanıcının Firestore verilerini siler: `users/{uid}`, `usernames/{ad}`,
  /// sahip olduğu çarklar ve dahil olduğu arkadaşlık ilişkileri.
  Future<void> _deleteUserData(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);
    final userSnap = await userRef.get();
    final usernameLower = userSnap.data()?['usernameLower'] as String?;

    final batch = _firestore.batch();
    batch.delete(userRef);
    if (usernameLower != null && usernameLower.isNotEmpty) {
      batch.delete(_firestore.collection('usernames').doc(usernameLower));
    }

    final wheels = await _firestore
        .collection('wheels')
        .where('ownerId', isEqualTo: uid)
        .get();
    for (final d in wheels.docs) {
      batch.delete(d.reference);
    }

    final friendships = await _firestore
        .collection('friendships')
        .where('users', arrayContains: uid)
        .get();
    for (final d in friendships.docs) {
      batch.delete(d.reference);
    }

    await batch.commit();
  }

  /// Kullanıcının profil ve kapak fotoğraflarını Storage'dan siler.
  Future<void> _deleteUserStorage(String uid) async {
    for (final path in ['profile_photos/$uid.jpg', 'cover_photos/$uid.jpg']) {
      try {
        await _storage.ref(path).delete();
      } catch (_) {
        // Dosya yoksa / silinemezse hesap silmeyi engelleme.
      }
    }
  }

  /// FirebaseAuth hata kodlarını Türkçe kullanıcı mesajlarına çevirir.
  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Kullanıcı adı veya şifre hatalı.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'email-already-in-use':
        return 'Bu e-posta zaten kullanımda.';
      case 'weak-password':
        return 'Şifre çok zayıf, en az 6 karakter olmalı.';
      case 'network-request-failed':
        return 'İnternet bağlantısı kurulamadı. Lütfen tekrar deneyin.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.';
      case 'requires-recent-login':
        return 'Bu işlem için yakın zamanda giriş gerekli. Lütfen tekrar dene.';
      case 'account-exists-with-different-credential':
        return 'Bu e-posta farklı bir giriş yöntemiyle kayıtlı.';
      case 'operation-not-allowed':
        return 'Bu giriş yöntemi şu anda devre dışı.';
      default:
        return 'Bir hata oluştu. Lütfen tekrar deneyin.';
    }
  }
}

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
  ),
);
