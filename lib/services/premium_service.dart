import 'package:purchases_flutter/purchases_flutter.dart';

class PremiumService {
  static Future<bool> isPremium() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey('premium');
    } catch (_) {
      return false;
    }
  }

  static Future<void> purchase(String packageId) async {
    final offerings = await Purchases.getOfferings();
    final package = offerings.current?.availablePackages
        .firstWhere((p) => p.identifier == packageId);
    if (package != null) {
      // ignore: deprecated_member_use
      await Purchases.purchasePackage(package);
    }
  }

  static Future<void> restorePurchases() async {
    await Purchases.restorePurchases();
  }
}
