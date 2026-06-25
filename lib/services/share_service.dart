import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'analytics_service.dart';

/// Paylaşılabilir görsel üretimi ve paylaşımı.
///
/// Bir [RepaintBoundary]'nin ekran görüntüsünü alır, PNG'e çevirip geçici bir
/// dosyaya yazar ve `share_plus` ile sistem paylaşım sayfasını açar.
class ShareService {
  const ShareService._();

  /// [boundaryKey] ile bağlı [RepaintBoundary] widget'ının görüntüsünü üretir,
  /// geçici bir dosyaya kaydeder ve paylaşır. Görsel henüz çizilmemişse
  /// (boundary bulunamazsa) sessizce çıkar.
  static Future<void> captureAndShare({
    required GlobalKey boundaryKey,
    String text = '',
    double pixelRatio = 3.0,
  }) async {
    final boundary =
        boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    // ui.Image → PNG byte'ları.
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) return;
    final bytes = byteData.buffer.asUint8List();

    // Geçici dosyaya yaz.
    final dir = await getTemporaryDirectory();
    final fileName = 'competra_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    // Sistem paylaşım sayfası.
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: text),
    );
    AnalyticsService.logShareResult().ignore();
  }

  /// Yalnızca metin paylaşır.
  static Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
    AnalyticsService.logShareResult().ignore();
  }
}

/// Turnuva şampiyonu için paylaşılabilir, markalı kart görseli.
///
/// Bu widget bir [RepaintBoundary] içine alınıp görüntüsü yakalanır; bu yüzden
/// renkleri kasıtlı olarak temadan bağımsız, sabit marka renkleridir (üretilen
/// görselin uygulama temasından etkilenmemesi için).
class ChampionShareCard extends StatelessWidget {
  const ChampionShareCard({
    super.key,
    required this.tournamentName,
    required this.championName,
    required this.totalMatches,
    required this.totalGoals,
  });

  final String tournamentName;
  final String championName;
  final int totalMatches;
  final int totalGoals;

  // Sabit marka renkleri (paylaşım görseli temadan bağımsızdır).
  static const Color _bg = Color(0xFF0A1F14);
  static const Color _gold = Color(0xFFFFD700);
  static const Color _green = Color(0xFF1FC36B);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _green.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Üst: Competra wordmark.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_soccer, color: _green, size: 22),
              const SizedBox(width: 8),
              Text(
                'COMPETRA',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Kupa.
          const Icon(Icons.emoji_events, color: _gold, size: 72),
          const SizedBox(height: 12),

          // "🏆 Şampiyon" başlığı.
          const Text(
            '🏆 ŞAMPİYON',
            style: TextStyle(
              color: _gold,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 14),

          // Kazanan kullanıcı adı (büyük, bold).
          Text(
            championName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 32,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),

          // Turnuva adı.
          Text(
            tournamentName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 28),

          // İstatistikler: toplam maç, toplam gol.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ShareStat(value: '$totalMatches', label: 'Maç'),
              Container(
                width: 1,
                height: 40,
                margin: const EdgeInsets.symmetric(horizontal: 28),
                color: Colors.white.withValues(alpha: 0.15),
              ),
              _ShareStat(value: '$totalGoals', label: 'Gol'),
            ],
          ),
          const SizedBox(height: 28),

          // Watermark.
          Text(
            'competra.app',
            style: TextStyle(
              color: _green.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareStat extends StatelessWidget {
  const _ShareStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: ChampionShareCard._gold,
            fontWeight: FontWeight.w900,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Turnuva gol kralı için paylaşılabilir, markalı kart görseli.
class ScorerShareCard extends StatelessWidget {
  const ScorerShareCard({
    super.key,
    required this.tournamentName,
    required this.scorerName,
    required this.goals,
  });

  final String tournamentName;
  final String scorerName;
  final int goals;

  static const Color _bg = Color(0xFF0A1F14);
  static const Color _gold = Color(0xFFFFD700);
  static const Color _green = Color(0xFF1FC36B);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _green.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_soccer, color: _green, size: 22),
              const SizedBox(width: 8),
              Text(
                'COMPETRA',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Icon(Icons.sports_soccer, color: _gold, size: 72),
          const SizedBox(height: 12),
          const Text(
            '⚽ GOL KRALI',
            style: TextStyle(
              color: _gold,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            scorerName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 32,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tournamentName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            '$goals Gol',
            style: const TextStyle(
              color: _gold,
              fontWeight: FontWeight.w900,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'competra.app',
            style: TextStyle(
              color: _green.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Turnuva genel özeti için paylaşılabilir, markalı kart görseli.
class SummaryShareCard extends StatelessWidget {
  const SummaryShareCard({
    super.key,
    required this.tournamentName,
    required this.totalMatches,
    required this.totalGoals,
    required this.totalPlayers,
  });

  final String tournamentName;
  final int totalMatches;
  final int totalGoals;
  final int totalPlayers;

  static const Color _bg = Color(0xFF0A1F14);
  static const Color _gold = Color(0xFFFFD700);
  static const Color _green = Color(0xFF1FC36B);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _green.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_soccer, color: _green, size: 22),
              const SizedBox(width: 8),
              Text(
                'COMPETRA',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Icon(Icons.insights, color: _gold, size: 72),
          const SizedBox(height: 12),
          const Text(
            '📊 TURNUVA ÖZETİ',
            style: TextStyle(
              color: _gold,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            tournamentName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 28,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text(
                    '$totalMatches',
                    style: const TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Maç',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    '$totalGoals',
                    style: const TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Gol',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    '$totalPlayers',
                    style: const TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Oyuncu',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'competra.app',
            style: TextStyle(
              color: _green.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
