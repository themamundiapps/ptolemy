import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_client.dart';
import '../theme.dart';

/// A dismiss-free top banner shown only while the backend health check
/// fails, with a manual retry -- distinct from the action-specific error
/// messages shown inline on individual requests (calculation failures,
/// electional timeouts), since this is a passive, persistent connectivity
/// signal rather than a response to something the user just did.
class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _unreachable = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final reachable = await _pingBackend();
    if (!mounted) return;
    setState(() {
      _unreachable = !reachable;
      _checking = false;
    });
  }

  Future<bool> _pingBackend() async {
    try {
      final uri = Uri.parse('${defaultBaseUrl()}/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_unreachable) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppColors.warning.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'No connection — some features may be unavailable',
              style: TextStyle(color: AppColors.warning, fontSize: 12.5),
            ),
          ),
          TextButton(
            onPressed: _checking ? null : _check,
            child: const Text('Retry', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
