import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:competra/main.dart';

void main() {
  testWidgets('Splash görünür ve giriş ekranına yönlendirir',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CompetraApp()));
    await tester.pump();

    // Splash içeriği görünür.
    expect(find.text('COMPETRA'), findsOneWidget);
    expect(find.text('Your tournament. Your rules.'), findsOneWidget);

    // Splash süresi dolunca login ekranına geçilir.
    await tester.pump(const Duration(seconds: 3));
    // Login ekranının (tek seferlik) açılış animasyonlarını tamamla.
    await tester.pumpAndSettle();
    expect(find.text('Misafir Devam Et'), findsOneWidget);
    expect(find.text('Şifremi Unuttum'), findsOneWidget);
  });

  testWidgets('Login -> Misafir Devam Et -> Guest Warning',
      (WidgetTester tester) async {
    // Tüm içerik tek ekrana sığsın diye telefon boyutunda viewport kullan.
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: CompetraApp()));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Misafir Devam Et'));
    await tester.pumpAndSettle();

    // Guest warning içeriği görünür.
    expect(find.text('Emin misin?'), findsOneWidget);
    expect(find.text('Hesap Oluştur'), findsOneWidget);
    expect(find.text('Turnuva geçmişi'), findsOneWidget);
  });
}
