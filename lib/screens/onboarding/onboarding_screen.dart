import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../router/route_paths.dart';

/// Uygulamayı ilk kez açan kullanıcıya gösterilen tanıtım (onboarding) turu.
///
/// 5 slayttan oluşur (PageView). Tamamlandığında (ya da atlandığında)
/// `SharedPreferences`'a `onboarding_completed: true` yazılır ve oturum
/// durumuna göre giriş ya da ana ekrana yönlendirilir. Bayrak kontrolü
/// [SplashScreen] içinde yapılır; bu ekran yalnızca bayrak `false` iken açılır.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  /// Onboarding tamamlandığını işaretleyen SharedPreferences anahtarı.
  static const String completedKey = 'onboarding_completed';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const List<_Slide> _slides = [
    _Slide(
      icon: Icons.emoji_events,
      emoji: '🏆',
      title: 'Hoş Geldin!',
      heading: "Competra'ya hoş geldin!",
      description:
          'Arkadaşlarınla turnuva organize etmenin en kolay yolu.',
    ),
    _Slide(
      icon: Icons.sports_soccer,
      emoji: '⚽',
      title: 'Turnuva Oluştur',
      heading: 'Kendi turnuvanı oluştur',
      description:
          'Lig, eleme, grup veya Şampiyonlar Ligi formatını seç.',
    ),
    _Slide(
      icon: Icons.group,
      emoji: '👥',
      title: 'Arkadaşlarını Davet Et',
      heading: 'Davet koduyla katılım',
      description:
          '6 haneli kodu paylaş, arkadaşların anında katılsın.',
    ),
    _Slide(
      icon: Icons.bar_chart,
      emoji: '📊',
      title: 'Takip Et',
      heading: 'Canlı puan tablosu',
      description:
          'Fikstür, skor ve istatistikleri anlık takip et.',
    ),
    _Slide(
      icon: Icons.rocket_launch,
      emoji: '🚀',
      title: 'Başla!',
      heading: 'Hazır mısın?',
      description:
          'İlk turnuvanı oluştur ve oynamaya başla!',
    ),
  ];

  bool get _isLast => _index == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Onboarding'i tamamlar: bayrağı yazar ve oturum durumuna göre yönlendirir.
  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.completedKey, true);
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.goNamed(RoutePaths.homeName);
    } else {
      context.goNamed(RoutePaths.loginName);
    }
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Üst: "Atla" text butonu (son slaytta gizlenir).
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: AnimatedOpacity(
                  opacity: _isLast ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: _isLast ? null : _finish,
                    child: const Text('Atla'),
                  ),
                ),
              ),
            ),

            // Orta: kaydırılabilir slaytlar.
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
              ),
            ),

            // Alt: sayfa göstergesi noktaları.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? scheme.primary
                          : scheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // Alt: İleri / Başla butonu.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    _isLast ? 'Başla' : 'İleri',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tek bir onboarding slaytının içerik tanımı.
class _Slide {
  const _Slide({
    required this.icon,
    required this.emoji,
    required this.title,
    required this.heading,
    required this.description,
  });

  final IconData icon;
  final String emoji;
  final String title;
  final String heading;
  final String description;
}

/// Bir slaytı ekranda gösterir: büyük ikon, başlık ve açıklama. İçerik her
/// görünüşte hafif bir fade/slide animasyonuyla belirir.
class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Büyük ikon rozeti (80px, primary renk).
          Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(slide.icon, size: 80, color: scheme.primary),
          )
              .animate(key: ValueKey(slide.title))
              .fadeIn(duration: 400.ms)
              .scaleXY(begin: 0.8, end: 1, curve: Curves.easeOutBack),
          const SizedBox(height: 36),

          // "Başlık emoji" — slayt başlığı (bold, 24sp).
          Text(
            '${slide.title} ${slide.emoji}',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: scheme.onSurface,
            ),
          )
              .animate(key: ValueKey('${slide.title}-h'))
              .fadeIn(delay: 120.ms, duration: 400.ms)
              .slideY(begin: 0.2, end: 0),
          const SizedBox(height: 12),

          // Vurgulu alt başlık.
          Text(
            slide.heading,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            ),
          )
              .animate(key: ValueKey('${slide.title}-s'))
              .fadeIn(delay: 200.ms, duration: 400.ms),
          const SizedBox(height: 12),

          // Açıklama metni (secondary/ikincil renk, 16sp).
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          )
              .animate(key: ValueKey('${slide.title}-d'))
              .fadeIn(delay: 280.ms, duration: 400.ms),
        ],
      ),
    );
  }
}
