import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 80});
  final double height;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context).colorScheme.surfaceContainerLow;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context).colorScheme.surfaceContainerLow;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListTile(
        leading: CircleAvatar(backgroundColor: base, radius: 20),
        title: Container(
            height: 14,
            color: base,
            margin: const EdgeInsets.only(right: 80)),
        subtitle: Container(
            height: 10,
            color: base,
            margin: const EdgeInsets.only(right: 40, top: 4)),
      ),
    );
  }
}
