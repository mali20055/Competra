import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'offline_banner.dart';

/// Bottom navigation barı barındıran kabuk (shell).
///
/// [StatefulNavigationShell] her sekmenin kendi navigasyon yığınını ve
/// durumunu korumasını sağlar (IndexedStack mantığı).
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    // Aynı sekmeye tekrar dokunulursa o sekmeyi köküne döndür.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Fiziksel geri tuşunda uygulama doğrudan kapanmasın.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          // Pop edilecek bir sayfa varsa onu pop et.
          router.pop();
        } else if (navigationShell.currentIndex != 0) {
          // Kök sekmedeyiz ve Home değiliz → Home sekmesine dön.
          navigationShell.goBranch(0);
        }
        // Home sekmesindeyken: hiçbir şey yapma (uygulama kapanmaz).
      },
      child: Scaffold(
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: navigationShell),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            activeIcon: Icon(Icons.emoji_events),
            label: 'Leagues',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.casino_outlined),
            activeIcon: Icon(Icons.casino),
            label: 'Wheel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_outlined),
            activeIcon: Icon(Icons.group),
            label: 'Social',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        ),
      ),
    );
  }
}
