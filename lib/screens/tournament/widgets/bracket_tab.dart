import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/bracket_utils.dart';
import '../../../models/tournament.dart';
import 'bracket_painter.dart';

class BracketTab extends ConsumerStatefulWidget {
  const BracketTab({
    super.key,
    required this.tournament,
    required this.matches,
  });

  final Tournament tournament;
  final List<TournamentMatch> matches;

  @override
  ConsumerState<BracketTab> createState() => _BracketTabState();
}

class _BracketTabState extends ConsumerState<BracketTab> {
  final GlobalKey _boundaryKey = GlobalKey();

  Future<void> _shareBracket() async {
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();
      if (pngBytes == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/bracket_${widget.tournament.id}.png').create();
      await file.writeAsBytes(pngBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Turnuva braketi! ${widget.tournament.name} 🏆',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paylaşım hatası: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // We search matches with phase == 'knockout'
    final rounds = buildBracketTree(widget.matches, 'knockout');

    if (rounds.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_tree_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Eleme aşaması henüz başlamadı.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Map player IDs to usernames
    final Map<String, String> playerNames = {
      for (final p in widget.tournament.participants) p.uid: p.username
    };

    // Calculate canvas size
    final int maxMatches = rounds.first.length;
    const double bWidth = BracketPainter.boxWidth;
    const double bHeight = BracketPainter.boxHeight;
    const double hGap = BracketPainter.horizontalGap;
    const double vGap = BracketPainter.verticalGap;

    final double canvasWidth = rounds.length * (bWidth + hGap) + hGap;
    final double canvasHeight = maxMatches * (bHeight * 2 + vGap) + vGap * 2;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _shareBracket,
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Braketi Paylaş'),
              ),
            ],
          ),
        ),
        Expanded(
          child: InteractiveViewer(
            constrained: false,
            minScale: 0.2,
            maxScale: 2.5,
            child: RepaintBoundary(
              key: _boundaryKey,
              child: Container(
                color: scheme.surface,
                padding: const EdgeInsets.all(16),
                child: CustomPaint(
                  size: Size(canvasWidth, canvasHeight),
                  painter: BracketPainter(
                    rounds: rounds,
                    playerNames: playerNames,
                    colorScheme: scheme,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
