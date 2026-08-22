import 'package:flutter/material.dart';

import '../../features/auth/data/auth_service.dart';
import '../../features/auth/data/me_service.dart';
import '../../features/auth/presentation/email_verification_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/provider/presentation/provider_enablement_page.dart';
import 'client_shell.dart';
import 'provider_shell.dart';

class RoleGatePage extends StatefulWidget {
  const RoleGatePage({super.key});

  @override
  State<RoleGatePage> createState() => _RoleGatePageState();
}

class _RoleGatePageState extends State<RoleGatePage> {
  final MeService _me = MeService();
  final AuthService _auth = AuthService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _profile = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await _me.getMe();
      if (mounted) setState(() => _profile = Map<String, dynamic>.from(value));
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'No pudimos abrir tu cuenta. Revisa tu conexión e intenta nuevamente.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Reintentar')),
              ],
            ),
          ),
        ),
      );
    }

    final emailStatus = _profile['email_verification_status']
        ?.toString()
        .toUpperCase();
    if (emailStatus != 'VERIFIED') return const EmailVerificationPage();

    final modes = _profile['modes'] is Map
        ? Map<String, dynamic>.from(_profile['modes'] as Map)
        : <String, dynamic>{};
    final activeMode =
        (_profile['active_mode'] ?? modes['active_mode'] ?? 'client')
            .toString()
            .toLowerCase();
    final canProvide = modes['can_provide'] == true;

    if (activeMode == 'provider') {
      if (canProvide) return const ProviderShell();
      return const ProviderEnablementPage();
    }
    return const ClientShell();
  }
}
