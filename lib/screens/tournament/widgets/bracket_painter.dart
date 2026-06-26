import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/tournament.dart';

class BracketPainter extends CustomPainter {
  final List<List<TournamentMatch>> rounds;
  final Map<String, String> playerNames; // uid → kullanıcı adı
  final ColorScheme colorScheme;

  // Sabitler
  static const double boxWidth = 140;
  static const double boxHeight = 28; // Her oyuncu satırı 28px, toplam 56px
  static const double horizontalGap = 40;
  static const double verticalGap = 24;

  BracketPainter({
    required this.rounds,
    required this.playerNames,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rounds.isEmpty) return;

    final matchHeight = boxHeight * 2;
    final matchPositions = <int, Map<int, Offset>>{};

    // 1. Tüm maç konumlarını hesapla
    for (int r = 0; r < rounds.length; r++) {
      matchPositions[r] = {};
      final roundMatches = rounds[r];
      for (int i = 0; i < roundMatches.length; i++) {
        double x = horizontalGap / 2 + r * (boxWidth + horizontalGap);
        double y;
        if (r == 0) {
          y = verticalGap + i * (matchHeight + verticalGap);
        } else {
          final prevRoundPositions = matchPositions[r - 1]!;
          final child1Index = 2 * i;
          final child2Index = 2 * i + 1;
          final p1 = prevRoundPositions[child1Index];
          final p2 = prevRoundPositions[child2Index];
          if (p1 != null && p2 != null) {
            y = (p1.dy + p2.dy) / 2;
          } else if (p1 != null) {
            y = p1.dy;
          } else {
            y = verticalGap + i * (matchHeight + verticalGap * math.pow(2, r));
          }
        }
        matchPositions[r]![i] = Offset(x, y);
      }
    }

    // 2. Turlar arasındaki bağlantı çizgilerini çiz
    for (int r = 0; r < rounds.length - 1; r++) {
      final roundMatches = rounds[r];
      for (int i = 0; i < roundMatches.length; i++) {
        final topLeft = matchPositions[r]![i];
        final parentIndex = i ~/ 2;
        final parentTopLeft = matchPositions[r + 1]?[parentIndex];

        if (topLeft != null && parentTopLeft != null) {
          final fromRight = Offset(topLeft.dx + boxWidth, topLeft.dy + boxHeight);
          final toLeftY = (i % 2 == 0)
              ? parentTopLeft.dy + boxHeight / 2
              : parentTopLeft.dy + boxHeight * 1.5;
          final toLeft = Offset(parentTopLeft.dx, toLeftY);

          drawConnectorLines(canvas, fromRight, toLeft);
        }
      }
    }

    // 3. Maç kutularını çiz
    for (int r = 0; r < rounds.length; r++) {
      final roundMatches = rounds[r];
      for (int i = 0; i < roundMatches.length; i++) {
        final topLeft = matchPositions[r]![i];
        if (topLeft != null) {
          final match = roundMatches[i];
          final homeName = playerNames[match.homeUid] ?? match.homeName;
          final awayName = playerNames[match.awayUid] ?? match.awayName;
          drawMatchBox(canvas, topLeft, match, homeName, awayName);
        }
      }
    }
  }

  void drawMatchBox(Canvas canvas, Offset topLeft,
                    TournamentMatch match, String homeName, String awayName) {
    final matchHeight = boxHeight * 2;
    final rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, boxWidth, matchHeight);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    // Arka plan
    final bgPaint = Paint()..color = colorScheme.surface;
    canvas.drawRRect(rrect, bgPaint);

    // Kutu Kenarlığı
    final borderPaint = Paint()
      ..color = colorScheme.outline.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(rrect, borderPaint);

    // Yatay Ayırıcı Çizgi
    final dividerPaint = Paint()
      ..color = colorScheme.outline.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(topLeft.dx, topLeft.dy + boxHeight),
      Offset(topLeft.dx + boxWidth, topLeft.dy + boxHeight),
      dividerPaint,
    );

    // Kazanan durum tespiti
    final isHomeWinner = match.isFinal && 
        match.homeScore != null && 
        match.awayScore != null && 
        match.homeScore! > match.awayScore!;
    final isAwayWinner = match.isFinal && 
        match.homeScore != null && 
        match.awayScore != null && 
        match.awayScore! > match.homeScore!;

    // Home Oyuncu Satırı
    _drawPlayerRow(
      canvas: canvas,
      rectTopLeft: topLeft,
      playerName: homeName,
      score: match.homeScore,
      isWinner: isHomeWinner,
      isBye: match.isBye && match.homeUid.isNotEmpty && match.awayUid.isEmpty,
    );

    // Away Oyuncu Satırı
    _drawPlayerRow(
      canvas: canvas,
      rectTopLeft: Offset(topLeft.dx, topLeft.dy + boxHeight),
      playerName: match.isBye && match.awayUid.isEmpty ? 'BYE' : awayName,
      score: match.awayScore,
      isWinner: isAwayWinner,
      isBye: match.isBye && match.awayUid.isNotEmpty && match.homeUid.isEmpty,
    );
  }

  void _drawPlayerRow({
    required Canvas canvas,
    required Offset rectTopLeft,
    required String playerName,
    required int? score,
    required bool isWinner,
    required bool isBye,
  }) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final name = playerName.length > 12 ? '${playerName.substring(0, 10)}..' : playerName;

    textPainter.text = TextSpan(
      text: name,
      style: TextStyle(
        color: isWinner
            ? colorScheme.primary
            : (score == null && !isBye ? colorScheme.onSurface : colorScheme.onSurfaceVariant),
        fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
        fontSize: 11,
      ),
    );
    textPainter.layout(maxWidth: boxWidth - 36);
    textPainter.paint(canvas, Offset(rectTopLeft.dx + 8, rectTopLeft.dy + (boxHeight - 14) / 2));

    String scoreText = '';
    if (isBye) {
      scoreText = 'BYE';
    } else if (score != null) {
      scoreText = score.toString();
    }

    if (scoreText.isNotEmpty) {
      textPainter.text = TextSpan(
        text: scoreText,
        style: TextStyle(
          color: isWinner ? colorScheme.primary : colorScheme.onSurfaceVariant,
          fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
          fontSize: 11,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(rectTopLeft.dx + boxWidth - textPainter.width - 8, rectTopLeft.dy + (boxHeight - 14) / 2),
      );
    }
  }

  void drawConnectorLines(Canvas canvas, Offset fromRight, Offset toLeft) {
    final paint = Paint()
      ..color = colorScheme.outline.withValues(alpha: 0.4)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final midX = (fromRight.dx + toLeft.dx) / 2;
    final path = Path()
      ..moveTo(fromRight.dx, fromRight.dy)
      ..lineTo(midX, fromRight.dy)
      ..lineTo(midX, toLeft.dy)
      ..lineTo(toLeft.dx, toLeft.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(BracketPainter old) =>
      old.rounds != rounds || old.playerNames != playerNames;
}
