import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/billing_service.dart';

/// Rebuilds whenever the user's Pro entitlement status changes -- e.g. right
/// after a successful purchase or restore on the paywall -- so a Pro-gated
/// screen doesn't need its own [BillingService.customerInfoStream]
/// subscription/dispose boilerplate just to stay in sync.
class ProStatusBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, bool isPro) builder;

  const ProStatusBuilder({required this.builder, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CustomerInfo>(
      stream: BillingService.instance.customerInfoStream,
      builder: (context, snapshot) => builder(context, BillingService.instance.isPro),
    );
  }
}
