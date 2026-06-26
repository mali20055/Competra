import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    if (isOnline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.error,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 14,
               color: Theme.of(context).colorScheme.onError),
          const SizedBox(width: 8),
          Text(
            'Çevrimdışı — veriler kaydedilecek',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
        ],
      ),
    );
  }
}
