import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<bool>(
  (ref) => Connectivity()
      .onConnectivityChanged
      .map((result) => result.isNotEmpty && !result.contains(ConnectivityResult.none)),
);

final isOnlineProvider = Provider<bool>(
  (ref) => ref.watch(connectivityProvider).asData?.value ?? true,
);
