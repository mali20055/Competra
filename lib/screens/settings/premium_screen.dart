import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/route_paths.dart';
import '../../services/firebase_providers.dart';
import '../../services/premium_service.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _isLoading = false;

  Future<void> _handlePurchase(String packageId) async {
    setState(() => _isLoading = true);
    try {
      await PremiumService.purchase(packageId);
      // Satın alma sonrası isPremiumProvider'ı tetikle
      ref.invalidate(isPremiumProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Satın alım başarılı! Teşekkür ederiz.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İşlem başarısız: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);
    try {
      await PremiumService.restorePurchases();
      ref.invalidate(isPremiumProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Satın alımlar başarıyla geri yüklendi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Geri yükleme başarısız: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final advantages = [
      'Reklamsız deneyim',
      'Sınırsız turnuva',
      'ELO geçmişi ve gelişmiş istatistikler',
      'Özel temalar ve kozmetikler',
      'Öncelikli destek',
    ];

    return Scaffold(
      body: Stack(
        children: [
          // Premium Gradient Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF1E0E3D), // Deep Dark Purple
                        const Color(0xFF0F0826), // Near Black Purple
                        const Color(0xFF2C0B40), // Rich Violet
                      ]
                    : [
                        const Color(0xFFEDE7F6), // Very light purple
                        const Color(0xFFF3E5F5), // Light violet
                        const Color(0xFFE3F2FD), // Light blue tint
                      ],
              ),
            ),
          ),
          
          // Outer Glow/Neon effects
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9C27B0).withValues(alpha: 0.15),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  title: Text(
                    'Competra Pro',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  centerTitle: true,
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),
                        // Crown/Trophy Premium Icon with pulsing vibe
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                            border: Border.all(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                                blurRadius: 20,
                                spreadRadius: 5,
                              )
                            ]
                          ),
                          child: const Icon(
                            Icons.workspace_premium,
                            size: 54,
                            color: Color(0xFFFFD700), // Gold
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Sınırları Kaldır',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Competra Pro ile reklamsız, sınırsız ve profesyonel turnuva deneyimini hemen başlat.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Advantages Container (Glassmorphic card look)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Column(
                            children: advantages.map((advantage) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF4CAF50), // Green Checkmark
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        advantage,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFFEEEEEE) : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Pricing Plans Title
                        Text(
                          'Abonelik Planları',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 2 Purchase Cards/Buttons
                        Row(
                          children: [
                            // Monthly Card
                            Expanded(
                              child: _SubscriptionCard(
                                title: 'Aylık',
                                price: '₺49.99 / ay',
                                isPopular: false,
                                isDark: isDark,
                                theme: theme,
                                onTap: () => _handlePurchase('\$rc_monthly'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Yearly Card (En İyi Değer)
                            Expanded(
                              child: _SubscriptionCard(
                                title: 'Yıllık',
                                price: '₺299.99 / yıl',
                                subText: 'En iyi değer ⚡',
                                isPopular: true,
                                isDark: isDark,
                                theme: theme,
                                onTap: () => _handlePurchase('\$rc_yearly'),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Actions & Restore
                        if (_isLoading)
                          const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFFD700),
                            ),
                          )
                        else ...[
                          TextButton(
                            onPressed: _handleRestore,
                            child: Text(
                              'Mevcut satın alımları geri yükle',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: isDark ? Colors.white70 : Colors.black87,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () => context.pushNamed(RoutePaths.privacyPolicyName),
                                child: Text(
                                  'Gizlilik Politikası',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark ? Colors.white54 : Colors.black54,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '•',
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: () {
                                  // Kullanım koşulları sayfası olmadığı için bir popup veya web url'e yönlendirebiliriz, 
                                  // veya gizlilik politikasına yönlendirebiliriz.
                                  // Şimdilik gizlilik politikası sayfasına yönlendirelim veya dialog açalım.
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Kullanım Koşulları'),
                                      content: const Text(
                                        'Competra uygulamasını kullanarak, kullanım koşullarımızı kabul etmiş olursunuz. Abonelikler RevenueCat aracılığıyla yönetilmekte olup istediğiniz zaman iptal edebilirsiniz.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Tamam'),
                                        )
                                      ],
                                    ),
                                  );
                                },
                                child: Text(
                                  'Kullanım Koşulları',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark ? Colors.white54 : Colors.black54,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.title,
    required this.price,
    this.subText,
    required this.isPopular,
    required this.isDark,
    required this.theme,
    required this.onTap,
  });

  final String title;
  final String price;
  final String? subText;
  final bool isPopular;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: isPopular
              ? (isDark ? const Color(0xFF2D1B4E) : Colors.white)
              : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.01)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPopular ? const Color(0xFFFFD700) : (isDark ? Colors.white12 : Colors.black12),
            width: isPopular ? 2 : 1,
          ),
          boxShadow: isPopular
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                    blurRadius: 15,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            if (isPopular) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'EN İYİ DEĞER',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              price,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isPopular ? const Color(0xFFFFD700) : (isDark ? Colors.white70 : Colors.black87),
              ),
              textAlign: TextAlign.center,
            ),
            if (subText != null) ...[
              const SizedBox(height: 8),
              Text(
                subText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: isPopular ? const Color(0xFFFFD700) : (isDark ? Colors.white24 : Colors.black54),
                foregroundColor: isPopular ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: isPopular ? 4 : 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                'Abone Ol',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isPopular ? Colors.black : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

