import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// Product IDs -- will be activated when Play Store review completes. These
// must match whatever is configured as the Google Play product ids once
// they exist; until then no live product will ever resolve to these.
const String kMonthlyProductId = 'ptolemy_pro_monthly';
const String kYearlyProductId = 'ptolemy_pro_yearly';
const String kRevenueCatApiKey = 'REVENUECAT_API_KEY_PLACEHOLDER';

/// Shown wherever a billing operation fails while the API key/products are
/// still placeholders -- i.e. essentially always, until the Play Store
/// review completes and real values replace the constants above.
const String kBillingUnavailableMessage =
    'Subscriptions will be available when the app launches publicly. Thank you for your patience.';

/// Thrown by [BillingService] operations that fail for any reason other than
/// the user backing out of the purchase flow themselves. [message] is always
/// user-facing copy, safe to show directly.
class BillingException implements Exception {
  final String message;
  BillingException(this.message);

  @override
  String toString() => message;
}

/// Thrown when the user cancels the native purchase sheet -- distinct from
/// [BillingException] so callers can silently reset to idle rather than
/// showing an error for something the user did on purpose.
class PurchaseCancelledException implements Exception {}

/// Thin wrapper around the RevenueCat `purchases_flutter` SDK: configuration,
/// offerings, purchasing, restoring, and the current Pro entitlement state.
///
/// Every operation here degrades gracefully rather than throwing a raw
/// platform exception -- with a placeholder API key and no real Google Play
/// products yet, every real network call to RevenueCat is expected to fail
/// until the Play Store review completes, and that failure needs to reach
/// the UI as [kBillingUnavailableMessage] rather than a crash.
class BillingService {
  BillingService._();
  static final BillingService instance = BillingService._();

  bool _configured = false;
  CustomerInfo? _customerInfo;
  final _customerInfoController = StreamController<CustomerInfo>.broadcast();

  /// Emits every time RevenueCat reports a new [CustomerInfo] -- on
  /// [initialize], after a purchase, after a restore, or from a background
  /// entitlement refresh -- so any UI watching Pro status stays live.
  Stream<CustomerInfo> get customerInfoStream => _customerInfoController.stream;

  /// The most recently received customer info, if any -- exposed so callers
  /// that need more than a boolean (e.g. Settings showing a renewal date)
  /// can read entitlement details without re-deriving them.
  CustomerInfo? get customerInfo => _customerInfo;

  /// Test-only override for [isPro], since constructing a real [CustomerInfo]
  /// (a freezed class with many required fields) just to flip Pro state on
  /// in a widget test is needless ceremony. Must be reset to null in
  /// tearDown so state doesn't leak between tests.
  @visibleForTesting
  bool? debugIsProOverride;

  /// True once an active entitlement is present. Checks "any active
  /// entitlement" rather than a specific entitlement identifier because the
  /// real entitlement isn't configured in the RevenueCat dashboard yet --
  /// narrow this to a specific id once the Play Store products (and the
  /// entitlement they attach to) exist.
  bool get isPro => debugIsProOverride ?? (_customerInfo?.entitlements.active.isNotEmpty ?? false);

  Future<void> initialize() async {
    try {
      await Purchases.setLogLevel(LogLevel.warn);
      await Purchases.configure(PurchasesConfiguration(kRevenueCatApiKey));
      _configured = true;
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
      try {
        _onCustomerInfoUpdated(await Purchases.getCustomerInfo());
      } catch (_) {
        // Non-fatal: isPro just stays false until the first successful fetch.
      }
    } catch (e) {
      // Expected until the real API key is in place -- don't crash startup.
      _configured = false;
      debugPrint('BillingService: RevenueCat configuration failed (expected with a placeholder API key): $e');
    }
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    _customerInfo = info;
    _customerInfoController.add(info);
  }

  Future<Offerings> getOfferings() async {
    _ensureConfigured();
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      _throwFriendly(e);
    }
  }

  Future<CustomerInfo> purchasePackage(Package package) async {
    _ensureConfigured();
    try {
      final info = await Purchases.purchasePackage(package);
      _onCustomerInfoUpdated(info);
      return info;
    } catch (e) {
      _throwFriendly(e);
    }
  }

  Future<CustomerInfo> restorePurchases() async {
    _ensureConfigured();
    try {
      final info = await Purchases.restorePurchases();
      _onCustomerInfoUpdated(info);
      return info;
    } catch (e) {
      _throwFriendly(e);
    }
  }

  void _ensureConfigured() {
    if (!_configured) throw BillingException(kBillingUnavailableMessage);
  }

  /// Converts any RevenueCat failure into either [PurchaseCancelledException]
  /// (the user closed the purchase sheet themselves) or [BillingException]
  /// with the standard placeholder-setup message -- callers never need to
  /// know about [PlatformException] or [PurchasesErrorCode] directly.
  Never _throwFriendly(Object e) {
    if (e is PlatformException) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        throw PurchaseCancelledException();
      }
    }
    throw BillingException(kBillingUnavailableMessage);
  }

  void dispose() {
    Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    _customerInfoController.close();
  }
}
