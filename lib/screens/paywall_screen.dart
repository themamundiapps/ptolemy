import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/billing_service.dart';
import '../theme.dart';
import '../widgets/armillary_sphere_icon.dart';

/// Pushes the paywall as a full-screen route. The single entry point every
/// Pro-gated location in the app should call instead of building its own
/// "Unlock with Pro" sheet.
Future<void> showPaywallScreen(BuildContext context) {
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaywallScreen(), fullscreenDialog: true));
}

const _features = [
  'All 6 Electional themes',
  'Daily Transit interpretations',
  'Personalized Chart Analysis',
  'Synastry readings',
  'Traditional health recommendations',
  'Save multiple charts',
];

enum _Plan { yearly, monthly }

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  _Plan _selected = _Plan.yearly;
  Offerings? _offerings;
  bool _purchasing = false;
  bool _restoring = false;
  bool _success = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await BillingService.instance.getOfferings();
      if (mounted) setState(() => _offerings = offerings);
    } catch (_) {
      // Expected with placeholder RevenueCat setup -- the screen falls back
      // to static display pricing, and any real purchase attempt will still
      // surface the standard "not available yet" message.
    }
  }

  Package? _packageFor(_Plan plan) {
    final current = _offerings?.current;
    if (current == null) return null;
    return plan == _Plan.yearly ? current.annual : current.monthly;
  }

  Future<void> _subscribe() async {
    setState(() {
      _purchasing = true;
      _message = null;
    });
    try {
      final package = _packageFor(_selected);
      if (package == null) {
        throw BillingException(kBillingUnavailableMessage);
      }
      await BillingService.instance.purchasePackage(package);
      if (!mounted) return;
      setState(() {
        _purchasing = false;
        _success = true;
      });
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.of(context).pop();
    } on PurchaseCancelledException {
      if (mounted) setState(() => _purchasing = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _purchasing = false;
        _message = e is BillingException ? e.message : kBillingUnavailableMessage;
      });
    }
  }

  Future<void> _restore() async {
    setState(() {
      _restoring = true;
      _message = null;
    });
    try {
      await BillingService.instance.restorePurchases();
      if (!mounted) return;
      if (BillingService.instance.isPro) {
        setState(() {
          _restoring = false;
          _success = true;
        });
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() {
          _restoring = false;
          _message = 'No active subscription found to restore.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _message = e is BillingException ? e.message : kBillingUnavailableMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _purchasing || _restoring;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _success
            ? const _SuccessBody()
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  children: [
                    const ArmillarySphereIcon(size: 72),
                    const SizedBox(height: 20),
                    Text('Ptolemy Pro', style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text(
                      'The complete traditional astrology experience',
                      style: TextStyle(color: AppColors.mutedText, fontSize: 14, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [for (final feature in _features) _FeatureRow(text: feature)],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _PlanCard(
                            title: 'Yearly',
                            priceLine: _yearlyPriceLine(),
                            subLine: _yearlyMonthlyEquivalent(),
                            badge: 'Best Value',
                            selected: _selected == _Plan.yearly,
                            onTap: () => setState(() => _selected = _Plan.yearly),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PlanCard(
                            title: 'Monthly',
                            priceLine: _monthlyPriceLine(),
                            subLine: null,
                            badge: null,
                            selected: _selected == _Plan.monthly,
                            onTap: () => setState(() => _selected = _Plan.monthly),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_message != null) ...[
                      Text(
                        _message!,
                        style: const TextStyle(color: AppColors.warning, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy ? null : _subscribe,
                        child: _purchasing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                              )
                            : const Text('Subscribe'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: busy ? null : _restore,
                      child: _restoring
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mutedGold),
                            )
                          : const Text('Restore Purchase', style: TextStyle(color: AppColors.mutedGold, fontSize: 13)),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: busy ? null : () => Navigator.of(context).pop(),
                      child: const Text('Maybe later', style: TextStyle(color: AppColors.mutedText, fontSize: 13)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  String _yearlyPriceLine() {
    final package = _packageFor(_Plan.yearly);
    return package?.storeProduct.priceString ?? '\$19.99/year';
  }

  String? _yearlyMonthlyEquivalent() {
    final package = _packageFor(_Plan.yearly);
    if (package == null) return '\$1.67/month';
    final monthly = package.storeProduct.price / 12;
    return '\$${monthly.toStringAsFixed(2)}/month';
  }

  String _monthlyPriceLine() {
    final package = _packageFor(_Plan.monthly);
    return package?.storeProduct.priceString ?? '\$3.99/month';
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;

  const _FeatureRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✦', style: TextStyle(color: AppColors.gold, fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.bodyText, fontSize: 15, height: 1.3))),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String priceLine;
  final String? subLine;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.priceLine,
    required this.subLine,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.gold : Colors.white24, width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  badge!.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.background,
                    fontSize: 10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(title, style: const TextStyle(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(priceLine, style: const TextStyle(color: AppColors.bodyText, fontSize: 14)),
            if (subLine != null) ...[
              const SizedBox(height: 2),
              Text(subLine!, style: const TextStyle(color: AppColors.mutedText, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuccessBody extends StatelessWidget {
  const _SuccessBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.gold, size: 56),
            const SizedBox(height: 16),
            Text("You're all set", style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Welcome to Ptolemy Pro.',
              style: TextStyle(color: AppColors.mutedText, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
