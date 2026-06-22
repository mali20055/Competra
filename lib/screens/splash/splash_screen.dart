import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../components/pitch_pattern_background.dart';
import '../../router/route_paths.dart';
import '../onboarding/onboarding_screen.dart';

/// Açılış (splash) ekranı.
///
/// Stitch tasarımına göre: futbol sahası dokulu arka plan, ortada parlayan
/// logo, "COMPETRA" wordmark'ı (nabız animasyonu), tagline ve altta yüklenme
/// noktaları. Belirli bir süre sonra giriş ekranına yönlendirir.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Duration _holdDuration = Duration(milliseconds: 2600);

  Timer? _timer;

  /// Hem süreli zamanlayıcı hem de dokunma aynı anda tetiklenebileceğinden,
  /// yönlendirmenin yalnızca bir kez yapılmasını sağlar.
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_holdDuration, _goNext);
  }

  /// Önce onboarding bayrağını kontrol eder; ilk açılışsa (bayrak `false`)
  /// tanıtım turuna gider. Aksi halde oturum durumuna göre yönlendirir: oturum
  /// açık (gerçek ya da misafir/anonim) kullanıcı → ana panel; oturum yok →
  /// giriş ekranı.
  Future<void> _goNext() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone =
        prefs.getBool(OnboardingScreen.completedKey) ?? false;
    if (!mounted) return;

    if (!onboardingDone) {
      context.goNamed(RoutePaths.onboardingName);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Gerçek hesap ve anonim (misafir) oturum → ana panel.
      context.goNamed(RoutePaths.homeName);
    } else {
      context.goNamed(RoutePaths.loginName);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      // Dokunarak geçişe izin ver (tasarımdaki "tap to continue").
      body: GestureDetector(
        onTap: _goNext,
        child: PitchPatternBackground(
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Logo(color: scheme.secondary, surface: scheme.surface)
                          .animate()
                          .fadeIn(
                            delay: 200.ms,
                            duration: 700.ms,
                            curve: Curves.easeOut,
                          )
                          .slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 24),
                      Text(
                        'COMPETRA',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: scheme.secondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      )
                          .animate(
                            onPlay: (c) => c.repeat(reverse: true),
                          )
                          // Sürekli hafif nabız (scale) — tasarımdaki pulse-logo.
                          .scaleXY(
                            begin: 1.0,
                            end: 1.04,
                            duration: 1800.ms,
                            curve: Curves.easeInOut,
                          )
                          // İlk giriş animasyonu.
                          .animate()
                          .fadeIn(delay: 500.ms, duration: 700.ms)
                          .slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 12),
                      Text(
                        'Your tournament. Your rules.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 800.ms, duration: 700.ms)
                          .slideY(begin: 0.2, end: 0),
                    ],
                  ),
                ),
                // Alt yüklenme noktaları.
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 56),
                    child: _LoadingDots(color: scheme.primary)
                        .animate()
                        .fadeIn(delay: 900.ms, duration: 700.ms),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Yuvarlak, hafif parlayan logo rozeti.
class _Logo extends StatelessWidget {
  const _Logo({required this.color, required this.surface});

  final Color color;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: surface,
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(Icons.sports_soccer, size: 44, color: color),
    );
  }
}

/// Sıralı yanıp sönen üç yüklenme noktası.
class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.4 + i * 0.3),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(
                delay: (i * 200).ms,
                duration: 600.ms,
              )
              .then()
              .fadeOut(duration: 600.ms),
        );
      }),
    );
  }
}
